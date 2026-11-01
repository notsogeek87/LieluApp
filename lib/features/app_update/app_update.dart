import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lieluapp/platform/store_platform.dart';

const _latestReleaseUrl =
    'https://api.github.com/repos/notsogeek87/LieluApp/releases/latest';

/// Package Android du store.
const storePackageName = 'eu.lielu.lieluapp';

/// Empreinte SHA-256 du certificat de publication du store (CN=Lielu Store).
/// Toute mise à jour signée par une autre clé est refusée avant l'installation.
const storeSigningCertSha256 =
    '7d85d066c9575d76afe3b7a2b3fe8417a6f9059a76e5034d13aba586fed09e4f';

/// URL des releases, pour réinstaller à la main.
const storeReleasesUrl = 'https://github.com/notsogeek87/LieluApp/releases/latest';

/// A newer APK published as a GitHub release.
final class AppUpdate {
  final String versionName;
  final String apkUrl;

  /// SHA-256 publié par GitHub (`digest` de l'asset), null si inconnu.
  final String? sha256;
  const AppUpdate({required this.versionName, required this.apkUrl, this.sha256});
}

/// Contrôles d'un APK de mise à jour du store, lu par Android, avant installation.
/// Retourne null si tout est bon, sinon le motif du refus.
String? verifyStoreUpdate(ApkInspection apk, {int? installedBuild}) {
  if (apk.packageName != storePackageName) {
    return 'Ce fichier est « ${apk.packageName} », pas Lielu Store. Installation refusée.';
  }
  if (!apk.currentSigners.contains(storeSigningCertSha256)) {
    return 'Ce fichier n\'est pas signé par la clé de Lielu Store. Installation refusée.';
  }
  if (installedBuild != null && apk.versionCode <= installedBuild) {
    return 'Ce fichier (code ${apk.versionCode}) n\'est pas plus récent que la version '
        'installée (code $installedBuild).';
  }
  return null;
}

/// Vrai si le store installé est signé par l'ancienne clé de debug publique :
/// Android refusera toute mise à jour signée par la nouvelle clé.
bool storeNeedsReinstall(InstalledInfo? self) =>
    self != null && !self.signers.contains(storeSigningCertSha256);

/// Release tags are `v<pubspec version>.<run_number>` and the installed
/// versionCode is the run number (see android-build.yml), so the last tag
/// segment is directly comparable with the installed build number.
int? buildFromTag(String tag) {
  final parts = tag.replaceFirst(RegExp(r'^v'), '').split('.');
  return parts.length < 2 ? null : int.tryParse(parts.last);
}

/// Outcome of an update check, with enough detail to explain itself.
final class UpdateCheck {
  final String installedVersion;
  final int? installedBuild;
  final String? latestTag;
  final AppUpdate? update;
  final String? error;
  const UpdateCheck({
    required this.installedVersion,
    this.installedBuild,
    this.latestTag,
    this.update,
    this.error,
  });
}

const _repoUrl = 'https://github.com/notsogeek87/LieluApp';

/// Latest release via the GitHub API (60 req/h/IP without a token — the store's
/// own catalogue refresh shares that quota, so this can answer 403).
Future<({String tag, String? apkUrl, String? sha256})> _latestFromApi(Dio dio) async {
  final resp = await dio.get<Map<String, dynamic>>(
    _latestReleaseUrl,
    options: Options(headers: {'Accept': 'application/vnd.github+json'}),
  );
  final data = resp.data;
  final tag = data?['tag_name'] as String? ?? '';
  String? apk;
  String? digest;
  for (final asset in (data?['assets'] as List?) ?? const []) {
    final url = (asset as Map)['browser_download_url'] as String?;
    if (url != null && url.endsWith('.apk')) {
      apk = url;
      digest = RegExp(r'^sha256:([0-9a-fA-F]{64})$')
          .firstMatch('${asset['digest']}')
          ?.group(1)
          ?.toLowerCase();
      break;
    }
  }
  return (tag: tag, apkUrl: apk, sha256: digest);
}

/// Fallback without the API quota: `/releases/latest` redirects to the tag page,
/// and CI always names the asset `LieluApp-<version>.apk`.
Future<({String tag, String? apkUrl, String? sha256})> _latestFromRedirect(Dio dio) async {
  final resp = await dio.get<void>(
    '$_repoUrl/releases/latest',
    options: Options(
      followRedirects: false,
      validateStatus: (s) => s != null && s < 400,
    ),
  );
  final location = resp.headers.value('location') ?? '';
  final tag = location.split('/tag/').last.split('?').first;
  if (!RegExp(r'^v\d+(?:\.\d+)+$').hasMatch(tag)) {
    return (tag: tag, apkUrl: null, sha256: null);
  }
  final version = tag.replaceFirst(RegExp(r'^v'), '');
  return (
    tag: tag,
    apkUrl: '$_repoUrl/releases/download/$tag/LieluApp-$version.apk',
    sha256: null,
  );
}

/// Checks GitHub for a release newer than the installed build. Never throws:
/// failures (offline, rate limit, no release) are reported in [UpdateCheck.error].
Future<UpdateCheck> runUpdateCheck() async {
  String version = '?';
  int? installed;
  try {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version}+${info.buildNumber}';
    installed = int.tryParse(info.buildNumber);

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ));
    ({String tag, String? apkUrl, String? sha256}) latestRelease;
    try {
      latestRelease = await _latestFromApi(dio);
      if (buildFromTag(latestRelease.tag) == null) throw const FormatException('tag');
    } catch (_) {
      latestRelease = await _latestFromRedirect(dio);
    }

    final tag = latestRelease.tag;
    final latest = buildFromTag(tag);
    if (latest == null) {
      return UpdateCheck(
          installedVersion: version,
          installedBuild: installed,
          latestTag: tag,
          error: 'Unreadable release tag "$tag"');
    }

    AppUpdate? update;
    final apkUrl = latestRelease.apkUrl;
    if (installed != null && latest > installed && apkUrl != null) {
      update = AppUpdate(versionName: tag, apkUrl: apkUrl, sha256: latestRelease.sha256);
    }
    return UpdateCheck(
        installedVersion: version,
        installedBuild: installed,
        latestTag: tag,
        update: update);
  } catch (e) {
    return UpdateCheck(
        installedVersion: version, installedBuild: installed, error: '$e');
  }
}

Future<AppUpdate?> checkForAppUpdate() async => (await runUpdateCheck()).update;

/// Full outcome of the store's own update check (checked once per launch,
/// re-run on demand from the settings).
final appUpdateCheckProvider = FutureProvider<UpdateCheck>((ref) => runUpdateCheck());

final appUpdateProvider = Provider<AsyncValue<AppUpdate?>>(
    (ref) => ref.watch(appUpdateCheckProvider).whenData((c) => c.update));
