import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/home_tokens.dart';
import '../../core/star_shape.dart';

/// أيقونات الشاشة الرئيسية: paths منقولة حرفيًا من zikr-home-v11.html
/// (viewBox 24×24، stroke 1.7، round، بدون تعبئة).
class HomeIcons {
  HomeIcons._();
  static const moon =
      '<path d="M20 14.500A8 8 0 1 1 9.500 4a6.500 6.500 0 0 0 10.500 10.500z"/>';
  static const sun =
      '<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.600 5.600l1.400 1.400M17 17l1.400 1.400M5.600 18.400L7 17M17 7l1.400-1.400"/>';
  static const sunset =
      '<path d="M7 18a5 5 0 0 1 10 0M12 9v2M5.600 12.600l1.400 1.400M18.400 12.600L17 14M3 18h2M19 18h2M3 21h18"/>';
  static const clock =
      '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
  static const hourglass =
      '<path d="M6 3h12M6 21h12M7 3c0 5 5 6 5 9s-5 4-5 9M17 3c0 5-5 6-5 9s5 4 5 9"/>';
  static const qibla =
      '<path d="M5 8l7-3 7 3v9l-7 3-7-3z"/><path d="M5 8l7 3 7-3M12 11v9"/>';
  static const compass =
      '<circle cx="12" cy="12" r="9"/><path d="M15.500 8.500l-2 5-5 2 2-5z"/>';
  static const hand =
      '<path d="M8 11V6a1.500 1.500 0 0 1 3 0v4M11 10V4.500a1.500 1.500 0 0 1 3 0V10M14 10V6a1.500 1.500 0 0 1 3 0v6c0 4-2 7-6 7-3 0-4-2-6-5l-1-2a1.500 1.500 0 0 1 2.500-1.500L8 13"/>';
  static const quran =
      '<path d="M3 5c3-1 6-1 9 1 3-2 6-2 9-1v13c-3-1-6-1-9 1-3-2-6-2-9-1zM12 6v13"/>';
  static const headphones =
      '<path d="M4 15v-3a8 8 0 0 1 16 0v3M4 15a2 2 0 0 1 2-2h1v6H6a2 2 0 0 1-2-2zM20 15a2 2 0 0 0-2-2h-1v6h1a2 2 0 0 0 2-2z"/>';
  /// سبحة (مسبحة) — للأذكار.
  static const misbaha =
      '<circle cx=\"12\" cy=\"17\" r=\".9\"/><circle cx=\"8.5\" cy=\"16\" r=\".9\"/><circle cx=\"6.1\" cy=\"13.2\" r=\".9\"/><circle cx=\"5.6\" cy=\"9.6\" r=\".9\"/><circle cx=\"7.1\" cy=\"6.2\" r=\".9\"/><circle cx=\"10.2\" cy=\"4.3\" r=\".9\"/><circle cx=\"13.8\" cy=\"4.3\" r=\".9\"/><circle cx=\"16.9\" cy=\"6.2\" r=\".9\"/><circle cx=\"18.4\" cy=\"9.6\" r=\".9\"/><circle cx=\"17.9\" cy=\"13.2\" r=\".9\"/><circle cx=\"15.5\" cy=\"16\" r=\".9\"/><path d=\"M12 17.9v1.6\"/><circle cx=\"12\" cy=\"21\" r=\".9\"/>';
  /// هلال ونجمة — هوية التطبيق.
  static const crescentStar =
      '<path d=\"M19 14.500A8 8 0 1 1 9.500 5a6.500 6.500 0 0 0 9.500 9.500z\"/><path d=\"M17 4l.8 1.700 1.700.8-1.700.8L17 9l-.8-1.700-1.700-.8 1.700-.8z\"/>';
  static const sparkle =
      '<path d="M9 4l1.800 4.200L15 10l-4.200 1.800L9 16l-1.800-4.200L3 10l4.200-1.800zM17 14l.9 2.100L20 17l-2.100.9L17 20l-.9-2.100L14 17l2.100-.9z"/>';
  static const heart =
      '<path d="M12 20s-7-4.500-7-10a4 4 0 0 1 7-2.500A4 4 0 0 1 19 10c0 5.500-7 10-7 10z"/>';
  static const trophy =
      '<path d="M8 4h8v4a4 4 0 0 1-8 0zM8 6H4v1a3 3 0 0 0 4 3M16 6h4v1a3 3 0 0 1-4 3M12 12v4M8 20h8"/>';
  static const home = '<path d="M4 11l8-7 8 7v9h-5v-6H9v6H4z"/>';
  static const forum =
      '<path d="M20 12a8 8 0 0 1-11.500 7.200L4 20l1-4.200A8 8 0 1 1 20 12z"/>';
  static const more =
      '<rect x="4" y="4" width="6.500" height="6.500" rx="1.500"/><rect x="13.500" y="4" width="6.500" height="6.500" rx="1.500"/><rect x="4" y="13.500" width="6.500" height="6.500" rx="1.500"/><rect x="13.500" y="13.500" width="6.500" height="6.500" rx="1.500"/>';
}

class HomeIcon extends StatelessWidget {
  final String paths;
  final double size;
  final Color color;
  const HomeIcon(this.paths,
      {super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="${hexOf(color)}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">$paths</svg>',
      width: size,
      height: size,
    );
  }
}

/// رسمة المسجد: منقولة حرفيًا من <svg class="art"> مع استبدال المتغيّرات بألوان الثيم.
class MosqueArt extends StatelessWidget {
  final double width;
  final HomeTokens tokens;
  const MosqueArt({super.key, required this.width, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final ink = hexOf(tokens.mintInk);
    final mint = hexOf(tokens.mint);
    final svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 110">
<g fill="$ink" opacity=".3">
<rect x="0" y="100" width="150" height="10"/>
<path d="M38 72h64v28H38z"/><path d="M40 72a30 30 0 0 1 60 0z"/>
<path d="M24 100V90a7 7 0 0 1 14 0v10zM102 100V90a7 7 0 0 1 14 0v10z"/>
<rect x="8" y="54" width="12" height="46"/><rect x="5" y="52" width="18" height="3"/><rect x="10" y="42" width="8" height="10"/><path d="M9 42l5-14 5 14z"/>
<rect x="130" y="54" width="12" height="46"/><rect x="127" y="52" width="18" height="3"/><rect x="132" y="42" width="8" height="10"/><path d="M131 42l5-14 5 14z"/>
</g>
<g fill="$mint">
<path d="M46 94v-8a4 4 0 0 1 8 0v8zM86 94v-8a4 4 0 0 1 8 0v8z"/>
<path d="M64 100V86a6 6 0 0 1 12 0v14z"/>
<rect x="13" y="64" width="2" height="8" rx="1"/><rect x="13" y="80" width="2" height="8" rx="1"/>
<rect x="135" y="64" width="2" height="8" rx="1"/><rect x="135" y="80" width="2" height="8" rx="1"/>
<path d="M28 100v-6a3 3 0 0 1 6 0v6zM106 100v-6a3 3 0 0 1 6 0v6z"/>
</g>
<g fill="none" stroke="$mint" stroke-width="1.2" stroke-linecap="round"><path d="M70 43v28M56 49q-4 11-4 22M84 49q4 11 4 22"/><path d="M40 72h60"/></g>
<g fill="#B8923A">
<rect x="69.5" y="27" width="1" height="16"/>
<circle cx="70" cy="19" r="7"/><circle cx="72.5" cy="18" r="5.5" fill="$mint"/>
<circle cx="14" cy="26" r="1.6"/><circle cx="136" cy="26" r="1.6"/>
<circle cx="100" cy="12" r="1.2"/><circle cx="40" cy="14" r="1.2"/><circle cx="118" cy="30" r="1"/>
</g></svg>''';
    return SvgPicture.string(svg, width: width, height: width * 110 / 150);
  }
}

/// نقش النجمة الإسلامية: بلاط 44×44 يتكرر، stroke ذهبي عرض 1 بدون تعبئة.
class IslamicPatternPainter extends CustomPainter {
  final double opacity;
  const IslamicPatternPainter({required this.opacity});

  static final Path _star = () {
    final p = Path()
      ..moveTo(kIslamicStarPoints.first.dx, kIslamicStarPoints.first.dy);
    for (final o in kIslamicStarPoints.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    p.close();
    return p;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = HomeTokens.patternGold.withValues(alpha: opacity);
    for (double y = 0; y < size.height; y += 44) {
      for (double x = 0; x < size.width; x += 44) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPath(_star, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(IslamicPatternPainter old) => old.opacity != opacity;
}

/// إطار متقطع (dashed) بسُمك 1dp وزوايا مدوّرة.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 3.0, gap = 3.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// شريط التقدم: ارتفاع 6، radius 3، الخلفية line والتعبئة leaf، تبدأ من اليمين (RTL).
class HomeProgressBar extends StatelessWidget {
  final double value;
  final HomeTokens tokens;
  const HomeProgressBar({super.key, required this.value, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        width: double.infinity,
        color: tokens.line,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: value.isNaN ? 0 : value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.leaf,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ضغط الكارت: scale 0.97 وإطار ذهبي خلال 120ms.
class PressableCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool pressed) builder;
  const PressableCard({super.key, required this.onTap, required this.builder});

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.builder(context, _down),
      ),
    );
  }
}
