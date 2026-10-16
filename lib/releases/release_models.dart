import 'package:lieluapp/core/version.dart';

/// Un APK téléchargeable attaché à une release GitHub.
final class ApkAsset {
  final String name;
  final String url;
  final int? size;

  /// SHA-256 publié par GitHub (champ `digest`) ou par un fichier `.sha256`
  /// voisin, en hexadécimal minuscule. Null = aucune somme de contrôle fiable.
  final String? sha256;

  /// URL d'un fichier `<apk>.sha256` publié à côté de l'APK, si présent et
  /// qu'aucun digest n'est fourni par l'API.
  final String? checksumUrl;

  const ApkAsset({
    required this.name,
    required this.url,
    this.size,
    this.sha256,
    this.checksumUrl,
  });
}

/// Dernière release stable d'une application.
final class ReleaseInfo {
  final String tag;
  final AppVersion version;
  final String title;
  final String notes;
  final DateTime? publishedAt;
  final String htmlUrl;
  final bool prerelease;

  /// APK retenu, ou null si aucun ne convient ([apkProblem] dit pourquoi).
  final ApkAsset? apk;
  final String? apkProblem;

  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.title,
    required this.notes,
    required this.publishedAt,
    required this.htmlUrl,
    required this.prerelease,
    required this.apk,
    required this.apkProblem,
  });
}

enum ReleaseStatus {
  ok,
  noRelease,
  notFound,
  rateLimited,
  offline,
  error,
}

/// Ce que le store sait des releases d'une application à un instant donné.
final class ReleaseResult {
  final ReleaseStatus status;
  final ReleaseInfo? release;
  final String? message;
  final DateTime? fetchedAt;

  /// Vrai si [release] vient du cache alors que le rafraîchissement a échoué.
  final bool stale;

  const ReleaseResult({
    required this.status,
    this.release,
    this.message,
    this.fetchedAt,
    this.stale = false,
  });
}
