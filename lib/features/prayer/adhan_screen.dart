import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../providers/prayer_provider.dart';
import '../home/home_art.dart';

/// شاشة الأذان بخمسة أشكال متحركة. [style] اختياري: بدونه يُستخدم الشكل المختار في الإعدادات.
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
  const _Theme(this.bg, this.ink, this.accent, this.button, this.buttonInk);
}

const _themes = <_Theme>[
  _Theme([Color(0xFF0F4A41), Color(0xFF1E7A5F)], Colors.white,
      Color(0xFFE2BC63), Colors.white, Color(0xFF0F4A41)),
  _Theme([Color(0xFF070B24), Color(0xFF1B2A5C)], Color(0xFFEFF2FF),
      Color(0xFFBFD0FF), Color(0xFFEFF2FF), Color(0xFF0B1433)),
  _Theme([Color(0xFF0B0B0B), Color(0xFF1A1710)], Color(0xFFF6E7B4),
      Color(0xFFE2BC63), Color(0xFFE2BC63), Color(0xFF1A1710)),
  _Theme([Color(0xFF3B1F4F), Color(0xFFE5784B)], Colors.white,
      Color(0xFFFFE2A8), Colors.white, Color(0xFF7A2E1E)),
  _Theme([Color(0xFFF7F5EE), Color(0xFFF7F5EE)], Color(0xFF1F2A1F),
      Color(0xFFB8923A), Color(0xFF2F6B3A), Colors.white),
];

/// المحتوى نفسه بلا Navigator، ليُستخدم في المعاينة داخل الإعدادات أيضًا
/// (المعاينة تُرسم إطارًا ثابتًا بدون أنيميشن لتبقى الإعدادات خفيفة).
class AdhanView extends StatefulWidget {
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
  State<AdhanView> createState() => _AdhanViewState();
}

class _AdhanViewState extends State<AdhanView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(2.6);
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400));
    if (widget.preview) {
      _in.value = 1;
    } else {
      _in.forward();
    }
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6);
    if (!widget.preview) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _in.dispose();
    _time.dispose();
    super.dispose();
  }

  Widget _enter(double from, double to, Widget child,
      {double dy = 22, double scale = 1}) {
    final curve = CurvedAnimation(
        parent: _in,
        curve: Interval(from, to,
            curve: scale < 1 ? Curves.easeOutBack : Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: curve,
      builder: (_, c) {
        final v = curve.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * dy),
            child: Transform.scale(scale: scale + (1 - scale) * v, child: c),
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.style.clamp(0, 4);
    final t = _themes[st];
    final soft = t.ink.withValues(alpha: .82);
    final content = LayoutBuilder(builder: (context, c) {
      final top = c.maxHeight * .075;
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                  painter: _ArtPainter(st, _time, top + 66, t),
                  isComplex: true,
                  willChange: !widget.preview),
            ),
          ),
          Positioned(
            top: top + 132 + 28,
            left: 24,
            right: 24,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _enter(
                  .08,
                  .4,
                  Text('حان الآن وقت صلاة',
                      textAlign: TextAlign.center,
                      style: cairoStyle(17, weight: 600, color: soft))),
              const SizedBox(height: 4),
              _enter(
                  .16,
                  .6,
                  scale: .8,
                  Text(widget.prayerName,
                      textAlign: TextAlign.center,
                      style: amiriStyle(60,
                          bold: true, color: t.accent, height: 1.25))),
              const SizedBox(height: 12),
              _enter(
                  .3,
                  .6,
                  dy: 0,
                  Container(
                      width: 64,
                      height: 2,
                      decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: .85),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              _enter(
                  .4,
                  .8,
                  Text(
                    'حيَّ على الصلاة، حيَّ على الفلاح\nاللهم اجعل الصلاة قرة عين لنا',
                    textAlign: TextAlign.center,
                    style: amiriStyle(19,
                        color: t.ink.withValues(alpha: .9), height: 1.9),
                  )),
            ]),
          ),
          if (!widget.preview)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: _enter(
                    .6,
                    1,
                    Center(
                      child: _PulseButton(
                          color: t.button,
                          ink: t.buttonInk,
                          onTap: widget.onDone),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
    if (widget.preview) return IgnorePointer(child: content);
    return Scaffold(backgroundColor: t.bg.first, body: content);
  }
}

class _PulseButton extends StatefulWidget {
  final Color color, ink;
  final VoidCallback? onTap;
  const _PulseButton({required this.color, required this.ink, this.onTap});
  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.045)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withValues(alpha: .35),
                  blurRadius: 22,
                  spreadRadius: 1)
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_rounded, color: widget.ink, size: 20),
            const SizedBox(width: 8),
            Text('حسنًا', style: cairoStyle(16, weight: 700, color: widget.ink)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── الرسم المتحرك ─────────────────────────

class _ArtPainter extends CustomPainter {
  final int style;
  final ValueNotifier<double> time;
  final double cy;
  final _Theme th;
  _ArtPainter(this.style, this.time, this.cy, this.th) : super(repaint: time);

  static final _star = () {
    final p = Path();
    for (var k = 0; k < 2; k++) {
      for (var i = 0; i < 4; i++) {
        final a = math.pi / 4 * k + math.pi / 2 * i;
        final x = math.cos(a), y = math.sin(a);
        i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      p.close();
    }
    return p;
  }();

  static final _rnd = math.Random(7);
  static final _stars = List.generate(
      80,
      (_) => [
            _rnd.nextDouble(),
            _rnd.nextDouble(),
            .6 + _rnd.nextDouble() * 1.5,
            _rnd.nextDouble() * 6.28
          ]);

  Color _a(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value, w = size.width, h = size.height;
    const s = 132.0;
    final cx = w / 2;
    final accent = th.accent;
    final fill = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: th.bg)
          .createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fill);

    switch (style) {
      case 0:
        _pattern(canvas, size, t, const Color(0x22FFFFFF));
        _glow(canvas, cx, cy, s * (1.5 + .08 * math.sin(t * 1.6)), accent, .35);
        _ripples(canvas, cx, cy, s, accent, t);
        _mosque(canvas, cx, cy + 4 * math.sin(t * 1.3), s, accent);
      case 1:
        for (final st in _stars) {
          final a = .25 +
              .65 * (.5 + .5 * math.sin(t * (.8 + st[2] * .5) + st[3]));
          canvas.drawCircle(Offset(st[0] * w, st[1] * h), st[2] * .8,
              Paint()..color = _a(Colors.white, a));
        }
        _shooting(canvas, t, w, h);
        _glow(canvas, cx, cy, s * 1.5, const Color(0xFFBFD0FF),
            .25 + .08 * math.sin(t * 1.4));
        final fy = 5 * math.sin(t * 1.1);
        _crescent(canvas, cx, cy + fy, s * .36, accent);
        canvas.drawCircle(Offset(cx + s * .30, cy + fy - s * .22), 3.2,
            Paint()..color = _a(Colors.white, .6 + .4 * math.sin(t * 3)));
      case 2:
        _pattern(canvas, size, t, const Color(0x1FE2BC63));
        _frame(canvas, size, t);
        _glow(canvas, cx, cy, s * 1.4, accent, .22);
        _star8(canvas, cx, cy, s * .5, t * 14, accent, false);
        _star8(canvas, cx, cy, s * .34, -t * 22, accent, true);
        _crescent(canvas, cx, cy, s * .13, accent);
      case 3:
        _sun(canvas, size, t, cx, s);
      default:
        _ripples(canvas, cx, cy, s * .92, accent, t);
        final br = 1 + .03 * math.sin(t * 1.8);
        canvas.drawCircle(
            Offset(cx, cy), s * .46 * br, Paint()..color = const Color(0xFFE3EFD8));
        canvas.drawCircle(
            Offset(cx, cy),
            s * .46 * br,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = accent);
        _mosque(canvas, cx, cy + s * .02, s * .62, const Color(0xFF2F5A2A));
    }
  }

  void _pattern(Canvas c, Size sz, double t, Color color) {
    const cell = 46.0, r = cell * .36 * 1.4;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / r
      ..color = color;
    final ox = (t * 5) % cell, oy = (t * 3) % cell;
    for (var y = -cell + oy; y < sz.height + cell; y += cell) {
      for (var x = -cell + ox; x < sz.width + cell; x += cell) {
        c.save();
        c.translate(x, y);
        c.scale(r, r);
        c.drawPath(_star, p);
        c.restore();
      }
    }
  }

  void _glow(Canvas c, double x, double y, double r, Color color, double a) {
    c.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = RadialGradient(colors: [_a(color, a), _a(color, 0)])
              .createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
  }

  void _ripples(Canvas c, double x, double y, double s, Color color, double t) {
    for (var i = 0; i < 3; i++) {
      final u = ((t / 3.6) + i / 3) % 1;
      c.drawCircle(
          Offset(x, y),
          s * (.45 + u * .85),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _a(color, (1 - u) * .55));
    }
  }

  void _mosque(Canvas c, double cx, double cy, double s, Color color) {
    final p = Paint()..color = color;
    final dome = Path()
      ..moveTo(cx - .26 * s, cy + .12 * s)
      ..arcTo(Rect.fromLTRB(cx - .26 * s, cy - .16 * s, cx + .26 * s, cy + .40 * s),
          math.pi, math.pi, false)
      ..close();
    c.drawPath(dome, p);
    c.drawRect(Rect.fromLTRB(cx - .30 * s, cy + .12 * s, cx + .30 * s, cy + .40 * s), p);
    c.drawCircle(Offset(cx, cy - .24 * s), .028 * s, p);
    c.drawRect(Rect.fromLTRB(cx - .004 * s, cy - .22 * s, cx + .004 * s, cy - .14 * s), p);
    for (final sd in [-1.0, 1.0]) {
      final mx = cx + sd * .43 * s;
      c.drawRect(Rect.fromLTRB(mx - .045 * s, cy - .06 * s, mx + .045 * s, cy + .40 * s), p);
      c.drawPath(
          Path()
            ..moveTo(mx - .065 * s, cy - .06 * s)
            ..lineTo(mx + .065 * s, cy - .06 * s)
            ..lineTo(mx, cy - .27 * s)
            ..close(),
          p);
      c.drawRect(Rect.fromLTRB(mx - .065 * s, cy + .06 * s, mx + .065 * s, cy + .075 * s), p);
    }
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - .5 * s, cy + .40 * s, cx + .5 * s, cy + .45 * s),
            Radius.circular(.02 * s)),
        p);
  }

  void _crescent(Canvas c, double x, double y, double r, Color color) {
    final a = Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    final b = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(x + r * .42, y - r * .12), radius: r * .82));
    c.drawPath(Path.combine(PathOperation.difference, a, b), Paint()..color = color);
  }

  void _star8(Canvas c, double x, double y, double r, double deg, Color color,
      bool stroke) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = math.pi / 8 * i;
      final rr = i.isEven ? r : r * .62;
      final px = x + math.cos(a) * rr, py = y + math.sin(a) * rr;
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    c.save();
    c.translate(x, y);
    c.rotate(deg * math.pi / 180);
    c.translate(-x, -y);
    c.drawPath(
        path,
        Paint()
          ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 1.8
          ..color = stroke ? color : _a(color, .92));
    c.restore();
  }

  void _shooting(Canvas c, double t, double w, double h) {
    final u = (t % 7) / 1.3;
    if (u > 1) return;
    final x = w * (.95 - .6 * u), y = h * (.12 + .28 * u);
    for (var i = 0; i < 12; i++) {
      final k = i / 12;
      c.drawLine(
          Offset(x + k * 42, y - k * 18),
          Offset(x + (k + .08) * 42, y - (k + .08) * 18),
          Paint()
            ..strokeWidth = 1.6
            ..color = _a(Colors.white, (1 - k) * (1 - u * .6) * .8));
    }
  }

  void _frame(Canvas c, Size sz, double t) {
    final shader = SweepGradient(
      colors: const [
        Color(0x66E2BC63),
        Color(0xFFFFF1C4),
        Color(0x66E2BC63),
        Color(0x66E2BC63)
      ],
      stops: const [0, .12, .3, 1],
      transform: GradientRotation(t * 40 * math.pi / 180),
    ).createShader(Offset.zero & sz);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..shader = shader;
    var r = Rect.fromLTWH(18, 18, sz.width - 36, sz.height - 36);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(26)),
        p..strokeWidth = 1.8);
    r = r.deflate(6);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(21)),
        p..strokeWidth = 1);
  }

  void _sun(Canvas c, Size sz, double t, double cx, double s) {
    final accent = th.accent;
    final pulse = 1 + .06 * math.sin(t * 1.2);
    final gy = sz.height + 40 - 10 * math.sin(t * .6);
    _glow(c, sz.width / 2, gy, 330 * pulse, const Color(0xFFFFD08A), .9);
    _glow(c, cx, cy, s * 1.5, accent, .30);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _a(accent, .9);
    for (var i = 0; i < 16; i++) {
      final a = math.pi * 2 / 16 * i + t * .25;
      final len = s * (i.isEven ? .17 : .10) * (1 + .25 * math.sin(t * 2 + i));
      final r0 = s * .33;
      c.drawLine(Offset(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
          Offset(cx + math.cos(a) * (r0 + len), cy + math.sin(a) * (r0 + len)), line);
    }
    c.drawCircle(Offset(cx, cy), s * .24, Paint()..color = accent);
    for (var i = 0; i < 6; i++) {
      final u = ((t * .05) + i / 6) % 1;
      c.drawCircle(
          Offset(sz.width * (.15 + .7 * ((i * 37 % 10) / 10)), sz.height * (1 - u)),
          2.0 + i % 3,
          Paint()..color = _a(const Color(0xFFFFE2A8), .5 * math.sin(u * math.pi)));
    }
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.style != style || old.cy != cy;
}
