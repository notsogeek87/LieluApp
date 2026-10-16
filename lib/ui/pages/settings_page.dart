import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/catalog/catalog_repository.dart';
import 'package:lieluapp/core/format.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/state/settings.dart';
import 'package:lieluapp/ui/widgets/links.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>((_) => PackageInfo.fromPlatform());

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static String _hoursLabel(int h) => switch (h) {
        0 => 'Manuel uniquement',
        1 => 'Toutes les heures',
        24 => 'Tous les jours',
        _ => 'Toutes les $h heures',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final catalog = ref.watch(catalogProvider).value;
    final releases = ref.watch(releasesProvider).value;
    final info = ref.watch(_packageInfoProvider).value;
    final refreshing = (catalog?.refreshing ?? false) || (releases?.refreshing ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: DecoratedBox(
        decoration: const BoxDecoration(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _Title('Catalogue'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Fréquence de rafraîchissement'),
                        subtitle: Text(_hoursLabel(settings.refreshHours)),
                        trailing: PopupMenuButton<int>(
                          icon: const Icon(Icons.expand_more),
                          initialValue: settings.refreshHours,
                          onSelected: notifier.setRefreshHours,
                          itemBuilder: (_) => [
                            for (final h in refreshChoices)
                              PopupMenuItem(value: h, child: Text(_hoursLabel(h))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Vérifier les mises à jour'),
                        subtitle: Text(
                            'Catalogue : ${formatDateTime(catalog?.fetchedAt)}\n'
                            'Releases : ${formatDateTime(releases?.lastCheck)}'),
                        isThreeLine: true,
                        trailing: refreshing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Icon(Icons.refresh),
                        onTap: refreshing
                            ? null
                            : () async {
                                await ref.read(catalogProvider.notifier).refresh();
                                await ref.read(releasesProvider.notifier).refresh();
                                await ref.read(installedProvider.notifier).refresh();
                              },
                      ),
                    ],
                  ),
                ),
                if (catalog != null && catalog.issues.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text('Entrées du catalogue ignorées :\n${catalog.issues.join('\n')}',
                          style: theme.textTheme.bodySmall),
                    ),
                  ),
                ],
                _Title('Apparence'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: ThemeMode.dark, label: Text('Sombre')),
                        ButtonSegment(value: ThemeMode.light, label: Text('Clair')),
                        ButtonSegment(value: ThemeMode.system, label: Text('Système')),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) => notifier.setThemeMode(s.first),
                    ),
                  ),
                ),
                _Title('Provenance et confiance'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Les APK sont téléchargés uniquement depuis les releases GitHub '
                          'publiques des dépôts listés dans le catalogue (HTTPS, hôtes GitHub '
                          'uniquement, chaque redirection est contrôlée).\n\n'
                          'Avant toute installation, le store vérifie quand c\'est possible : '
                          'la somme SHA-256 publiée avec la release, le nom du paquet, la '
                          'compatibilité avec votre téléphone, l\'absence de rétrogradation et '
                          'que la signature est la même que celle de l\'application déjà '
                          'installée. Ce qui n\'a pas pu être vérifié est indiqué comme tel.\n\n'
                          'Android demande toujours votre confirmation pour installer. '
                          'Aucun compte, aucune donnée collectée.',
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                        ),
                        const SizedBox(height: 10),
                        Text('Catalogue : $catalogUrl',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                _Title('À propos'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Lielu Store'),
                        subtitle: Text(info == null
                            ? '—'
                            : 'Version ${info.version} (build ${info.buildNumber})\n'
                                'Mes applications, au même endroit.'),
                        isThreeLine: true,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Code source du store'),
                        subtitle: const Text('github.com/notsogeek87/LieluApp'),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => openUrl(context, 'https://github.com/notsogeek87/LieluApp'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}
