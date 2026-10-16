import 'dart:convert';

import 'package:lieluapp/core/url_policy.dart';

enum Maintenance {
  active('Activement maintenue'),
  maintenance('Maintenance uniquement'),
  paused('En pause'),
  archived('Archivée');

  final String label;
  const Maintenance(this.label);

  static Maintenance parse(Object? value) => Maintenance.values.firstWhere(
        (m) => m.name == value,
        orElse: () => Maintenance.active,
      );
}

/// Comment savoir quelle version est installée par rapport à la dernière release.
enum UpdateDetection {
  /// `versionName` installé comparé à la version extraite du tag (cas normal).
  versionName,

  /// Pour les apps dont le `versionName` ne change pas d'un build à l'autre :
  /// on compare le dernier tag installé *par le store* au dernier tag publié.
  installedTag,
}

/// Règles de lecture des releases GitHub d'une application.
final class ReleaseRules {
  /// Les tags qui ne correspondent pas sont ignorés ; le groupe 1 est la version.
  final RegExp tagPattern;

  /// Nom du fichier APK à choisir (sinon : tous les `.apk`).
  final RegExp? apkPattern;

  /// APK à écarter explicitement (ex. variante « Staging »).
  final RegExp? apkExclude;
  final bool includePrereleases;
  final UpdateDetection updateDetection;

  const ReleaseRules({
    required this.tagPattern,
    this.apkPattern,
    this.apkExclude,
    this.includePrereleases = false,
    this.updateDetection = UpdateDetection.versionName,
  });

  static final defaultTagPattern =
      RegExp(r'^v?(\d+(?:\.\d+)*(?:-[0-9A-Za-z.\-]+)?)$');

  factory ReleaseRules.fromJson(Map<String, dynamic>? json) {
    RegExp? re(String key) {
      final v = json?[key];
      return v is String && v.isNotEmpty ? RegExp(v) : null;
    }

    return ReleaseRules(
      tagPattern: re('tagPattern') ?? defaultTagPattern,
      apkPattern: re('apkPattern'),
      apkExclude: re('apkExclude'),
      includePrereleases: json?['includePrereleases'] == true,
      updateDetection: json?['updateDetection'] == 'installedTag'
          ? UpdateDetection.installedTag
          : UpdateDetection.versionName,
    );
  }
}

/// Une application Lielu du catalogue central.
final class CatalogEntry {
  final String id;
  final String name;
  final String packageName;

  /// `owner/name` d'un dépôt GitHub public.
  final String repo;
  final String category;
  final String shortDescription;
  final String description;
  final String? iconUrl;
  final List<String> screenshots;
  final Maintenance maintenance;
  final bool featured;

  /// Indication de compatibilité (API Android minimale). La valeur réelle est
  /// relue dans l'APK avant installation.
  final int? minSdk;

  /// Empreinte SHA-256 du certificat de signature attendu, si on veut l'imposer
  /// dès la première installation.
  final String? signingCertSha256;
  final ReleaseRules release;

  const CatalogEntry({
    required this.id,
    required this.name,
    required this.packageName,
    required this.repo,
    required this.category,
    required this.shortDescription,
    required this.description,
    required this.release,
    this.iconUrl,
    this.screenshots = const [],
    this.maintenance = Maintenance.active,
    this.featured = false,
    this.minSdk,
    this.signingCertSha256,
  });

  String get repoUrl => 'https://github.com/$repo';
  String get releasesUrl => '$repoUrl/releases';
}

/// Résultat de lecture d'un catalogue : les entrées valides + les problèmes.
final class CatalogParseResult {
  final List<CatalogEntry> entries;
  final List<String> issues;
  final DateTime? updatedAt;
  const CatalogParseResult(this.entries, this.issues, this.updatedAt);
}

final _idRe = RegExp(r'^[a-z0-9][a-z0-9\-]{0,40}$');
final _packageRe = RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$');
final _repoRe = RegExp(r'^[A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+$');
final _sha256Re = RegExp(r'^[0-9A-Fa-f]{2}(:?[0-9A-Fa-f]{2}){31}$');

const supportedSchema = 1;

/// Lit un catalogue JSON. Une entrée invalide est ignorée (et signalée) sans
/// empêcher l'affichage des autres. Lève [FormatException] si le document
/// lui-même est inutilisable.
CatalogParseResult parseCatalog(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    throw FormatException('Catalogue illisible : ${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Catalogue : objet JSON attendu');
  }
  final schema = decoded['schemaVersion'];
  if (schema is! int || schema > supportedSchema) {
    throw FormatException(
        'Catalogue de version $schema non géré (max $supportedSchema) : mettez le store à jour');
  }
  final apps = decoded['apps'];
  if (apps is! List) throw const FormatException('Catalogue : « apps » manquant');

  final issues = <String>[];
  final entries = <CatalogEntry>[];
  final seenIds = <String>{};
  final seenPackages = <String>{};
  for (var i = 0; i < apps.length; i++) {
    final raw = apps[i];
    final label = raw is Map ? (raw['id'] ?? '#$i') : '#$i';
    try {
      if (raw is! Map<String, dynamic>) throw const FormatException('objet attendu');
      if (raw['listed'] == false) continue;
      final entry = _parseEntry(raw);
      if (!seenIds.add(entry.id)) {
        throw FormatException('id en double : ${entry.id}');
      }
      if (!seenPackages.add(entry.packageName)) {
        throw FormatException('packageName en double : ${entry.packageName}');
      }
      entries.add(entry);
    } on FormatException catch (e) {
      issues.add('Entrée « $label » ignorée : ${e.message}');
    }
  }
  return CatalogParseResult(
      entries, issues, DateTime.tryParse('${decoded['updatedAt']}'));
}

CatalogEntry _parseEntry(Map<String, dynamic> j) {
  String req(String key) {
    final v = j[key];
    if (v is! String || v.trim().isEmpty) {
      throw FormatException('champ « $key » manquant');
    }
    return v.trim();
  }

  final id = req('id');
  if (!_idRe.hasMatch(id)) throw FormatException('id invalide : $id');
  final packageName = req('packageName');
  if (!_packageRe.hasMatch(packageName)) {
    throw FormatException('packageName invalide : $packageName');
  }
  final repo = req('repo');
  if (!_repoRe.hasMatch(repo)) throw FormatException('repo invalide : $repo');

  String? imageUrl(Object? v) {
    if (v == null) return null;
    if (v is! String) throw const FormatException('URL d\'image invalide');
    try {
      return UrlPolicy.github.require(v).toString();
    } on UrlRejected catch (e) {
      throw FormatException(e.toString());
    }
  }

  final cert = j['signingCertSha256'];
  if (cert != null && (cert is! String || !_sha256Re.hasMatch(cert))) {
    throw const FormatException('signingCertSha256 invalide (SHA-256 hexadécimal)');
  }

  final shots = j['screenshots'];
  final rules = ReleaseRules.fromJson(j['release'] as Map<String, dynamic>?);
  // Le groupe 1 du tagPattern porte la version : on exige qu'il existe.
  if (RegExp('${rules.tagPattern.pattern}|').firstMatch('')!.groupCount < 1) {
    throw const FormatException('release.tagPattern doit contenir un groupe (version)');
  }
  return CatalogEntry(
    id: id,
    name: req('name'),
    packageName: packageName,
    repo: repo,
    category: (j['category'] as String?)?.trim().isNotEmpty == true
        ? (j['category'] as String).trim()
        : 'Autres',
    shortDescription: req('shortDescription'),
    description: (j['description'] as String?)?.trim() ?? req('shortDescription'),
    iconUrl: imageUrl(j['iconUrl']),
    screenshots: [
      for (final s in (shots is List ? shots : const [])) imageUrl(s)!,
    ],
    maintenance: Maintenance.parse(j['maintenance']),
    featured: j['featured'] == true,
    minSdk: j['minSdk'] is int ? j['minSdk'] as int : null,
    signingCertSha256: (cert as String?)?.replaceAll(':', '').toLowerCase(),
    release: rules,
  );
}
