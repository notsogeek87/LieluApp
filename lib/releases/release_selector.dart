import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/core/version.dart';
import 'package:lieluapp/releases/release_models.dart';

/// Choisit la dernière release stable d'une application dans la réponse
/// brute de `GET /repos/{repo}/releases`.
///
/// - brouillons ignorés ; préversions ignorées sauf `includePrereleases` ;
/// - le tag doit correspondre à `tagPattern` (le groupe 1 est la version) ;
/// - on prend la plus haute *version* (pas la plus récente par date), à date
///   de publication égale on garde la plus récente.
/// Retourne null s'il n'y a aucune release éligible.
ReleaseInfo? selectRelease(
  ReleaseRules rules,
  List<dynamic> rawReleases, {
  List<String> deviceAbis = const [],
}) {
  ReleaseInfo? best;
  for (final raw in rawReleases) {
    if (raw is! Map<String, dynamic>) continue;
    if (raw['draft'] == true) continue;
    final prerelease = raw['prerelease'] == true;
    if (prerelease && !rules.includePrereleases) continue;
    final tag = raw['tag_name'];
    if (tag is! String) continue;
    final m = rules.tagPattern.firstMatch(tag);
    if (m == null || m.groupCount < 1) continue;
    final version = AppVersion.tryParse(m.group(1));
    if (version == null) continue;

    final published = DateTime.tryParse('${raw['published_at']}');
    if (best != null) {
      final c = version.compareTo(best.version);
      final newer = c > 0 ||
          (c == 0 &&
              published != null &&
              best.publishedAt != null &&
              published.isAfter(best.publishedAt!));
      if (!newer) continue;
    }

    final choice = selectApk(rules, (raw['assets'] as List?) ?? const [],
        deviceAbis: deviceAbis);
    best = ReleaseInfo(
      tag: tag,
      version: version,
      title: (raw['name'] as String?)?.trim().isNotEmpty == true
          ? raw['name'] as String
          : tag,
      notes: (raw['body'] as String?)?.trim() ?? '',
      publishedAt: published,
      htmlUrl: (raw['html_url'] as String?) ?? '',
      prerelease: prerelease,
      apk: choice.asset,
      apkProblem: choice.problem,
    );
  }
  return best;
}

final class ApkChoice {
  final ApkAsset? asset;
  final String? problem;
  const ApkChoice.found(this.asset) : problem = null;
  const ApkChoice.none(this.problem) : asset = null;
}

const _abiAliases = <String, List<String>>{
  'arm64-v8a': ['arm64-v8a', 'arm64'],
  'armeabi-v7a': ['armeabi-v7a', 'armv7', 'arm32'],
  'x86_64': ['x86_64', 'x64'],
  'x86': ['x86'],
  'universal': ['universal'],
};

/// ABI annoncée par le nom de fichier, ou null si le nom n'en dit rien.
String? abiOfFileName(String fileName) {
  final n = fileName.toLowerCase();
  // x86_64 avant x86 : le second est un préfixe du premier.
  for (final abi in ['x86_64', 'arm64-v8a', 'armeabi-v7a', 'universal', 'x86']) {
    for (final alias in _abiAliases[abi]!) {
      final re = RegExp(r'(^|[^a-z0-9])' + RegExp.escape(alias) + r'(?!_64)($|[^a-z0-9])');
      if (re.hasMatch(n)) return abi;
    }
  }
  return null;
}

/// Choisit l'APK d'une release. Ne devine jamais : en cas d'ambiguïté ou
/// d'incompatibilité, retourne un problème explicite.
ApkChoice selectApk(
  ReleaseRules rules,
  List<dynamic> rawAssets, {
  List<String> deviceAbis = const [],
}) {
  final apks = <Map<String, dynamic>>[
    for (final a in rawAssets)
      if (a is Map<String, dynamic> &&
          (a['name'] as String? ?? '').toLowerCase().endsWith('.apk') &&
          a['state'] != 'open' &&
          a['browser_download_url'] is String)
        a,
  ];
  if (apks.isEmpty) return const ApkChoice.none('Aucun fichier APK dans cette release.');

  final candidates = apks.where((a) {
    final name = a['name'] as String;
    if (rules.apkPattern != null && !rules.apkPattern!.hasMatch(name)) return false;
    if (rules.apkExclude != null && rules.apkExclude!.hasMatch(name)) return false;
    return true;
  }).toList();
  if (candidates.isEmpty) {
    return ApkChoice.none(rules.apkPattern != null
        ? 'Aucun APK ne correspond à la règle du catalogue (${apks.map((a) => a['name']).join(', ')}).'
        : 'Tous les APK de cette release sont exclus par le catalogue.');
  }

  // Rang : plus petit = meilleur. ABI propre à l'appareil < universel < sans indication.
  int? rankOf(String name) {
    final abi = abiOfFileName(name);
    if (abi == null) return 101;
    if (abi == 'universal') return 100;
    if (deviceAbis.isEmpty) return 50;
    final i = deviceAbis.indexOf(abi);
    return i < 0 ? null : i;
  }

  final ranked = <(int, Map<String, dynamic>)>[];
  for (final a in candidates) {
    final r = rankOf(a['name'] as String);
    if (r != null) ranked.add((r, a));
  }
  if (ranked.isEmpty) {
    return ApkChoice.none(
        'Aucun APK compatible avec ce téléphone (architectures : ${deviceAbis.join(', ')}).');
  }
  ranked.sort((x, y) => x.$1.compareTo(y.$1));
  final top = ranked.where((e) => e.$1 == ranked.first.$1).toList();
  if (top.length > 1) {
    return ApkChoice.none(
        'Plusieurs APK possibles (${top.map((e) => e.$2['name']).join(', ')}) : '
        'précisez « apkPattern » dans le catalogue.');
  }
  return ApkChoice.found(_toAsset(top.single.$2, rawAssets));
}

final _digestRe = RegExp(r'^sha256:([0-9a-fA-F]{64})$');

ApkAsset _toAsset(Map<String, dynamic> a, List<dynamic> allAssets) {
  final name = a['name'] as String;
  final digest = _digestRe.firstMatch('${a['digest']}')?.group(1)?.toLowerCase();
  String? checksumUrl;
  if (digest == null) {
    // Pas de digest fourni par GitHub : un fichier « <apk>.sha256 » (ou
    // « .sha256sum ») publié à côté de l'APK peut en tenir lieu.
    for (final other in allAssets) {
      if (other is! Map<String, dynamic>) continue;
      final n = (other['name'] as String? ?? '').toLowerCase();
      if ((n == '${name.toLowerCase()}.sha256' ||
              n == '${name.toLowerCase()}.sha256sum') &&
          other['browser_download_url'] is String) {
        checksumUrl = other['browser_download_url'] as String;
        break;
      }
    }
  }
  return ApkAsset(
    name: name,
    url: a['browser_download_url'] as String,
    size: a['size'] is int ? a['size'] as int : null,
    sha256: digest,
    checksumUrl: checksumUrl,
  );
}
