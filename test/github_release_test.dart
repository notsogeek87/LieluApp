import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/releases/github_client.dart';
import 'package:lieluapp/releases/release_models.dart';
import 'package:lieluapp/releases/release_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

final entry = CatalogEntry(
  id: 'demo',
  name: 'Demo',
  packageName: 'eu.lielu.demo',
  repo: 'notsogeek87/demo',
  category: 'Outils',
  shortDescription: 'x',
  description: 'x',
  release: ReleaseRules.fromJson({'tagPattern': r'^v(\d+(?:\.\d+)*)$'}),
);

Map<String, dynamic> rel(String tag) => {
      'tag_name': tag,
      'prerelease': false,
      'draft': false,
      'published_at': '2026-10-10T10:00:00Z',
      'body': 'Corrections',
      'assets': [
        {
          'name': 'Demo-$tag.apk',
          'size': 10,
          'state': 'uploaded',
          'browser_download_url': 'https://github.com/notsogeek87/demo/releases/download/$tag/Demo.apk',
        }
      ],
    };

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ReleaseRepository repoWith(ResponseBody Function(RequestOptions) h) =>
      ReleaseRepository(GithubReleaseClient(fakeDio(h)), prefs);

  test('succès : release choisie, mise en cache avec son ETag', () async {
    final repo = repoWith((_) => text(releasesJson([rel('v1.0.2'), rel('v1.0.1')]), 200,
        headers: {'etag': ['"abc"']}));
    final r = await repo.refresh(entry);
    expect(r.status, ReleaseStatus.ok);
    expect(r.release!.tag, 'v1.0.2');
    expect(r.stale, isFalse);
    expect(prefs.getString('rel.demo.etag'), '"abc"');
    expect(repo.cached(entry)!.release!.tag, 'v1.0.2');
  });

  test('requête conditionnelle : 304 réutilise le cache et envoie If-None-Match', () async {
    final adapter = FakeAdapter((o) => o.headers['If-None-Match'] == null
        ? text(releasesJson([rel('v1.0.2')]), 200, headers: {'etag': ['"abc"']})
        : text('', 304));
    final repo = ReleaseRepository(GithubReleaseClient(Dio()..httpClientAdapter = adapter), prefs);
    await repo.refresh(entry);
    final second = await repo.refresh(entry);
    expect(adapter.requests.last.headers['If-None-Match'], '"abc"');
    expect(second.release!.tag, 'v1.0.2');
    expect(second.stale, isFalse);
  });

  test('dépôt sans release → noRelease (pas une erreur)', () async {
    final r = await repoWith((_) => text('[]', 200)).refresh(entry);
    expect(r.status, ReleaseStatus.noRelease);
    expect(r.release, isNull);
  });

  test('404 → dépôt introuvable ou privé', () async {
    final r = await repoWith((_) => text('{}', 404)).refresh(entry);
    expect(r.status, ReleaseStatus.notFound);
  });

  test('limite d\'API : 403 avec quota épuisé → rateLimited, heure de reprise indiquée', () async {
    final r = await repoWith((_) => text('{}', 403, headers: {
          'x-ratelimit-remaining': ['0'],
          'x-ratelimit-reset': ['1800000000'],
        })).refresh(entry);
    expect(r.status, ReleaseStatus.rateLimited);
    expect(r.message, contains('Réessayez'));
  });

  test('403 sans quota épuisé n\'est pas pris pour une limite d\'API', () async {
    final r = await repoWith((_) => text('{}', 403)).refresh(entry);
    expect(r.status, ReleaseStatus.error);
  });

  test('hors-ligne sans cache → offline', () async {
    final r = await repoWith((o) => throw DioException.connectionError(
        requestOptions: o, reason: 'down')).refresh(entry);
    expect(r.status, ReleaseStatus.offline);
  });

  test('hors-ligne avec cache : la dernière release reste affichée, marquée périmée', () async {
    var online = true;
    final repo = repoWith((o) {
      if (online) return text(releasesJson([rel('v1.0.2')]), 200);
      throw DioException.connectionTimeout(requestOptions: o, timeout: const Duration(seconds: 1));
    });
    await repo.refresh(entry);
    online = false;
    final r = await repo.refresh(entry);
    expect(r.status, ReleaseStatus.ok);
    expect(r.stale, isTrue);
    expect(r.release!.tag, 'v1.0.2');
    expect(r.message, contains('Délai'));
  });

  test('erreur serveur 500 → error, sans planter', () async {
    final r = await repoWith((_) => text('oops', 500)).refresh(entry);
    expect(r.status, ReleaseStatus.error);
  });

  test('réponse non JSON → error', () async {
    final r = await repoWith((_) => text('<html>', 200)).refresh(entry);
    expect(r.status, ReleaseStatus.error);
  });
}
