import 'package:flutter/material.dart';

/// Green-toned Material 3 theme for the app.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF1B7A3D);
  static const Color leaf = Color(0xFF43A047);
  static const Color moss = Color(0xFF7CB342);
  static const Color deep = Color(0xFF0F3D1E);
  static const Color terracotta = Color(0xFFC1663B);
  static const String fontFamily = 'NotoSansBengali';

  /// Stitch-style hero gradients used across feature cards.
  static const List<Color> heroGradient = <Color>[Color(0xFF156B36), deep];
  static const List<Color> accentGradient = <Color>[seed, leaf];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      primary: isLight ? const Color(0xFF1B7A3D) : const Color(0xFF7BD69B),
      onPrimary: isLight ? Colors.white : const Color(0xFF00391A),
      primaryContainer: isLight ? const Color(0xFFC7EFD1) : const Color(0xFF14532B),
      onPrimaryContainer:
          isLight ? const Color(0xFF00210E) : const Color(0xFFB6F2C7),
      secondary: isLight ? const Color(0xFF4E7A2D) : const Color(0xFFB7D48A),
      onSecondary: isLight ? Colors.white : const Color(0xFF1A3000),
      secondaryContainer:
          isLight ? const Color(0xFFD6EBC0) : const Color(0xFF33471C),
      onSecondaryContainer:
          isLight ? const Color(0xFF152900) : const Color(0xFFD3E9B0),
      tertiary: isLight ? const Color(0xFF7A6412) : const Color(0xFFE4C56A),
      onTertiary: isLight ? Colors.white : const Color(0xFF2E2600),
      tertiaryContainer:
          isLight ? const Color(0xFFF6E6BF) : const Color(0xFF3D2F0C),
      onTertiaryContainer:
          isLight ? const Color(0xFF2A1F00) : const Color(0xFFEFDDA6),
      error: isLight ? const Color(0xFFB3261E) : const Color(0xFFFFB4AB),
      errorContainer:
          isLight ? const Color(0xFFF9DEDC) : const Color(0xFF601410),
      onErrorContainer:
          isLight ? const Color(0xFF410E0B) : const Color(0xFFFFDAD6),
      surface: isLight ? const Color(0xFFF6FBF4) : const Color(0xFF101611),
      onSurface: isLight ? const Color(0xFF161D15) : const Color(0xFFE1EAE0),
      onSurfaceVariant: isLight ? const Color(0xFF4C594B) : const Color(0xFFBECBBE),
      surfaceContainerLowest:
          isLight ? Colors.white : const Color(0xFF0A0F0A),
      surfaceContainerLow:
          isLight ? const Color(0xFFF0F7ED) : const Color(0xFF151C15),
      surfaceContainer:
          isLight ? const Color(0xFFEBF3E7) : const Color(0xFF1A2219),
      surfaceContainerHigh:
          isLight ? const Color(0xFFE5EFE1) : const Color(0xFF202A1E),
      surfaceContainerHighest:
          isLight ? const Color(0xFFDFEBD9) : const Color(0xFF263124),
      outline: isLight ? const Color(0xFF7C8B7A) : const Color(0xFF879487),
      outlineVariant: isLight ? const Color(0xFFCEDACB) : const Color(0xFF404C40),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF1F8EC) : const Color(0xFF0C110D),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? const Color(0xFFF1F8EC) : const Color(0xFF0C110D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        color: isLight ? const Color(0xFFFCFFFB) : const Color(0xFF161E16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isLight
                ? const Color(0xFFDCE9D6)
                : const Color(0xFF2B382B),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? Colors.white : const Color(0xFF161E16),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          color: scheme.onSurfaceVariant,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF151C15),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isLight ? const Color(0xFFD5E4D1) : const Color(0xFF2B382B),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isLight ? const Color(0xFFD5E4D1) : const Color(0xFF2B382B),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isLight ? const Color(0xFFFBFDFA) : const Color(0xFF121812),
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      textTheme: const TextTheme().apply(fontFamily: fontFamily),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.primary,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 6,
        color: scheme.primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}
