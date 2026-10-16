import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:lieluapp/core/url_policy.dart';

final class DownloadException implements Exception {
  final String message;
  const DownloadException(this.message);
  @override
  String toString() => message;
}

/// Téléchargement HTTPS d'un APK, avec contrôle de chaque redirection.
///
/// GitHub répond par un 302 vers un stockage signé (`objects.` / `release-assets.githubusercontent.com`) :
/// les redirections sont suivies à la main pour que *chaque* hôte traversé
/// passe par [UrlPolicy]. Le fichier est écrit en `.part` puis renommé.
final class ApkDownloader {
  final Dio _dio;
  final UrlPolicy policy;
  static const _maxRedirects = 5;

  ApkDownloader(this._dio, {this.policy = UrlPolicy.github});

  Future<ResponseBody> _open(String url, CancelToken? cancel) async {
    var current = policy.require(url);
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final Response<ResponseBody> resp;
      try {
        resp = await _dio.getUri<ResponseBody>(
          current,
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            receiveTimeout: const Duration(seconds: 30),
            validateStatus: (s) => s != null && s < 400,
          ),
        );
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        final code = e.response?.statusCode;
        throw DownloadException(code == 404
            ? 'Fichier introuvable sur GitHub (404).'
            : code != null
                ? 'GitHub a refusé le téléchargement (HTTP $code).'
                : 'Téléchargement impossible : connexion perdue ou indisponible.');
      }
      final code = resp.statusCode ?? 0;
      if (code >= 300) {
        unawaited(resp.data!.stream.listen(null).cancel());
        final location = resp.headers.value('location');
        if (location == null) throw const DownloadException('Redirection invalide.');
        try {
          current = policy.require(current.resolve(location).toString());
        } on UrlRejected catch (e) {
          throw DownloadException('Téléchargement bloqué : $e');
        }
        continue;
      }
      return resp.data!;
    }
    throw const DownloadException('Trop de redirections.');
  }

  /// Télécharge [url] vers [destPath]. [onProgress] reçoit (reçu, total) ;
  /// total vaut -1 s'il est inconnu.
  Future<File> download(
    String url,
    String destPath, {
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final body = await _open(url, cancelToken);
    final total = int.tryParse(body.headers['content-length']?.first ?? '') ??
        expectedSize ??
        -1;
    final part = File('$destPath.part');
    await part.parent.create(recursive: true);
    final sink = part.openWrite();
    var received = 0;
    try {
      await for (final chunk in body.stream) {
        if (cancelToken?.isCancelled ?? false) {
          throw DioException.requestCancelled(
              requestOptions: RequestOptions(path: url), reason: 'annulé');
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      if (cancelToken?.isCancelled ?? false) {
        throw DioException.requestCancelled(
            requestOptions: RequestOptions(path: url), reason: 'annulé');
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close().catchError((_) {});
      if (await part.exists()) await part.delete();
      if (e is DioException) rethrow;
      throw const DownloadException('Téléchargement interrompu : connexion perdue.');
    }
    if (expectedSize != null && expectedSize > 0 && received != expectedSize) {
      await part.delete();
      throw DownloadException(
          'Fichier incomplet ($received octets reçus sur $expectedSize attendus).');
    }
    final dest = File(destPath);
    if (await dest.exists()) await dest.delete();
    return part.rename(destPath);
  }

  /// Lit un petit fichier texte (somme de contrôle). Plafonné pour éviter
  /// qu'un fichier géant soit chargé en mémoire.
  Future<String> fetchSmallText(String url, {int maxBytes = 4096}) async {
    final body = await _open(url, null);
    final bytes = <int>[];
    await for (final chunk in body.stream) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) {
        throw const DownloadException('Fichier de somme de contrôle trop volumineux.');
      }
    }
    return String.fromCharCodes(bytes);
  }
}

/// SHA-256 hexadécimal minuscule d'un fichier, lu en flux.
Future<String> sha256OfFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// Extrait un SHA-256 d'un fichier `.sha256` (hex seul, ou hex suivi du nom de fichier).
String? parseSha256File(String text) =>
    RegExp(r'\b([0-9a-fA-F]{64})\b').firstMatch(text)?.group(1)?.toLowerCase();
