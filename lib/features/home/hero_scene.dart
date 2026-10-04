import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/star_shape.dart';

/// مشاهد الكارت الرئيسي حسب وقت اليوم.
enum HeroScene { dawn, day, sunset, night }

HeroScene heroSceneFor(DateTime n) {
  final h = n.hour;
  if (h >= 3 && h < 6) return HeroScene.dawn;
  if (h >= 6 && h < 15) return HeroScene.day;
  if (h >= 15 && h < 19) return HeroScene.sunset;
  return HeroScene.night;
}

class HeroPalette {
  final List<Color> sky;
  final Color ink, sub, accent, silhouette, hill, pill, track, fill;
  const HeroPalette({
    required this.sky,
    required this.ink,
    required this.sub,
    required this.accent,
    required this.silhouette,
    required this.hill,
    required this.pill,
    required this.track,
    required this.fill,
  });

  static HeroPalette of(HeroScene s) {
    switch (s) {
      case HeroScene.dawn:
        return const HeroPalette(
          sky: [Color(0xFF0C2B3D), Color(0xFF2F6A78), Color(0xFFE9B98A)],
          ink: Color(0xFFFFF6E3),
          sub: Color(0xFFFFE9C7),
          accent: Color(0xFFF2CB78),
          silhouette: Color(0xFF0B2530),
          hill: Color(0xFF123846),
          pill: Color(0x33FFFFFF),
          track: Color(0x40FFFFFF),
          fill: Color(0xFFF2CB78),
        );
      case HeroScene.day:
        return const HeroPalette(
          sky: [Color(0xFF8FD0EC), Color(0xFFCDEBEF), Color(0xFFF1F6DC)],
          ink: Color(0xFF14432A),
          sub: Color(0xFF2E5E3F),
          accent: Color(0xFFB8801F),
          silhouette: Color(0xFF3F7D55),
          hill: Color(0xFF9CCB92),
          pill: Color(0x66FFFFFF),
          track: Color(0x40144A2A),
          fill: Color(0xFF3E9A55),
        );
      case HeroScene.sunset:
        return const HeroPalette(
          sky: [Color(0xFF3A2B5C), Color(0xFFD9683A), Color(0xFFF8C970)],
          ink: Color(0xFFFFF4E0),
          sub: Color(0xFFFFE2B8),
          accent: Color(0xFFFFD98A),
          silhouette: Color(0xFF2A1E3F),
          hill: Color(0xFF4A2B45),
          pill: Color(0x33FFFFFF),
          track: Color(0x40FFFFFF),
          fill: Color(0xFFFFD98A),
        );
      case HeroScene.night:
        return const HeroPalette(
          sky: [Color(0xFF050F16), Color(0xFF0C2B31), Color(0xFF16473F)],
          ink: Color(0xFFF1EEE2),
          sub: Color(0xFFB9D3C6),
          accent: Color(0xFFE2BC63),
          silhouette: Color(0xFF040C10),
          hill: Color(0xFF0A2127),
          pill: Color(0x26FFFFFF),
          track: Color(0x33FFFFFF),
          fill: Color(0xFFE2BC63),
        );
    }
  }
}

/// خلفية متحركة بهدوء (نجوم تلمع، سحاب، أشعة) للكارت الرئيسي.
class HeroBackdrop extends StatefulWidget {
  final HeroScene scene;
  const HeroBackdrop({super.key, required this.scene});

  @override
  State<HeroBackdrop> createState() => _HeroBackdropState();
}

class _HeroBackdropState extends State<HeroBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        child: CustomPaint(
          key: ValueKey(widget.scene),
          painter: _ScenePainter(widget.scene, _c),
          size: Size.infinite,
        ),
      ),
    );
  }
}

double _frac(double x) => x - x.floorToDouble();

class _ScenePainter extends CustomPainter {
  final HeroScene scene;
  final Animation<double> anim;
  _ScenePainter(this.scene, this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final pal = HeroPalette.of(scene);
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: pal.sky,
          ).createShader(rect));

    // نقش النجمة الإسلامية خفيف جدًا فوق السماء.
    _pattern(canvas, size, pal.accent.withValues(alpha: scene == HeroScene.day ? .16 : .1));

    final sunC = Offset(w * .24, h * .5);
    switch (scene) {
      case HeroScene.dawn:
        _stars(canvas, size, t, .55);
        _glow(canvas, Offset(w * .24, h * .86), h * .75, const Color(0xFFFFC98A), .55);
        _crescent(canvas, Offset(w * .1, h * .2), h * .08, const Color(0xFFFFF2CF), .85);
        break;
      case HeroScene.day:
        _glow(canvas, sunC, h * .62, const Color(0xFFFFF3B0), .8);
        _rays(canvas, sunC, h * .2, h * .46, t, const Color(0xFFFFE27A));
        canvas.drawCircle(sunC, h * .15, Paint()..color = const Color(0xFFFFD34D));
        canvas.drawCircle(sunC, h * .15,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFFFF1A8));
        _cloud(canvas, size, t, .14, h * .2, 1.0);
        _cloud(canvas, size, t, .62, h * .34, .7);
        break;
      case HeroScene.sunset:
        _glow(canvas, Offset(w * .24, h * .78), h * .9, const Color(0xFFFFB347), .7);
        canvas.drawCircle(Offset(w * .24, h * .74), h * .2, Paint()..color = const Color(0xFFFFE1A0));
        _birds(canvas, size, t);
        break;
      case HeroScene.night:
        _stars(canvas, size, t, 1);
        _glow(canvas, Offset(w * .2, h * .3), h * .5, const Color(0xFFFFF0B8), .22);
        _crescent(canvas, Offset(w * .2, h * .3), h * .15, const Color(0xFFFFF0B8), 1);
        break;
    }

    // تلال ثم المسجد.
    final hill = Path()
      ..moveTo(0, h * .84)
      ..cubicTo(w * .2, h * .74, w * .38, h * .9, w * .58, h * .82)
      ..cubicTo(w * .76, h * .75, w * .88, h * .86, w, h * .8)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill, Paint()..color = pal.hill);

    final mw = math.min(w * .5, h * 1.25);
    _mosque(canvas, Offset(w * .02, h + 1), mw, pal.silhouette,
        lit: scene == HeroScene.night || scene == HeroScene.dawn || scene == HeroScene.sunset
            ? pal.accent
            : null);
  }

  void _pattern(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = color;
    final star = Path()..moveTo(kIslamicStarPoints.first.dx, kIslamicStarPoints.first.dy);
    for (final o in kIslamicStarPoints.skip(1)) {
      star.lineTo(o.dx, o.dy);
    }
    star.close();
    for (var y = 0.0; y < size.height; y += 44) {
      for (var x = 0.0; x < size.width; x += 44) {
        canvas.drawPath(star.shift(Offset(x, y)), p);
      }
    }
  }

  void _glow(Canvas canvas, Offset c, double r, Color color, double a) {
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: a),
            color.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
  }

  void _rays(Canvas canvas, Offset c, double r0, double r1, double t, Color color) {
    final p = Paint()
      ..color = color.withValues(alpha: .75)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const n = 12;
    for (var k = 0; k < n; k++) {
      final a = 2 * math.pi * k / n + t * (2 * math.pi / n);
      final long = k.isEven ? r1 : r1 * .82;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r0,
          c + Offset(math.cos(a), math.sin(a)) * long, p);
    }
  }

  void _cloud(Canvas canvas, Size size, double t, double phase, double y, double s) {
    final span = size.width + 140;
    final x = ((phase * span + t * span) % span) - 70;
    final p = Paint()..color = Colors.white.withValues(alpha: .85);
    final u = size.height * .09 * s;
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: u * 4.4, height: u * 1.5), p);
    canvas.drawCircle(Offset(x - u * .7, y - u * .5), u * .9, p);
    canvas.drawCircle(Offset(x + u * .5, y - u * .7), u * 1.1, p);
  }

  void _stars(Canvas canvas, Size size, double t, double strength) {
    final p = Paint();
    for (var i = 0; i < 26; i++) {
      final x = _frac(math.sin(i * 12.9898) * 43758.5453) * size.width;
      final y = _frac(math.sin(i * 78.233) * 12345.6789) * size.height * .62;
      final tw = .35 + .65 * (.5 + .5 * math.sin(2 * math.pi * (t * 3 + i * .137)));
      final r = .8 + _frac(i * .37) * 1.3;
      p.color = const Color(0xFFFFF6D8).withValues(alpha: tw * strength);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  void _crescent(Canvas canvas, Offset c, double r, Color color, double a) {
    final p = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c + Offset(r * .45, -r * .12), radius: r * .88)),
    );
    canvas.drawPath(p, Paint()..color = color.withValues(alpha: a));
  }

  void _birds(Canvas canvas, Size size, double t) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2A1E3F).withValues(alpha: .7);
    final span = size.width + 60;
    for (var i = 0; i < 3; i++) {
      final x = ((i * .09 + t) % 1) * span - 30;
      final y = size.height * (.28 + i * .07) + math.sin((t + i) * 2 * math.pi) * 3;
      final b = Path()
        ..moveTo(x - 7, y)
        ..quadraticBezierTo(x - 3.5, y - 5, x, y)
        ..quadraticBezierTo(x + 3.5, y - 5, x + 7, y);
      canvas.drawPath(b, p);
    }
  }

  void _mosque(Canvas canvas, Offset o, double w, Color col, {Color? lit}) {
    final k = w / 150;
    final p = Paint()..color = col;
    canvas.save();
    canvas.translate(o.dx, o.dy - 110 * k);
    canvas.scale(k);
    canvas.drawRect(const Rect.fromLTWH(0, 100, 150, 10), p);
    canvas.drawRect(const Rect.fromLTWH(38, 72, 64, 28), p);
    canvas.drawPath(
        Path()
          ..moveTo(40, 72)
          ..arcToPoint(const Offset(100, 72), radius: const Radius.circular(30))
          ..close(),
        p);
    canvas.drawRect(const Rect.fromLTWH(69.5, 27, 1, 16), p);
    canvas.drawCircle(const Offset(70, 24), 3.2, p);
    canvas.drawRect(const Rect.fromLTWH(24, 88, 14, 12), p);
    canvas.drawRect(const Rect.fromLTWH(102, 88, 14, 12), p);
    for (final x in [8.0, 130.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 54, 12, 46), p);
      canvas.drawRect(Rect.fromLTWH(x - 3, 52, 18, 3), p);
      canvas.drawPath(
          Path()
            ..moveTo(x + 1, 52)
            ..lineTo(x + 6, 34)
            ..lineTo(x + 11, 52)
            ..close(),
          p);
      canvas.drawRect(Rect.fromLTWH(x + 5.5, 22, 1, 12), p);
    }
    if (lit != null) {
      final l = Paint()..color = lit.withValues(alpha: .9);
      for (final x in [13.0, 135.0]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, 64, 2, 8), const Radius.circular(1)), l);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, 80, 2, 8), const Radius.circular(1)), l);
      }
      for (final x in [46.0, 86.0]) {
        canvas.drawPath(
            Path()
              ..moveTo(x, 94)
              ..lineTo(x, 86)
              ..arcToPoint(Offset(x + 8, 86), radius: const Radius.circular(4))
              ..lineTo(x + 8, 94)
              ..close(),
            l);
      }
      canvas.drawPath(
          Path()
            ..moveTo(64, 100)
            ..lineTo(64, 86)
            ..arcToPoint(const Offset(76, 86), radius: const Radius.circular(6))
            ..lineTo(76, 100)
            ..close(),
          l);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene;
}
