import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/star_shape.dart';

/// مشاهد الكارت الرئيسي: ١٠ مشاهد تتبدّل على مدار اليوم.
/// (العصر هو المشهد المفضّل: برتقالي/بنفسجي دافئ.)
enum HeroScene {
  deepNight, // ٠٠:٠٠ – ٠٣:٠٠  الليل العميق
  sahar, //     ٠٣:٠٠ – ٠٥:٠٠  السَّحَر
  dawn, //      ٠٥:٠٠ – ٠٦:٣٠  الفجر
  morning, //   ٠٦:٣٠ – ٠٩:٣٠  الضحى
  noon, //      ٠٩:٣٠ – ١٣:٠٠  الظهيرة
  afternoon, // ١٣:٠٠ – ١٥:٠٠  بعد الظهر
  asr, //       ١٥:٠٠ – ١٧:٣٠  العصر
  maghrib, //   ١٧:٣٠ – ١٩:٠٠  الغروب
  dusk, //      ١٩:٠٠ – ٢١:٠٠  العشاء
  night, //     ٢١:٠٠ – ٢٤:٠٠  الليل
}

HeroScene heroSceneFor(DateTime n) {
  final h = n.hour + n.minute / 60;
  if (h < 3) return HeroScene.deepNight;
  if (h < 5) return HeroScene.sahar;
  if (h < 6.5) return HeroScene.dawn;
  if (h < 9.5) return HeroScene.morning;
  if (h < 13) return HeroScene.noon;
  if (h < 15) return HeroScene.afternoon;
  if (h < 17.5) return HeroScene.asr;
  if (h < 19) return HeroScene.maghrib;
  if (h < 21) return HeroScene.dusk;
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
      case HeroScene.deepNight:
        return const HeroPalette(
          sky: [Color(0xFF050816), Color(0xFF0B1B3A), Color(0xFF16305A)],
          ink: Color(0xFFF1EEE2),
          sub: Color(0xFFC3D3E4),
          accent: Color(0xFFF0D58A),
          silhouette: Color(0xFF050A18),
          hill: Color(0xFF0A1830),
          pill: Color(0x26FFFFFF),
          track: Color(0x33FFFFFF),
          fill: Color(0xFFF0D58A),
        );
      case HeroScene.sahar:
        return const HeroPalette(
          sky: [Color(0xFF0A1530), Color(0xFF1B2F5E), Color(0xFF4B4A7C)],
          ink: Color(0xFFFFF4E0),
          sub: Color(0xFFE6D8EC),
          accent: Color(0xFFF6D58F),
          silhouette: Color(0xFF0A1226),
          hill: Color(0xFF121F42),
          pill: Color(0x2EFFFFFF),
          track: Color(0x38FFFFFF),
          fill: Color(0xFFF6D58F),
        );
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
      case HeroScene.morning:
        return const HeroPalette(
          sky: [Color(0xFF1F5F73), Color(0xFF59A3A0), Color(0xFFF3D28B)],
          ink: Color(0xFFFFF8E6),
          sub: Color(0xFFFFEBC8),
          accent: Color(0xFFFFE08A),
          silhouette: Color(0xFF0F3B3F),
          hill: Color(0xFF1C5C57),
          pill: Color(0x33FFFFFF),
          track: Color(0x40FFFFFF),
          fill: Color(0xFFFFE08A),
        );
      case HeroScene.noon:
        return const HeroPalette(
          sky: [Color(0xFF0F4C75), Color(0xFF2D86A8), Color(0xFF9AD3CF)],
          ink: Color(0xFFFFF9EA),
          sub: Color(0xFFE3F4EE),
          accent: Color(0xFFFFE9A0),
          silhouette: Color(0xFF0C3B4A),
          hill: Color(0xFF17566A),
          pill: Color(0x33FFFFFF),
          track: Color(0x40FFFFFF),
          fill: Color(0xFFFFE9A0),
        );
      case HeroScene.afternoon:
        return const HeroPalette(
          sky: [Color(0xFF2B4F5E), Color(0xFFD39A4A), Color(0xFFF6D88F)],
          ink: Color(0xFFFFF6E0),
          sub: Color(0xFFFFE9C2),
          accent: Color(0xFFFFE3A0),
          silhouette: Color(0xFF26352C),
          hill: Color(0xFF3A4A3A),
          pill: Color(0x33FFFFFF),
          track: Color(0x40FFFFFF),
          fill: Color(0xFFFFE3A0),
        );
      case HeroScene.asr:
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
      case HeroScene.maghrib:
        return const HeroPalette(
          sky: [Color(0xFF2B1B4A), Color(0xFFB5384A), Color(0xFFF08A4B)],
          ink: Color(0xFFFFF1DC),
          sub: Color(0xFFFFD9B8),
          accent: Color(0xFFFFC27A),
          silhouette: Color(0xFF241233),
          hill: Color(0xFF3A1B3F),
          pill: Color(0x33FFFFFF),
          track: Color(0x40FFFFFF),
          fill: Color(0xFFFFC27A),
        );
      case HeroScene.dusk:
        return const HeroPalette(
          sky: [Color(0xFF120F33), Color(0xFF3B2A63), Color(0xFF9B4F6E)],
          ink: Color(0xFFF6EBDD),
          sub: Color(0xFFE3CFE0),
          accent: Color(0xFFF2C27A),
          silhouette: Color(0xFF0E0A22),
          hill: Color(0xFF1C1238),
          pill: Color(0x2EFFFFFF),
          track: Color(0x38FFFFFF),
          fill: Color(0xFFF2C27A),
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

class _HeroBackdropState extends State<HeroBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))
        ..repeat();

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
    _pattern(canvas, size, pal.accent.withValues(alpha: .1));

    switch (scene) {
      case HeroScene.deepNight:
        _stars(canvas, size, t, 1);
        _glow(canvas, Offset(w * .19, h * .32), h * .5, const Color(0xFFFFF0B8),
            .2);
        _crescent(canvas, Offset(w * .19, h * .32), h * .12,
            const Color(0xFFFFF0B8), 1);
        break;
      case HeroScene.sahar:
        _stars(canvas, size, t, .6);
        _glow(canvas, Offset(w * .24, h * .98), h * .85,
            const Color(0xFF9B7BC0), .4);
        _crescent(canvas, Offset(w * .12, h * .22), h * .08,
            const Color(0xFFFFF2CF), .85);
        break;
      case HeroScene.dawn:
        _stars(canvas, size, t, .55);
        _glow(canvas, Offset(w * .24, h * .86), h * .75,
            const Color(0xFFFFC98A), .55);
        _crescent(canvas, Offset(w * .1, h * .2), h * .08,
            const Color(0xFFFFF2CF), .85);
        break;
      case HeroScene.morning:
        _glow(canvas, Offset(w * .24, h * .66), h * .9, const Color(0xFFFFD98A),
            .6);
        canvas.drawCircle(Offset(w * .24, h * .62), h * .14,
            Paint()..color = const Color(0xFFFFE7A3));
        _cloud(canvas, size, t, .2, h * .31, .5, .24);
        _cloud(canvas, size, t, .68, h * .31, .45, .18);
        break;
      case HeroScene.noon:
        _glow(canvas, Offset(w * .2, h * .36), h * .7, const Color(0xFFFFF1B8),
            .45);
        canvas.drawCircle(Offset(w * .2, h * .34), h * .12,
            Paint()..color = const Color(0xFFFFF1B8));
        _cloud(canvas, size, t, .12, h * .31, .5, .24);
        _cloud(canvas, size, t, .6, h * .31, .45, .18);
        break;
      case HeroScene.afternoon:
        _glow(canvas, Offset(w * .24, h * .55), h * .8, const Color(0xFFFFD27A),
            .55);
        canvas.drawCircle(Offset(w * .24, h * .52), h * .14,
            Paint()..color = const Color(0xFFFFE6A8));
        _cloud(canvas, size, t, .5, h * .31, .5, .2);
        break;
      case HeroScene.asr:
        _glow(canvas, Offset(w * .24, h * .78), h * .9, const Color(0xFFFFB347),
            .7);
        canvas.drawCircle(Offset(w * .24, h * .74), h * .2,
            Paint()..color = const Color(0xFFFFE1A0));
        _birds(canvas, size, t);
        break;
      case HeroScene.maghrib:
        _glow(canvas, Offset(w * .24, h * .88), h * 1.0,
            const Color(0xFFFF8A4A), .75);
        canvas.drawCircle(Offset(w * .24, h * .9), h * .2,
            Paint()..color = const Color(0xFFFFB36B));
        _birds(canvas, size, t);
        break;
      case HeroScene.dusk:
        _stars(canvas, size, t, .45);
        _glow(canvas, Offset(w * .24, h * .98), h * .9, const Color(0xFFFF9A5A),
            .35);
        _crescent(canvas, Offset(w * .19, h * .32), h * .1,
            const Color(0xFFFFEBC4), .9);
        break;
      case HeroScene.night:
        _stars(canvas, size, t, 1);
        _glow(canvas, Offset(w * .19, h * .32), h * .5, const Color(0xFFFFF0B8),
            .22);
        _crescent(canvas, Offset(w * .19, h * .32), h * .12,
            const Color(0xFFFFF0B8), 1);
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
        lit: (scene == HeroScene.morning ||
                scene == HeroScene.noon ||
                scene == HeroScene.afternoon)
            ? null
            : pal.accent);
  }

  void _pattern(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = color;
    final star = Path()
      ..moveTo(kIslamicStarPoints.first.dx, kIslamicStarPoints.first.dy);
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

  void _rays(
      Canvas canvas, Offset c, double r0, double r1, double t, Color color) {
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

  void _cloud(
      Canvas canvas, Size size, double t, double phase, double y, double s,
      [double alpha = .85]) {
    final span = size.width + 140;
    final x = ((phase * span + t * span) % span) - 70;
    final p = Paint()..color = Colors.white.withValues(alpha: alpha);
    final u = size.height * .09 * s;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: u * 4.4, height: u * 1.5),
        p);
    canvas.drawCircle(Offset(x - u * .7, y - u * .5), u * .9, p);
    canvas.drawCircle(Offset(x + u * .5, y - u * .7), u * 1.1, p);
  }

  /// النجوم لا تقع أبدًا تحت النص: ممنوعة خلف الكبسولة العلوية وخلف كتلة العنوان
  /// وفوق المسجد؛ وتبقى في المنطقة اليسرى العليا وشريط ضيّق في المنتصف.
  /// نفس الشرط في HeroArt.java كي يتطابق الودجت مع التطبيق.
  void _stars(Canvas canvas, Size size, double t, double strength) {
    final p = Paint();
    var drawn = 0;
    for (var i = 0; i < 160 && drawn < 26; i++) {
      final fx = _frac(math.sin(i * 12.9898) * 43758.5453);
      final fy = _frac(math.sin(i * 78.233) * 12345.6789) * .62;
      final ok = (fx < .30 && fy < .27) || (fx >= .30 && fy > .34 && fy < .40);
      if (!ok) continue;
      drawn++;
      final x = fx * size.width, y = fy * size.height;
      final tw =
          .35 + .65 * (.5 + .5 * math.sin(2 * math.pi * (t * 3 + i * .137)));
      final r = .8 + _frac(i * .37) * 1.3;
      p.color = const Color(0xFFFFF6D8).withValues(alpha: tw * strength);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  void _crescent(Canvas canvas, Offset c, double r, Color color, double a) {
    final p = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()
        ..addOval(Rect.fromCircle(
            center: c + Offset(r * .45, -r * .12), radius: r * .88)),
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
      final y =
          size.height * (.28 + i * .07) + math.sin((t + i) * 2 * math.pi) * 3;
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

    void crescent(double cx, double cy, double r) {
      canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
            Path()
              ..addOval(Rect.fromCircle(
                  center: Offset(cx + r * .4, cy - r * .2), radius: r * .8)),
          ),
          p);
    }

    // الأرض + القاعة الرئيسية + القبة الكبيرة.
    canvas.drawRect(const Rect.fromLTWH(0, 100, 150, 10), p);
    canvas.drawRect(const Rect.fromLTWH(38, 76, 66, 24), p);
    canvas.drawPath(
        Path()
          ..moveTo(42, 76)
          ..cubicTo(40, 60, 54, 46, 71, 44)
          ..cubicTo(88, 46, 102, 60, 100, 76)
          ..close(),
        p);
    canvas.drawRect(const Rect.fromLTWH(70.4, 35, 1.2, 9), p);
    crescent(71, 31, 5);

    // القبة الصغيرة اليسرى.
    canvas.drawRect(const Rect.fromLTWH(8, 86, 28, 14), p);
    canvas.drawPath(
        Path()
          ..moveTo(8, 86)
          ..cubicTo(8, 77, 15, 73, 22, 69)
          ..cubicTo(29, 73, 36, 77, 36, 86)
          ..close(),
        p);
    canvas.drawRect(const Rect.fromLTWH(21.6, 62, .8, 7), p);
    crescent(22, 59.5, 2.3);

    // القبة الصغيرة اليمنى.
    canvas.drawRect(const Rect.fromLTWH(103, 88, 21, 12), p);
    canvas.drawPath(
        Path()
          ..moveTo(103, 88)
          ..cubicTo(103, 81, 108, 78, 113.5, 75)
          ..cubicTo(119, 78, 124, 81, 124, 88)
          ..close(),
        p);
    canvas.drawRect(const Rect.fromLTWH(113.1, 68, .8, 7), p);
    crescent(113.5, 65.5, 2.2);

    // المئذنة.
    canvas.drawRect(const Rect.fromLTWH(130, 56, 10, 44), p);
    canvas.drawRect(const Rect.fromLTWH(126.5, 53, 17, 3), p);
    canvas.drawRect(const Rect.fromLTWH(131, 43, 8, 10), p);
    canvas.drawPath(
        Path()
          ..moveTo(130.5, 43)
          ..arcToPoint(const Offset(139.5, 43),
              radius: const Radius.circular(4.5))
          ..close(),
        p);
    canvas.drawRect(const Rect.fromLTWH(134.6, 29, .8, 9.5), p);
    crescent(135, 26.5, 2.5);

    if (lit != null) {
      final l = Paint()..color = lit.withValues(alpha: .9);
      Path arch(double x, double base, double aw, double bodyH) {
        final r = aw / 2;
        return Path()
          ..moveTo(x, base)
          ..lineTo(x, base - bodyH)
          ..arcToPoint(Offset(x + aw, base - bodyH),
              radius: Radius.circular(r))
          ..lineTo(x + aw, base)
          ..close();
      }

      for (final x in [44.0, 54.0, 82.0, 92.0]) {
        canvas.drawPath(arch(x, 92, 6, 6), l);
      }
      canvas.drawPath(arch(65, 100, 12, 14), l);
      canvas.drawPath(arch(19, 100, 6, 8), l);
      canvas.drawPath(arch(110.5, 100, 6, 6), l);
      canvas.drawPath(arch(132, 52, 2.4, 4), l);
      canvas.drawPath(arch(135.6, 52, 2.4, 4), l);
      for (final y in [64.0, 80.0]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(134, y, 2, 9), const Radius.circular(1)),
            l);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene;
}
