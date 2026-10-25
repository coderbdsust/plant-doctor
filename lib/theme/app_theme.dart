import 'package:flutter/material.dart';

/// Material 3 theme mirroring the Stitch "PlantDoc AI" design tokens.
class AppTheme {
  AppTheme._();

  /// Design primary (dark mode) from the Stitch project.
  static const Color seed = Color(0xFF4BE277);
  static const Color leaf = Color(0xFF22C55E);
  static const Color moss = Color(0xFF6BFF8F);
  static const Color deep = Color(0xFF07170C);
  static const Color terracotta = Color(0xFFC1663B);
  static const String fontFamily = 'NotoSansBengali';

  /// Foliage gradients kept for icon tiles / FABs.
  /// [heroGradient] now reads as the dark design's layered container stack.
  static const List<Color> heroGradient = <Color>[
    Color(0xFF0F1F14),
    Color(0xFF132318),
  ];
  static const List<Color> accentGradient = <Color>[
    Color(0xFF4DE082),
    Color(0xFF6BFF8F),
  ];

  /// Soft glow accent used on scanner corners and hero cards.
  static const Color glow = Color(0xFF4BE277);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    // Dark scheme: exact tokens from the Stitch design.
    // Light scheme: harmonized green family with the same structure.
    final ColorScheme scheme = isLight
        ? const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF006E2F),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFA6F2CF),
            onPrimaryContainer: Color(0xFF004B1E),
            secondary: Color(0xFF00B55D),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFD9F7E2),
            onSecondaryContainer: Color(0xFF003E1C),
            tertiary: Color(0xFF3C6B54),
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFFD9F2E6),
            onTertiaryContainer: Color(0xFF004934),
            error: Color(0xFFB3261E),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF690005),
            surface: Color(0xFFF6FAF4),
            onSurface: Color(0xFF18221A),
            onSurfaceVariant: Color(0xFF4C594B),
            surfaceContainerLowest: Color(0xFFFFFFFF),
            surfaceContainerLow: Color(0xFFF1F8EF),
            surfaceContainer: Color(0xFFEBF3E9),
            surfaceContainerHigh: Color(0xFFE4EFE2),
            surfaceContainerHighest: Color(0xFFDEEADC),
            outline: Color(0xFF71816F),
            outlineVariant: Color(0xFFC9D8C7),
            inverseSurface: Color(0xFF18221A),
            onInverseSurface: Color(0xFFECF3EA),
            inversePrimary: Color(0xFF4BE277),
          )
        : const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFF4BE277),
            onPrimary: Color(0xFF003915),
            primaryContainer: Color(0xFF22C55E),
            onPrimaryContainer: Color(0xFF004B1E),
            secondary: Color(0xFF4DE082),
            onSecondary: Color(0xFF003919),
            secondaryContainer: Color(0xFF00B55D),
            onSecondaryContainer: Color(0xFF003E1C),
            tertiary: Color(0xFF8BD6B4),
            onTertiary: Color(0xFF004A2E),
            tertiaryContainer: Color(0xFF70BA9A),
            onTertiaryContainer: Color(0xFF004934),
            error: Color(0xFFFFB4AB),
            onError: Color(0xFF690005),
            errorContainer: Color(0xFF93000A),
            onErrorContainer: Color(0xFFFFDAD6),
            surface: Color(0xFF07170C),
            onSurface: Color(0xFFD4E8D6),
            onSurfaceVariant: Color(0xFFBCCBB9),
            surfaceContainerLowest: Color(0xFF031107),
            surfaceContainerLow: Color(0xFF0F1F14),
            surfaceContainer: Color(0xFF132318),
            surfaceContainerHigh: Color(0xFF1D2E22),
            surfaceContainerHighest: Color(0xFF28392C),
            outline: Color(0xFF869585),
            outlineVariant: Color(0xFF3D4A3D),
            inverseSurface: Color(0xFFD4E8D6),
            onInverseSurface: Color(0xFF243428),
            inversePrimary: Color(0xFF006E2F),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: TextStyle(color: scheme.outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.surfaceContainerHigh,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
