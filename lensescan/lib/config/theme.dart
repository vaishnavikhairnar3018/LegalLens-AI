/// LenseScan light theme — clean gov-tech Material 3 aesthetic.
///
/// Light surface, teal primary, emerald secondary, Inter typography.
/// Color tokens extracted from Stitch design export tailwind.config.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LenseScanTheme {
  LenseScanTheme._();

  // ── Core Palette (from Stitch tailwind.config) ──
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceDim = Color(0xFFCBDBF5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);

  static const Color primary = Color(0xFF003633);
  static const Color primaryContainer = Color(0xFF134E4A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF87BEB8);
  static const Color primaryFixed = Color(0xFFB5EDE7);
  static const Color primaryFixedDim = Color(0xFF9AD1CB);

  static const Color secondary = Color(0xFF006C4A);
  static const Color secondaryContainer = Color(0xFF82F5C1);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF00714E);
  static const Color secondaryFixed = Color(0xFF85F8C4);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color tertiary = Color(0xFF670005);
  static const Color tertiaryContainer = Color(0xFF91000B);

  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF404847);
  static const Color outline = Color(0xFF707977);
  static const Color outlineVariant = Color(0xFFBFC8C6);

  static const Color inverseSurface = Color(0xFF213145);
  static const Color inverseOnSurface = Color(0xFFEAF1FF);
  static const Color inversePrimary = Color(0xFF9AD1CB);

  // ── Semantic Colors ──
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberLight = Color(0xFFFFF7ED); // amber-50
  static const Color warningAmberBorder = Color(0xFFFDE68A); // amber-200

  // ── Legacy aliases (for gradual migration) ──
  static const Color emeraldAccent = secondary;
  static const Color successGreen = secondary;
  static const Color errorRed = error;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;

  // ── Theme Data ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        tertiaryContainer: tertiaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        inverseSurface: inverseSurface,
        onInverseSurface: inverseOnSurface,
        inversePrimary: inversePrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        // display-lg: 36/44, -0.03em, 700
        displayLarge: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -1.08,
          height: 44 / 36,
        ),
        // display-sm: 28/34, -0.02em, 700
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.56,
          height: 34 / 28,
        ),
        // headline-lg: 24/30, -0.015em, 600
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: onSurface,
          letterSpacing: -0.36,
          height: 30 / 24,
        ),
        // headline-sm: 20/26, -0.01em, 600
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
          letterSpacing: -0.2,
          height: 26 / 20,
        ),
        // title-md: 17/22, -0.005em, 600
        titleLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: onSurface,
          letterSpacing: -0.085,
          height: 22 / 17,
        ),
        // body-lg: 15/21, 400
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: onSurface,
          height: 21 / 15,
        ),
        // body-md: 13/18, 400
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
          height: 18 / 13,
        ),
        // label-md: 12/16, 0.01em, 500
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariant,
          letterSpacing: 0.12,
          height: 16 / 12,
        ),
        // label-sm: 11/14, 0.03em, 600
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: onSurfaceVariant,
          letterSpacing: 0.33,
          height: 14 / 11,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.085,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: outlineVariant.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryContainer, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: GoogleFonts.inter(
          color: outline,
          fontSize: 15,
        ),
        labelStyle: GoogleFonts.inter(
          color: onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverseSurface,
        contentTextStyle: GoogleFonts.inter(color: inverseOnSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant.withValues(alpha: 0.2),
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.9),
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primary,
              letterSpacing: 0.33,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: onSurfaceVariant,
            letterSpacing: 0.33,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: onSurfaceVariant, size: 24);
        }),
      ),
    );
  }

  // Keep darkTheme as a redirect for backward compat during migration
  static ThemeData get darkTheme => lightTheme;
}
