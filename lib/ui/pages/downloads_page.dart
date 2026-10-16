import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/core/format.dart';
import 'package:lieluapp/install/install_models.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/ui/theme.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final states = ref.watch(installControllerProvider).values.toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Téléchargements',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (states.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Aucun téléchargement en cours.')),
            ),
          for (final s in states)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _Tile(s)),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  final InstallState s;
  const _Tile(this.s);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(installControllerProvider.notifier);
    final entries = ref.watch(catalogProvider).value?.entries ?? const <CatalogEntry>[];
    final entry = entries.where((e) => e.id == s.appId).firstOrNull;
    final view = ref.watch(appViewsProvider).where((v) => v.entry.id == s.appId).firstOrNull;
    final (IconData icon, Color color) = switch (s.phase) {
      InstallPhase.installed => (Icons.check_circle, LieluColors.mint),
      InstallPhase.failed => (Icons.error, LieluColors.danger),
      InstallPhase.cancelled => (Icons.cancel_outlined, LieluColors.textMuted),
      _ => (Icons.downloading, theme.colorScheme.primary),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${s.appName} ${s.versionLabel}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (!s.phase.active)
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => controller.dismiss(s.appId),
                  ),
              ],
            ),
            if (s.phase == InstallPhase.downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: s.progress, borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 4),
              Text(
                  s.total > 0
                      ? '${formatBytes(s.received)} / ${formatBytes(s.total)}'
                      : formatBytes(s.received),
                  style: theme.textTheme.bodySmall),
            ] else if (s.message != null) ...[
              const SizedBox(height: 6),
              Text(s.message!, style: theme.textTheme.bodySmall),
            ],
            if (s.integrityNote != null || s.signatureNote != null) ...[
              const SizedBox(height: 6),
              if (s.integrityNote != null) Text(s.integrityNote!, style: theme.textTheme.bodySmall),
              if (s.signatureNote != null) Text(s.signatureNote!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (s.phase == InstallPhase.downloading || s.phase == InstallPhase.needsPermission)
                  OutlinedButton(
                      onPressed: () => controller.cancel(s.appId), child: const Text('Annuler')),
                if (s.phase == InstallPhase.needsPermission)
                  FilledButton(
                      onPressed: () => ref.read(platformProvider).openInstallSettings(),
                      child: const Text('Ouvrir les réglages')),
                if ((s.phase == InstallPhase.failed || s.phase == InstallPhase.cancelled) &&
                    entry != null &&
                    view?.release?.apk != null)
                  FilledButton(
                      onPressed: () => controller.start(entry, view!.release!),
                      child: const Text('Réessayer')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
