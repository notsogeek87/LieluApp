import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/ui/widgets/app_card.dart';
import 'package:lieluapp/ui/widgets/status_banner.dart';

enum _InstallFilter { all, installed, notInstalled }

enum _Sort { news, name }

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  String _query = '';
  String? _category;
  _InstallFilter _filter = _InstallFilter.all;
  _Sort _sort = _Sort.news;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(appViewsProvider);
    final categories = {for (final v in all) v.entry.category}.toList()..sort();

    var shown = all.where((v) {
      if (_query.isNotEmpty &&
          !v.entry.name.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_category != null && v.entry.category != _category) return false;
      return switch (_filter) {
        _InstallFilter.all => true,
        _InstallFilter.installed => v.isInstalled,
        _InstallFilter.notInstalled => !v.isInstalled,
      };
    }).toList();
    shown.sort((a, b) {
      if (_sort == _Sort.name) {
        return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
      }
      final da = a.release?.publishedAt;
      final db = b.release?.publishedAt;
      if (da == null && db == null) return a.entry.name.compareTo(b.entry.name);
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search), hintText: 'Rechercher une application…'),
                  ),
                ),
                PopupMenuButton<_Sort>(
                  tooltip: 'Trier',
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _Sort.news, child: Text('Nouveautés')),
                    PopupMenuItem(value: _Sort.name, child: Text('Nom (A → Z)')),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (f, label) in [
                  (_InstallFilter.all, 'Toutes'),
                  (_InstallFilter.installed, 'Installées'),
                  (_InstallFilter.notInstalled, 'Non installées'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
                if (categories.length > 1) const VerticalDivider(width: 16, indent: 10, endIndent: 10),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (on) => setState(() => _category = on ? c : null),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16), child: StatusBanner()),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(releasesProvider.notifier).refresh(),
              child: shown.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Text(
                            all.isEmpty
                                ? 'Chargement du catalogue…'
                                : 'Aucune application ne correspond.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: shown.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => AppCard(shown[i], showDate: true),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
