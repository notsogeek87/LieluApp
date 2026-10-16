import 'dart:io';

import 'package:dio/dio.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/install/apk_downloader.dart';
import 'package:lieluapp/install/apk_verifier.dart';
import 'package:lieluapp/install/install_models.dart';
import 'package:lieluapp/platform/store_platform.dart';
import 'package:lieluapp/releases/release_models.dart';

typedef DownloadFn = Future<File> Function(
  String url,
  String destPath, {
  int? expectedSize,
  CancelToken? cancelToken,
  void Function(int received, int total)? onProgress,
});

/// Parcours complet d'une installation : autorisation → téléchargement →
/// intégrité → lecture de l'APK par Android → contrôles → installation.
///
/// Chaque étape qui échoue s'arrête avec un message compréhensible ; rien
/// n'est installé tant que toutes les vérifications n'ont pas réussi.
final class InstallService {
  final StorePlatform platform;
  final DownloadFn download;
  final Future<String> Function(String url) fetchText;
  final Future<Directory> Function() workDir;
  final Future<void> Function(CatalogEntry entry, ReleaseInfo release)? onInstalled;

  InstallService({
    required this.platform,
    required this.download,
    required this.fetchText,
    required this.workDir,
    this.onInstalled,
  });

  Future<void> run(
    CatalogEntry entry,
    ReleaseInfo release,
    CancelToken cancel,
    void Function(InstallState) emit,
  ) async {
    final label = release.version.toString();
    var state = InstallState(
      appId: entry.id,
      appName: entry.name,
      versionLabel: label,
      phase: InstallPhase.downloading,
      at: DateTime.now(),
    );
    void set(InstallState s) {
      state = s;
      emit(s);
    }

    void fail(String message) =>
        set(state.copyWith(phase: InstallPhase.failed, message: message));

    final apk = release.apk;
    if (apk == null) {
      fail(release.apkProblem ?? 'Aucun APK disponible pour cette version.');
      return;
    }

    File? file;
    try {
      set(state);
      if (!await platform.canInstallPackages()) {
        set(state.copyWith(
          phase: InstallPhase.needsPermission,
          message: 'Autorisez Lielu Store à installer des applications, '
              'puis revenez ici : le téléchargement reprendra.',
        ));
        return;
      }

      final dir = await workDir();
      final path = '${dir.path}/${entry.id}-${release.tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.apk';
      file = await download(
        apk.url,
        path,
        expectedSize: apk.size,
        cancelToken: cancel,
        onProgress: (received, total) =>
            set(state.copyWith(received: received, total: total)),
      );

      if (cancel.isCancelled) {
        throw DioException.requestCancelled(
            requestOptions: RequestOptions(path: apk.url), reason: 'annulé');
      }
      set(state.copyWith(phase: InstallPhase.verifying, message: 'Vérification du fichier…'));

      // Intégrité : somme de contrôle publiée par GitHub (digest) ou fichier .sha256.
      var expected = apk.sha256;
      if (expected == null && apk.checksumUrl != null) {
        try {
          expected = parseSha256File(await fetchText(apk.checksumUrl!));
        } on Object {
          expected = null;
        }
      }
      String integrity;
      if (expected != null) {
        final actual = await sha256OfFile(file);
        if (actual != expected) {
          await file.delete();
          fail('La somme de contrôle SHA-256 du fichier ne correspond pas à celle publiée '
              'par GitHub. Le fichier a été supprimé, rien n\'a été installé.');
          return;
        }
        integrity = 'Intégrité vérifiée (SHA-256 identique à celui publié sur GitHub).';
      } else {
        integrity =
            'Aucune somme de contrôle publiée pour ce fichier : intégrité non vérifiée.';
      }
      set(state.copyWith(integrityNote: integrity));

      final device = await platform.deviceInfo();
      final installed = (await platform.installed([entry.packageName]))[entry.packageName];
      final ApkInspection inspection;
      try {
        inspection = await platform.inspectApk(file.path);
      } on Object {
        fail('Android n\'a pas pu lire ce fichier : l\'APK est invalide ou corrompu.');
        return;
      }
      final verdict =
          verifyApk(entry: entry, apk: inspection, device: device, installed: installed);
      if (!verdict.ok) {
        fail(verdict.error!);
        return;
      }
      set(state.copyWith(
        phase: InstallPhase.awaitingConfirmation,
        signatureNote: verdict.signatureNote,
        message: 'Confirmez l\'installation dans la fenêtre Android.',
      ));

      final result = await platform.install(file.path, entry.packageName);
      if (result.ok) {
        await onInstalled?.call(entry, release);
        set(state.copyWith(
            phase: InstallPhase.installed, message: '${entry.name} $label est installée.'));
      } else if (result.code == 'cancelled') {
        set(state.copyWith(
            phase: InstallPhase.cancelled, message: 'Installation annulée.'));
      } else {
        fail(describeInstallFailure(result.code, result.message));
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        set(state.copyWith(
            phase: InstallPhase.cancelled, message: 'Téléchargement annulé.'));
      } else {
        fail('Téléchargement impossible : ${e.message ?? 'erreur réseau'}.');
      }
    } on DownloadException catch (e) {
      fail(e.message);
    } on UnsupportedError catch (e) {
      fail('${e.message}');
    } catch (e) {
      fail('Erreur inattendue : $e');
    } finally {
      // L'APK n'est jamais conservé : il est supprimé quelle que soit l'issue
      // (sauf attente d'autorisation, où rien n'a encore été téléchargé).
      try {
        if (file != null && await file.exists()) await file.delete();
      } on Object {
        // Nettoyage best-effort.
      }
    }
  }
}

String describeInstallFailure(String? code, String? detail) => switch (code) {
      'incompatible' =>
        'Android indique que cet APK n\'est pas compatible avec ce téléphone.',
      'conflict' =>
        'Android refuse cette installation : signature ou version en conflit avec '
            'l\'application déjà installée. Rien n\'a été modifié.',
      'storage' => 'Espace de stockage insuffisant sur le téléphone.',
      'invalid' => 'Android juge cet APK invalide ou corrompu.',
      'blocked' =>
        'Installation bloquée par Android ou par une règle de cet appareil.',
      _ => detail == null || detail.isEmpty
          ? 'L\'installation a échoué.'
          : 'L\'installation a échoué : $detail',
    };
