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
    final payload = jsonDecode(widgetPayload(views, WidgetIconSize.large)) as Map<String, dynamic>;
    expect(payload['size'], 'large');
    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    expect(items.length, catalog.entries.length);
    final web = items.firstWhere((i) => i['id'] == 'kigardeki');
    expect(web['url'], 'https://kigardeki.lielu.eu');
    expect(web.containsKey('packageName'), isFalse);
    final android = items.firstWhere((i) => i['id'] == 'swipernews');
    expect(android['packageName'], 'eu.lielu.news');
    expect(android.containsKey('url'), isFalse);
  });
}
