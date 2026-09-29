import 'package:flutter/material.dart';

class AppColors {
  static const ivory = Color(0xFFF7F3EA);
  static const paper = Color(0xFFFFFCF5);
  static const green = Color(0xFF2F6B55);
  static const greenSoft = Color(0xFFDDEBE3);
  static const gold = Color(0xFFB08D3C);
  static const ink = Color(0xFF1E2622);

  static const night = Color(0xFF0F1512);
  static const nightSurface = Color(0xFF17201C);
  static const nightGreen = Color(0xFF7CC4A4);
  static const nightGold = Color(0xFFD1B061);
}

class AppTheme {
  static const fontFamily = 'Tajawal';
  static const quranFont = 'AmiriQuran';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.green,
      secondary: AppColors.gold,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      primaryContainer: AppColors.greenSoft,
    );
    return _base(scheme, AppColors.ivory);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.nightGreen,
      secondary: AppColors.nightGold,
      surface: AppColors.nightSurface,
      onSurface: const Color(0xFFE6ECE8),
      primaryContainer: const Color(0xFF244036),
    );
    return _base(scheme, AppColors.night);
  }

  static ThemeData _base(ColorScheme scheme, Color bg) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: fontFamily, fontSize: 12, color: scheme.onSurface),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}

/// ألوان صفحة القراءة (مستقلة عن ثيم التطبيق).
class ReaderPalette {
  final Color bg;
  final Color fg;
  final Color muted;
  final Color accent;
  final Color highlight;
  const ReaderPalette(this.bg, this.fg, this.muted, this.accent, this.highlight);

  static const light = ReaderPalette(
      Color(0xFFFFFCF5), Color(0xFF1E2622), Color(0xFF7A8580), Color(0xFF2F6B55), Color(0x33B08D3C));
  static const dark = ReaderPalette(
      Color(0xFF000000), Color(0xFFE9EDEA), Color(0xFF8A938E), Color(0xFFD1B061), Color(0x33D1B061));
  static const sepia = ReaderPalette(
      Color(0xFFF1E5C8), Color(0xFF3B2F1E), Color(0xFF8A7756), Color(0xFF7A5C1E), Color(0x338A6A20));

  static ReaderPalette byName(String name, Brightness appBrightness) {
    switch (name) {
      case 'light':
        return light;
      case 'dark':
        return dark;
      case 'sepia':
        return sepia;
      default:
        return appBrightness == Brightness.dark ? dark : light;
    }
  }
}
