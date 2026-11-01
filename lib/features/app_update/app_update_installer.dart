import 'dart:io';

import 'package:lieluapp/features/app_update/app_update.dart';
import 'package:lieluapp/install/apk_downloader.dart';
import 'package:lieluapp/platform/store_platform.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/ui/widgets/links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('eu.lielu.lieluapp/apk_installer');

/// Refus d'une mise à jour du store (fichier non conforme ou clé différente).
final class StoreUpdateRejected implements Exception {
  final String message;

  /// Le store installé doit être désinstallé puis réinstallé à la main.
  final bool needsReinstall;
  const StoreUpdateRejected(this.message, {this.needsReinstall = false});
  @override
  String toString() => message;
}

/// Downloads [update]'s APK inside the app (progress reported in 0..1),
/// verifies it, and returns the local file path.
///
/// Même chaîne de confiance que pour les apps du catalogue : hôtes GitHub en
/// HTTPS à chaque redirection, SHA-256 publié par GitHub, puis lecture de l'APK
/// par Android (paquet, empreinte de la clé du store, version).
Future<String> downloadUpdateApk(
  AppUpdate update, {
  required StorePlatform platform,
  required void Function(double progress) onProgress,
  CancelToken? cancelToken,
}) async {
  final self = (await platform.installed([storePackageName]))[storePackageName];
  if (storeNeedsReinstall(self)) {
    throw const StoreUpdateRejected(
        'Lielu Store change de clé de signature (l\'ancienne était publique). '
        'Android ne peut pas faire ce passage par une mise à jour : désinstallez '
        'Lielu Store, puis installez la dernière version depuis GitHub. '
        'Vos apps installées ne sont pas touchées.',
        needsReinstall: true);
  }

  final cache = await getTemporaryDirectory();
  final dir = Directory('${cache.path}/apk_updates');
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final path = '${dir.path}/update.apk';

  final file = await ApkDownloader(Dio()).download(
    update.apkUrl,
    path,
    cancelToken: cancelToken,
    onProgress: (received, total) {
      if (total > 0) onProgress(received / total);
    },
  );
  try {
    if (update.sha256 != null && await sha256OfFile(file) != update.sha256) {
      throw const StoreUpdateRejected(
          'La somme de contrôle SHA-256 ne correspond pas à celle publiée par GitHub. '
          'Rien n\'a été installé.');
    }
    final ApkInspection apk;
    try {
      apk = await platform.inspectApk(file.path);
    } on Object {
      throw const StoreUpdateRejected('Android n\'a pas pu lire ce fichier : APK invalide.');
    }
    final installedBuild = int.tryParse((await PackageInfo.fromPlatform()).buildNumber);
    final problem = verifyStoreUpdate(apk, installedBuild: installedBuild);
    if (problem != null) throw StoreUpdateRejected(problem);
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  }
  return file.path;
}

Future<bool> canInstallApks() async =>
    await _channel.invokeMethod<bool>('canInstall') ?? false;

Future<void> openInstallPermissionSettings() =>
    _channel.invokeMethod('openInstallSettings');

Future<void> installApk(String path) =>
    _channel.invokeMethod('install', {'path': path});

/// Full in-app flow: dialog with download progress, then hand-off to the
/// system installer (a single confirmation sheet, no browser involved).
Future<void> downloadAndInstallUpdate(
    BuildContext context, AppUpdate update) async {
  final platform = ProviderScope.containerOf(context, listen: false).read(platformProvider);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateProgressDialog(update: update, platform: platform),
  );
}

class _UpdateProgressDialog extends StatefulWidget {
  final AppUpdate update;
  final StorePlatform platform;
  const _UpdateProgressDialog({required this.update, required this.platform});

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  final _cancel = CancelToken();
  double _progress = 0;
  String? _error;
  String? _apkPath;
  bool _needsPermission = false;
  bool _needsReinstall = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    if (!_cancel.isCancelled) _cancel.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _needsPermission = false;
      _needsReinstall = false;
      _progress = 0;
    });
    try {
      _apkPath ??= await downloadUpdateApk(
        widget.update,
        platform: widget.platform,
        cancelToken: _cancel,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      if (!await canInstallApks()) {
        setState(() => _needsPermission = true);
        return;
      }
      await installApk(_apkPath!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted || (e is DioException && CancelToken.isCancel(e))) return;
      setState(() {
        _error = '$e';
        _needsReinstall = e is StoreUpdateRejected && e.needsReinstall;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String body;
    if (_error != null) {
      body = _error!;
    } else if (_needsPermission) {
      body = 'Autorisez Lielu Store à installer des applications, puis revenez et réessayez.';
    } else {
      body = 'Téléchargement de ${widget.update.versionName}… '
          '${(_progress * 100).round()}%';
    }

    return AlertDialog(
      title: const Text('Mise à jour du store'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (_error == null && !_needsPermission) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        if (_needsPermission)
          FilledButton(
            onPressed: () async {
              await openInstallPermissionSettings();
            },
            child: const Text('Ouvrir les réglages'),
          ),
        if (_needsReinstall)
          FilledButton(
            onPressed: () => openUrl(context, storeReleasesUrl),
            child: const Text('Ouvrir GitHub'),
          )
        else if (_needsPermission || _error != null)
          FilledButton(onPressed: _run, child: const Text('Réessayer')),
      ],
    );
  }
}
