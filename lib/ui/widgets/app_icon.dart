import 'package:flutter/material.dart';
import 'package:lieluapp/catalog/catalog_models.dart';

/// Icône d'application : image du catalogue si disponible, sinon pastille
/// colorée avec l'initiale (couleur stable, dérivée de l'identifiant).
class AppIcon extends StatelessWidget {
  final CatalogEntry entry;
  final double size;
  const AppIcon(this.entry, {super.key, this.size = 56});

  static const _palettes = [
    [Color(0xFF7B61FF), Color(0xFF4F8CFF)],
    [Color(0xFFFF8A5B), Color(0xFFFFC857)],
    [Color(0xFF3DDC97), Color(0xFF2BB5C8)],
    [Color(0xFFFF6B9A), Color(0xFF9B5DE5)],
    [Color(0xFF5B8DEF), Color(0xFF38D6C4)],
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.26);
    final colors = _palettes[entry.id.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length];
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          entry.name.characters.first.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: radius,
        child: entry.iconUrl == null
            ? fallback
            : Image.network(
                entry.iconUrl!,
                fit: BoxFit.cover,
                semanticLabel: 'Icône de ${entry.name}',
                loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
                errorBuilder: (context, error, stack) => fallback,
              ),
      ),
    );
  }
}
