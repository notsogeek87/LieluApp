import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/releases/release_models.dart';
import 'package:lieluapp/state/providers.dart';
import 'package:lieluapp/ui/theme.dart';

/// Informe, sans bloquer, des problèmes réseau/GitHub (catalogue ou releases).
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider).value;
    final releases = ref.watch(releasesProvider).value;
    final messages = <String>[];
    if (catalog?.error != null) {
      messages.add('${catalog!.error} Le catalogue en cache est affiché.');
    }
    final results = releases?.results.values ?? const <ReleaseResult>[];
    final limited = results.where((r) => r.status == ReleaseStatus.rateLimited);
    final offline = results.where((r) => r.status == ReleaseStatus.offline || r.stale);
    if (limited.isNotEmpty) {
      messages.add(limited.first.message ?? 'Limite de requêtes GitHub atteinte.');
    } else if (offline.isNotEmpty) {
      messages.add('GitHub est injoignable : dernières versions connues affichées.');
    }
    if (messages.isEmpty) return const SizedBox.shrink();
    return Card(
      color: LieluColors.amber.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: LieluColors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(messages.join('\n'), style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
