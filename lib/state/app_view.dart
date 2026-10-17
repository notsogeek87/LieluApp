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

  /// Une version plus récente existe sur GitHub, mais l'app a été installée
  /// via un autre magasin (ex. Play Store) ou signée avec une autre clé :
  /// Android refuserait la mise à jour.
  updateBlocked,
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
  AppStatus get status {
    final s = computeStatus(entry, installed, release, trackedTag);
    return s == AppStatus.updateAvailable && updateBlockedReason != null
        ? AppStatus.updateBlocked
        : s;
  }

  bool get hasUpdate => status == AppStatus.updateAvailable;

  /// Pourquoi la mise à jour GitHub ne pourrait pas s'installer (null = rien à signaler).
  String? get updateBlockedReason {
    final inst = installed;
    if (inst == null) return null;
    final pinned = entry.signingCertSha256;
    if (pinned != null && inst.signers.isNotEmpty && !inst.signers.contains(pinned)) {
      return 'Votre version (${inst.installerLabel}) n\'est pas signée avec la clé de la version GitHub : '
          'Android refuserait la mise à jour. Désinstallez-la puis installez celle de GitHub '
          '(les données de l\'app seront perdues).';
    }
    if (inst.fromForeignStore) {
      return 'Installée via ${inst.installerLabel} : cette version est plus ancienne que celle de GitHub, '
          'mais la mise à jour ne fonctionnera pas (signature différente). '
          'Mettez-la à jour depuis ${inst.installerLabel}, ou désinstallez-la pour installer celle de GitHub '
          '(les données de l\'app seront perdues).';
    }
    return null;
  }
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
