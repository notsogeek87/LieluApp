import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/features/home_widget/widget_order.dart';
import 'package:lieluapp/state/app_view.dart';
import 'package:lieluapp/ui/widgets/app_icon.dart';

/// Classement des applications du widget d'écran d'accueil, par glisser-déposer.
class WidgetOrderPage extends ConsumerWidget {
  const WidgetOrderPage({super.key});

  static String _subtitle(AppView v) => v.entry.isWeb
      ? 'Application web'
      : v.isInstalled
          ? 'Installée'
          : 'Non installée · ouvre sa fiche dans le store';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final apps = ref.watch(widgetAppsProvider);
    final order = ref.watch(widgetOrderProvider);
    final notifier = ref.read(widgetOrderProvider.notifier);
    final size = ref.watch(widgetIconSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget d\'accueil'),
        actions: [
          TextButton(
            onPressed: order.isEmpty ? null : notifier.reset,
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            buildDefaultDragHandles: false,
            header: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconSizeSetting(size: size, preview: apps.take(4).toList()),
                  const SizedBox(height: 8),
                  _TransparencySetting(preview: apps.take(4).toList()),
                  const SizedBox(height: 20),
                  Text('Ordre des applications', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                'Le widget « Applications Lielu » affiche toutes les apps du catalogue dans cet '
                'ordre. Faites glisser une ligne (poignée à droite, ou appui long) pour la déplacer.\n\n'
                'Pour l\'ajouter : appui long sur l\'écran d\'accueil → Widgets → Lielu Store. '
                'Les nouvelles apps du catalogue s\'ajoutent à la fin.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
                  ),
                ],
              ),
            ),
            itemCount: apps.length,
            onReorder: (oldIndex, newIndex) => notifier.set([
              for (final v in moveItem(apps, oldIndex, newIndex)) v.entry.id,
            ]),
            itemBuilder: (context, i) {
              final v = apps[i];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(v.entry.id),
                index: i,
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: AppIcon(v.entry, size: 40),
                    title: Text(v.entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_subtitle(v), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle, semanticLabel: 'Déplacer'),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Taille des icônes du widget : curseur de très petites à très grandes, avec aperçu.
class _IconSizeSetting extends ConsumerWidget {
  final int size;
  final List<AppView> preview;
  const _IconSizeSetting({required this.size, required this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(widgetIconSizeProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Taille des icônes', style: theme.textTheme.titleSmall)),
                Text('$size dp', style: theme.textTheme.labelLarge),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Réduire',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: size > widgetIconMinDp
                      ? () => notifier.set(size - widgetIconStepDp * 2)
                      : null,
                ),
                Expanded(
                  child: Slider(
                    min: widgetIconMinDp.toDouble(),
                    max: widgetIconMaxDp.toDouble(),
                    divisions: (widgetIconMaxDp - widgetIconMinDp) ~/ widgetIconStepDp,
                    value: size.toDouble(),
                    label: '$size dp',
                    onChanged: (v) => notifier.set(v.round()),
                  ),
                ),
                IconButton(
                  tooltip: 'Agrandir',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: size < widgetIconMaxDp
                      ? () => notifier.set(size + widgetIconStepDp * 2)
                      : null,
                ),
              ],
            ),
            // Aperçu à la taille réelle (1 dp Android = 1 unité Flutter).
            SizedBox(
              height: widgetIconMaxDp + 24,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final v in preview)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(v.entry, size: size.toDouble()),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: size + 12,
                                child: Text(v.entry.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transparence du fond du widget, avec un aperçu sur un faux fond d'écran.
class _TransparencySetting extends ConsumerWidget {
  final List<AppView> preview;
  const _TransparencySetting({required this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transparency = ref.watch(widgetTransparencyProvider);
    final notifier = ref.read(widgetTransparencyProvider.notifier);
    final opacity = (100 - transparency) / 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Transparence du fond', style: theme.textTheme.titleSmall)),
                Text(
                    switch (transparency) {
                      0 => 'Opaque',
                      100 => 'Invisible',
                      _ => '$transparency %',
                    },
                    style: theme.textTheme.labelLarge),
              ],
            ),
            Slider(
              min: 0,
              max: 100,
              divisions: 100 ~/ widgetTransparencyStep,
              value: transparency.toDouble(),
              label: '$transparency %',
              onChanged: (v) => notifier.set(v.round()),
            ),
            // Aperçu : le fond du widget posé sur un faux fond d'écran.
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3DDC97), Color(0xFF5B8DEF), Color(0xFFFF8A5B)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141826).withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final v in preview) AppIcon(v.entry, size: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
