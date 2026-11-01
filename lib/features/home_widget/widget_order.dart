import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/state/app_view.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/state/settings.dart';

/// Trie [items] selon l'ordre choisi par l'utilisateur ([order], liste d'identifiants).
///
/// Les éléments absents de [order] (apps ajoutées au catalogue depuis le dernier
/// classement) sont placés à la fin, dans l'ordre du catalogue. Les identifiants de
/// [order] qui n'existent plus sont ignorés.
List<T> applyOrder<T>(List<T> items, List<String> order, String Function(T) idOf) {
  final rank = <String, int>{};
  for (var i = 0; i < order.length; i++) {
    rank.putIfAbsent(order[i], () => i);
  }
  final ranked = [
    for (final e in items)
      if (rank.containsKey(idOf(e))) e,
  ]..sort((a, b) => rank[idOf(a)]!.compareTo(rank[idOf(b)]!));
  return [
    ...ranked,
    for (final e in items)
      if (!rank.containsKey(idOf(e))) e,
  ];
}

/// Déplace l'élément [oldIndex] vers [newIndex] (convention de `ReorderableListView` :
/// [newIndex] est compté avant le retrait de l'élément).
List<T> moveItem<T>(List<T> items, int oldIndex, int newIndex) {
  final out = List.of(items);
  final item = out.removeAt(oldIndex);
  out.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
  return out;
}

/// Ordre des applications dans le widget d'écran d'accueil, choisi par l'utilisateur.
final class WidgetOrderNotifier extends Notifier<List<String>> {
  static const _key = 'widget.order';

  @override
  List<String> build() =>
      List.unmodifiable(ref.read(sharedPrefsProvider).getStringList(_key) ?? const <String>[]);

  Future<void> set(List<String> ids) async {
    state = List.unmodifiable(ids);
    await ref.read(sharedPrefsProvider).setStringList(_key, ids);
  }

  /// Revient à l'ordre du catalogue.
  Future<void> reset() async {
    state = const [];
    await ref.read(sharedPrefsProvider).remove(_key);
  }
}

final widgetOrderProvider =
    NotifierProvider<WidgetOrderNotifier, List<String>>(WidgetOrderNotifier.new);

/// Toutes les applications du catalogue, dans l'ordre du widget.
final widgetAppsProvider = Provider<List<AppView>>((ref) => applyOrder(
    ref.watch(appViewsProvider), ref.watch(widgetOrderProvider), (v) => v.entry.id));

/// Données transmises au widget Android (JSON). L'état « installée » est relu par
/// le widget lui-même, pour rester juste même si le store n'est pas ouvert.
String widgetPayload(List<AppView> apps) => jsonEncode([
      for (final v in apps)
        {
          'id': v.entry.id,
          'name': v.entry.name,
          if (!v.entry.isWeb) 'packageName': v.entry.packageName,
          if (v.entry.webUrl != null) 'url': v.entry.webUrl,
        },
    ]);
