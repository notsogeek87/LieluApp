import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/core/version.dart';
import 'package:lieluapp/platform/store_platform.dart';
import 'package:lieluapp/releases/release_models.dart';

enum AppStatus {
  notInstalled,
  upToDate,
  updateAvailable,

  /// Installée, mais on ne peut pas dire si elle est à jour (version illisible,
  /// ou dernière version inconnue faute de release/réseau).
  unknown,
}

/// Une application du catalogue avec tout ce qu'on sait d'elle.
final class AppView {
  final CatalogEntry entry;
  final InstalledInfo? installed;
  final ReleaseResult? result;

  /// Dernier tag installé *par le store* (utile si `updateDetection: installedTag`).
  final String? trackedTag;

  const AppView(this.entry, {this.installed, this.result, this.trackedTag});

  ReleaseInfo? get release => result?.release;
  bool get isInstalled => installed != null;
  bool get installable => release?.apk != null;
  AppStatus get status => computeStatus(entry, installed, release, trackedTag);
  bool get hasUpdate => status == AppStatus.updateAvailable;
}

AppStatus computeStatus(
  CatalogEntry entry,
  InstalledInfo? installed,
  ReleaseInfo? latest,
  String? trackedTag,
) {
  if (installed == null) return AppStatus.notInstalled;
  if (latest == null) return AppStatus.unknown;

  final AppVersion? current;
  if (entry.release.updateDetection == UpdateDetection.installedTag) {
    final m = trackedTag == null ? null : entry.release.tagPattern.firstMatch(trackedTag);
    current = m == null || m.groupCount < 1 ? null : AppVersion.tryParse(m.group(1));
  } else {
    current = AppVersion.tryParse(installed.versionName);
  }
  if (current == null) return AppStatus.unknown;
  return latest.version > current ? AppStatus.updateAvailable : AppStatus.upToDate;
}
