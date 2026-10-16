import 'package:flutter/material.dart';
import 'package:lieluapp/core/url_policy.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre un lien externe dans le navigateur, uniquement en HTTPS.
Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null && uri.scheme == 'https' && UrlPolicy.github.isAllowed(uri) ||
      (uri != null && uri.scheme == 'https' && uri.host == 'github.com');
  if (!ok || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le lien.')));
    }
  }
}
