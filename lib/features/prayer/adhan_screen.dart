import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../providers/prayer_provider.dart';
import '../home/home_art.dart';

/// شاشة الأذان بخمسة أشكال. [style] اختياري: بدونه يُستخدم الشكل المختار في الإعدادات.
class AdhanScreen extends StatelessWidget {
  final String prayerName;
  final int? style;

  const AdhanScreen({super.key, this.prayerName = 'الصلاة', this.style});

  @override
  Widget build(BuildContext context) {
    var s = style ?? 0;
    if (style == null) {
      try {
        s = context.read<PrayerProvider>().adhanStyle;
      } catch (_) {}
    }
    return AdhanView(
        prayerName: prayerName,
        style: s.clamp(0, 4),
        onDone: () => Navigator.of(context).pop());
  }
}

class _Theme {
  final List<Color> bg;
  final Color ink, accent, button, buttonInk;
  final bool stars, pattern, frame, sun;
  const _Theme(this.bg, this.ink, this.accent, this.button, this.buttonInk,
      {this.stars = false,
      this.pattern = false,
      this.frame = false,
      this.sun = false});
}

const _themes = <_Theme>[
  _Theme([Color(0xFF0F4A41), Color(0xFF1E7A5F)], Colors.white,
      Color(0xFFE2BC63), Colors.white, Color(0xFF0F4A41),
      pattern: true),
  _Theme([Color(0xFF070B24), Color(0xFF1B2A5C)], Color(0xFFEFF2FF),
      Color(0xFFBFD0FF), Color(0xFFEFF2FF), Color(0xFF0B1433),
      stars: true),
  _Theme([Color(0xFF0B0B0B), Color(0xFF1A1710)], Color(0xFFF6E7B4),
      Color(0xFFE2BC63), Color(0xFFE2BC63), Color(0xFF1A1710),
      frame: true, pattern: true),
  _Theme([Color(0xFF3B1F4F), Color(0xFFE5784B)], Colors.white,
      Color(0xFFFFE2A8), Colors.white, Color(0xFF7A2E1E),
      sun: true),
  _Theme([Color(0xFFF7F5EE), Color(0xFFF7F5EE)], Color(0xFF1F2A1F),
      Color(0xFFB8923A), Color(0xFF2F6B3A), Colors.white),
];

/// المحتوى نفسه بلا Navigator، ليُستخدم في المعاينة داخل الإعدادات أيضًا.
class AdhanView extends StatelessWidget {
  final String prayerName;
  final int style;
  final VoidCallback? onDone;
  final bool preview;

  const AdhanView(
      {super.key,
      required this.prayerName,
      required this.style,
      this.onDone,
      this.preview = false});

  @override
  Widget build(BuildContext context) {
    final t = _themes[style];
    const big = 1.0;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: t.bg,
            ),
          ),
        ),
        if (t.pattern)
          const Positioned.fill(
              child: CustomPaint(painter: IslamicPatternPainter(opacity: .10))),
        if (t.stars) const Positioned.fill(child: CustomPaint(painter: _Stars())),
        if (t.sun)
          Positioned(
            bottom: -60 * big,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 280 * big,
                height: 280 * big,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFFFFD08A).withValues(alpha: .85),
                    const Color(0xFFFFD08A).withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
        if (t.frame)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: t.accent, width: 1.4),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: t.accent.withValues(alpha: .4), width: 1),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _emblem(t, big),
                  SizedBox(height: 26 * big),
                  Text('حان الآن وقت الصلاة',
                      textAlign: TextAlign.center,
                      style: cairoStyle(17 * big,
                          weight: 600, color: t.ink.withValues(alpha: .8))),
                  SizedBox(height: 8 * big),
                  Text(prayerName,
                      textAlign: TextAlign.center,
                      style: amiriStyle(58 * big,
                          bold: true, color: t.ink, height: 1.2)),
                  SizedBox(height: 14 * big),
                  Container(
                      width: 56 * big,
                      height: 2,
                      color: t.accent.withValues(alpha: .8)),
                  SizedBox(height: 16 * big),
                  Text(
                    'حيَّ على الصلاة، حيَّ على الفلاح\nاللهم اجعل الصلاة قرة عين لنا',
                    textAlign: TextAlign.center,
                    style: amiriStyle(19 * big,
                        color: t.ink.withValues(alpha: .88), height: 1.9),
                  ),
                  if (!preview) ...[
                    const SizedBox(height: 44),
                    SizedBox(
                      width: 200,
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: t.button,
                          foregroundColor: t.buttonInk,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: onDone,
                        icon: const Icon(Icons.check_rounded),
                        label: Text('حسنًا',
                            style: cairoStyle(15,
                                weight: 700, color: t.buttonInk)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
    if (preview) return IgnorePointer(child: content);
    return Scaffold(body: content);
  }

  Widget _emblem(_Theme t, double big) {
    final size = 92.0 * big;
    switch (style) {
      case 1:
        return Icon(Icons.nightlight_round, size: size, color: t.accent);
      case 2:
        return Icon(Icons.auto_awesome, size: size, color: t.accent);
      case 3:
        return Icon(Icons.wb_twilight_rounded, size: size, color: t.accent);
      case 4:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE3EFD8),
              border: Border.all(color: t.accent, width: 1.5)),
          child: Icon(Icons.mosque_rounded,
              size: size * .5, color: const Color(0xFF2F5A2A)),
        );
      default:
        return Icon(Icons.mosque_rounded, size: size, color: t.accent);
    }
  }
}

class _Stars extends CustomPainter {
  const _Stars();
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    final p = Paint();
    for (var i = 0; i < 70; i++) {
      p.color = Colors.white.withValues(alpha: .25 + r.nextDouble() * .6);
      canvas.drawCircle(
          Offset(r.nextDouble() * size.width, r.nextDouble() * size.height),
          .6 + r.nextDouble() * 1.4,
          p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
