import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/dates.dart';
import '../../core/text_utils.dart';
import '../../core/prayer_times.dart';
import '../../providers/prayer_provider.dart';
import 'city_picker_screen.dart';
import 'prayer_settings_screen.dart';
import 'qibla_screen.dart';
import 'tick_builder.dart';
import '../../core/home_tokens.dart';
import '../home/home_art.dart';

/// بطاقة الرئيسية: الصلاة القادمة والوقت المتبقي.
class PrayerHomeCard extends StatelessWidget {
  const PrayerHomeCard({super.key});

  void _open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const PrayerScreen()));

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PrayerProvider>();
    if (p.loading) return const SizedBox.shrink();
    final title = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    if (!p.hasLocation) {
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مواقيت الصلاة', style: title),
                      const SizedBox(height: 4),
                      const Text('حدد موقعك لعرض الصلاة القادمة'),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TickBuilder(builder: (context, now) {
            final next = context.read<PrayerProvider>().nextPrayer(now);
            if (next == null) {
              return Text('تعذّر حساب المواقيت لهذا الموقع', style: title);
            }
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الصلاة القادمة',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text('${next.name} · ${formatClock(next.time)}',
                          style: title),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('المتبقي',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      formatCountdown(next.time.difference(now)),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  DateTime _date = DateTime.now();

  void _shift(int days) => setState(() => _date = addDays(_date, days));

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _gps() async {
    final err = await context.read<PrayerProvider>().useGps();
    if (!mounted || err == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  void _settings() => _push(const PrayerSettingsScreen());

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PrayerProvider>();
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مواقيت الصلاة'),
          actions: [
            IconButton(
              tooltip: 'القبلة',
              icon: const Icon(Icons.explore_outlined),
              onPressed: () => _push(const QiblaScreen()),
            ),
            IconButton(
              tooltip: 'الإعدادات',
              icon: const Icon(Icons.tune_rounded),
              onPressed: _settings,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
          children: [
            _locationRow(p, tk),
            const SizedBox(height: 10),
            if (!p.hasLocation)
              _noLocation(tk)
            else
              TickBuilder(builder: (context, now) => _content(p, tk, now)),
          ],
        ),
      ),
    );
  }

  Widget _locationRow(PrayerProvider p, HomeTokens tk) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _push(const CityPickerScreen()),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: tk.card,
                border: Border.all(color: tk.line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: tk.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.hasLocation ? p.placeName : 'اختر مدينتك',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairoStyle(13, weight: 600, color: tk.ink),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 18, color: tk.muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: p.locating ? null : _gps,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tk.card,
              border: Border.all(color: tk.line),
              shape: BoxShape.circle,
            ),
            child: p.locating
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.my_location, size: 19, color: tk.gold),
          ),
        ),
      ],
    );
  }

  Widget _noLocation(HomeTokens tk) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tk.card,
        border: Border.all(color: tk.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          HomeIcon(HomeIcons.clock, size: 34, color: tk.gold),
          const SizedBox(height: 10),
          Text('حدّد موقعك لعرض المواقيت',
              style: cairoStyle(16, weight: 700, color: tk.ink)),
          const SizedBox(height: 4),
          Text('اختر مدينتك أو اسمح بالتحديد التلقائي',
              style: cairoStyle(12.5, color: tk.muted)),
        ],
      ),
    );
  }

  Widget _content(PrayerProvider p, HomeTokens tk, DateTime now) {
    final isToday = dayKey(_date) == dayKey(now);
    final day = p.timesFor(_date);
    final next = isToday ? p.nextPrayer(now) : null;
    final friday = _date.weekday == DateTime.friday;
    final canTick =
        !_date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isToday && next != null) ...[
          _Hero(tk: tk, p: p, now: now, next: next),
          const SizedBox(height: 10),
        ],
        _dateBar(p, tk, friday),
        const SizedBox(height: 8),
        if (day == null || day.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('تعذّر حساب المواقيت لهذا الموقع في هذا اليوم.',
                style: cairoStyle(13, color: tk.muted)),
          )
        else ...[
          for (final e in day.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PrayerRow(
                tk: tk,
                entry: e,
                isNext: next?.id == e.id,
                isPast: isToday && e.time.isBefore(now) && next?.id != e.id,
                done: e.isPrayer && p.isDone(_date, e.id),
                canTick: e.isPrayer && canTick,
                badge: friday && e.id == 'dhuhr' ? 'الجمعة' : null,
                muted: e.isPrayer && p.modeOf(e.id) == 2,
                onTick: () => p.toggleDone(_date, e.id),
              ),
            ),
          const SizedBox(height: 2),
          _summary(p, tk, now),
          const SizedBox(height: 10),
          _night(p, tk, day),
        ],
      ],
    );
  }

  Widget _dateBar(PrayerProvider p, HomeTokens tk, bool friday) {
    Widget arrow(IconData i, VoidCallback f, String tip) =>
        IconButton(tooltip: tip, onPressed: f, icon: Icon(i, color: tk.muted));
    return Row(
      children: [
        arrow(Icons.chevron_right, () => _shift(-1), 'اليوم السابق'),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _date = DateTime.now()),
            child: Column(
              children: [
                Text(arabicDate(_date),
                    textAlign: TextAlign.center,
                    style: cairoStyle(14, weight: 700, color: tk.ink)),
                Text(
                    '${p.hijriFor(_date).format()}${friday ? '  ·  يوم الجمعة' : ''}',
                    textAlign: TextAlign.center,
                    style: cairoStyle(12, color: tk.muted)),
              ],
            ),
          ),
        ),
        arrow(Icons.chevron_left, () => _shift(1), 'اليوم التالي'),
      ],
    );
  }

  Widget _summary(PrayerProvider p, HomeTokens tk, DateTime now) {
    final n = p.doneCount(_date);
    final streak = p.fullDaysStreak(now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tk.card,
        border: Border.all(color: tk.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HomeIcon(HomeIcons.trophy, size: 20, color: tk.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text('صلوات اليوم · ${toArabicDigits(n)} / ٥',
                    style: cairoStyle(14, weight: 700, color: tk.ink)),
              ),
              Text('أيام متواصلة: ${toArabicDigits(streak)}',
                  style: cairoStyle(11.5, color: tk.muted)),
            ],
          ),
          const SizedBox(height: 8),
          HomeProgressBar(value: n / 5, tokens: tk),
        ],
      ),
    );
  }

  Widget _night(PrayerProvider p, HomeTokens tk, PrayerDay day) {
    final maghrib = day.maghrib;
    final fajrNext = p.timesFor(addDays(_date, 1))?.fajr;
    if (maghrib == null || fajrNext == null) return const SizedBox.shrink();
    final night = fajrNext.difference(maghrib);
    final mid = maghrib.add(night ~/ 2);
    final third = maghrib.add(night * 2 ~/ 3);
    Widget cell(String title, DateTime t) => Expanded(
          child: Column(
            children: [
              Text(title, style: cairoStyle(11.5, color: tk.muted)),
              const SizedBox(height: 2),
              Text(formatClock(t),
                  style: cairoStyle(16, weight: 700, color: tk.ink)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: tk.card,
        border: Border.all(color: tk.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          cell('منتصف الليل', mid),
          Container(width: 1, height: 30, color: tk.line),
          cell('الثلث الأخير', third),
        ],
      ),
    );
  }
}

/// بطاقة الصلاة القادمة (نفس أسلوب كارت الأذكار في الرئيسية).
class _Hero extends StatelessWidget {
  final HomeTokens tk;
  final PrayerProvider p;
  final DateTime now;
  final NextPrayer next;
  const _Hero(
      {required this.tk,
      required this.p,
      required this.now,
      required this.next});

  /// نسبة ما مضى بين الصلاة السابقة والقادمة.
  double get _progress {
    final today = p.timesFor(now);
    DateTime? prev;
    for (final e in today?.prayers ?? const <PrayerEntry>[]) {
      if (!e.time.isAfter(now)) prev = e.time;
    }
    prev ??= p.timesFor(DateTime(now.year, now.month, now.day - 1))?.isha;
    if (prev == null) return 0;
    final total = next.time.difference(prev).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(prev).inSeconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final soft = tk.mintInk.withValues(alpha: .75);
    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tk.mint,
        borderRadius: BorderRadius.circular(18),
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
              child: MosqueArt(width: box.maxWidth * .42, tokens: tk),
            ),
            Positioned.fill(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: box.maxWidth * .62,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: box.maxWidth * .62,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الصلاة القادمة',
                                style: cairoStyle(12, color: soft)),
                            Text(next.name,
                                style: amiriStyle(30,
                                    bold: true,
                                    color: tk.mintInk,
                                    height: 1.2)),
                            Text('عند ${formatClock(next.time)}',
                                style: cairoStyle(13, color: soft)),
                            const SizedBox(height: 4),
                            Text(
                              formatCountdown(next.time.difference(now)),
                              textDirection: TextDirection.ltr,
                              style:
                                  cairoStyle(32, weight: 700, color: tk.mintInk)
                                      .copyWith(fontFeatures: const [
                                FontFeature.tabularFigures()
                              ]),
                            ),
                            const SizedBox(height: 6),
                            HomeProgressBar(value: _progress, tokens: tk),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// صف صلاة واحد.
class _PrayerRow extends StatelessWidget {
  final HomeTokens tk;
  final PrayerEntry entry;
  final bool isNext, isPast, done, canTick;
  final String? badge;
  final bool muted;
  final VoidCallback onTick;
  const _PrayerRow({
    required this.tk,
    required this.entry,
    required this.isNext,
    required this.isPast,
    required this.done,
    required this.canTick,
    required this.onTick,
    this.badge,
    this.muted = false,
  });

  String get _icon {
    switch (entry.id) {
      case 'fajr':
      case 'isha':
        return HomeIcons.moon;
      case 'sunrise':
      case 'maghrib':
        return HomeIcons.sunset;
      default:
        return HomeIcons.sun;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isPast && !isNext ? .72 : 1,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isNext ? tk.mint : tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isNext ? tk.gold : tk.line),
        ),
        child: Row(
          children: [
            HomeIcon(_icon,
                size: 24, color: entry.isPrayer ? tk.gold : tk.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(entry.name,
                      style: cairoStyle(16,
                          weight: entry.isPrayer ? 700 : 400,
                          color: isNext ? tk.mintInk : tk.ink)),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: tk.gold),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(badge!,
                          style: cairoStyle(11, weight: 600, color: tk.gold)),
                    ),
                  ],
                ],
              ),
            ),
            if (muted)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Icon(Icons.notifications_off_outlined,
                    size: 15, color: tk.muted),
              ),
            Text(formatClock(entry.time),
                style: cairoStyle(17,
                    weight: 700, color: isNext ? tk.mintInk : tk.ink)),
            if (entry.isPrayer) ...[
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: canTick ? onTick : null,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? tk.leaf : Colors.transparent,
                    border:
                        Border.all(color: done ? tk.leaf : tk.line, width: 1.5),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
