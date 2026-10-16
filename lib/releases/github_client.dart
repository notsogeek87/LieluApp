import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:lieluapp/core/url_policy.dart';

sealed class ReleasesFetch {
  const ReleasesFetch();
}

/// Réponse 200 : corps JSON brut (liste de releases) et ETag pour la fois suivante.
final class ReleasesFetched extends ReleasesFetch {
  final List<dynamic> releases;
  final String rawBody;
  final String? etag;
  const ReleasesFetched(this.releases, this.rawBody, this.etag);
}

/// Réponse 304 : le cache est toujours valable (et ne consomme pas le quota).
final class ReleasesNotModified extends ReleasesFetch {
  const ReleasesNotModified();
}

enum FetchFailureKind { notFound, rateLimited, offline, server }

final class ReleasesFailure extends ReleasesFetch {
  final FetchFailureKind kind;
  final String message;
  final DateTime? retryAt;
  const ReleasesFailure(this.kind, this.message, {this.retryAt});
}

/// Lecture des releases publiques via l'API GitHub, sans jeton ni compte.
///
/// Sans authentification le quota est de 60 requêtes/heure/IP : on utilise
/// donc les requêtes conditionnelles (ETag) — une réponse 304 n'est pas décomptée.
final class GithubReleaseClient {
  final Dio _dio;
  static const _policy = UrlPolicy.github;

  GithubReleaseClient(this._dio);

  Future<ReleasesFetch> fetchReleases(String repo, {String? etag}) async {
    final uri = _policy.require('https://api.github.com/repos/$repo/releases?per_page=30');
    try {
      final resp = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            if (etag != null) 'If-None-Match': etag,
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          validateStatus: (_) => true,
        ),
      );
      final code = resp.statusCode ?? 0;
      if (code == 304) return const ReleasesNotModified();
      if (code == 200) {
        final body = resp.data ?? '';
        final decoded = jsonDecode(body);
        if (decoded is! List) {
          return const ReleasesFailure(
              FetchFailureKind.server, 'Réponse GitHub inattendue.');
        }
        return ReleasesFetched(decoded, body, resp.headers.value('etag'));
      }
      if (code == 404) {
        return const ReleasesFailure(FetchFailureKind.notFound,
            'Dépôt introuvable ou non public.');
      }
      if (code == 403 || code == 429) {
        final remaining = resp.headers.value('x-ratelimit-remaining');
        final reset = int.tryParse(resp.headers.value('x-ratelimit-reset') ?? '');
        if (remaining == '0' || code == 429) {
          return ReleasesFailure(
            FetchFailureKind.rateLimited,
            'Limite de requêtes GitHub atteinte.',
            retryAt: reset == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(reset * 1000),
          );
        }
        return const ReleasesFailure(
            FetchFailureKind.server, 'Accès refusé par GitHub (403).');
      }
      return ReleasesFailure(
          FetchFailureKind.server, 'GitHub indisponible (HTTP $code).');
    } on DioException catch (e) {
      return ReleasesFailure(
        FetchFailureKind.offline,
        switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout =>
            'Délai dépassé : GitHub ne répond pas.',
          _ => 'Pas de connexion à GitHub.',
        },
      );
    } on FormatException {
      return const ReleasesFailure(
          FetchFailureKind.server, 'Réponse GitHub illisible.');
    }
  }
}
