import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/install/install_models.dart';
import 'package:lieluapp/state/app_view.dart';
import 'package:lieluapp/state/providers.dart';

Future<void> openApp(BuildContext context, WidgetRef ref, AppView view) async {
  final ok = await ref.read(platformProvider).launch(view.entry.packageName);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir ${view.entry.name}.')));
  }
}

/// Bouton contextuel : Installer / Ouvrir / Mettre à jour, ou progression.
class AppActionButton extends ConsumerWidget {
  final AppView view;
  final bool compact;
  const AppActionButton(this.view, {super.key, this.compact = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final install = ref.watch(installControllerProvider)[view.entry.id];
    final controller = ref.read(installControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    Widget child;
    if (install != null && install.phase.active) {
      child = _Progress(install: install, compact: compact, onCancel: () => controller.cancel(view.entry.id));
    } else {
      switch (view.status) {
        case AppStatus.notInstalled:
          child = view.installable
              ? FilledButton(
                  onPressed: () => controller.start(view.entry, view.release!),
                  child: const Text('Installer'),
                )
              : FilledButton(
                  onPressed: null,
                  child: Text(view.result?.status.name == 'offline' ? 'Hors ligne' : 'Indisponible'),
                );
        case AppStatus.updateAvailable:
          child = FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.secondary),
            onPressed: view.installable
                ? () => controller.start(view.entry, view.release!)
                : null,
            child: const Text('Mettre à jour'),
          );
        case AppStatus.upToDate || AppStatus.unknown || AppStatus.updateBlocked:
          child = FilledButton.tonal(
            onPressed: () => openApp(context, ref, view),
            child: const Text('Ouvrir'),
          );
      }
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      child: KeyedSubtree(
        key: ValueKey('${view.status.name}-${install?.phase.name}-${view.installable}'),
        child: child,
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final InstallState install;
  final bool compact;
  final VoidCallback onCancel;
  const _Progress({required this.install, required this.compact, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final cancellable = install.phase == InstallPhase.downloading ||
        install.phase == InstallPhase.needsPermission;
    final label = switch (install.phase) {
      InstallPhase.downloading =>
        install.progress == null ? 'Téléchargement…' : '${(install.progress! * 100).round()} %',
      InstallPhase.verifying => 'Vérification…',
      InstallPhase.needsPermission => 'Autorisation requise',
      InstallPhase.awaitingConfirmation => 'Confirmez',
      _ => '',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            value: install.phase == InstallPhase.downloading ? install.progress : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        if (cancellable)
          IconButton(
            tooltip: 'Annuler',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
      ],
    );
  }
}
