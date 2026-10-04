import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/quran_data.dart';
import '../../models/zikr.dart';
import '../../providers/activity_provider.dart';
import '../../providers/azkar_provider.dart';
import '../../providers/prayer_provider.dart';
import '../../providers/quran_audio_provider.dart';
import '../../providers/quran_provider.dart';
import '../../screens/categories_screen.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/zikr_list_screen.dart';
import '../challenges/challenges_screen.dart';
import '../more/support_screen.dart';
import '../prayer/prayer_screen.dart';
import '../quran/quran_audio_screen.dart';
import '../quran/quran_home_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';
import 'home_art.dart';

enum _Slot { morning, evening, sleep }

/// الشاشة الرئيسية الجديدة: بدون Scroll، 6 صفوف بنسب 1.65:1:1:1:1:1.2.
class HomeDashboard extends StatefulWidget {
  final void Function(int tab) onSwitchTab;
  const HomeDashboard({super.key, required this.onSwitchTab});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  Timer? _timer;
  _Slot _slot = _slotFor(DateTime.now());
  NextPrayer? _next;
  String _ayahDay = '';
  Ayah? _ayah;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      _now.value = n;
      final s = _slotFor(n);
      final passed = _next != null && !_next!.time.isAfter(n);
      if (s != _slot || passed) {
        setState(() => _slot = s);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _now.dispose();
    super.dispose();
  }

  /// نفس منطق التطبيق السابق (٣–١٢ صباح، ١٥–٢٠ مساء، ٢١–٣ نوم)،
  /// مع سدّ الفجوتين (١٢–١٥ ← صباح، ٢٠–٢١ ← مساء) لأن الكارت لازم يظهر دائمًا.
  static _Slot _slotFor(DateTime n) {
    final h = n.hour;
    if (h >= 3 && h < 15) return _Slot.morning;
    if (h >= 15 && h < 21) return _Slot.evening;
    return _Slot.sleep;
  }

  AzkarCategory? _categoryFor(AzkarProvider p, _Slot s) {
    for (final c in p.categories) {
      if (s == _Slot.sleep ? c.id == 'hisn-28' : c.id == 'hisn-27') return c;
    }
    final titles = s == _Slot.sleep
        ? const ['النوم']
        : const ['الصباح والمساء', 'الصباح', 'المساء'];
    for (final t in titles) {
      for (final c in p.categories) {
        if (c.title.contains(t)) return c;
      }
    }
    return null;
  }

  Ayah? _dailyAyah(QuranData? d, DateTime now) {
    if (d == null || d.ayahs.isEmpty) return null;
    final key = '${now.year}-${now.month}-${now.day}';
    if (_ayahDay == key && _ayah != null) return _ayah;
    final pool = d.ayahs.where((a) => a.text.length <= 90).toList();
    final list = pool.isEmpty ? d.ayahs : pool;
    final doy = now.difference(DateTime(now.year, 1, 1)).inDays;
    _ayahDay = key;
    _ayah = list[(doy + now.year * 7) % list.length];
    return _ayah;
  }

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  void _pushTitled(String title, Widget body) => _push(Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(child: body),
      ));

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final compact = mq.size.height < 640;

    final now = DateTime.now();
    final azkar = context.watch<AzkarProvider>();
    final quran = context.watch<QuranProvider>();
    final activity = context.watch<ActivityProvider>();
    final prayer = context.watch<PrayerProvider>();
    final audioSub = context.select<QuranAudioProvider, String>((a) {
      if (a.displaySurah != null) {
        return '${a.isPlaying ? 'يعمل الآن: ' : 'آخر استماع: '}'
            'سورة ${QuranAudioProvider.surahName(a.displaySurah!)}';
      }
      return a.hasAnyAudio
          ? 'التلاوة جاهزة · اضغط للاستماع'
          : 'اختر شيخًا ونزّل التلاوة';
    });

    _next = prayer.nextPrayer(now);
    final next = _next;
    final cat = _categoryFor(azkar, _slot);
    final progress = cat == null ? 0.0 : azkar.categoryProgress(cat.id);

    // تابع القراءة
    final qd = quran.data;
    final started = quran.hasStartedReading && qd != null;
    final page = qd == null ? 1 : quran.lastPage.clamp(1, qd.pageCount);
    final first = qd?.byPage[page]?.first;
    final read = quran.readPages.length;
    String readSub;
    if (qd == null) {
      readSub = '';
    } else if (started) {
      final s = first == null ? '' : QuranAudioProvider.surahName(first.surah);
      readSub = '$s · صفحة ${toArabicDigits(page)}'
          '${read > 0 ? ' — قرأت ${toArabicDigits(read)} من ${toArabicDigits(qd.pageCount)} صفحة' : ''}';
    } else {
      readSub = 'افتح المصحف من الفاتحة أو اختر السورة';
    }

    // التحديات
    final daily = activity.dailyFor(now);
    final done = activity.dailyDone(now);
    final total = daily.length;

    final ayah = _dailyAyah(qd, now);

    Widget slotTile(
        {required int span,
        required double colW,
        required double fullW,
        required Widget child}) {
      final w = span == 3 ? fullW : (span == 2 ? colW * 2 + 10 : colW);
      return SizedBox(width: w, child: child);
    }

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: Container(
        color: tk.bg,
        child: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: IslamicPatternPainter(opacity: .10)),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    _HomeHeader(
                      tk: tk,
                      compact: compact,
                      hijri: prayer.hijriFor(now).format(),
                      onSupport: () => _push(const SupportScreen()),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 10),
                        child: LayoutBuilder(builder: (context, box) {
                          final fullW = box.maxWidth;
                          final colW = (fullW - 20) / 3;
                          Widget row(int flex, List<Widget> kids) => Expanded(
                                flex: flex,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < kids.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 10),
                                      kids[i],
                                    ],
                                  ],
                                ),
                              );
                          const gap = SizedBox(height: 10);
                          return Column(
                            children: [
                              row(165, [
                                slotTile(
                                  span: 3,
                                  colW: colW,
                                  fullW: fullW,
                                  child: _AzkarTimeCard(
                                    tk: tk,
                                    slot: _slot,
                                    progress: progress,
                                    compact: compact,
                                    onTap: () => cat == null
                                        ? _pushTitled(
                                            'الأذكار', const CategoriesScreen())
                                        : _push(ZikrListScreen(
                                            categoryId: cat.id)),
                                  ),
                                ),
                              ]),
                              gap,
                              row(100, [
                                slotTile(
                                  span: 2,
                                  colW: colW,
                                  fullW: fullW,
                                  child: HomeTile(
                                    tk: tk,
                                    compact: compact,
                                    icon: HomeIcons.clock,
                                    title: 'الصلاة القادمة',
                                    subtitle: next == null
                                        ? 'حدّد موقعك لعرض المواقيت'
                                        : '${next.name} · ${formatClock(next.time)}',
                                    onTap: () => _push(const PrayerScreen()),
                                  ),
                                ),
                                slotTile(
                                  span: 1,
                                  colW: colW,
                                  fullW: fullW,
                                  child: ValueListenableBuilder<DateTime>(
                                    valueListenable: _now,
                                    builder: (context, n, _) => HomeTile(
                                      tk: tk,
                                      compact: compact,
                                      icon: HomeIcons.hourglass,
                                      title: 'المتبقي',
                                      subtitle: next == null
                                          ? '--:--:--'
                                          : formatCountdown(
                                              next.time.difference(n)),
                                      subtitleIsClock: true,
                                      alwaysShowSubtitle: true,
                                      onTap: () => _push(const PrayerScreen()),
                                    ),
                                  ),
                                ),
                              ]),
                              gap,
                              row(100, [
                                slotTile(
                                  span: 1,
                                  colW: colW,
                                  fullW: fullW,
                                  child: HomeTile(
                                    tk: tk,
                                    compact: compact,
                                    icon: HomeIcons.hand,
                                    title: 'التسبيح',
                                    onTap: () => _push(const TasbeehScreen()),
                                  ),
                                ),
                                slotTile(
                                  span: 2,
                                  colW: colW,
                                  fullW: fullW,
                                  child: HomeTile(
                                    tk: tk,
                                    compact: compact,
                                    icon: HomeIcons.quran,
                                    title: started ? 'تابع القراءة' : 'ابدأ القراءة',
                                    subtitle: readSub,
                                    progress: started && read > 0
                                        ? quran.khatmaProgress
                                        : null,
                                    onTap: () => started
                                        ? openReader(context, page)
                                        : widget.onSwitchTab(1),
                                  ),
                                ),
                              ]),
                              gap,
                              row(100, [
                                slotTile(
                                  span: 2,
                                  colW: colW,
                                  fullW: fullW,
                                  child: HomeTile(
                                    tk: tk,
                                    compact: compact,
                                    icon: HomeIcons.headphones,
                                    title: 'القرآن صوتيًا',
                                    subtitle: audioSub,
                                    onTap: () => _push(const QuranAudioScreen()),
                                  ),
                                ),
                                slotTile(
                                  span: 1,
                                  colW: colW,
                                  fullW: fullW,
                                  child: HomeTile(
                                    tk: tk,
                                    compact: compact,
                                    icon: HomeIcons.sparkle,
                                    title: 'الأذكار',
                                    onTap: () => _pushTitled(
                                        'الأذكار', const CategoriesScreen()),
                                  ),
                                ),
                              ]),
                              gap,
                              row(100, [
                                slotTile(
                                  span: 1,
                                  colW: colW,
                                  fullW: fullW,
                                  child: HomeTile(
                                    tk: tk,
                                    compact: compact,
                                    icon: HomeIcons.heart,
                                    title: 'المفضّلة',
                                    onTap: () => _pushTitled(
                                        'المفضلة', const FavoritesScreen()),
                                  ),
                                ),
                                slotTile(
                                  span: 2,
                                  colW: colW,
                                  fullW: fullW,
                                  child: HomeTile(
                                    tk: tk,
                                    compact: compact,
                                    icon: HomeIcons.trophy,
                                    title:
                                        'تحديات اليوم · ${toArabicDigits(done)} / ${toArabicDigits(total)}',
                                    subtitle:
                                        'أيام متواصلة: ${toArabicDigits(activity.streak)}',
                                    progress: total == 0 ? 0 : done / total,
                                    onTap: () =>
                                        _push(const ChallengesScreen()),
                                  ),
                                ),
                              ]),
                              gap,
                              row(120, [
                                slotTile(
                                  span: 3,
                                  colW: colW,
                                  fullW: fullW,
                                  child: _AyahCard(
                                    tk: tk,
                                    text: ayah?.text ??
                                        'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
                                    ref: ayah == null
                                        ? 'سورة الرعد · ٢٨'
                                        : 'سورة ${QuranAudioProvider.surahName(ayah.surah)} · ${toArabicDigits(ayah.number)}',
                                    onTap: ayah == null
                                        ? null
                                        : () => openReader(context, ayah.page,
                                            highlight:
                                                '${ayah.surah}:${ayah.number}'),
                                  ),
                                ),
                              ]),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header: ارتفاع 58 — الشعار (يمين) · التاريخ الهجري (منتصف) · زر الدعم (شمال).
class _HomeHeader extends StatelessWidget {
  final HomeTokens tk;
  final bool compact;
  final String hijri;
  final VoidCallback onSupport;
  const _HomeHeader(
      {required this.tk,
      required this.compact,
      required this.hijri,
      required this.onSupport});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Text('ذِكر',
              style: amiriStyle(compact ? 26 : 30, bold: true, color: tk.ink)),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: CustomPaint(
                  painter: DashedBorderPainter(color: tk.gold, radius: 14),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(hijri,
                        maxLines: 1,
                        softWrap: false,
                        style: cairoStyle(13, weight: 600, color: tk.muted)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSupport,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: tk.card,
                border: Border.all(color: tk.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HomeIcon(HomeIcons.heart, size: 16, color: tk.gold),
                  const SizedBox(width: 6),
                  Text('ادعم التطبيق',
                      style: cairoStyle(13, weight: 600, color: tk.ink)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// الكارت العادي.
class HomeTile extends StatelessWidget {
  final HomeTokens tk;
  final bool compact;
  final String icon;
  final String title;
  final String? subtitle;
  final double? progress;
  final bool subtitleIsClock;
  final bool alwaysShowSubtitle;
  final VoidCallback onTap;
  const HomeTile({
    super.key,
    required this.tk,
    required this.compact,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.progress,
    this.subtitleIsClock = false,
    this.alwaysShowSubtitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final showSub = subtitle != null &&
        subtitle!.isNotEmpty &&
        (!compact || alwaysShowSubtitle);
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pressed ? tk.gold : tk.line),
        ),
        child: LayoutBuilder(builder: (context, c) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeIcon(icon, size: 24, color: tk.gold),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: c.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: cairoStyle(16,
                                weight: 700, color: tk.ink, height: 1.25)),
                        if (showSub)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: subtitleIsClock
                                ? Text(subtitle!,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.right,
                                    style: cairoStyle(11.5, color: tk.muted)
                                        .copyWith(fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ]))
                                : Text(subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: cairoStyle(11.5, color: tk.muted)),
                          ),
                        if (progress != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: HomeProgressBar(value: progress!, tokens: tk),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// كارت الأذكار المتغيّر حسب الوقت (الكارت الأول).
class _AzkarTimeCard extends StatelessWidget {
  final HomeTokens tk;
  final _Slot slot;
  final double progress;
  final bool compact;
  final VoidCallback onTap;
  const _AzkarTimeCard(
      {required this.tk,
      required this.slot,
      required this.progress,
      required this.compact,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = switch (slot) {
      _Slot.morning => 'أذكار الصباح',
      _Slot.evening => 'أذكار المساء',
      _Slot.sleep => 'أذكار النوم',
    };
    final icon = switch (slot) {
      _Slot.morning => HomeIcons.sun,
      _Slot.evening => HomeIcons.sunset,
      _Slot.sleep => HomeIcons.moon,
    };
    final pct = (progress * 100).round();
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tk.mint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pressed ? tk.gold : Colors.transparent),
        ),
        child: LayoutBuilder(builder: (context, box) {
          return Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: IslamicPatternPainter(opacity: .22)),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: MosqueArt(width: box.maxWidth * .44, tokens: tk),
              ),
              Positioned.fill(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  child: LayoutBuilder(builder: (context, c) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HomeIcon(icon, size: 24, color: tk.gold),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: SizedBox(
                              width: c.maxWidth * .62,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('حان وقت',
                                      style: cairoStyle(11.5,
                                          color: tk.mintInk
                                              .withValues(alpha: .75))),
                                  Text(title,
                                      maxLines: 1,
                                      style: amiriStyle(22,
                                          bold: true,
                                          color: tk.mintInk,
                                          height: 1.2)),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: HomeProgressBar(
                                        value: progress, tokens: tk),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                        'أنجزت ${toArabicDigits(pct)}٪ · اضغط للمتابعة',
                                        maxLines: 1,
                                        style: cairoStyle(11.5,
                                            color: tk.mintInk
                                                .withValues(alpha: .75))),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// كارت آية اليوم: شفاف + إطار ذهبي متقطع + نقش.
class _AyahCard extends StatelessWidget {
  final HomeTokens tk;
  final String text;
  final String ref;
  final VoidCallback? onTap;
  const _AyahCard(
      {required this.tk, required this.text, required this.ref, this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap ?? () {},
      builder: (context, pressed) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          foregroundPainter: DashedBorderPainter(
              color: tk.gold, radius: 18),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: IslamicPatternPainter(opacity: .18)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                child: LayoutBuilder(builder: (context, c) {
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: c.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('آية اليوم',
                                style:
                                    cairoStyle(11.5, weight: 600, color: tk.gold)),
                            const SizedBox(height: 2),
                            Text('﴿ $text ﴾',
                                textAlign: TextAlign.center,
                                style: amiriStyle(21, color: tk.ink, height: 1.7)),
                            const SizedBox(height: 2),
                            Text(ref,
                                style:
                                    cairoStyle(11.5, weight: 600, color: tk.gold)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
