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
                  Text('Taille des icônes', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<WidgetIconSize>(
                    showSelectedIcon: false,
                    segments: [
                      for (final s in WidgetIconSize.values)
                        ButtonSegment(value: s, label: Text(s.label)),
                    ],
                    selected: {size},
                    onSelectionChanged: (s) =>
                        ref.read(widgetIconSizeProvider.notifier).set(s.first),
                  ),
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
