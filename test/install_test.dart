import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/core/url_policy.dart';
import 'package:lieluapp/core/version.dart';
import 'package:lieluapp/install/apk_downloader.dart';
import 'package:lieluapp/install/install_models.dart';
import 'package:lieluapp/install/install_service.dart';
import 'package:lieluapp/platform/store_platform.dart';
import 'package:lieluapp/releases/release_models.dart';

import 'support/fakes.dart';

final apkBytes = utf8.encode('faux contenu apk');
final goodSha = sha256.convert(apkBytes).toString();

final entry = CatalogEntry(
  id: 'demo',
  name: 'Demo',
  packageName: 'eu.lielu.demo',
  repo: 'o/r',
  category: 'Outils',
  shortDescription: 'x',
  description: 'x',
  release: ReleaseRules.fromJson(null),
);

ReleaseInfo release({String? sha, String? checksumUrl, int? size, bool noApk = false}) =>
    ReleaseInfo(
      tag: 'v1.0.10',
      version: AppVersion.tryParse('1.0.10')!,
      title: 'v1.0.10',
      notes: '',
      publishedAt: null,
      htmlUrl: '',
      prerelease: false,
      apk: noApk
          ? null
          : ApkAsset(
              name: 'Demo.apk',
              url: 'https://github.com/o/r/releases/download/v1.0.10/Demo.apk',
              size: size ?? apkBytes.length,
              sha256: sha,
              checksumUrl: checksumUrl),
      apkProblem: noApk ? 'Aucun APK' : null,
    );

ApkInspection inspection({String pkg = 'eu.lielu.demo', int code = 10}) => ApkInspection(
    packageName: pkg,
    versionName: '1.0.10',
    versionCode: code,
    minSdk: 26,
    signers: {'aa'},
    abis: {});

void main() {
  late Directory tmp;
  late FakePlatform platform;
  late List<InstallState> states;
  var recorded = <String>[];

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('store_test');
    platform = FakePlatform()..inspection = inspection();
    states = [];
    recorded = [];
  });
  tearDown(() => tmp.delete(recursive: true));

  InstallService service({Dio? dio}) {
    final d = ApkDownloader(dio ?? fakeDio((_) => bytes(apkBytes, 200)));
    return InstallService(
      platform: platform,
      download: d.download,
      fetchText: d.fetchSmallText,
      workDir: () async => tmp,
      onInstalled: (e, r) async => recorded.add(r.tag),
    );
  }

  Future<InstallState> run(InstallService s, ReleaseInfo r) async {
    await s.run(entry, r, CancelToken(), states.add);
    return states.last;
  }

  test('chemin nominal avec SHA-256 : installé, tag enregistré, APK supprimé', () async {
    final last = await run(service(), release(sha: goodSha));
    expect(last.phase, InstallPhase.installed);
    expect(last.integrityNote, contains('vérifiée'));
    expect(platform.installCalls, hasLength(1));
    expect(recorded, ['v1.0.10']);
    expect(tmp.listSync().whereType<File>(), isEmpty);
  });

  test('SHA-256 incorrect : rien n\'est installé, fichier supprimé', () async {
    final last = await run(service(), release(sha: 'f' * 64));
    expect(last.phase, InstallPhase.failed);
    expect(last.message, contains('somme de contrôle'));
    expect(platform.installCalls, isEmpty);
    expect(tmp.listSync().whereType<File>(), isEmpty);
  });

  test('sans somme de contrôle : installable mais l\'intégrité n\'est PAS déclarée vérifiée', () async {
    final last = await run(service(), release());
    expect(last.phase, InstallPhase.installed);
    expect(last.integrityNote, contains('non vérifiée'));
    expect(last.integrityNote, isNot(contains('Intégrité vérifiée')));
  });

  test('fichier .sha256 voisin téléchargé et appliqué', () async {
    final dio = fakeDio((o) => o.uri.path.endsWith('.sha256')
        ? bytes(utf8.encode('$goodSha  Demo.apk\n'), 200)
        : bytes(apkBytes, 200));
    final ok = await run(service(dio: dio),
        release(checksumUrl: 'https://github.com/o/r/releases/download/v1.0.10/Demo.apk.sha256'));
    expect(ok.integrityNote, contains('vérifiée'));

    states.clear();
    final badDio = fakeDio((o) => o.uri.path.endsWith('.sha256')
        ? bytes(utf8.encode('${'0' * 64}  Demo.apk'), 200)
        : bytes(apkBytes, 200));
    final bad = await run(service(dio: badDio),
        release(checksumUrl: 'https://github.com/o/r/releases/download/v1.0.10/Demo.apk.sha256'));
    expect(bad.phase, InstallPhase.failed);
  });

  test('taille inattendue (fichier tronqué) : échec', () async {
    final last = await run(service(), release(size: apkBytes.length + 100));
    expect(last.phase, InstallPhase.failed);
    expect(last.message, contains('incomplet'));
    expect(platform.installCalls, isEmpty);
  });

  test('autorisation « sources inconnues » manquante : on s\'arrête avant de télécharger', () async {
    platform.canInstall = false;
    final dio = fakeDio((_) => fail('aucun téléchargement attendu'));
    final last = await run(service(dio: dio), release(sha: goodSha));
    expect(last.phase, InstallPhase.needsPermission);
    expect(platform.installCalls, isEmpty);
  });

  test('APK d\'un autre paquet : refusé avant installation', () async {
    platform.inspection = inspection(pkg: 'com.pirate');
    final last = await run(service(), release(sha: goodSha));
    expect(last.phase, InstallPhase.failed);
    expect(platform.installCalls, isEmpty);
  });

  test('signature incompatible avec l\'app installée : jamais installé', () async {
    platform.installedApps['eu.lielu.demo'] = const InstalledInfo(
        packageName: 'eu.lielu.demo', versionName: '1.0.5', versionCode: 5, signers: {'zz'});
    final last = await run(service(), release(sha: goodSha));
    expect(last.phase, InstallPhase.failed);
    expect(last.message, contains('autre clé'));
    expect(platform.installCalls, isEmpty);
  });

  test('APK illisible par Android : message clair', () async {
    platform.inspectError = Exception('parse');
    final last = await run(service(), release(sha: goodSha));
    expect(last.phase, InstallPhase.failed);
    expect(last.message, contains('invalide ou corrompu'));
  });

  test('l\'utilisateur annule dans la fenêtre Android → annulé, pas une erreur', () async {
    platform.installResult = const InstallResult.failure('cancelled');
    final last = await run(service(), release(sha: goodSha));
    expect(last.phase, InstallPhase.cancelled);
    expect(recorded, isEmpty);
  });

  test('refus Android (conflit) : message compréhensible', () async {
    platform.installResult = const InstallResult.failure('conflict', 'INSTALL_FAILED_UPDATE_INCOMPATIBLE');
    final last = await run(service(), release(sha: goodSha));
    expect(last.phase, InstallPhase.failed);
    expect(last.message, contains('Rien n\'a été modifié'));
  });

  test('release sans APK exploitable : message du sélecteur', () async {
    final last = await run(service(), release(noApk: true));
    expect(last.phase, InstallPhase.failed);
    expect(last.message, 'Aucun APK');
  });

  test('annulation pendant le téléchargement : état annulé, fichier partiel supprimé', () async {
    final cancel = CancelToken();
    final s = service();
    final future = s.run(entry, release(sha: goodSha), cancel, (st) {
      states.add(st);
      if (st.received > 0) cancel.cancel('stop');
    });
    await future;
    expect(states.last.phase, InstallPhase.cancelled);
    expect(tmp.listSync().whereType<File>(), isEmpty);
  });

  group('ApkDownloader', () {
    test('suit la redirection GitHub → stockage de releases', () async {
      final dio = fakeDio((o) {
        if (o.uri.host == 'github.com') {
          return redirect('https://release-assets.githubusercontent.com/abc?sig=1');
        }
        return bytes(apkBytes, 200);
      });
      final f = await ApkDownloader(dio)
          .download('https://github.com/o/r/releases/download/v1/x.apk', '${tmp.path}/x.apk');
      expect(await f.readAsBytes(), apkBytes);
    });

    test('redirection vers un hôte non autorisé : bloquée', () async {
      final dio = fakeDio((_) => redirect('https://evil.example/x.apk'));
      expect(
          ApkDownloader(dio).download('https://github.com/o/r/x.apk', '${tmp.path}/x.apk'),
          throwsA(isA<DownloadException>()));
    });

    test('redirection vers HTTP : bloquée', () async {
      final dio = fakeDio((_) => redirect('http://objects.githubusercontent.com/x'));
      expect(
          ApkDownloader(dio).download('https://github.com/o/r/x.apk', '${tmp.path}/x.apk'),
          throwsA(isA<DownloadException>()));
    });

    test('URL de départ non autorisée : refusée sans requête', () async {
      final dio = fakeDio((_) => fail('aucune requête attendue'));
      expect(ApkDownloader(dio).download('https://evil.example/x.apk', '${tmp.path}/x.apk'),
          throwsA(isA<UrlRejected>()));
    });

    test('404 : message compréhensible', () async {
      final dio = fakeDio((_) => text('', 404));
      expect(
          ApkDownloader(dio).download('https://github.com/o/r/x.apk', '${tmp.path}/x.apk'),
          throwsA(predicate((e) => e is DownloadException && e.message.contains('404'))));
    });

    test('boucle de redirections interrompue', () async {
      final dio = fakeDio((_) => redirect('https://github.com/o/r/loop'));
      expect(
          ApkDownloader(dio).download('https://github.com/o/r/x.apk', '${tmp.path}/x.apk'),
          throwsA(predicate((e) => e is DownloadException && e.message.contains('redirections'))));
    });
  });

  test('parseSha256File lit « hex » et « hex  fichier »', () {
    expect(parseSha256File('${goodSha.toUpperCase()}  a.apk\n'), goodSha);
    expect(parseSha256File('pas de somme'), isNull);
  });
}
