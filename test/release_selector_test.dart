import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/releases/release_selector.dart';

Map<String, dynamic> asset(String name, {int size = 1000, String? digest}) => {
      'name': name,
      'size': size,
      'state': 'uploaded',
      'browser_download_url': 'https://github.com/o/r/releases/download/t/$name',
      if (digest != null) 'digest': digest,
    };

Map<String, dynamic> rel(String tag,
        {List<Map<String, dynamic>>? assets,
        bool draft = false,
        bool pre = false,
        String published = '2026-10-01T10:00:00Z',
        String body = 'notes'}) =>
    {
      'tag_name': tag,
      'draft': draft,
      'prerelease': pre,
      'published_at': published,
      'body': body,
      'html_url': 'https://github.com/o/r/releases/tag/$tag',
      'assets': assets ?? [asset('App-$tag.apk')],
    };

void main() {
  final rules = ReleaseRules.fromJson({'tagPattern': r'^v(\d+(?:\.\d+)*)$'});

  group('selectRelease', () {
    test('prend la version la plus haute, pas la plus récemment créée', () {
      final r = selectRelease(rules, [
        rel('v1.0.9'),
        rel('v1.0.10'),
        rel('v1.0.8'),
      ])!;
      expect(r.tag, 'v1.0.10');
      expect(r.notes, 'notes');
    });

    test('ignore brouillons et préversions par défaut', () {
      final r = selectRelease(rules, [
        rel('v2.0.0', draft: true),
        rel('v1.5.0', pre: true),
        rel('v1.0.0'),
      ])!;
      expect(r.tag, 'v1.0.0');
    });

    test('préversions incluses sur demande du catalogue', () {
      final withPre = ReleaseRules.fromJson(
          {'tagPattern': r'^v(\d+(?:\.\d+)*)$', 'includePrereleases': true});
      expect(selectRelease(withPre, [rel('v1.5.0', pre: true), rel('v1.0.0')])!.tag, 'v1.5.0');
    });

    test('les tags hors motif (debug-main, staging-v…) sont ignorés', () {
      final r = selectRelease(rules, [
        rel('debug-main'),
        rel('staging-v9.9.9'),
        rel('v1.0.1'),
      ])!;
      expect(r.tag, 'v1.0.1');
    });

    test('aucune release éligible → null', () {
      expect(selectRelease(rules, []), isNull);
      expect(selectRelease(rules, [rel('debug-x', pre: true)]), isNull);
    });

    test('deux familles de tags (android-v… et v…) comparées sur la version', () {
      final both = ReleaseRules.fromJson({'tagPattern': r'^(?:android-)?v(\d+(?:\.\d+)*)$'});
      final r = selectRelease(both, [rel('v1.5.6'), rel('android-v1.5.6.80'), rel('android-v1.5.5.90')])!;
      expect(r.tag, 'android-v1.5.6.80');
    });

    test('release sans APK : conservée, avec le problème expliqué', () {
      final r = selectRelease(rules, [rel('v1.0.0', assets: [])])!;
      expect(r.apk, isNull);
      expect(r.apkProblem, contains('Aucun fichier APK'));
    });
  });

  group('selectApk', () {
    const abis = ['arm64-v8a', 'armeabi-v7a'];

    test('un seul APK : retenu, avec taille et digest GitHub', () {
      final c = selectApk(rules, [
        asset('a.apk', size: 42, digest: 'sha256:${'AB' * 32}'),
        asset('notes.txt'),
      ]);
      expect(c.asset!.name, 'a.apk');
      expect(c.asset!.size, 42);
      expect(c.asset!.sha256, 'ab' * 32);
    });

    test('fichier .sha256 voisin utilisé si GitHub ne fournit pas de digest', () {
      final c = selectApk(rules, [asset('a.apk'), asset('a.apk.sha256')]);
      expect(c.asset!.checksumUrl, endsWith('a.apk.sha256'));
      expect(c.asset!.sha256, isNull);
    });

    test('digest invalide ignoré', () {
      final c = selectApk(rules, [asset('a.apk', digest: 'md5:abc')]);
      expect(c.asset!.sha256, isNull);
    });

    test('plusieurs ABI : choisit celle du téléphone, jamais une incompatible', () {
      final c = selectApk(rules, [
        asset('app-x86_64.apk'),
        asset('app-armeabi-v7a.apk'),
        asset('app-arm64-v8a.apk'),
      ], deviceAbis: abis);
      expect(c.asset!.name, 'app-arm64-v8a.apk');
    });

    test('retombe sur armeabi-v7a puis sur universel', () {
      expect(selectApk(rules, [asset('app-x86.apk'), asset('app-armeabi-v7a.apk')],
              deviceAbis: abis).asset!.name,
          'app-armeabi-v7a.apk');
      expect(selectApk(rules, [asset('app-x86.apk'), asset('app-universal.apk')],
              deviceAbis: abis).asset!.name,
          'app-universal.apk');
    });

    test('x86 n\'est pas confondu avec x86_64', () {
      expect(abiOfFileName('app-x86_64-release.apk'), 'x86_64');
      expect(abiOfFileName('app-x86-release.apk'), 'x86');
      expect(abiOfFileName('Backlog-1.0.5.apk'), isNull);
    });

    test('uniquement des APK d\'une autre architecture → problème explicite', () {
      final c = selectApk(rules, [asset('app-x86.apk'), asset('app-x86_64.apk')],
          deviceAbis: abis);
      expect(c.asset, isNull);
      expect(c.problem, contains('compatible'));
    });

    test('ambiguïté : refuse de deviner', () {
      final c = selectApk(rules, [asset('one.apk'), asset('two.apk')], deviceAbis: abis);
      expect(c.asset, isNull);
      expect(c.problem, contains('apkPattern'));
    });

    test('apkPattern et apkExclude lèvent l\'ambiguïté (Yakwa / Yakwa-Staging)', () {
      final r = ReleaseRules.fromJson(
          {'apkPattern': r'^Yakwa-.*\.apk$', 'apkExclude': 'Staging'});
      final c = selectApk(r, [asset('Yakwa-1.0.3.apk'), asset('Yakwa-Staging-1.0.3.apk')]);
      expect(c.asset!.name, 'Yakwa-1.0.3.apk');
    });

    test('apkPattern sans correspondance → problème, pas un autre fichier', () {
      final r = ReleaseRules.fromJson({'apkPattern': r'^Backlog-.*\.apk$'});
      final c = selectApk(r, [asset('autre.apk')]);
      expect(c.asset, isNull);
      expect(c.problem, contains('correspond'));
    });
  });
}
