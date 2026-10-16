/// Politique de confiance réseau : HTTPS obligatoire, hôtes GitHub uniquement.
///
/// Appliquée au catalogue, à l'API des releases et à *chaque* redirection d'un
/// téléchargement d'APK.
final class UrlPolicy {
  final Set<String> allowedHosts;
  const UrlPolicy(this.allowedHosts);

  static const github = UrlPolicy({
    'github.com',
    'api.github.com',
    'raw.githubusercontent.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
    'github-releases.githubusercontent.com',
  });

  bool isAllowed(Uri uri) =>
      uri.scheme == 'https' && allowedHosts.contains(uri.host.toLowerCase());

  /// Lève [UrlRejected] si [url] n'est pas autorisée.
  Uri require(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) throw UrlRejected(url, 'URL illisible');
    if (uri.scheme != 'https') throw UrlRejected(url, 'HTTPS obligatoire');
    if (!allowedHosts.contains(uri.host.toLowerCase())) {
      throw UrlRejected(url, 'hôte non autorisé : ${uri.host}');
    }
    return uri;
  }
}

final class UrlRejected implements Exception {
  final String url;
  final String reason;
  const UrlRejected(this.url, this.reason);

  @override
  String toString() => 'URL refusée ($reason) : $url';
}
