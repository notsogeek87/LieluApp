import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/catalog/catalog_models.dart';

String doc(List<Map<String, Object?>> apps, {Object schema = 1}) =>
    jsonEncode({'schemaVersion': schema, 'apps': apps});

Map<String, Object?> app([Map<String, Object?> over = const {}]) => {
      'id': 'demo',
      'name': 'Demo',
      'packageName': 'eu.lielu.demo',
      'repo': 'notsogeek87/demo',
      'shortDescription': 'Une démo',
      ...over,
    };

void main() {
  test('le catalogue livré dans le dépôt est valide et sans doublon', () {
    final r = parseCatalog(File('catalog/apps.json').readAsStringSync());
    expect(r.issues, isEmpty);
    expect(r.entries.length, greaterThanOrEqualTo(5));
    expect(r.entries.map((e) => e.id).toSet().length, r.entries.length);
    expect(r.entries.map((e) => e.packageName).toSet().length, r.entries.length);
    // Entrée masquée (listed:false) non exposée.
    expect(r.entries.any((e) => e.id == 'ninjago-wishlist'), isFalse);
  });

  test('entrée minimale : valeurs par défaut raisonnables', () {
    final e = parseCatalog(doc([app()])).entries.single;
    expect(e.category, 'Autres');
    expect(e.maintenance, Maintenance.active);
    expect(e.release.includePrereleases, isFalse);
    expect(e.release.tagPattern.firstMatch('v1.2.3')!.group(1), '1.2.3');
    expect(e.repoUrl, 'https://github.com/notsogeek87/demo');
  });

  test('une entrée invalide est ignorée, les autres restent', () {
    final r = parseCatalog(doc([
      app({'id': 'ok'}),
      app({'id': 'mauvais', 'packageName': 'pas un package'}),
      app({'id': 'sans-repo', 'packageName': 'eu.lielu.b', 'repo': 'x'}),
    ]));
    expect(r.entries.map((e) => e.id), ['ok']);
    expect(r.issues.length, 2);
  });

  test('doublons d\'id ou de package refusés', () {
    final r = parseCatalog(doc([app(), app({'packageName': 'eu.lielu.autre'}), app({'id': 'x'})]));
    expect(r.entries.length, 1);
    expect(r.issues.length, 2);
  });

  test('les images doivent venir d\'un hôte GitHub en HTTPS', () {
    final bad = parseCatalog(doc([app({'iconUrl': 'https://tracker.example/i.png'})]));
    expect(bad.entries, isEmpty);
    final http = parseCatalog(doc([app({'iconUrl': 'http://raw.githubusercontent.com/i.png'})]));
    expect(http.entries, isEmpty);
    final ok = parseCatalog(doc([app({'iconUrl': 'https://raw.githubusercontent.com/a/b/main/i.png'})]));
    expect(ok.entries.single.iconUrl, isNotNull);
  });

  test('tagPattern sans groupe de version ou regex cassée → entrée refusée', () {
    expect(parseCatalog(doc([app({'release': {'tagPattern': r'^v\d+$'}})])).entries, isEmpty);
    expect(parseCatalog(doc([app({'release': {'tagPattern': '(['}})])).entries, isEmpty);
  });

  test('empreinte de signature : format vérifié et normalisé', () {
    final good = 'AA:' * 31 + 'AA';
    final e = parseCatalog(doc([app({'signingCertSha256': good})])).entries.single;
    expect(e.signingCertSha256, 'aa' * 32);
    expect(parseCatalog(doc([app({'signingCertSha256': 'abc'})])).entries, isEmpty);
  });

  test('document inutilisable ou schéma trop récent → FormatException', () {
    expect(() => parseCatalog('pas du json'), throwsFormatException);
    expect(() => parseCatalog('[]'), throwsFormatException);
    expect(() => parseCatalog(doc([], schema: 99)), throwsFormatException);
    expect(() => parseCatalog('{"schemaVersion":1}'), throwsFormatException);
  });
}
