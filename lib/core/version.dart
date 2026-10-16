/// Comparaison de versions tolérante : `1.0.152`, `v1.2`, `1.0-rc1`, `1.0.0+5`.
///
/// Les segments numériques se comparent numériquement (`1.9` < `1.10`), un
/// segment manquant vaut 0 (`1.0` == `1.0.0`) et une pré-version est inférieure
/// à la version finale (`1.0.0-rc1` < `1.0.0`).
final class AppVersion implements Comparable<AppVersion> {
  final List<int> numbers;
  final String? preRelease;
  final String raw;

  const AppVersion._(this.numbers, this.preRelease, this.raw);

  static final _pattern =
      RegExp(r'^[vV]?(\d+(?:\.\d+)*)(?:-([0-9A-Za-z.\-]+))?(?:\+[0-9A-Za-z.\-]+)?$');

  /// Retourne null si [text] n'est pas une version lisible.
  static AppVersion? tryParse(String? text) {
    if (text == null) return null;
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    final numbers = m.group(1)!.split('.').map(int.parse).toList();
    return AppVersion._(numbers, m.group(2), text.trim());
  }

  @override
  int compareTo(AppVersion other) {
    final length =
        numbers.length > other.numbers.length ? numbers.length : other.numbers.length;
    for (var i = 0; i < length; i++) {
      final a = i < numbers.length ? numbers[i] : 0;
      final b = i < other.numbers.length ? other.numbers[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    if (preRelease == other.preRelease) return 0;
    if (preRelease == null) return 1;
    if (other.preRelease == null) return -1;
    return _comparePre(preRelease!, other.preRelease!);
  }

  static int _comparePre(String a, String b) {
    final pa = a.split('.');
    final pb = b.split('.');
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = (na != null && nb != null)
          ? na.compareTo(nb)
          : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(numbers.join('.'), preRelease);

  @override
  String toString() => raw;
}
