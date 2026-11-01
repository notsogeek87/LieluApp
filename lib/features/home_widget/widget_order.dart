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

/// Taille des icônes du widget d'écran d'accueil, en dp : de très petites à très grandes.
const widgetIconMinDp = 32;
const widgetIconMaxDp = 128;
const widgetIconStepDp = 4;
const widgetIconDefaultDp = 56;

final class WidgetIconSizeNotifier extends Notifier<int> {
  static const _key = 'widget.iconDp';
  static const _legacyKey = 'widget.iconSize'; // ancien réglage petites/moyennes/grandes

  @override
  int build() {
    final prefs = ref.read(sharedPrefsProvider);
    final saved = prefs.getInt(_key);
    if (saved != null) return clamp(saved);
    return switch (prefs.getString(_legacyKey)) {
      'small' => 40,
      'large' => 80,
      _ => widgetIconDefaultDp,
    };
  }

  static int clamp(int dp) {
    final stepped = (dp / widgetIconStepDp).round() * widgetIconStepDp;
    return stepped.clamp(widgetIconMinDp, widgetIconMaxDp);
  }

  Future<void> set(int dp) async {
    state = clamp(dp);
    await ref.read(sharedPrefsProvider).setInt(_key, state);
  }
}

final widgetIconSizeProvider =
    NotifierProvider<WidgetIconSizeNotifier, int>(WidgetIconSizeNotifier.new);

/// Transparence du fond du widget, en % : 0 = fond opaque, 100 = invisible.
const widgetTransparencyStep = 5;
const widgetTransparencyDefault = 10;

final class WidgetTransparencyNotifier extends Notifier<int> {
  static const _key = 'widget.transparency';

  @override
  int build() => clamp(ref.read(sharedPrefsProvider).getInt(_key) ?? widgetTransparencyDefault);

  static int clamp(int percent) =>
      ((percent / widgetTransparencyStep).round() * widgetTransparencyStep).clamp(0, 100);

  Future<void> set(int percent) async {
    state = clamp(percent);
    await ref.read(sharedPrefsProvider).setInt(_key, state);
  }
}

final widgetTransparencyProvider =
    NotifierProvider<WidgetTransparencyNotifier, int>(WidgetTransparencyNotifier.new);

/// Données transmises au widget Android (JSON) : taille des icônes (dp), transparence
/// du fond (%) et apps dans
/// l'ordre choisi. L'état « installée » est relu par le widget lui-même, pour
/// rester juste même si le store n'est pas ouvert.
String widgetPayload(List<AppView> apps,
        [int iconDp = widgetIconDefaultDp, int transparency = widgetTransparencyDefault]) =>
    jsonEncode({
      'iconDp': iconDp,
      'transparency': transparency,
      'items': [
        for (final v in apps)
          {
            'id': v.entry.id,
            'name': v.entry.name,
            if (!v.entry.isWeb) 'packageName': v.entry.packageName,
            if (v.entry.webUrl != null) 'url': v.entry.webUrl,
          },
      ],
    });

final homeWidgetPayloadProvider = Provider<String>((ref) => widgetPayload(
    ref.watch(widgetAppsProvider),
    ref.watch(widgetIconSizeProvider),
    ref.watch(widgetTransparencyProvider)));

/// Tient le widget d'écran d'accueil à jour (catalogue, apps installées, ordre,
/// taille). Écoute au niveau du conteneur : contrairement à un écran, cette écoute
/// n'est jamais mise en pause quand une autre page est affichée par-dessus.
void startHomeWidgetSync(ProviderContainer container) {
  String? last;
  container.listen<String>(homeWidgetPayloadProvider, (_, payload) async {
    if (payload == last) return;
    last = payload;
    try {
      await container.read(platformProvider).updateWidget(payload);
    } on Object {
      last = null; // réessayé au prochain changement
    }
  }, fireImmediately: true);
}
