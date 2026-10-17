import 'package:flutter/material.dart';
import 'package:lieluapp/core/format.dart';
import 'package:lieluapp/state/app_view.dart';
import 'package:lieluapp/ui/pages/detail_page.dart';
import 'package:lieluapp/ui/theme.dart';
import 'package:lieluapp/ui/widgets/action_button.dart';
import 'package:lieluapp/ui/widgets/app_icon.dart';

/// Ligne « application » : icône, nom, description, version, action principale.
class AppCard extends StatelessWidget {
  final AppView view;
  final bool showDate;
  const AppCard(this.view, {super.key, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => AppDetailPage(appId: view.entry.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(view.entry, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(view.entry.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(view.entry.shortDescription,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Tag(view.entry.category),
                        _VersionLabel(view, showDate: showDate),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppActionButton(view),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}

class _VersionLabel extends StatelessWidget {
  final AppView view;
  final bool showDate;
  const _VersionLabel(this.view, {required this.showDate});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final latest = view.release?.version;
    final inst = view.installed;
    final (String text, Color? color) = switch (view.status) {
      AppStatus.updateAvailable => (
          'v${inst!.versionName} → v$latest',
          LieluColors.amber,
        ),
      AppStatus.updateBlocked => (
          'v${inst!.versionName} (${inst.installerLabel}) · GitHub : v$latest, mise à jour impossible',
          LieluColors.amber,
        ),
      AppStatus.upToDate => ('v${inst!.versionName} · à jour', LieluColors.mint),
      AppStatus.unknown => ('v${inst!.versionName} installée', null),
      AppStatus.notInstalled => (
          latest != null
              ? 'v$latest${showDate ? ' · ${formatDate(view.release?.publishedAt)}' : ''}'
              : view.result == null
                  ? 'Recherche…'
                  : 'Aucune release',
          null,
        ),
    };
    return Text(text, style: style?.copyWith(color: color));
  }
}
