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
  /// AI camera reticle lines are #22C55E at 80% opacity per design.
  static const Color glow = Color(0xFF22C55E);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    // Dark scheme: exact tokens from the dark Stitch design.
    // Light scheme: strictly follows the "Botanical Clinical Minimalism"
    // DESIGN.md — base canvas #F4FBF6, white cards, chlorophyll darks
    // (#0D3823 headlines, #153E2B body), sage borders (#D1E7D8).
    final ColorScheme scheme = isLight
        ? const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF15803D), // Primary action green
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFDCFCE7), // Optimal/healthy surface
            onPrimaryContainer: Color(0xFF0D3823),
            secondary: Color(0xFF22C55E), // AI detection accents
            onSecondary: Color(0xFF052E16),
            secondaryContainer: Color(0xFFDCFCE7),
            onSecondaryContainer: Color(0xFF0D3823),
            tertiary: Color(0xFF0D3823), // Deep botanical forest green
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFFEBF8EE), // Mint container
            onTertiaryContainer: Color(0xFF0D3823),
            error: Color(0xFFDC2626), // Severe blight / necrosis
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFFEE2E2),
            onErrorContainer: Color(0xFF7F1D1D),
            surface: Color(0xFFF4FBF6), // Base canvas
            onSurface: Color(0xFF153E2B), // Rich pine body copy
            onSurfaceVariant: Color(0xFF3F493F),
            surfaceContainerLowest: Color(0xFFE8F5E9), // Recessed inputs
            surfaceContainerLow: Color(0xFFFFFFFF), // Elevated card layer
            surfaceContainer: Color(0xFFF0FDF4), // Soft chlorophyll
            surfaceContainerHigh: Color(0xFFEBF8EE), // Nested containers
            surfaceContainerHighest: Color(0xFFDCFCE7), // Status pills
            outline: Color(0xFFD1E7D8), // Soft sage perimeter
            outlineVariant: Color(0xFFE1F3E7),
            inverseSurface: Color(0xFF0D3823),
            onInverseSurface: Color(0xFFCEFBDF),
            inversePrimary: Color(0xFF79DB8D),
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
        backgroundColor: scheme.surface.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: const Color(0x0A0D3823),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          // Headlines sit in deep botanical forest green.
          color: isLight ? const Color(0xFF0D3823) : scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLight ? 24 : 12),
          side: isLight
              ? const BorderSide(color: Color(0x14153E2B)) // 8% sage border
              : BorderSide.none,
        ),
        surfaceTintColor: Colors.transparent,
        color: scheme.surfaceContainerLow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isLight ? const Color(0xFF0D3823) : scheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isLight
            ? const Color(0x0F153E2B) // 6% divider lines
            : scheme.outlineVariant.withValues(alpha: 0.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // #FFFFFF inputs with a #D1E7D8 sage border (1rem radius).
        fillColor: scheme.surfaceContainerLow,
        hintStyle: TextStyle(
          color: isLight ? const Color(0x73153E2B) : scheme.outline,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isLight ? scheme.outline : BorderSide.none.color,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: isLight
              ? const BorderSide(color: Color(0xFFD1E7D8))
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isLight ? const Color(0xFF16A34A) : scheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      chipTheme: ChipThemeData(
        // Filter chips: white with a 12% pine border; active = primary fill.
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isLight ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
        side: isLight
            ? const BorderSide(color: Color(0x1F153E2B))
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: const StadiumBorder(),
              elevation: isLight ? 4 : 0,
              shadowColor: const Color(0x5916A34A), // 0 4px 14px green glow
              textStyle: const TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) =>
                    states.contains(WidgetState.pressed)
                    ? (isLight
                          ? const Color(
                              0xFF0D3823,
                            ) // Active state → forest green
                          : scheme.primary.withValues(alpha: 0.9))
                    : scheme.primary,
              ),
              foregroundColor: const WidgetStatePropertyAll<Color>(
                Color(0xFFFFFFFF),
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
        elevation: isLight ? 6 : 0,
        shadowColor: const Color(0x0F0D3823), // upper ambient glow
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
          color: isLight ? scheme.onInverseSurface : scheme.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
