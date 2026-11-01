import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/features/home_widget/widget_order.dart';
import 'package:lieluapp/state/app_view.dart';

void main() {
  String id(String s) => s;

  test('ordre utilisateur appliqué, nouvelles apps à la fin, ids disparus ignorés', () {
    expect(applyOrder(['a', 'b', 'c', 'd'], ['c', 'x', 'a'], id), ['c', 'a', 'b', 'd']);
    expect(applyOrder(['a', 'b'], const [], id), ['a', 'b']);
    expect(applyOrder(['a', 'b'], ['b', 'b', 'a'], id), ['b', 'a']);
  });

  test('déplacement façon ReorderableListView', () {
    expect(moveItem(['a', 'b', 'c'], 0, 3), ['b', 'c', 'a']);
    expect(moveItem(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    expect(moveItem(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
  });

  test('données du widget : toutes les apps, paquet Android ou adresse web', () {
    final catalog = parseCatalog(File('catalog/apps.json').readAsStringSync());
    final views = [for (final e in catalog.entries) AppView(e)];
    final payload = jsonDecode(widgetPayload(views, 96)) as Map<String, dynamic>;
    expect(payload['iconDp'], 96);
    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    expect(items.length, catalog.entries.length);
    final web = items.firstWhere((i) => i['id'] == 'kigardeki');
    expect(web['url'], 'https://kigardeki.lielu.eu');
    expect(web.containsKey('packageName'), isFalse);
    final android = items.firstWhere((i) => i['id'] == 'swipernews');
    expect(android['packageName'], 'eu.lielu.news');
    expect(android.containsKey('url'), isFalse);
  });

  test('taille des icônes : bornée et arrondie au pas', () {
    expect(WidgetIconSizeNotifier.clamp(10), widgetIconMinDp);
    expect(WidgetIconSizeNotifier.clamp(500), widgetIconMaxDp);
    expect(WidgetIconSizeNotifier.clamp(57), 56);
    expect(WidgetIconSizeNotifier.clamp(59), 60);
  });

  test('transparence : bornée de 0 à 100 et arrondie au pas', () {
    expect(WidgetTransparencyNotifier.clamp(-10), 0);
    expect(WidgetTransparencyNotifier.clamp(130), 100);
    expect(WidgetTransparencyNotifier.clamp(42), 40);
    expect(WidgetTransparencyNotifier.clamp(43), 45);
  });
}
