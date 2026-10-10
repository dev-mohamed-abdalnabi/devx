import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../providers/prayer_provider.dart';
import 'adhan_styles.dart';

/// شاشة الأذان بخمسة أشكال متحركة، وشعار «ذِكر» في كلٍّ منها.
/// [style] اختياري: بدونه يُستخدم الشكل المختار في الإعدادات.
/// [demo] يعرض كلمات الأذان متتابعة كمعاينة للتصميم (المزامنة الفعلية مع الصوت
/// تتم في شاشة الأذان الأصلية على أندرويد).
class AdhanScreen extends StatelessWidget {
  final String prayerName;
  final int? style;
  final bool demo;

  const AdhanScreen(
      {super.key, this.prayerName = 'الصلاة', this.style, this.demo = false});

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
        demo: demo,
        onDone: () => Navigator.of(context).pop());
  }
}

class _Theme {
  final List<Color> bg;
  final Color ink, accent, button, buttonInk;
  final List<Color> logo;
  const _Theme(this.bg, this.ink, this.accent, this.button, this.buttonInk,
      this.logo);
}

// مطابقة لـ AdhanArtView.java
const _themes = <_Theme>[
  _Theme([Color(0xFF0B3B34), Color(0xFF1E7A5F)], Colors.white,
      Color(0xFFE2BC63), Colors.white, Color(0xFF0F4A41),
      [Color(0xFFF7E3A1), Color(0xFFD9A93C)]),
  _Theme([Color(0xFF050818), Color(0xFF1B2A5C)], Color(0xFFEFF2FF),
      Color(0xFFBFD0FF), Color(0xFFEFF2FF), Color(0xFF0B1433),
      [Color(0xFFFFFFFF), Color(0xFFBFD0FF)]),
  _Theme([Color(0xFF070707), Color(0xFF1C1810)], Color(0xFFF6E7B4),
      Color(0xFFE2BC63), Color(0xFFE2BC63), Color(0xFF1A1710),
      [Color(0xFFFFF1C4), Color(0xFFC9962E)]),
  _Theme([Color(0xFF2E1A48), Color(0xFFE5784B)], Colors.white,
      Color(0xFFFFE2A8), Colors.white, Color(0xFF7A2E1E),
      [Color(0xFFFFFFFF), Color(0xFFFFE2A8)]),
  _Theme([Color(0xFFF7F5EE), Color(0xFFEFEBDD)], Color(0xFF1F2A1F),
      Color(0xFFB8923A), Color(0xFF2F6B3A), Colors.white,
      [Color(0xFF3F7A47), Color(0xFF1F4A2A)]),
];

/// المحتوى نفسه بلا Navigator، ليُستخدم في المعاينة داخل الإعدادات أيضًا
/// (المعاينة تُرسم إطارًا ثابتًا بدون أنيميشن لتبقى الإعدادات خفيفة).
class AdhanView extends StatefulWidget {
  final String prayerName;
  final int style;
  final VoidCallback? onDone;
  final bool preview;
  final bool demo;

  const AdhanView(
      {super.key,
      required this.prayerName,
      required this.style,
      this.onDone,
      this.preview = false,
      this.demo = false});

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

  /// الشعار مُلوَّن بتدرّج الشكل، مع طفو ولمعة (في الذهبي).
  Widget _logo(_Theme t, double eh, int st) {
    final img = Image.asset('assets/brand/logo_mark.png',
        height: eh, cacheHeight: 420, filterQuality: FilterQuality.medium);
    Widget tinted(Widget child, Gradient g) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => g.createShader(r),
        child: child);
    final base = tinted(
        img,
        LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: t.logo));
    if (widget.preview) return base;
    return ValueListenableBuilder<double>(
      valueListenable: _time,
      builder: (_, time, __) {
        final dy = st == 0
            ? 3 * math.sin(time * 1.3)
            : st == 1
                ? 6 * math.sin(time * 1.1)
                : 0.0;
        Widget w = base;
        if (st == 2) {
          final u = (time % 5) / 1.6;
          if (u < 1) {
            w = Stack(alignment: Alignment.center, children: [
              base,
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => LinearGradient(
                  colors: const [
                    Color(0x00FFFFFF),
                    Color(0xCCFFFFFF),
                    Color(0x00FFFFFF)
                  ],
                  stops: const [0, .5, 1],
                  transform: _Slide(-1 + u * 2),
                ).createShader(Rect.fromLTWH(0, 0, r.width * .6, r.height)),
                child: img,
              ),
            ]);
          }
        }
        return Transform.translate(offset: Offset(0, dy), child: w);
      },
    );
  }

  Widget _lyrics(_Theme t) {
    Widget card(String label, String prev, String cur, String next,
        double progress, int dotIndex, double curSize) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: t.ink.withValues(alpha: t.ink.computeLuminance() > .5 ? .09 : .06),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: t.accent.withValues(alpha: .45)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: cairoStyle(12.5, weight: 700, color: t.accent)),
          const SizedBox(height: 8),
          Text(prev,
              textAlign: TextAlign.center,
              style: amiriStyle(14, color: t.ink.withValues(alpha: .38))),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 74),
            child: Center(
              child: Text(cur,
                  textAlign: TextAlign.center,
                  style: amiriStyle(curSize,
                      bold: true, color: t.ink, height: 1.55)),
            ),
          ),
          Text(next,
              textAlign: TextAlign.center,
              style: amiriStyle(14, color: t.ink.withValues(alpha: .38))),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: t.ink.withValues(alpha: .15),
                valueColor: AlwaysStoppedAnimation(t.accent)),
          ),
          const SizedBox(height: 12),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < adhanLines.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == dotIndex ? 9 : 6,
                height: i == dotIndex ? 9 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < dotIndex
                      ? t.accent.withValues(alpha: .85)
                      : i == dotIndex
                          ? t.accent
                          : t.ink.withValues(alpha: .22),
                ),
              ),
          ]),
        ]),
      );
    }

    if (!widget.demo) {
      // معاينة ثابتة (أو فتح من الإشعار): العبارة المميّزة للأذان
      return card('ردِّد مع المؤذن', adhanLines[5], adhanLines[6],
          adhanLines[8], .45, 6, 27);
    }
    return ValueListenableBuilder<double>(
      valueListenable: _time,
      builder: (_, time, __) {
        const per = 3.4;
        final total = adhanLines.length + 1; // + الدعاء
        final k = (time / per).floor() % total;
        final prog = (time % per) / per;
        if (k == adhanLines.length) {
          return card('الدعاء بعد الأذان', '', adhanAfterDua, '', 1,
              adhanLines.length, 19);
        }
        return card(
            'ردِّد مع المؤذن · ${k + 1} / ${adhanLines.length}',
            k > 0 ? adhanLines[k - 1] : '',
            adhanLines[k],
            k + 1 < adhanLines.length ? adhanLines[k + 1] : '',
            prog,
            k,
            27);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.style.clamp(0, 4);
    final t = _themes[st];
    final soft = t.ink.withValues(alpha: .8);
    final content = LayoutBuilder(builder: (context, c) {
      final top = c.maxHeight * .06;
      final eh = math.min(150.0, c.maxHeight * .21);
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                  painter: _ArtPainter(st, _time, top + eh / 2, eh, t),
                  isComplex: true,
                  willChange: !widget.preview),
            ),
          ),
          Positioned(
              top: top,
              left: 0,
              right: 0,
              height: eh,
              child: Center(child: _logo(t, eh, st))),
          Positioned.fill(
            child: Column(children: [
              SizedBox(height: top + eh + 16),
              _enter(
                  .08,
                  .4,
                  Text('حان الآن وقت صلاة',
                      textAlign: TextAlign.center,
                      style: cairoStyle(15, weight: 600, color: soft))),
              const SizedBox(height: 2),
              _enter(
                  .16,
                  .6,
                  scale: .8,
                  Text(widget.prayerName,
                      textAlign: TextAlign.center,
                      style: amiriStyle(46,
                          bold: true, color: t.accent, height: 1.25))),
              const SizedBox(height: 8),
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
              Expanded(
                  child: Center(
                      child: _enter(.5, .85, _lyrics(t)))),
              if (!widget.preview)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30, top: 8),
                    child: _enter(
                      .6,
                      1,
                      _PulseButton(
                          color: t.button,
                          ink: t.buttonInk,
                          onTap: widget.onDone),
                    ),
                  ),
                )
              else
                const SizedBox(height: 24),
            ]),
          ),
        ],
      );
    });
    if (widget.preview) return IgnorePointer(child: content);
    return Scaffold(backgroundColor: t.bg.first, body: content);
  }
}

class _Slide extends GradientTransform {
  final double percent;
  const _Slide(this.percent);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
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
// الخلفيات فقط (الشعار يُرسم كـ Widget فوقها)، مطابقة لـ AdhanArtView.java.

class _ArtPainter extends CustomPainter {
  final int style;
  final ValueNotifier<double> time;
  final double cy, s;
  final _Theme th;
  _ArtPainter(this.style, this.time, this.cy, this.s, this.th)
      : super(repaint: time);

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
    final cx = w / 2;
    final accent = th.accent;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: th.bg)
              .createShader(Offset.zero & size));

    switch (style) {
      case 0:
        _pattern(canvas, size, t, const Color(0x22FFFFFF));
        _glow(canvas, cx, cy, s * (1.25 + .06 * math.sin(t * 1.6)), accent, .38);
        _ripples(canvas, cx, cy, s * .8, accent, t);
      case 1:
        for (final st in _stars) {
          final a = .25 +
              .65 * (.5 + .5 * math.sin(t * (.8 + st[2] * .5) + st[3]));
          canvas.drawCircle(Offset(st[0] * w, st[1] * h), st[2] * .8,
              Paint()..color = _a(Colors.white, a));
        }
        _shooting(canvas, t, w, h);
        _glow(canvas, cx, cy, s * 1.2, const Color(0xFFBFD0FF),
            .22 + .08 * math.sin(t * 1.4));
        _crescent(canvas, w * .84, h * .05 + 10 * math.sin(t * .7), 10,
            _a(Colors.white, .35));
      case 2:
        _pattern(canvas, size, t, const Color(0x1FE2BC63));
        _frame(canvas, size, t);
        _glow(canvas, cx, cy, s * 1.15, accent, .20);
        _star8(canvas, cx, cy, s * .78, t * 10, accent);
        _star8(canvas, cx, cy, s * .60, -t * 16, accent);
      case 3:
        _sun(canvas, size, t, cx);
      default:
        _ripples(canvas, cx, cy, s * .72, accent, t);
        final br = 1 + .03 * math.sin(t * 1.8);
        canvas.drawCircle(Offset(cx, cy), s * .62 * br,
            Paint()..color = const Color(0xFFE3EFD8));
        canvas.drawCircle(
            Offset(cx, cy),
            s * .62 * br,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = accent);
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

  void _crescent(Canvas c, double x, double y, double r, Color color) {
    final a = Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    final b = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(x + r * .42, y - r * .12), radius: r * .82));
    c.drawPath(Path.combine(PathOperation.difference, a, b), Paint()..color = color);
  }

  void _star8(Canvas c, double x, double y, double r, double deg, Color color) {
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
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _a(color, .55));
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

  void _sun(Canvas c, Size sz, double t, double cx) {
    final accent = th.accent;
    final pulse = 1 + .06 * math.sin(t * 1.2);
    final gy = sz.height + 40 - 10 * math.sin(t * .6);
    _glow(c, sz.width / 2, gy, 330 * pulse, const Color(0xFFFFD08A), .9);
    _glow(c, cx, cy, s * 1.3, accent, .30);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = _a(accent, .55);
    for (var i = 0; i < 24; i++) {
      final a = math.pi * 2 / 24 * i + t * .18;
      final len = s * (i.isEven ? .30 : .18) * (1 + .2 * math.sin(t * 2 + i));
      final r0 = s * .66;
      c.drawLine(Offset(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
          Offset(cx + math.cos(a) * (r0 + len), cy + math.sin(a) * (r0 + len)), line);
    }
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
      old.style != style || old.cy != cy || old.s != s;
}
