import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/releases/release_selector.dart';

/// Tags et noms d'APK relevés sur les releases GitHub réelles (16/10/2026).
/// Chaque entrée : (tag, prerelease, apk).
typedef R = (String, bool, String);

List<Map<String, dynamic>> releases(List<R> rs) => [
      for (final (tag, pre, apk) in rs)
        {
          'tag_name': tag,
          'draft': false,
          'prerelease': pre,
          'published_at': '2026-10-01T00:00:00Z',
          'assets': [
            {
              'name': apk,
              'size': 1000,
              'state': 'uploaded',
              'digest': 'sha256:${'a' * 64}',
              'browser_download_url': 'https://github.com/o/r/releases/download/$tag/$apk',
            }
          ],
        }
    ];

void main() {
  final catalog = parseCatalog(File('catalog/apps.json').readAsStringSync());
  CatalogEntry app(String id) => catalog.entries.firstWhere((e) => e.id == id);

  void expectLatest(String id, List<R> rs, String tag, String apk) {
    final r = selectRelease(app(id).release, releases(rs), deviceAbis: ['arm64-v8a'])!;
    expect(r.tag, tag);
    expect(r.apk?.name, apk, reason: r.apkProblem);
    expect(r.apk?.sha256, isNotNull);
  }

  test('Backlog', () => expectLatest('backlog', [
        ('v0.1.295', false, 'Backlog-0.1.295.apk'),
        ('v0.1.292', false, 'Backlog-0.1.292.apk'),
        ('debug-staging', true, 'Backlog-0.1.291.apk'),
      ], 'v0.1.295', 'Backlog-0.1.295.apk'));

  test('SwiperNews : tags android-v…, préversion android-staging ignorée', () => expectLatest('swipernews', [
        ('android-v1.5.0.653', false, 'swipernews-1.5.0.653.apk'),
        ('android-staging', true, 'swipernews-1.5.0.655.apk'),
        ('android-v1.5.0.656', false, 'swipernews-1.5.0.656.apk'),
        ('android-v1.5.0.645', false, 'swipernews-1.5.0.645.apk'),
      ], 'android-v1.5.0.656', 'swipernews-1.5.0.656.apk'));

  test('Vizuzik', () => expectLatest('vizuzik', [
        ('v1.0.416', false, 'Vizuzik-1.0.416.apk'),
        ('debug-security-audit-2026-10-15', true, 'Vizuzik-1.0.417.apk'),
        ('v1.0.418', false, 'Vizuzik-1.0.418.apk'),
      ], 'v1.0.418', 'Vizuzik-1.0.418.apk'));

  test('Yakwa', () => expectLatest('yakwa', [
        ('v1.0.174', false, 'Yakwa-1.0.174.apk'),
        ('v1.0.175', false, 'Yakwa-1.0.175.apk'),
        ('v1.0.9', false, 'Yakwa-1.0.9.apk'),
      ], 'v1.0.175', 'Yakwa-1.0.175.apk'));

  test('Messous', () => expectLatest('messous', [
        ('v1.0.64', false, 'Messous-1.0.64.apk'),
        ('debug-staging', true, 'x.apk'),
        ('v1.0.66', false, 'Messous-1.0.66.apk'),
      ], 'v1.0.66', 'Messous-1.0.66.apk'));

  test('monNhuitNe', () => expectLatest('monnhuitne', [
        ('v1.0.28', false, 'monNhuitNe-1.0.28.apk'),
        ('v1.0.34', false, 'monNhuitNe-1.0.34.apk'),
        ('debug-staging', true, 'x.apk'),
      ], 'v1.0.34', 'monNhuitNe-1.0.34.apk'));

  test('ArcExtract : v0.1.0-34 est bien plus récent que v0.1.0-7', () => expectLatest('arcextract', [
        ('v0.1.0-7', false, 'ArcExtract-0.1.0-7.apk'),
        ('v0.1.0-34', false, 'ArcExtract-0.1.0-34.apk'),
        ('v0.1.0-4', false, 'ArcExtract-0.1.0-4.apk'),
      ], 'v0.1.0-34', 'ArcExtract-0.1.0-34.apk'));
}
