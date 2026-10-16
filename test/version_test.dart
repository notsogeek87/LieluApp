import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/core/version.dart';
import 'package:lieluapp/core/url_policy.dart';

AppVersion v(String s) => AppVersion.tryParse(s)!;

void main() {
  group('AppVersion', () {
    test('compare numériquement, pas alphabétiquement', () {
      expect(v('1.10') > v('1.9'), isTrue);
      expect(v('1.0.152') > v('1.0.99'), isTrue);
    });
    test('segments manquants valent 0 et le préfixe v est ignoré', () {
      expect(v('v1.0'), v('1.0.0'));
      expect(v('1.0.1') > v('1.0'), isTrue);
    });
    test('une pré-version est inférieure à la version finale', () {
      expect(v('1.0.0-rc1') > v('1.0.0'), isFalse);
      expect(v('1.0.0') > v('1.0.0-rc1'), isTrue);
      expect(v('0.1.0-13') > v('0.1.0-12'), isTrue);
      expect(v('0.1.0-12') > v('0.1.0-9'), isTrue);
    });
    test('les métadonnées de build (+5) sont ignorées', () {
      expect(v('1.2.3+5'), v('1.2.3'));
    });
    test('texte illisible → null', () {
      expect(AppVersion.tryParse('debug-main'), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse(null), isNull);
    });
  });

  group('UrlPolicy', () {
    const p = UrlPolicy.github;
    test('accepte HTTPS sur les hôtes GitHub', () {
      expect(p.isAllowed(Uri.parse('https://github.com/a/b/releases/download/v1/x.apk')), isTrue);
      expect(p.isAllowed(Uri.parse('https://release-assets.githubusercontent.com/x')), isTrue);
    });
    test('refuse HTTP, hôtes inconnus et pièges de sous-domaine', () {
      expect(p.isAllowed(Uri.parse('http://github.com/x')), isFalse);
      expect(p.isAllowed(Uri.parse('https://evil.example/x.apk')), isFalse);
      expect(p.isAllowed(Uri.parse('https://github.com.evil.example/x')), isFalse);
      expect(p.isAllowed(Uri.parse('https://evilgithub.com/x')), isFalse);
    });
    test('require lève UrlRejected avec la raison', () {
      expect(() => p.require('http://github.com/x'), throwsA(isA<UrlRejected>()));
      expect(() => p.require('https://example.org/x'), throwsA(isA<UrlRejected>()));
    });
  });
}
