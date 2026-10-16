import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/features/app_update/app_update_banner.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/ui/pages/settings_page.dart';
import 'package:lieluapp/ui/theme.dart';
import 'package:lieluapp/ui/widgets/app_card.dart';
import 'package:lieluapp/ui/widgets/status_banner.dart';

class HomePage extends ConsumerWidget {
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenUpdates;
  const HomePage({super.key, required this.onOpenCatalog, required this.onOpenUpdates});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final views = ref.watch(appViewsProvider);
    final updates = views.where((a) => a.hasUpdate).toList();
    var featured = views.where((a) => a.entry.featured).toList();
    if (featured.isEmpty) featured = views.take(3).toList();
    final news = views.where((a) => a.release?.publishedAt != null).toList()
      ..sort((a, b) => b.release!.publishedAt!.compareTo(a.release!.publishedAt!));
    final loading = ref.watch(catalogProvider).isLoading;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(catalogProvider.notifier).refresh();
          await ref.read(releasesProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                        colors: [LieluColors.violet, LieluColors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  alignment: Alignment.center,
                  child: const Text('L',
                      style: TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Lielu '),
                  TextSpan(text: 'Store', style: TextStyle(color: theme.colorScheme.primary)),
                ]), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  tooltip: 'Paramètres',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onOpenCatalog,
              child: InputDecorator(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'Rechercher une application…'),
                child: Text('Rechercher une application…',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
            const SizedBox(height: 14),
            const AppUpdateBanner(),
            const StatusBanner(),
            const SizedBox(height: 4),
            _Hero(onOpenCatalog: onOpenCatalog),
            if (updates.isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: Icon(Icons.system_update_alt, color: theme.colorScheme.secondary),
                  title: Text(updates.length == 1
                      ? '1 mise à jour disponible'
                      : '${updates.length} mises à jour disponibles'),
                  subtitle: Text(updates.map((u) => u.entry.name).join(', '),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenUpdates,
                ),
              ),
            ],
            if (loading && views.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            if (featured.isNotEmpty) ...[
              _Header('Applications à la une', onSeeAll: onOpenCatalog),
              for (final v in featured) _Gap(AppCard(v)),
            ],
            if (news.isNotEmpty) ...[
              const _Header('Dernières nouveautés'),
              for (final v in news.take(4)) _Gap(AppCard(v, showDate: true)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  final Widget child;
  const _Gap(this.child);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: child);
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _Header(this.title, {this.onSeeAll});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
            if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('Tout voir')),
          ],
        ),
      );
}

class _Hero extends StatelessWidget {
  final VoidCallback onOpenCatalog;
  const _Hero({required this.onOpenCatalog});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2A7A), Color(0xFF1B2A6B), Color(0xFF14204F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: LieluColors.violet.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bienvenue sur Lielu Store',
              style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          Text('Mes applications,\nau bout des doigts',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
          const SizedBox(height: 8),
          Text('Découvrez, installez et mettez à jour toutes les applications Lielu. '
              'Sans compte, sans connexion GitHub.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenCatalog,
            icon: const Icon(Icons.arrow_forward, size: 18),
            iconAlignment: IconAlignment.end,
            label: const Text('Voir toutes les apps'),
          ),
        ],
      ),
    );
  }
}
