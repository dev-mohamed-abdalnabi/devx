import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/hijri.dart';
import '../../core/text_utils.dart';
import '../../providers/activity_provider.dart';
import '../../providers/azkar_provider.dart';
import '../../providers/prayer_provider.dart';
import '../../providers/quran_audio_provider.dart';
import '../../providers/quran_provider.dart';
import '../../screens/zikr_list_screen.dart';
import '../../screens/favorites_screen.dart';
import '../challenges/challenges_screen.dart';
import '../more/support_screen.dart';
import '../prayer/prayer_screen.dart';
import '../quran/quran_audio_screen.dart';
import '../quran/quran_home_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';
import '../../widgets/support_app_button.dart';

const _bg = Color(0xFFF7F5EE);
const _card = Color(0xFFFFFFFF);
const _line = Color(0xFFE7E1CE);
const _ink = Color(0xFF1F2A1F);
const _muted = Color(0xFF7B8270);
const _gold = Color(0xFFB8923A);
const _mint = Color(0xFFE3EFD8);
const _mintInk = Color(0xFF2F5A2A);
const _leaf = Color(0xFF6FAE5A);

class HomeDashboard extends StatelessWidget {
  final void Function(int tab) onSwitchTab;
  const HomeDashboard({super.key, required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final azkar = context.watch<AzkarProvider>();
    final quran = context.watch<QuranProvider>();
    final activity = context.watch<ActivityProvider>();
    final prayer = context.watch<PrayerProvider>();
    final audio = context.watch<QuranAudioProvider>();
    final daily = activity.dailyFor(now);
    final category = _categoryForTime(azkar, prayer, now);
    final hijri = prayer.hijriFor(now).format();
    final done = daily.isEmpty ? 0 : activity.dailyDone(now);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Text('ذِكر', style: TextStyle(fontFamily: 'Amiri', fontSize: 30, fontWeight: FontWeight.w700, color: _ink)),
                    const Spacer(),
                    _DashedLabel(hijri),
                    const Spacer(),
                    _SupportPill(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen()))),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Column(
                  children: [
                    Expanded(flex: 165, child: _HeroCard(category: category, provider: azkar)),
                    const SizedBox(height: 10),
                    Expanded(flex: 100, child: Row(textDirection: TextDirection.rtl, children: [
                      Expanded(flex: 2, child: _PrayerCard(prayer: prayer)), const SizedBox(width: 10), Expanded(child: _CountdownCard()),
                    ])),
                    const SizedBox(height: 10),
                    Expanded(flex: 100, child: Row(textDirection: TextDirection.rtl, children: [
                      Expanded(child: _ActionCard(icon: LineIcon.hand, title: 'التسبيح', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasbeehScreen())))), const SizedBox(width: 10), Expanded(flex: 2, child: _ReadingCard(quran: quran, onTap: () => onSwitchTab(1))),
                    ])),
                    const SizedBox(height: 10),
                    Expanded(flex: 100, child: Row(textDirection: TextDirection.rtl, children: [
                      Expanded(flex: 2, child: _AudioCard(audio: audio)), const SizedBox(width: 10), Expanded(child: _ActionCard(icon: LineIcon.sparkle, title: 'الأذكار', onTap: () => onSwitchTab(2))),
                    ])),
                    const SizedBox(height: 10),
                    Expanded(flex: 100, child: Row(textDirection: TextDirection.rtl, children: [
                      Expanded(child: _ActionCard(icon: LineIcon.heart, title: 'المفضّلة', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())))), const SizedBox(width: 10), Expanded(flex: 2, child: _ChallengesCard(done: done, total: daily.length, streak: activity.streak, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen())))),
                    ])),
                    const SizedBox(height: 10),
                    Expanded(flex: 120, child: const _AyahCard()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AzkarCategory? _categoryForTime(AzkarProvider p, PrayerProvider prayer, DateTime now) {
    final times = prayer.timesFor(now);
    final asr = times?.asr;
    final maghrib = times?.maghrib;
    final isha = times?.isha;
    if (isha != null && (now.isAfter(isha) || now.isBefore(times?.fajr ?? now))) return _find(p, const ['النوم']);
    if ((maghrib != null && now.isAfter(maghrib)) || (asr != null && now.isAfter(asr))) return _find(p, const ['الصباح والمساء', 'المساء']);
    return _find(p, const ['الصباح', 'الصباح والمساء']) ?? (p.categories.isEmpty ? null : p.categories.first);
  }
  AzkarCategory? _find(AzkarProvider p, List<String> names) { for (final n in names) { for (final c in p.categories) { if (c.title.contains(n)) return c; } } return null; }
}

class _DashedLabel extends StatelessWidget { final String text; const _DashedLabel(this.text); @override Widget build(BuildContext context) => CustomPaint(painter: _DashedBorderPainter(_gold), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted)))); }
class _SupportPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SupportPill({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _line)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          height: 36,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              LineIcon(LineIcon.heart, size: 16),
              SizedBox(width: 6),
              Text('ادعم التطبيق', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget { final AzkarCategory? category; final AzkarProvider provider; const _HeroCard({required this.category, required this.provider}); @override Widget build(BuildContext context) { final c = category; final progress = c == null ? 0.0 : provider.categoryProgress(c.id); final title = c?.title ?? 'أذكار الصباح'; return _TapCard(color: _mint, border: Colors.transparent, onTap: c == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ZikrListScreen(categoryId: c.id))), child: Stack(children: [const Positioned.fill(child: _Pattern(opacity: .22)), const Positioned(top: 12, right: 14, child: LineIcon(LineIcon.moon)), Align(alignment: AlignmentDirectional.centerEnd, child: FractionallySizedBox(widthFactor: .62, child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 0, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('حان وقت', style: TextStyle(fontSize: 11.5, color: _mintInk)), Text(title, style: const TextStyle(fontFamily: 'Amiri', fontSize: 22, fontWeight: FontWeight.w700, color: _mintInk)), _ProgressBar(value: progress), Text('أنجزت ${toArabicDigits((progress * 100).round())}٪ · اضغط للمتابعة', style: const TextStyle(fontSize: 11.5, color: _mintInk))])))), const Positioned(left: -2, bottom: -2, width: 190, height: 140, child: _MosqueArt())])); } }

class _PrayerCard extends StatelessWidget { final PrayerProvider prayer; const _PrayerCard({required this.prayer}); @override Widget build(BuildContext context) { final next = prayer.nextPrayer(DateTime.now()); final label = next == null ? 'اختر مدينتك من المواقيت' : '${next.name} · ${_time(next.time)}'; return _InfoCard(icon: LineIcon.clock, title: 'الصلاة القادمة', subtitle: label, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrayerScreen()))); } }
class _CountdownCard extends StatefulWidget { const _CountdownCard(); @override State<_CountdownCard> createState() => _CountdownCardState(); }
class _CountdownCardState extends State<_CountdownCard> { Timer? timer; Duration left = Duration.zero; @override void initState() { super.initState(); _tick(); timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick()); } void _tick() { final n = DateTime.now(); final t = DateTime(n.year, n.month, n.day, 5, 25).isAfter(n) ? DateTime(n.year, n.month, n.day, 5, 25) : DateTime(n.year, n.month, n.day + 1, 5, 25); if (mounted) setState(() => left = t.difference(n)); } @override void dispose() { timer?.cancel(); super.dispose(); } @override Widget build(BuildContext context) { final s = left.inSeconds.clamp(0, 86399); final str = '${(s ~/ 3600).toString().padLeft(2, '0')}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}'; return _InfoCard(icon: LineIcon.hourglass, title: 'المتبقي', subtitle: toArabicDigitsStr(str), ltr: true); } }
class _ActionCard extends StatelessWidget { final String icon, title; final VoidCallback onTap; const _ActionCard({required this.icon, required this.title, required this.onTap}); @override Widget build(BuildContext context) => _TapCard(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [LineIcon(icon), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink))])); }
class _ReadingCard extends StatelessWidget { final QuranProvider quran; final VoidCallback onTap; const _ReadingCard({required this.quran, required this.onTap}); @override Widget build(BuildContext context) { final data = quran.data; final page = quran.lastPage.clamp(1, data?.pageCount ?? 604).toInt(); final first = data?.byPage[page]?.first; final surah = first == null ? 'ابدأ من الفاتحة' : QuranAudioProvider.surahName(first.surah); final read = quran.readPages.length; return _TapCard(onTap: quran.hasStartedReading ? () => openReader(context, page) : onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const LineIcon(LineIcon.book), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('تابع القراءة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)), Text('$surah · صفحة ${toArabicDigits(page)} — قرأت ${toArabicDigits(read)} من ${toArabicDigits(data?.pageCount ?? 604)} صفحة', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: _muted)), _ProgressBar(value: quran.khatmaProgress)])])); } }
class _AudioCard extends StatelessWidget { final QuranAudioProvider audio; const _AudioCard({required this.audio}); @override Widget build(BuildContext context) => _InfoCard(icon: LineIcon.headphones, title: 'القرآن صوتيًا', subtitle: audio.displaySurah == null ? 'اختر شيخًا للاستماع' : 'آخر استماع: سورة ${QuranAudioProvider.surahName(audio.displaySurah!)}', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuranAudioScreen()))); }
class _ChallengesCard extends StatelessWidget { final int done, total, streak; final VoidCallback onTap; const _ChallengesCard({required this.done, required this.total, required this.streak, required this.onTap}); @override Widget build(BuildContext context) => _TapCard(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const LineIcon(LineIcon.trophy), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تحديات اليوم · ${toArabicDigits( done)} / ${toArabicDigits(total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)), Text('أيام متواصلة: ${toArabicDigits(streak)}', style: const TextStyle(fontSize: 11.5, color: _muted)), _ProgressBar(value: total == 0 ? 0 : done / total)])])); }
class _AyahCard extends StatelessWidget { const _AyahCard(); @override Widget build(BuildContext context) => _TapCard(border: _gold, child: Stack(children: [const Positioned.fill(child: _Pattern(opacity: .18)), Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('آية اليوم', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _gold)), Text('﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Amiri', fontSize: 19, height: 1.7, color: _ink)), const Text('سورة الرعد · ٢٨', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _gold))]))])); }

class _InfoCard extends StatelessWidget {
  final String icon, title, subtitle;
  final VoidCallback? onTap;
  final bool ltr;
  const _InfoCard({required this.icon, required this.title, required this.subtitle, this.onTap, this.ltr = false});
  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LineIcon(icon),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
              Text(subtitle, textDirection: ltr ? TextDirection.ltr : TextDirection.rtl, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TapCard extends StatelessWidget { final Widget child; final VoidCallback? onTap; final Color? color, border; const _TapCard({required this.child, this.onTap, this.color = _card, this.border = _line}); @override Widget build(BuildContext context) => Material(color: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border ?? _line)), clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, splashColor: _gold.withValues(alpha: .08), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14), child: child))); }
class _ProgressBar extends StatelessWidget { final double value; const _ProgressBar({required this.value}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 6), child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: value.clamp(0, 1).toDouble(), minHeight: 6, backgroundColor: _line, color: _leaf))); }
class _Pattern extends StatelessWidget { final double opacity; const _Pattern({required this.opacity}); @override Widget build(BuildContext context) => CustomPaint(painter: _PatternPainter(opacity)); }
class _PatternPainter extends CustomPainter { final double opacity; _PatternPainter(this.opacity); @override void paint(Canvas c, Size s) { final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _gold.withValues(alpha: opacity); for (double x = -44; x < s.width + 44; x += 44) for (double y = -44; y < s.height + 44; y += 44) { final path = Path()..moveTo(x + 22, y + 3)..lineTo(x + 26.5, y + 13.5)..lineTo(x + 37, y + 9)..lineTo(x + 32.5, y + 19.5)..lineTo(x + 41, y + 22)..lineTo(x + 32.5, y + 24.5)..lineTo(x + 37, y + 35)..lineTo(x + 26.5, y + 30.5)..lineTo(x + 22, y + 41)..lineTo(x + 17.5, y + 30.5)..lineTo(x + 7, y + 35)..lineTo(x + 11.5, y + 24.5)..lineTo(x + 3, y + 22)..lineTo(x + 11.5, y + 19.5)..lineTo(x + 7, y + 9)..lineTo(x + 17.5, y + 13.5)..close(); c.drawPath(path, p); } } @override bool shouldRepaint(covariant _PatternPainter old) => old.opacity != opacity; }
class _DashedBorderPainter extends CustomPainter { final Color color; _DashedBorderPainter(this.color); @override void paint(Canvas c, Size s) { final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1; final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(14))); for (final metric in path.computeMetrics()) { for (double d = 0; d < metric.length; d += 7) c.drawPath(metric.extractPath(d, d + 4), p); } } @override bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color; }
class _MosqueArt extends StatelessWidget { const _MosqueArt(); @override Widget build(BuildContext context) => CustomPaint(painter: _MosquePainter()); }
class _MosquePainter extends CustomPainter { @override void paint(Canvas c, Size s) { final scale = s.width / 150; c.scale(scale, scale); final fill = Paint()..color = _mintInk.withValues(alpha: .3); c.drawRect(const Rect.fromLTWH(0, 100, 150, 10), fill); c.drawRect(const Rect.fromLTWH(38, 72, 64, 28), fill); c.drawArc(const Rect.fromLTWH(40, 42, 60, 60), math.pi, math.pi, true, fill); c.drawRect(const Rect.fromLTWH(8, 54, 12, 46), fill); c.drawRect(const Rect.fromLTWH(130, 54, 12, 46), fill); final gold = Paint()..color = _gold; c.drawCircle(const Offset(70, 19), 7, gold); c.drawCircle(const Offset(72.5, 18), 5.5, Paint()..color = _mint); c.drawRect(const Rect.fromLTWH(69.5, 27, 1, 16), gold); } @override bool shouldRepaint(covariant CustomPainter old) => false; }

class LineIcon extends StatelessWidget {
  static const clock = 'clock', hourglass = 'hourglass', hand = 'hand', book = 'book', headphones = 'headphones', sparkle = 'sparkle', heart = 'heart', trophy = 'trophy', moon = 'moon';
  final String icon; final double size;
  const LineIcon(this.icon, {this.size = 24, super.key});
  @override Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _IconPainter(icon, Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4AE5A) : _gold));
}

String _time(DateTime d) { final h = d.hour % 12 == 0 ? 12 : d.hour % 12; final m = d.minute.toString().padLeft(2, '0'); return '${toArabicDigitsStr('$h:$m')} ${d.hour < 12 ? 'ص' : 'م'}'; }
class _IconPainter extends CustomPainter { final String icon; final Color color; _IconPainter(this.icon, this.color); @override void paint(Canvas c, Size s) { final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.7..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round; final x = s.width / 24; c.scale(x, x); final path = Path(); switch (icon) { case 'clock': c.drawCircle(const Offset(12, 12), 9, p); path..moveTo(12, 7)..lineTo(12, 12)..lineTo(15, 14); c.drawPath(path, p); break; case 'hourglass': path..moveTo(6, 3)..lineTo(18, 3)..moveTo(6, 21)..lineTo(18, 21)..moveTo(7, 3)..cubicTo(7, 8, 12, 9, 12, 12)..cubicTo(12, 15, 7, 16, 7, 21)..moveTo(17, 3)..cubicTo(17, 8, 12, 9, 12, 12)..cubicTo(12, 15, 17, 16, 17, 21); c.drawPath(path, p); break; case 'book': path..moveTo(3, 5)..cubicTo(6, 4, 9, 4, 12, 6)..cubicTo(15, 4, 18, 4, 21, 5)..lineTo(21, 18)..cubicTo(18, 17, 15, 17, 12, 19)..cubicTo(9, 17, 6, 17, 3, 18)..close()..moveTo(12, 6)..lineTo(12, 19); c.drawPath(path, p); break; case 'heart': path..moveTo(12, 20)..cubicTo(10, 18, 5, 15, 5, 10)..cubicTo(5, 6, 9, 5, 12, 7.5)..cubicTo(15, 5, 19, 6, 19, 10)..cubicTo(19, 15, 14, 18, 12, 20); c.drawPath(path, p); break; case 'sparkle': path..moveTo(9, 4)..lineTo(10.8, 8.2)..lineTo(15, 10)..lineTo(10.8, 11.8)..lineTo(9, 16)..lineTo(7.2, 11.8)..lineTo(3, 10)..lineTo(7.2, 8.2)..close()..moveTo(17, 14)..lineTo(17.9, 16.1)..lineTo(20, 17)..lineTo(17.9, 17.9)..lineTo(17, 20)..lineTo(16.1, 17.9)..lineTo(14, 17)..lineTo(16.1, 16.1)..close(); c.drawPath(path, p); break; case 'trophy': path..moveTo(8, 4)..lineTo(16, 4)..lineTo(16, 8)..cubicTo(16, 11, 14, 12, 12, 12)..cubicTo(10, 12, 8, 11, 8, 8)..close()..moveTo(8, 6)..lineTo(4, 6)..cubicTo(4, 10, 6, 11, 8, 10)..moveTo(16, 6)..lineTo(20, 6)..cubicTo(20, 10, 18, 11, 16, 10)..moveTo(12, 12)..lineTo(12, 16)..moveTo(8, 20)..lineTo(16, 20)..moveTo(9, 16)..lineTo(15, 16); c.drawPath(path, p); break; case 'headphones': path..moveTo(4, 15)..lineTo(4, 12)..cubicTo(4, 7, 8, 4, 12, 4)..cubicTo(16, 4, 20, 7, 20, 12)..lineTo(20, 15)..moveTo(4, 15)..cubicTo(4, 13, 7, 13, 7, 15)..lineTo(7, 19)..cubicTo(7, 20, 4, 20, 4, 18)..moveTo(20, 15)..cubicTo(20, 13, 17, 13, 17, 15)..lineTo(17, 19)..cubicTo(17, 20, 20, 20, 20, 18); c.drawPath(path, p); break; case 'hand': path..moveTo(8, 11)..lineTo(8, 6)..cubicTo(8, 4, 11, 4, 11, 6)..lineTo(11, 10)..lineTo(11, 5)..cubicTo(11, 3, 14, 3, 14, 5)..lineTo(14, 10)..lineTo(14, 6)..cubicTo(14, 4, 17, 4, 17, 6)..lineTo(17, 12)..cubicTo(17, 17, 14, 20, 11, 20)..cubicTo(8, 20, 6, 17, 5, 14)..cubicTo(4, 12, 7, 11, 8, 13); c.drawPath(path, p); break; case 'moon': path..moveTo(20, 14.5)..cubicTo(16, 18, 10, 18, 7, 14)..cubicTo(4, 10, 6, 5, 9.5, 4)..cubicTo(9, 8, 12, 13, 16, 14)..cubicTo(17.5, 14.5, 19, 14.5, 20, 14.5); c.drawPath(path, p); break; } } @override bool shouldRepaint(covariant _IconPainter old) => old.icon != icon || old.color != color; }
