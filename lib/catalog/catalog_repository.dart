import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/core/url_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Catalogue central, hébergé dans un dépôt public. Surchargeable à la
/// compilation : `--dart-define=CATALOG_URL=https://raw.githubusercontent.com/...`.
const catalogUrl = String.fromEnvironment(
  'CATALOG_URL',
  defaultValue:
      'https://raw.githubusercontent.com/notsogeek87/LieluApp/main/catalog/apps.json',
);

const bundledCatalogAsset = 'catalog/apps.json';
const _cacheKey = 'catalog.json';
const _cacheTimeKey = 'catalog.fetchedAt';

/// Source du catalogue, par ordre de priorité :
/// 1. la copie distante (rafraîchie selon les réglages) ;
/// 2. la dernière copie valide gardée en cache (consultable hors ligne) ;
/// 3. la copie livrée dans l'APK (premier lancement sans réseau).
final class CatalogRepository {
  final Dio _dio;
  final SharedPreferences _prefs;
  final Future<String> Function() _loadBundled;
  final String url;

  CatalogRepository(
    this._dio,
    this._prefs, {
    Future<String> Function()? loadBundled,
    this.url = catalogUrl,
  }) : _loadBundled = loadBundled ?? (() => rootBundle.loadString(bundledCatalogAsset));

  DateTime? get lastFetch => DateTime.tryParse(_prefs.getString(_cacheTimeKey) ?? '');

  /// Catalogue disponible sans réseau (cache, sinon copie embarquée).
  Future<CatalogParseResult> loadLocal() async {
    final cached = _prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        return parseCatalog(cached);
      } on FormatException {
        // Cache corrompu : on retombe sur la copie embarquée.
      }
    }
    return parseCatalog(await _loadBundled());
  }

  /// Télécharge le catalogue distant. Retourne null en cas d'échec réseau ou
  /// de contenu invalide ([lastError] dit pourquoi) : le cache reste en place.
  Future<CatalogParseResult?> refresh() async {
    lastError = null;
    try {
      final uri = UrlPolicy.github.require(url);
      final resp = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Cache-Control': 'no-cache'},
        ),
      );
      final body = resp.data ?? '';
      final parsed = parseCatalog(body);
      await _prefs.setString(_cacheKey, body);
      await _prefs.setString(_cacheTimeKey, DateTime.now().toUtc().toIso8601String());
      return parsed;
    } on DioException catch (e) {
      lastError = e.response?.statusCode == 404
          ? 'Catalogue introuvable (dépôt non public ou fichier absent).'
          : 'Catalogue inaccessible : pas de connexion.';
    } on FormatException catch (e) {
      lastError = e.message;
    } on UrlRejected catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  String? lastError;
}
