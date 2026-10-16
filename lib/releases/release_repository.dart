import 'dart:convert';

import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/releases/github_client.dart';
import 'package:lieluapp/releases/release_models.dart';
import 'package:lieluapp/releases/release_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Releases de chaque application : récupération GitHub + cache local.
///
/// Le corps JSON brut est mis en cache (avec son ETag) puis re-analysé à
/// chaque lecture : si une règle du catalogue change, elle s'applique sans
/// nouvelle requête.
final class ReleaseRepository {
  final GithubReleaseClient _client;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  ReleaseRepository(this._client, this._prefs, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  String _body(String id) => 'rel.$id.body';
  String _etag(String id) => 'rel.$id.etag';
  String _time(String id) => 'rel.$id.at';

  /// Lit le cache sans réseau.
  ReleaseResult? cached(CatalogEntry entry, {List<String> deviceAbis = const []}) {
    final body = _prefs.getString(_body(entry.id));
    if (body == null) return null;
    return _build(entry, body, deviceAbis,
        fetchedAt: DateTime.tryParse(_prefs.getString(_time(entry.id)) ?? ''));
  }

  /// Interroge GitHub (requête conditionnelle). En cas d'échec, retombe sur le
  /// cache s'il existe, marqué `stale`.
  Future<ReleaseResult> refresh(
    CatalogEntry entry, {
    List<String> deviceAbis = const [],
  }) async {
    final outcome = await _client.fetchReleases(entry.repo,
        etag: _prefs.getString(_etag(entry.id)));
    final now = _now().toUtc();
    switch (outcome) {
      case ReleasesFetched(:final rawBody, :final etag):
        await _prefs.setString(_body(entry.id), rawBody);
        await _prefs.setString(_time(entry.id), now.toIso8601String());
        if (etag != null) {
          await _prefs.setString(_etag(entry.id), etag);
        } else {
          await _prefs.remove(_etag(entry.id));
        }
        return _build(entry, rawBody, deviceAbis, fetchedAt: now);
      case ReleasesNotModified():
        await _prefs.setString(_time(entry.id), now.toIso8601String());
        return cached(entry, deviceAbis: deviceAbis) ??
            const ReleaseResult(status: ReleaseStatus.error, message: 'Cache vide.');
      case ReleasesFailure(:final kind, :final message, :final retryAt):
        final text = kind == FetchFailureKind.rateLimited && retryAt != null
            ? '$message Réessayez vers ${_hhmm(retryAt)}.'
            : message;
        final old = cached(entry, deviceAbis: deviceAbis);
        if (old != null && old.release != null) {
          return ReleaseResult(
            status: ReleaseStatus.ok,
            release: old.release,
            message: text,
            fetchedAt: old.fetchedAt,
            stale: true,
          );
        }
        return ReleaseResult(
          status: switch (kind) {
            FetchFailureKind.notFound => ReleaseStatus.notFound,
            FetchFailureKind.rateLimited => ReleaseStatus.rateLimited,
            FetchFailureKind.offline => ReleaseStatus.offline,
            FetchFailureKind.server => ReleaseStatus.error,
          },
          message: text,
        );
    }
  }

  ReleaseResult _build(CatalogEntry entry, String body, List<String> abis,
      {DateTime? fetchedAt}) {
    try {
      final decoded = jsonDecode(body);
      final release = selectRelease(entry.release, decoded as List, deviceAbis: abis);
      if (release == null) {
        return ReleaseResult(
          status: ReleaseStatus.noRelease,
          message: 'Aucune release stable publiée pour le moment.',
          fetchedAt: fetchedAt,
        );
      }
      return ReleaseResult(
          status: ReleaseStatus.ok, release: release, fetchedAt: fetchedAt);
    } catch (_) {
      return const ReleaseResult(
          status: ReleaseStatus.error, message: 'Cache des releases illisible.');
    }
  }

  static String _hhmm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
