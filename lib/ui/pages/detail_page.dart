import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/core/format.dart';
import 'package:lieluapp/install/install_models.dart';
import 'package:lieluapp/releases/release_models.dart';
import 'package:lieluapp/state/app_view.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/ui/theme.dart';
import 'package:lieluapp/ui/widgets/action_button.dart';
import 'package:lieluapp/ui/widgets/app_icon.dart';
import 'package:lieluapp/ui/widgets/links.dart';

class AppDetailPage extends ConsumerWidget {
  final String appId;
  const AppDetailPage({super.key, required this.appId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(appViewsProvider).where((a) => a.entry.id == appId).firstOrNull;
    if (view == null) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: Text('Application introuvable.')));
    }
    final theme = Theme.of(context);
    final entry = view.entry;
    final release = view.release;
    final install = ref.watch(installControllerProvider)[entry.id];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Dépôt public',
            icon: const Icon(Icons.code),
            onPressed: () => openUrl(context, entry.repoUrl),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: lieluBackground(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppIcon(entry, size: 84),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.name,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('${entry.category} · ${entry.maintenance.label}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(_statusLine(view),
                              style: theme.textTheme.labelMedium?.copyWith(color: _statusColor(view))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _MainAction(view)),
                  ],
                ),
                if (install != null) _InstallPanel(install: install, appId: entry.id),
                if (view.status == AppStatus.unknown && view.installable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: Text('Installer la version ${release!.version}'),
                        onPressed: () => ref
                            .read(installControllerProvider.notifier)
                            .start(entry, release),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                _ReleaseProblem(view),
                if (entry.screenshots.isNotEmpty) ...[
                  _Section('Captures d\'écran'),
                  SizedBox(
                    height: 380,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entry.screenshots.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          entry.screenshots[i],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const SizedBox(width: 180),
                        ),
                      ),
                    ),
                  ),
                ],
                _Section('À propos'),
                Text(entry.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                _Section('Informations'),
                _InfoCard(view),
                if (release != null) ...[
                  _Section('Notes de version ${release.version}'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        release.notes.isEmpty
                            ? 'Aucune note publiée pour cette version.'
                            : plainNotes(release.notes),
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ),
                  ),
                  if (release.htmlUrl.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => openUrl(context, release.htmlUrl),
                        child: const Text('Voir la release sur GitHub'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _statusLine(AppView v) => switch (v.status) {
        AppStatus.notInstalled => 'Non installée',
        AppStatus.upToDate => 'Installée · à jour',
        AppStatus.updateAvailable => 'Mise à jour disponible',
        AppStatus.unknown => 'Installée',
      };

  static Color _statusColor(AppView v) => switch (v.status) {
        AppStatus.upToDate => LieluColors.mint,
        AppStatus.updateAvailable => LieluColors.amber,
        _ => LieluColors.textMuted,
      };
}

class _MainAction extends ConsumerWidget {
  final AppView view;
  const _MainAction(this.view);

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Align(alignment: Alignment.centerLeft, child: AppActionButton(view, compact: false));
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _ReleaseProblem extends StatelessWidget {
  final AppView view;
  const _ReleaseProblem(this.view);

  @override
  Widget build(BuildContext context) {
    final result = view.result;
    String? text;
    if (result == null) {
      text = null;
    } else if (view.release == null) {
      text = result.message ?? 'Aucune release disponible.';
    } else if (view.release!.apk == null) {
      text = view.release!.apkProblem;
    } else if (result.stale) {
      text = '${result.message} Affichage de la dernière version connue.';
    }
    if (text == null) return const SizedBox.shrink();
    return Card(
      color: LieluColors.amber.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: LieluColors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _InstallPanel extends ConsumerWidget {
  final InstallState install;
  final String appId;
  const _InstallPanel({required this.install, required this.appId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(installControllerProvider.notifier);
    final failed = install.phase == InstallPhase.failed;
    final needsPermission = install.phase == InstallPhase.needsPermission;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (install.phase == InstallPhase.downloading) ...[
                  Text('Téléchargement de ${install.versionLabel}…',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                      value: install.progress, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 6),
                  Text(
                    install.total > 0
                        ? '${formatBytes(install.received)} / ${formatBytes(install.total)}'
                        : formatBytes(install.received),
                    style: theme.textTheme.bodySmall,
                  ),
                ] else if (install.message != null)
                  Text(install.message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: failed ? theme.colorScheme.error : null)),
                if (install.integrityNote != null) ...[
                  const SizedBox(height: 8),
                  _Check(install.integrityNote!),
                ],
                if (install.signatureNote != null) _Check(install.signatureNote!),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (needsPermission)
                      FilledButton(
                        onPressed: () => ref.read(platformProvider).openInstallSettings(),
                        child: const Text('Ouvrir les réglages'),
                      ),
                    if (install.phase == InstallPhase.downloading || needsPermission)
                      OutlinedButton(
                          onPressed: () => controller.cancel(appId),
                          child: const Text('Annuler')),
                    if (!install.phase.active)
                      TextButton(
                          onPressed: () => controller.dismiss(appId),
                          child: const Text('Fermer')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final String text;
  const _Check(this.text);

  @override
  Widget build(BuildContext context) {
    final verified = !text.contains('non vérifiée') &&
        !text.contains('n\'a pas pu') &&
        !text.contains('Aucune');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(verified ? Icons.verified_outlined : Icons.help_outline,
              size: 16, color: verified ? LieluColors.mint : LieluColors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final AppView view;
  const _InfoCard(this.view);

  @override
  Widget build(BuildContext context) {
    final release = view.release;
    final apk = release?.apk;
    final entry = view.entry;
    final rows = <(String, String)>[
      ('Version installée', view.installed == null ? 'Non installée' : view.installed!.versionName),
      ('Dernière version', release == null ? '—' : '${release.version}'),
      if (release != null) ('Publiée le', formatDate(release.publishedAt)),
      if (apk != null) ('Taille de l\'APK', formatBytes(apk.size)),
      if (entry.minSdk != null)
        ('Compatibilité', '${androidLabel(entry.minSdk!)} ou plus récent'),
      ('Source du téléchargement', apk == null ? 'github.com/${entry.repo}' : _source(apk)),
      if (apk != null) ('Intégrité', _integrity(apk)),
      ('Dépôt public', 'github.com/${entry.repo}'),
    ];
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 4,
                      child: Text(rows[i].$1,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant))),
                  Expanded(flex: 6, child: Text(rows[i].$2, textAlign: TextAlign.end)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _source(ApkAsset apk) => Uri.parse(apk.url).host == 'github.com'
      ? 'GitHub Releases (${apk.name})'
      : Uri.parse(apk.url).host;

  static String _integrity(ApkAsset apk) => apk.sha256 != null
      ? 'SHA-256 publié par GitHub'
      : apk.checksumUrl != null
          ? 'SHA-256 publié avec la release'
          : 'Aucune somme de contrôle publiée';
}
