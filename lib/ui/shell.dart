import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/ui/pages/apps_page.dart';
import 'package:lieluapp/ui/pages/downloads_page.dart';
import 'package:lieluapp/ui/pages/home_page.dart';
import 'package:lieluapp/ui/pages/updates_page.dart';
import 'package:lieluapp/ui/theme.dart';

/// Navigation principale : barre inférieure sur téléphone, rail latéral sur grand écran.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(installControllerProvider.notifier).onResumed();
    }
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final updates = ref.watch(updatesProvider).length;
    final active =
        ref.watch(installControllerProvider).values.where((s) => s.phase.active).length;

    Widget badge(int n, Widget icon) =>
        n == 0 ? icon : Badge.count(count: n, child: icon);

    final destinations = [
      ('Accueil', const Icon(Icons.home_outlined), const Icon(Icons.home)),
      ('Toutes les apps', const Icon(Icons.apps_outlined), const Icon(Icons.apps)),
      ('Mises à jour', badge(updates, const Icon(Icons.system_update_alt_outlined)),
          badge(updates, const Icon(Icons.system_update_alt))),
      ('Téléchargements', badge(active, const Icon(Icons.download_outlined)),
          badge(active, const Icon(Icons.download))),
    ];

    final pages = [
      HomePage(onOpenCatalog: () => _go(1), onOpenUpdates: () => _go(2)),
      const AppsPage(),
      const UpdatesPage(),
      const DownloadsPage(),
    ];
    final body = IndexedStack(index: _index, children: pages);

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 840;
      return Scaffold(
        body: DecoratedBox(
          decoration: lieluBackground(context),
          child: wide
              ? Row(children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _go,
                    backgroundColor: Colors.transparent,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                            icon: d.$2, selectedIcon: d.$3, label: Text(d.$1)),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760), child: body),
                    ),
                  ),
                ])
              : body,
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _go,
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(icon: d.$2, selectedIcon: d.$3, label: d.$1),
                ],
              ),
      );
    });
  }
}
