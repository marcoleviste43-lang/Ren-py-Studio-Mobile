import 'package:flutter/material.dart';

class AppTheme {
  static const Color accent = Color(0xFF7C4DFF); // Ren'Py-ish purple
  static const Color bgDark = Color(0xFF121218);
  static const Color surfaceDark = Color(0xFF1B1B24);
  static const Color codeBg = Color(0xFF0F0F14);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bgDark,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: surfaceDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: codeBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    );
  }

  static ThemeData get light => ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
      );

  static const codeStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13.5,
    height: 1.5,
    color: Color(0xFFE0E0E8),
  );
}
