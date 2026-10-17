import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/core/version.dart';
import 'package:lieluapp/install/apk_verifier.dart';
import 'package:lieluapp/platform/store_platform.dart';
import 'package:lieluapp/releases/release_models.dart';
import 'package:lieluapp/state/app_view.dart';

CatalogEntry entry({String? pinned, Map<String, dynamic>? release}) => CatalogEntry(
      id: 'demo',
      name: 'Demo',
      packageName: 'eu.lielu.demo',
      repo: 'o/r',
      category: 'Outils',
      shortDescription: 'x',
      description: 'x',
      signingCertSha256: pinned,
      release: ReleaseRules.fromJson(release ?? {'tagPattern': r'^v(\d+(?:\.\d+)*)$'}),
    );

ApkInspection apk({
  String pkg = 'eu.lielu.demo',
  int code = 10,
  int minSdk = 26,
  Set<String> signers = const {'aa'},
  Set<String> abis = const {},
}) =>
    ApkInspection(
        packageName: pkg,
        versionName: '1.0.$code',
        versionCode: code,
        minSdk: minSdk,
        signers: signers,
        abis: abis);

InstalledInfo inst({int code = 5, String name = '1.0.5', Set<String> signers = const {'aa'}}) =>
    InstalledInfo(
        packageName: 'eu.lielu.demo', versionName: name, versionCode: code, signers: signers);

const device = DeviceInfo(34, ['arm64-v8a']);

ReleaseInfo release(String tag, String version) => ReleaseInfo(
      tag: tag,
      version: AppVersion.tryParse(version)!,
      title: tag,
      notes: '',
      publishedAt: null,
      htmlUrl: '',
      prerelease: false,
      apk: null,
      apkProblem: null,
    );

void main() {
  group('verifyApk', () {
    test('mise à jour normale, même signature : acceptée et dit ce qui a été comparé', () {
      final v = verifyApk(entry: entry(), apk: apk(), device: device, installed: inst());
      expect(v.ok, isTrue);
      expect(v.signatureNote, contains('identique'));
    });

    test('mauvais package : refusé', () {
      final v = verifyApk(entry: entry(), apk: apk(pkg: 'com.autre'), device: device);
      expect(v.ok, isFalse);
      expect(v.error, contains('com.autre'));
    });

    test('signature différente de l\'app installée : refusé, rien n\'est remplacé', () {
      final v = verifyApk(
          entry: entry(),
          apk: apk(signers: {'bb'}),
          device: device,
          installed: inst());
      expect(v.ok, isFalse);
      expect(v.error, contains('autre clé'));
    });

    test('rotation de clé : la signature actuelle de l\'APK figure dans l\'historique installé', () {
      final v = verifyApk(
          entry: entry(),
          apk: apk(signers: {'bb'}),
          device: device,
          installed: inst(signers: {'aa', 'bb'}));
      expect(v.ok, isTrue);
    });

    test('rétrogradation ou même version : refusé', () {
      expect(verifyApk(entry: entry(), apk: apk(code: 5), device: device, installed: inst()).ok, isFalse);
      expect(verifyApk(entry: entry(), apk: apk(code: 4), device: device, installed: inst()).ok, isFalse);
    });

    test('Android trop ancien : message lisible', () {
      final v = verifyApk(entry: entry(), apk: apk(minSdk: 35), device: device);
      expect(v.ok, isFalse);
      expect(v.error, contains('Android 15'));
    });

    test('code natif d\'une autre architecture : refusé', () {
      final v = verifyApk(entry: entry(), apk: apk(abis: {'x86_64'}), device: device);
      expect(v.ok, isFalse);
      expect(v.error, contains('x86_64'));
      expect(verifyApk(entry: entry(), apk: apk(abis: {'arm64-v8a', 'x86'}), device: device).ok, isTrue);
    });

    test('première installation sans empreinte : acceptée mais sans prétendre vérifier la signature', () {
      final v = verifyApk(entry: entry(), apk: apk(), device: device);
      expect(v.ok, isTrue);
      expect(v.signatureNote, contains('n\'a pas pu être comparée'));
    });

    test('empreinte épinglée dans le catalogue : imposée dès la première installation', () {
      final pinned = entry(pinned: 'cc');
      expect(verifyApk(entry: pinned, apk: apk(), device: device).ok, isFalse);
      final ok = verifyApk(entry: pinned, apk: apk(signers: {'cc'}), device: device);
      expect(ok.ok, isTrue);
      expect(ok.signatureNote, contains('catalogue'));
    });
  });

  group('computeStatus', () {
    test('installée via le Play Store : la mise à jour GitHub est signalée impossible', () {
      final play = InstalledInfo(
          packageName: 'eu.lielu.demo',
          versionName: '1.0.5',
          versionCode: 5,
          signers: const {'aa'},
          installer: 'com.android.vending');
      final v = AppView(entry(), installed: play, result: null);
      expect(v.updateBlockedReason, contains('Play Store'));
      final manual = AppView(entry(), installed: inst());
      expect(manual.updateBlockedReason, isNull);
    });
    test('non installée', () {
      expect(computeStatus(entry(), null, release('v1.0.9', '1.0.9'), null), AppStatus.notInstalled);
    });
    test('mise à jour disponible / à jour', () {
      expect(computeStatus(entry(), inst(name: '1.0.5'), release('v1.0.9', '1.0.9'), null),
          AppStatus.updateAvailable);
      expect(computeStatus(entry(), inst(name: '1.0.9'), release('v1.0.9', '1.0.9'), null),
          AppStatus.upToDate);
      expect(computeStatus(entry(), inst(name: '1.0.10'), release('v1.0.9', '1.0.9'), null),
          AppStatus.upToDate);
    });
    test('installée mais aucune release connue ou version illisible → unknown', () {
      expect(computeStatus(entry(), inst(), null, null), AppStatus.unknown);
      expect(computeStatus(entry(), inst(name: 'dev'), release('v1.0.9', '1.0.9'), null),
          AppStatus.unknown);
    });
    test('installedTag : versionName ignoré, tag installé par le store comparé', () {
      final e = entry(release: {
        'tagPattern': r'^v(\d+\.\d+\.\d+-\d+)$',
        'updateDetection': 'installedTag',
      });
      final latest = release('v0.1.0-14', '0.1.0-14');
      expect(computeStatus(e, inst(name: '0.1.0'), latest, null), AppStatus.unknown);
      expect(computeStatus(e, inst(name: '0.1.0'), latest, 'v0.1.0-12'), AppStatus.updateAvailable);
      expect(computeStatus(e, inst(name: '0.1.0'), latest, 'v0.1.0-14'), AppStatus.upToDate);
    });
  });
}
