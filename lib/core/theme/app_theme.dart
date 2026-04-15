// apps/mobile/lib/core/theme/app_theme.dart
// Temas claro y oscuro para RutaLibre — paleta Stitch 2025

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Paleta principal — verde profundo (Stitch 2025) ──────────
  static const Color _primaryGreen = Color(0xFF006B2C);
  static const Color _primaryGreenContainer = Color(0xFF00873A);
  static const Color _primaryGreenLight = Color(0xFFDCFCE7);
  static const Color _primaryAccentDark = Color(0xFF62DF7D); // acento vibrante dark mode

  // ── Gradiente cinemático para botones primarios ──────────────
  static const LinearGradient kineticGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF006B2C), Color(0xFF00873A)],
  );

  // ── Acento secundario — naranja cálido ───────────────────────
  static const Color _accentOrange = Color(0xFF9D4300);
  static const Color _accentOrangeContainer = Color(0xFFFD761A);

  // ── Fuente ───────────────────────────────────────────────────
  static TextTheme _textTheme(Color baseColor) {
    return GoogleFonts.interTextTheme().copyWith(
      bodyLarge: GoogleFonts.inter(color: baseColor),
      bodyMedium: GoogleFonts.inter(color: baseColor),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: baseColor),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: baseColor),
    );
  }

  // ─── Tema claro ───────────────────────────────────────────────
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: _primaryGreen,
      primaryContainer: _primaryGreenLight,
      secondary: _accentOrange,
      secondaryContainer: _accentOrangeContainer,
      surface: Color(0xFFFFFFFF),
      surfaceContainerHighest: Color(0xFFF8FAFC),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF0F172A),
      outline: Color(0xFF6E7B6C),
      outlineVariant: Color(0xFFBDCABA),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(const Color(0xFF0F172A)),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)), // 12→16
          side: BorderSide(color: Color(0xFFBDCABA)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)), // 10→12
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBDCABA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBDCABA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryGreen, width: 2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: _primaryGreen,
        unselectedItemColor: Color(0xFF94A3B8),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFBDCABA)),
      iconTheme: const IconThemeData(color: Color(0xFF475569)),
    );
  }

  // ─── Tema oscuro ──────────────────────────────────────────────
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: _primaryAccentDark,        // #62DF7D — vibrante en dark
      primaryContainer: _primaryGreenContainer,
      secondary: _accentOrangeContainer,  // #FD761A — naranja brillante en dark
      secondaryContainer: _accentOrange,
      surface: Color(0xFF1E293B),
      surfaceContainerHighest: Color(0xFF334155),
      onPrimary: Color(0xFF002109),
      onSecondary: Colors.white,
      onSurface: Color(0xFFF1F5F9),
      outline: Color(0xFF6E7B6C),
      outlineVariant: Color(0xFF3E4A3D),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(const Color(0xFFF1F5F9)),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: const Color(0xFFF1F5F9),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.3),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF1F5F9),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)), // 12→16
          side: BorderSide(color: Color(0xFF3E4A3D)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryAccentDark,
          foregroundColor: const Color(0xFF002109),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)), // 10→12
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3E4A3D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3E4A3D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryAccentDark, width: 2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E293B),
        selectedItemColor: _primaryAccentDark,
        unselectedItemColor: Color(0xFF64748B),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF3E4A3D)),
      iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
    );
  }
}
