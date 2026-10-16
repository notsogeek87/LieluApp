import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/platform/store_platform.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/state/settings.dart';
import 'package:lieluapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

Map<String, dynamic> release(String tag, String asset) => {
      'tag_name': tag,
      'draft': false,
      'prerelease': false,
      'published_at': '2026-10-10T10:00:00Z',
      'body': '## Nouveautés\n- Correctif **important**',
      'html_url': 'https://github.com/x/y/releases/tag/$tag',
      'assets': [
        {
          'name': asset,
          'size': 5000000,
          'state': 'uploaded',
          'browser_download_url': 'https://github.com/x/y/releases/download/$tag/$asset',
        }
      ],
    };

void main() {
  testWidgets('catalogue → cartes → bouton contextuel et fiche', (tester) async {
    tester.view.physicalSize = const Size(600, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final platform = FakePlatform()
      ..installedApps['com.davidgcd.backlog'] = const InstalledInfo(
          packageName: 'com.davidgcd.backlog',
          versionName: '1.0.5',
          versionCode: 5,
          signers: {'aa'})
      ..installedApps['com.vizuzik.app'] = const InstalledInfo(
          packageName: 'com.vizuzik.app',
          versionName: '1.0.20',
          versionCode: 20,
          signers: {'aa'});

    final dio = fakeDio((o) {
      final path = o.uri.path;
      if (path.contains('/notsogeek87/backlog/')) {
        return text(releasesJson([release('v1.0.9', 'Backlog-1.0.9.apk')]), 200);
      }
      if (path.contains('/notsogeek87/Vizuzik/')) {
        return text(releasesJson([release('v1.0.20', 'Vizuzik-1.0.20.apk')]), 200);
      }
      if (path.contains('/notsogeek87/swipernews/')) {
        return text(releasesJson([release('v1.5.6', 'swipernews-1.5.6.apk')]), 200);
      }
      return text('[]', 200);
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        platformProvider.overrideWithValue(platform),
        dioProvider.overrideWithValue(dio),
      ],
      child: const LieluStoreApp(),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Lielu '), findsNothing); // titre en TextSpan
    expect(find.textContaining('Mes applications'), findsWidgets);
    expect(find.text('1 mise à jour disponible'), findsOneWidget);

    // Onglet « Toutes les apps »
    await tester.tap(find.text('Toutes les apps'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Backlog'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsOneWidget); // Backlog 1.0.5 → 1.0.9
    expect(find.text('Ouvrir'), findsOneWidget); // Vizuzik à jour
    expect(find.text('Installer'), findsWidgets); // SwiperNews non installée
    expect(find.text('Ninjago Wishlist'), findsNothing); // listed:false

    // Recherche par nom
    await tester.enterText(find.byType(TextField), 'back');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Backlog'), findsOneWidget);
    expect(find.text('Vizuzik'), findsNothing);

    // Fiche application
    await tester.tap(find.text('Backlog'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Mise à jour disponible'), findsOneWidget);
    expect(find.text('Notes de version 1.0.9'), findsOneWidget);
    expect(find.textContaining('Correctif important'), findsOneWidget);
    expect(find.text('Aucune somme de contrôle publiée'), findsOneWidget);
  });
}
