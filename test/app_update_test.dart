import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/features/app_update/app_update.dart';
import 'package:lieluapp/platform/store_platform.dart';

ApkInspection apk({
  String pkg = storePackageName,
  Set<String> signers = const {storeSigningCertSha256},
  int code = 50,
}) =>
    ApkInspection(
      packageName: pkg,
      versionName: '1.0',
      versionCode: code,
      minSdk: 24,
      signers: signers,
      abis: const {},
    );

void main() {
  test('le numéro de build se lit dans le dernier segment du tag', () {
    expect(buildFromTag('v0.1.0.42'), 42);
    expect(buildFromTag('v0.1.0'), 0);
    expect(buildFromTag('debug-main'), isNull);
  });

  group('verifyStoreUpdate', () {
    test('APK du store, bonne clé, plus récent : accepté', () {
      expect(verifyStoreUpdate(apk(), installedBuild: 49), isNull);
    });

    test('autre paquet : refusé', () {
      expect(verifyStoreUpdate(apk(pkg: 'com.evil'), installedBuild: 49), contains('pas Lielu Store'));
    });

    test('signé par une autre clé (ex. ancienne clé de debug publique) : refusé', () {
      expect(verifyStoreUpdate(apk(signers: {'4935'}), installedBuild: 49),
          contains('pas signé par la clé'));
    });

    test('pas plus récent : refusé', () {
      expect(verifyStoreUpdate(apk(code: 49), installedBuild: 49), contains('pas plus récent'));
    });
  });

  test('store installé avec l\'ancienne clé : réinstallation nécessaire', () {
    const old = InstalledInfo(
        packageName: storePackageName, versionName: '1', versionCode: 1, signers: {'4935'});
    const current = InstalledInfo(
        packageName: storePackageName,
        versionName: '1',
        versionCode: 1,
        signers: {storeSigningCertSha256});
    expect(storeNeedsReinstall(old), isTrue);
    expect(storeNeedsReinstall(current), isFalse);
    expect(storeNeedsReinstall(null), isFalse);
  });
}
