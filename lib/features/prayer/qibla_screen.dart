import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../core/prayer_times.dart';
import '../../core/star_shape.dart';
import '../../core/text_utils.dart';
import '../../providers/prayer_provider.dart';
import '../home/home_art.dart';
import 'city_picker_screen.dart';

const _pinIcon =
    '<path d="M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>';
const _chevronIcon = '<path d="M9 6l6 6-6 6"/>';

/// الكعبة المشرّفة: مكعب أسود بحزام ذهبي وباب (viewBox 24×24).
const _kaabaSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M3 8l4-4h14l-4 4z" fill="#3A3A3A"/>
<rect x="3" y="8" width="14" height="13" fill="#1B1B1B"/>
<path d="M17 8l4-4v13l-4 4z" fill="#0F0F0F"/>
<rect x="3" y="11.500" width="14" height="2" fill="#B8923A"/>
<path d="M17 11.500l4-4v2l-4 4z" fill="#B8923A"/>
<rect x="10.500" y="15" width="4" height="6" rx=".6" fill="#B8923A"/>
</svg>''';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  bool _noSensor = false;
  bool _aligned = false;
  String? _locationError;
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final stream = FlutterCompass.events;
    if (stream == null) {
      _noSensor = true;
    } else {
      _sub = stream.listen(_onEvent, onError: (_) {
        if (mounted) setState(() => _noSensor = true);
      });
    }
  }

  void _onEvent(CompassEvent e) {
    final h = e.heading;
    if (h == null) {
      if (_heading == null && mounted) setState(() => _noSensor = true);
      return;
    }
    final target = (h + 360) % 360;
    final old = _heading;
    double next;
    if (old == null) {
      next = target;
    } else {
      // تنعيم دائري كي لا تهتز البوصلة ولا تقفز عند المرور بالصفر.
      final delta = ((target - old + 540) % 360) - 180;
      next = (old + delta * 0.25 + 360) % 360;
    }
    final q = context.read<PrayerProvider>().qibla;
    if (q != null) {
      final diff = ((q - next + 540) % 360) - 180;
      final nowAligned = diff.abs() <= 3;
      if (nowAligned && !_aligned) HapticFeedback.mediumImpact();
      _aligned = nowAligned;
      // اهتزاز خفيف متدرّج: كل ما قرّبت من القبلة تتقارب النبضات.
      if (!nowAligned && diff.abs() <= 20) {
        final gap = diff.abs() > 12 ? 650 : (diff.abs() > 6 ? 380 : 200);
        final t = DateTime.now();
        if (t.difference(_lastTick).inMilliseconds >= gap) {
          _lastTick = t;
          HapticFeedback.selectionClick();
        }
      }
    }
    if (mounted) {
      setState(() {
        _heading = next;
        _noSensor = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _pickCity() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CityPickerScreen()));

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final p = context.watch<PrayerProvider>();
    final mq = MediaQuery.of(context);

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _QiblaHeader(tk: tk, onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: p.hasLocation
                      ? _buildCompass(context, tk, p)
                      : _buildNoLocation(context, tk, p),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoLocation(BuildContext context, HomeTokens tk, PrayerProvider p) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            color: tk.mint,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: IslamicPatternPainter(opacity: .22)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HomeIcon(HomeIcons.compass, size: 56, color: tk.gold),
                      const SizedBox(height: 14),
                      Text('نحتاج موقعك',
                          style: amiriStyle(24, bold: true, color: tk.mintInk)),
                      const SizedBox(height: 6),
                      Text('لحساب اتجاه القبلة بدقة من مكانك',
                          textAlign: TextAlign.center,
                          style: cairoStyle(13,
                              color: tk.mintInk.withValues(alpha: .75))),
                      const SizedBox(height: 22),
                      _ActionButton(
                        tk: tk,
                        primary: true,
                        icon: HomeIcons.home,
                        label: 'اختيار مدينة',
                        onTap: _pickCity,
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        tk: tk,
                        primary: false,
                        icon: _pinIcon,
                        label: p.locating ? 'جارٍ التحديد…' : 'تحديد تلقائي',
                        onTap: p.locating
                            ? null
                            : () async {
                                final error =
                                    await context.read<PrayerProvider>().useGps();
                                if (mounted && error != null) {
                                  setState(() => _locationError = error);
                                }
                              },
                      ),
                      if (_locationError != null) ...[
                        const SizedBox(height: 14),
                        Text(_locationError!,
                            textAlign: TextAlign.center,
                            style: cairoStyle(12.5, color: tk.mintInk)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompass(BuildContext context, HomeTokens tk, PrayerProvider p) {
    final q = p.qibla!;
    final km = distanceToKaabaKm(p.lat!, p.lng!);
    final heading = _heading;
    final aligned = _aligned && heading != null;
    final accent = aligned ? tk.leaf : tk.gold;

    // الفرق بين اتجاه الهاتف والقبلة: موجب = القبلة على اليمين.
    String hint;
    if (_noSensor) {
      hint = 'لا يتوفر مستشعر بوصلة على هذا الجهاز';
    } else if (heading == null) {
      hint = 'جارٍ تشغيل البوصلة…';
    } else if (aligned) {
      hint = 'أنت باتجاه القبلة';
    } else {
      final diff = ((q - heading + 540) % 360) - 180;
      final side = diff > 0 ? 'يمينًا' : 'يسارًا';
      hint = 'لُفّ $side ${toArabicDigits(diff.abs().round())}°';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      child: Column(
        children: [
          // ── كارت البوصلة ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tk.mint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: aligned ? tk.leaf : Colors.transparent),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: IslamicPatternPainter(opacity: .22)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                  child: Column(
                    children: [
                      LayoutBuilder(builder: (context, box) {
                        final s = math.min(box.maxWidth, 340.0);
                        return SizedBox(
                          width: s,
                          height: s,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _CompassPainter(
                                      tk: tk,
                                      heading: heading ?? 0,
                                      qibla: q,
                                      aligned: aligned,
                                    ),
                                  ),
                                ),
                              ),
                              Builder(builder: (context) {
                                final a = (q - (heading ?? 0)) * math.pi / 180;
                                final r = s / 2 - 38;
                                final mx = s / 2 + math.sin(a) * r;
                                final my = s / 2 - math.cos(a) * r;
                                return Positioned(
                                  left: mx - 13,
                                  top: my - 13,
                                  child: IgnorePointer(
                                    child: SvgPicture.string(_kaabaSvg,
                                        width: 26, height: 26),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: aligned
                            ? amiriStyle(24, bold: true, color: tk.mintInk)
                            : cairoStyle(15, weight: 700, color: tk.mintInk),
                      ),
                      if (!aligned && heading != null && !_noSensor)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('حتى تصل الكعبة إلى العلامة',
                              style: cairoStyle(11.5,
                                  color: tk.mintInk.withValues(alpha: .75))),
                        ),
                      if (heading == null && !_noSensor)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: accent),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── اتجاه + مسافة ──
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  tk: tk,
                  icon: HomeIcons.compass,
                  value: '${toArabicDigits(q.round())}°',
                  label: 'اتجاه القبلة من الشمال',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  tk: tk,
                  icon: HomeIcons.qibla,
                  value: '${toArabicDigits(km.round())} كم',
                  label: 'المسافة إلى الكعبة',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── الموقع (يضغط لتغيير المدينة) ──
          PressableCard(
            onTap: _pickCity,
            builder: (context, pressed) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: tk.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pressed ? tk.gold : tk.line),
              ),
              child: Row(
                children: [
                  HomeIcon(_pinIcon, size: 24, color: tk.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الموقع',
                            style: cairoStyle(11.5, color: tk.muted)),
                        Text(p.placeName.isEmpty ? '—' : p.placeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: cairoStyle(15, weight: 700, color: tk.ink)),
                      ],
                    ),
                  ),
                  Text('تغيير',
                      style: cairoStyle(12.5, weight: 600, color: tk.gold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── ملاحظة المعايرة: إطار ذهبي متقطع مثل آية اليوم ──
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CustomPaint(
              foregroundPainter: DashedBorderPainter(color: tk.gold, radius: 18),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: IslamicPatternPainter(opacity: .18)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    child: Text(
                      _noSensor
                          ? 'استخدم زاوية القبلة أعلاه مع بوصلة أخرى.'
                          : 'البوصلة تتأثر بالمعادن والمغناطيس القريب. إن بدت غير دقيقة، '
                              'حرّك الهاتف على شكل ٨ لمعايرتها وابتعد عن الأجهزة الكهربائية.',
                      textAlign: TextAlign.center,
                      style: cairoStyle(12, color: tk.muted, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header بنفس ارتفاع الرئيسية (58): رجوع · عنوان · «مكة المكرمة» بإطار متقطع.
class _QiblaHeader extends StatelessWidget {
  final HomeTokens tk;
  final VoidCallback onBack;
  const _QiblaHeader({required this.tk, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tk.card,
                border: Border.all(color: tk.line),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: HomeIcon(_chevronIcon, size: 18, color: tk.ink),
            ),
          ),
          const SizedBox(width: 12),
          Text('القبلة', style: amiriStyle(30, bold: true, color: tk.ink)),
          const Spacer(),
          CustomPaint(
            painter: DashedBorderPainter(color: tk.gold, radius: 14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text('نحو الكعبة المشرّفة',
                  style: cairoStyle(13, weight: 600, color: tk.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

/// كارت إحصائية صغير (أيقونة + قيمة + وصف) بنفس شكل HomeTile.
class _StatTile extends StatelessWidget {
  final HomeTokens tk;
  final String icon, value, label;
  const _StatTile(
      {required this.tk,
      required this.icon,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeIcon(icon, size: 24, color: tk.gold),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value,
                maxLines: 1,
                style: cairoStyle(20, weight: 700, color: tk.ink, height: 1.2)),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cairoStyle(11.5, color: tk.muted)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final HomeTokens tk;
  final bool primary;
  final String icon, label;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.tk,
      required this.primary,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? tk.mint : tk.ink;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: PressableCard(
        onTap: onTap ?? () {},
        builder: (context, pressed) => Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            color: primary ? tk.mintInk : tk.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: pressed ? tk.gold : (primary ? tk.mintInk : tk.line)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HomeIcon(icon, size: 20, color: primary ? tk.mint : tk.gold),
              const SizedBox(width: 8),
              Text(label, style: cairoStyle(14.5, weight: 700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// بوصلة مرسومة بالكامل: حلقة + تدريج + اتجاهات + الكعبة على الحلقة.
/// القرص يدور مع الهاتف، والحروف والكعبة تبقى مستقيمة، والمؤشر العلوي ثابت.
class _CompassPainter extends CustomPainter {
  final HomeTokens tk;
  final double heading; // درجات
  final double qibla; // درجات
  final bool aligned;

  const _CompassPainter({
    required this.tk,
    required this.heading,
    required this.qibla,
    required this.aligned,
  });

  Offset _at(Offset c, double deg, double rad) {
    final a = deg * math.pi / 180;
    return Offset(c.dx + math.sin(a) * rad, c.dy - math.cos(a) * rad);
  }

  void _text(Canvas canvas, String t, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: style),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 38; // نصف قطر الحلقة
    final accent = aligned ? tk.leaf : tk.gold;

    // وجه القرص
    canvas.drawCircle(c, r, Paint()..color = tk.card);
    // نجمة باهتة في المنتصف
    final starSize = r * 1.15;
    canvas.save();
    canvas.translate(c.dx - starSize / 2, c.dy - starSize / 2);
    canvas.drawPath(
      islamicStarPath(Size(starSize, starSize)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = HomeTokens.patternGold.withValues(alpha: .28),
    );
    canvas.restore();
    // الحلقة
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 3 : 2
        ..color = accent,
    );

    // التدريج كل ٥°
    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 72; i++) {
      final deg = i * 5.0 - heading;
      final major = i % 6 == 0;
      if (i % 18 == 0) continue; // مكان الحروف
      tick
        ..strokeWidth = major ? 1.8 : 1
        ..color = major ? tk.gold : tk.muted.withValues(alpha: .55);
      canvas.drawLine(_at(c, deg, r - 5), _at(c, deg, r - (major ? 15 : 10)), tick);
    }

    // الاتجاهات الأربعة (مستقيمة دائمًا)
    const letters = ['ش', 'ق', 'ج', 'غ'];
    for (var i = 0; i < 4; i++) {
      final north = i == 0;
      _text(
        canvas,
        letters[i],
        _at(c, i * 90.0 - heading, r - 26),
        cairoStyle(north ? 19 : 16,
            weight: 700, color: north ? tk.gold : tk.muted),
      );
    }

    // خط القبلة من المركز
    final qDeg = qibla - heading;
    canvas.drawLine(
      _at(c, qDeg, 16),
      _at(c, qDeg, r - 46),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5
        ..color = accent,
    );
    canvas.drawCircle(_at(c, qDeg, r - 46), 3.5, Paint()..color = accent);

    // محور المركز
    canvas.drawCircle(c, 9, Paint()..color = tk.card);
    canvas.drawCircle(
      c,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );
    canvas.drawCircle(c, 3.5, Paint()..color = accent);

    // الكعبة على الحلقة
    final m = _at(c, qDeg, r);
    if (aligned) {
      canvas.drawCircle(
          m, 26, Paint()..color = tk.leaf.withValues(alpha: .22));
    }
    canvas.drawCircle(m, 18, Paint()..color = tk.card);
    canvas.drawCircle(
      m,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );
    // (رسمة الكعبة SVG تُوضع فوق الـ painter في الـ Stack)

    // المؤشر العلوي الثابت
    final tip = Offset(c.dx, c.dy - r - 22);
    final ptr = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 9, tip.dy - 13)
      ..lineTo(tip.dx + 9, tip.dy - 13)
      ..close();
    canvas.drawPath(ptr, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.heading != heading ||
      old.qibla != qibla ||
      old.aligned != aligned ||
      old.tk != tk;
}
