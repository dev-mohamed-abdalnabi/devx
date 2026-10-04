import 'package:flutter/material.dart';

/// ألوان الشاشة الرئيسية (مطابقة 1:1 لملف التصميم zikr-home-v11.html).
class HomeTokens {
  final Color bg, card, line, ink, muted, gold, mint, mintInk, leaf;
  const HomeTokens({
    required this.bg,
    required this.card,
    required this.line,
    required this.ink,
    required this.muted,
    required this.gold,
    required this.mint,
    required this.mintInk,
    required this.leaf,
  });

  static const light = HomeTokens(
    bg: Color(0xFFF7F5EE),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE7E1CE),
    ink: Color(0xFF1F2A1F),
    muted: Color(0xFF7B8270),
    gold: Color(0xFFB8923A),
    mint: Color(0xFFE3EFD8),
    mintInk: Color(0xFF2F5A2A),
    leaf: Color(0xFF6FAE5A),
  );

  static const dark = HomeTokens(
    bg: Color(0xFF141913),
    card: Color(0xFF1C231B),
    line: Color(0xFF2D3629),
    ink: Color(0xFFF1EEE2),
    muted: Color(0xFF9AA38E),
    gold: Color(0xFFD4AE5A),
    mint: Color(0xFF243320),
    mintInk: Color(0xFFBFE0AE),
    leaf: Color(0xFF6FAE5A),
  );

  /// الثيم يتبع سويتش الوضع الداكن في التطبيق (AzkarProvider.isDarkMode → ThemeMode).
  static HomeTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// لون النقش والهلال والنجوم ثابت في ملف التصميم (#B8923A) في الوضعين.
  static const patternGold = Color(0xFFB8923A);
}

/// Cairo (خط متغيّر): الوزن 400/600/700.
TextStyle cairoStyle(double size,
    {int weight = 400, required Color color, double? height}) {
  return TextStyle(
    fontFamily: 'Cairo',
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
    color: color,
    height: height,
  );
}

/// Amiri: Regular أو Bold.
TextStyle amiriStyle(double size,
    {bool bold = false, required Color color, double? height}) {
  return TextStyle(
    fontFamily: 'Amiri',
    fontSize: size,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    color: color,
    height: height,
  );
}

String hexOf(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
