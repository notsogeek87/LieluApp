import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/core/format.dart';
import 'package:lieluapp/install/install_models.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/ui/widgets/app_card.dart';
import 'package:lieluapp/ui/widgets/status_banner.dart';

class UpdatesPage extends ConsumerWidget {
  const UpdatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final updates = ref.watch(updatesProvider);
    final releases = ref.watch(releasesProvider).value;
    final history = ref
        .watch(appViewsProvider)
        .where((v) => v.release?.publishedAt != null && !v.hasUpdate)
        .toList()
      ..sort((a, b) => b.release!.publishedAt!.compareTo(a.release!.publishedAt!));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(releasesProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Mises à jour',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(
                  tooltip: 'Vérifier maintenant',
                  icon: releases?.refreshing == true
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  onPressed: () => ref.read(releasesProvider.notifier).refresh(),
                ),
              ],
            ),
            Text('Dernière vérification : ${formatDateTime(releases?.lastCheck)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            const StatusBanner(),
            if (updates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Toutes vos applications Lielu sont à jour.')),
              )
            else ...[
              Card(
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          updates.length == 1
                              ? '1 mise à jour disponible'
                              : '${updates.length} mises à jour disponibles',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Android demandera une confirmation pour chaque application.',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          final c = ref.read(installControllerProvider.notifier);
                          for (final u in updates) {
                            if (!u.installable) continue;
                            await c.start(u.entry, u.release!);
                            final phase = ref.read(installControllerProvider)[u.entry.id]?.phase;
                            // Une étape bloquée (autorisation, échec) interrompt la file.
                            if (phase != InstallPhase.installed) break;
                          }
                        },
                        child: const Text('Tout mettre à jour'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final u in updates)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(u)),
            ],
            if (history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Text('Dernières releases',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              for (final h in history)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(h, showDate: true)),
            ],
          ],
        ),
      ),
    );
  }
}
