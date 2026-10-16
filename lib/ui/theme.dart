import 'package:flutter/material.dart';

/// Identité visuelle Lielu : bleu nuit, violet, accents lumineux discrets.
abstract final class LieluColors {
  static const night = Color(0xFF0A0F1F);
  static const surface = Color(0xFF121A33);
  static const surfaceHigh = Color(0xFF1B2547);
  static const violet = Color(0xFF7B61FF);
  static const blue = Color(0xFF4F8CFF);
  static const mint = Color(0xFF3DDC97);
  static const amber = Color(0xFFFFB454);
  static const danger = Color(0xFFFF6B7A);
  static const textMuted = Color(0xFF9AA6C8);
}

ThemeData lieluTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: LieluColors.violet,
          onPrimary: Colors.white,
          secondary: LieluColors.blue,
          tertiary: LieluColors.mint,
          error: LieluColors.danger,
          surface: LieluColors.surface,
          onSurface: Color(0xFFEAEEFF),
          onSurfaceVariant: LieluColors.textMuted,
          surfaceContainerHighest: LieluColors.surfaceHigh,
          outlineVariant: Color(0xFF2A3560),
        )
      : ColorScheme.fromSeed(
          seedColor: LieluColors.violet,
          brightness: Brightness.light,
        );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final radius = BorderRadius.circular(14);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? LieluColors.night : null,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? LieluColors.surface : null,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: dark ? 0.6 : 1)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? LieluColors.surface : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? LieluColors.surface : null,
      indicatorColor: scheme.primary.withValues(alpha: 0.25),
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}

/// Dégradé de fond discret (bleu nuit → violet très atténué).
BoxDecoration lieluBackground(BuildContext context) {
  if (Theme.of(context).brightness != Brightness.dark) return const BoxDecoration();
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF111A3D), LieluColors.night],
      stops: [0, 0.45],
    ),
  );
}
