import 'dart:async';
import 'package:flutter/foundation.dart';
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
import '../prayer/qibla_screen.dart';
import '../quran/quran_audio_screen.dart';
import '../quran/quran_home_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';
import 'home_art.dart';
import 'hero_scene.dart';

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
    final id = switch (s) {
      _Slot.morning => 'hisn-27',
      _Slot.evening => 'hisn-27e',
      _Slot.sleep => 'hisn-28',
    };
    for (final c in p.categories) {
      if (c.id == id) return c;
    }
    final titles = switch (s) {
      _Slot.morning => const ['أذكار الصباح', 'الصباح'],
      _Slot.evening => const ['أذكار المساء', 'المساء'],
      _Slot.sleep => const ['النوم'],
    };
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
      // سطر واحد قصير؛ التقدّم يظهر في الشريط (النسبة المئوية تتشوّه في النص العربي).
      readSub = '$s · صفحة ${toArabicDigits(page)}';
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
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: LayoutBuilder(builder: (context, box) {
                final fullW = box.maxWidth;
                final colW = (fullW - 20) / 3;
                // تصميم ثابت المقاسات: الكروت لا تُضغط أبدًا (كان الضغط يصغّر الخط ويخفي النص).
                // نحسب معامل تكبير بسيط ليملأ الشاشات الطويلة، والقصيرة تُمرَّر.
                const baseTotal = 180 + 108 * 4 + 120 + 40.0;
                final avail = box.maxHeight - 74;
                final scale = (avail / baseTotal).clamp(1.0, 1.18);
                Widget row(int h, List<Widget> kids) {
                  return SizedBox(
                    height: h * scale,
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
                }

                const gap = SizedBox(height: 10);
                final grid = Column(
                  children: [
                    row(180, [
                      slotTile(
                        span: 3,
                        colW: colW,
                        fullW: fullW,
                        child: _AzkarTimeCard(
                          tk: tk,
                          slot: _slot,
                          progress: progress,
                          compact: compact,
                          now: _now,
                          next: next,
                          onTap: () => cat == null
                              ? _push(const CategoriesScreen())
                              : _push(ZikrListScreen(categoryId: cat.id)),
                        ),
                      ),
                    ]),
                    gap,
                    row(108, [
                      slotTile(
                        span: 2,
                        colW: colW,
                        fullW: fullW,
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: _now,
                          builder: (context, n, _) => HomeTile(
                            tk: tk,
                            compact: compact,
                            icon: HomeIcons.clock,
                            title: 'الصلاة القادمة',
                            subtitle: next == null
                                ? 'حدّد موقعك لعرض المواقيت'
                                : '${next.name} · ${formatClock(next.time)}',
                            badge: next == null
                                ? null
                                : '\u2066${formatCountdown(next.time.difference(n))}\u2069',
                            onTap: () => _push(const PrayerScreen()),
                          ),
                        ),
                      ),
                      slotTile(
                        span: 1,
                        colW: colW,
                        fullW: fullW,
                        child: HomeTile(
                          tk: tk,
                          compact: compact,
                          icon: HomeIcons.compass,
                          title: 'القبلة',
                          onTap: () => _push(const QiblaScreen()),
                        ),
                      ),
                    ]),
                    gap,
                    row(108, [
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
                          progress:
                              started && read > 0 ? quran.khatmaProgress : null,
                          onTap: () => started
                              ? openReader(context, page)
                              : widget.onSwitchTab(1),
                        ),
                      ),
                    ]),
                    gap,
                    row(108, [
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
                          onTap: () => _push(const CategoriesScreen()),
                        ),
                      ),
                    ]),
                    gap,
                    row(108, [
                      slotTile(
                        span: 1,
                        colW: colW,
                        fullW: fullW,
                        child: HomeTile(
                          tk: tk,
                          compact: compact,
                          icon: HomeIcons.heart,
                          title: 'المفضّلة',
                          onTap: () => _push(const FavoritesScreen()),
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
                          subtitle: activity.streak > 0
                              ? 'سلسلة ${toArabicDigits(activity.streak)} ${activity.streak == 1 ? 'يوم' : 'أيام'}'
                              : 'ابدأ سلسلتك اليوم',
                          progress: total == 0 ? 0 : done / total,
                          onTap: () => _push(const ChallengesScreen()),
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
                                  highlight: '${ayah.surah}:${ayah.number}'),
                        ),
                      ),
                    ]),
                  ],
                );
                final header = _HomeHeader(
                  tk: tk,
                  compact: compact,
                  hijri: prayer.hijriFor(now).format(),
                  onSupport: () => _push(const SupportScreen()),
                );
                // الهيدر جزء من الصفحة: يطلع مع التمرير على الشاشات القصيرة.
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [header, const SizedBox(height: 6), grid],
                  ),
                );
              }),
            ),
          ),
        ],
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
  final String? badge; // شارة صغيرة بجوار الأيقونة (مثل العدّ التنازلي)
  final Widget? extra;
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
    this.badge,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    // الشاشات القصيرة تتعامل معها الشبكة بارتفاعات ثابتة مع تمرير،
    // فلا داعي لإخفاء النص الفرعي (كان يختفي على بعض الأجهزة).
    final showSub = subtitle != null && subtitle!.isNotEmpty;
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HomeIcon(icon, size: 24, color: tk.gold),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tk.mint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(badge!,
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: cairoStyle(11.5, weight: 700, color: tk.mintInk)
                            .copyWith(fontFeatures: const [
                          FontFeature.tabularFigures()
                        ])),
                  ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairoStyle(16,
                        weight: 700, color: tk.ink, height: 1.25)),
                if (showSub)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: cairoStyle(11.5, color: tk.muted, height: 1.4)),
                  ),
                if (extra != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 2), child: extra!),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: HomeProgressBar(value: progress!, tokens: tk),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// كارت الأذكار المتغيّر حسب الوقت (الكارت الأول).
class _Hint {
  final String icon;
  final String text;
  const _Hint(this.icon, this.text);
}

/// ما المهم الآن؟ أولوية: اقتراب صلاة ← الجمعة ← صيام الاثنين/الخميس ← توجيه الوقت.
_Hint _hintFor(DateTime n, NextPrayer? next) {
  if (next != null) {
    final m = next.time.difference(n).inMinutes;
    if (m >= 0 && m <= 25) {
      return _Hint(
          HomeIcons.clock,
          m <= 1
              ? 'حان وقت صلاة ${next.name} تقريبًا'
              : 'صلاة ${next.name} بعد ${toArabicDigits(m)} دقيقة');
    }
  }
  final h = n.hour;
  if (n.weekday == DateTime.friday && h >= 6 && h < 15) {
    return const _Hint(
        HomeIcons.quran, 'يوم الجمعة · سورة الكهف وكثرة الصلاة على النبي ﷺ');
  }
  if ((n.weekday == DateTime.monday || n.weekday == DateTime.thursday) &&
      h >= 3 &&
      h < 12) {
    return _Hint(HomeIcons.sparkle,
        'اليوم ${n.weekday == DateTime.monday ? 'الإثنين' : 'الخميس'} · يُستحب صيامه');
  }
  if (h >= 3 && h < 6)
    return const _Hint(HomeIcons.sun, 'بعد الفجر · ابدأ يومك بالأذكار والقرآن');
  if (h >= 6 && h < 9)
    return const _Hint(HomeIcons.sun, 'بكّر بأذكار الصباح ثم اقرأ وردك');
  if (h >= 9 && h < 12)
    return const _Hint(HomeIcons.sun, 'وقت صلاة الضحى · ركعتان أو أكثر');
  if (h >= 12 && h < 15)
    return const _Hint(HomeIcons.quran, 'خذ لك وردًا من القرآن بعد الظهر');
  if (h >= 15 && h < 19)
    return const _Hint(HomeIcons.sunset, 'أذكار المساء بعد العصر');
  if (h >= 19 && h < 21)
    return const _Hint(HomeIcons.moon, 'أذكار المساء، وراجع وردك قبل النوم');
  if (h >= 21 || h < 1)
    return const _Hint(HomeIcons.moon, 'قبل النوم · آية الكرسي والمعوذات');
  return const _Hint(
      HomeIcons.moon, 'الثلث الأخير من الليل · وقت الدعاء والاستغفار');
}

class _AzkarTimeCard extends StatelessWidget {
  final HomeTokens tk;
  final _Slot slot;
  final double progress;
  final bool compact;
  final ValueListenable<DateTime> now;
  final NextPrayer? next;
  final VoidCallback onTap;
  const _AzkarTimeCard(
      {required this.tk,
      required this.slot,
      required this.progress,
      required this.compact,
      required this.now,
      required this.next,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = switch (slot) {
      _Slot.morning => 'أذكار الصباح',
      _Slot.evening => 'أذكار المساء',
      _Slot.sleep => 'أذكار النوم',
    };
    final pct = (progress * 100).round();
    return ValueListenableBuilder<DateTime>(
      valueListenable: now,
      builder: (context, n, _) {
        final scene = heroSceneFor(n);
        final pal = HeroPalette.of(scene);
        final hint = _hintFor(n, next);
        final prefix = (slot == _Slot.morning && scene == HeroScene.dawn)
            ? 'بعد الفجر'
            : 'حان وقت';
        return PressableCard(
          onTap: onTap,
          builder: (context, pressed) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            clipBehavior: Clip.antiAlias,
            // بدون إطار دائم: الإطار كان يظهر كخط أصفر خلف الكارت. الإطار الذهبي عند الضغط فقط، فوق المحتوى.
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
            foregroundDecoration: pressed
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: tk.gold),
                  )
                : null,
            child: Stack(
              children: [
                Positioned.fill(child: HeroBackdrop(scene: scene)),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    child: LayoutBuilder(builder: (context, c) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            HomeIcon(hint.icon, size: 22, color: pal.accent),
                            const SizedBox(width: 8),
                            Flexible(
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxWidth: c.maxWidth * .74),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: pal.pill,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(hint.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: cairoStyle(11.5,
                                          weight: 600,
                                          color: pal.ink,
                                          height: 1.35)),
                                ),
                              ),
                            ),
                          ]),
                          SizedBox(
                            width: c.maxWidth * .62,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Transform.translate(
                                  offset: const Offset(0, -2),
                                  child: Text(prefix,
                                      style: cairoStyle(11.5, color: pal.sub)),
                                ),
                                const SizedBox(height: 3),
                                Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: amiriStyle(26,
                                        bold: true,
                                        color: pal.ink,
                                        height: 1.2)),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Container(
                                    height: 6,
                                    color: pal.track,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: FractionallySizedBox(
                                      widthFactor: progress.isNaN
                                          ? 0
                                          : progress.clamp(0.0, 1.0),
                                      heightFactor: 1,
                                      child: ColoredBox(color: pal.fill),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                    'أنجزت ${toArabicDigits(pct)}٪ · اضغط للمتابعة',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: cairoStyle(11.5, color: pal.sub)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          foregroundPainter: DashedBorderPainter(color: tk.gold, radius: 18),
          child: Stack(
            children: [
              const Positioned.fill(
                child:
                    CustomPaint(painter: IslamicPatternPainter(opacity: .18)),
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
                                style: cairoStyle(11.5,
                                    weight: 600, color: tk.gold)),
                            const SizedBox(height: 2),
                            Text('﴿ $text ﴾',
                                textAlign: TextAlign.center,
                                style:
                                    amiriStyle(21, color: tk.ink, height: 1.7)),
                            const SizedBox(height: 2),
                            Text(ref,
                                style: cairoStyle(11.5,
                                    weight: 600, color: tk.gold)),
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
