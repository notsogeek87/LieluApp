/// Formats d'affichage en français, sans dépendance de localisation.
String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return 'Taille inconnue';
  const units = ['o', 'Ko', 'Mo', 'Go'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final text = i == 0 || value >= 100 ? value.round().toString() : value.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')} ${units[i]}';
}

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String formatDate(DateTime? d) {
  if (d == null) return 'Date inconnue';
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

String formatDateTime(DateTime? d) {
  if (d == null) return 'jamais';
  final l = d.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${formatDate(l)}, $hh:$mm';
}

/// Version lisible d'une release GitHub (markdown) : sans symboles de mise en forme.
String plainNotes(String markdown) {
  var t = markdown.replaceAll('\r\n', '\n');
  t = t.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');
  t = t.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
  t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!);
  t = t.replaceAll(RegExp(r'\*\*|__|`'), '');
  t = t.replaceAllMapped(RegExp(r'^\s*[-*]\s+', multiLine: true), (_) => '• ');
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return t.trim();
}

String androidLabel(int sdk) => switch (sdk) {
      24 => 'Android 7.0',
      25 => 'Android 7.1',
      26 => 'Android 8.0',
      27 => 'Android 8.1',
      28 => 'Android 9',
      29 => 'Android 10',
      30 => 'Android 11',
      31 => 'Android 12',
      32 => 'Android 12L',
      33 => 'Android 13',
      34 => 'Android 14',
      35 => 'Android 15',
      36 => 'Android 16',
      _ => 'API $sdk',
    };
