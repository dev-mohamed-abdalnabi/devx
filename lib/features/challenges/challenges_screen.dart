import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/challenges.dart';
import '../../providers/activity_provider.dart';
import '../../screens/categories_screen.dart';
import '../../widgets/app_ui.dart' hide IslamicPatternPainter;
import '../../widgets/page_kit.dart';
import '../home/home_art.dart';
import '../quran/quran_home_screen.dart';
import '../stats/stats_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';

/// تصميم التحديات مبني على مبادئ من علم النفس السلوكي:
///  • تأثير تدرّج الهدف (Goal-Gradient): كلما اقتربت من الإتمام زاد الدافع، فنُظهر «باقي القليل».
///  • العادات الصغيرة (Tiny Habits): نوجّه المستخدم لأسهل/أقرب تحدٍّ ليبدأ بزخم.
///  • تجنّب الخسارة بلا جلد للذات: السلسلة تُحفَظ بتنبيه لطيف، وإن انقطعت نُبرز «أفضل سلسلة» ونرحّب بالعودة
///    (الشعور بالفشل بعد الانقطاع هو أكبر سبب للتوقف).
///  • التعزيز الفوري: لمسة اهتزاز + رسالة تشجيع + حلقة تتحرك عند كل إنجاز.
///  • الرؤية الأسبوعية: شريط الأسبوع يجعل الاستمرارية مرئية.
///  • المعنى الداخلي لا المكافأة الخارجية: النقاط ثانوية، والخطاب مرتبط بمعنى الدوام (حديث «أدومها وإن قل»).
const _dayInitial = <int, String>{
  6: 'س',
  7: 'ح',
  1: 'ن',
  2: 'ث',
  3: 'ر',
  4: 'خ',
  5: 'ج',
};

IconData _catIcon(String cat) {
  switch (cat) {
    case 'quran':
      return Icons.menu_book_rounded;
    case 'dhikr':
      return Icons.auto_awesome_rounded;
    case 'prayer':
      return Icons.mosque_rounded;
    case 'worship':
      return Icons.self_improvement_rounded;
    case 'good':
      return Icons.volunteer_activism_rounded;
    case 'manners':
      return Icons.diversity_1_rounded;
    case 'habits':
      return Icons.wb_twilight_rounded;
    case 'self':
      return Icons.psychology_alt_rounded;
    default:
      return Icons.task_alt_rounded;
  }
}

int _xpFor(String period) =>
    period == 'week' ? 25 : (period == 'month' ? 60 : 10);

/// أين يذهب المستخدم لإنجاز هذا التحدي التلقائي؟ (تقليل الاحتكاك = زيادة الإنجاز)
Widget? _destinationFor(Challenge c) {
  final a = c.auto;
  if (a == null) return null;
  if (a == 'pages') return const QuranHomeScreen();
  if (a.startsWith('tasbeeh:')) return const TasbeehScreen();
  if (a.startsWith('azkar:')) return const CategoriesScreen();
  return null;
}

double _ratio(ActivityProvider a, Challenge c, DateTime now) {
  if (c.auto == null) return 0;
  return (a.progressOf(c, now) / c.goal).clamp(0.0, 1.0);
}

/// «خطوتك التالية»: أقرب تحدٍّ غير مكتمل (الأعلى تقدمًا، وإلا الأسهل).
Challenge? _nextStep(ActivityProvider a, List<Challenge> daily, DateTime now) {
  final open = daily.where((c) => !a.isDone(c, now)).toList();
  if (open.isEmpty) return null;
  open.sort((x, y) {
    final r = _ratio(a, y, now).compareTo(_ratio(a, x, now));
    if (r != 0) return r;
    // الأصغر هدفًا أولًا، واليدوي (خطوة واحدة) قبل التلقائي الكبير.
    return x.goal.compareTo(y.goal);
  });
  return open.first;
}

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<ActivityProvider>();
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final now = DateTime.now();
    if (a.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final daily = a.dailyFor(now);
    final weekly = a.weeklyFor(now);
    final monthly = a.monthlyFor(now);

    if (daily.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('التحديات')),
        body: const AppEmptyState(
            icon: Icons.task_alt_rounded, title: 'لا توجد تحديات اليوم'),
      );
    }

    final done = a.dailyDone(now);
    final next = _nextStep(a, daily, now);
    final weekEnd = addDays(weekStart(now), 7);
    final weekDaysLeft =
        weekEnd.difference(DateTime(now.year, now.month, now.day)).inDays;
    final monthDaysLeft =
        DateTime(now.year, now.month + 1, 0).day - now.day + 1;

    return Scaffold(
      appBar: AppBar(title: const Text('التحديات')),
      body: MediaQuery(
        data:
            mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _ProgressHero(a: a, done: done, total: daily.length, now: now),
              const SizedBox(height: 22),
              KitSectionTitle(
                text: 'تحديات اليوم',
                caption: done == daily.length
                    ? 'أتممتها كلها، تقبّل الله منك'
                    : 'ابدأ بما تستطيع، فالخطوة الصغيرة تكفي',
              ),
              for (final c in daily)
                _ChallengeCard(
                  c: c,
                  a: a,
                  now: now,
                  highlight: next != null && next.id == c.id,
                  total: daily.length,
                ),
              const SizedBox(height: 14),
              KitSectionTitle(
                text: 'تحديات الأسبوع',
                caption: weekDaysLeft <= 1
                    ? 'آخر يوم في الأسبوع'
                    : 'متبقٍ ${toArabicDigits(weekDaysLeft)} أيام',
              ),
              for (final c in weekly)
                _ChallengeCard(c: c, a: a, now: now, total: daily.length),
              const SizedBox(height: 14),
              KitSectionTitle(
                text: 'أهداف الشهر',
                caption: 'متبقٍ ${toArabicDigits(monthDaysLeft)} يومًا',
              ),
              for (final c in monthly)
                _ChallengeCard(c: c, a: a, now: now, total: daily.length),
              const SizedBox(height: 14),
              _LevelTile(a: a),
              const SizedBox(height: 22),
              _Quote(tk: tk),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── الهيرو ─────────────────────────

class _ProgressHero extends StatelessWidget {
  final ActivityProvider a;
  final int done, total;
  final DateTime now;
  const _ProgressHero(
      {required this.a,
      required this.done,
      required this.total,
      required this.now});

  ({String title, String sub}) _message() {
    final streak = a.streak;
    final best = a.bestStreak;
    final todayActive = a.activeDates.contains(dayKey(now));
    if (done >= total) {
      return (
        title: 'ما شاء الله، أتممت يومك',
        sub: 'تقبّل الله منك. عُد غدًا لتزيد سلسلتك.'
      );
    }
    if (done == total - 1) {
      return (
        title: 'باقي تحدٍّ واحد فقط',
        sub: 'أنت على بُعد خطوة من إتمام يومك.'
      );
    }
    if (done == 0) {
      if (streak > 0 && !todayActive) {
        return (
          title: 'حافظ على سلسلتك',
          sub:
              'سلسلتك ${toArabicDigits(streak)} ${streak == 1 ? 'يوم' : 'أيام'}، تحدٍّ واحد يكفي لتبقى.'
        );
      }
      if (streak == 0 && best > 0) {
        return (
          title: 'يوم جديد وبداية جديدة',
          sub:
              'العودة أجمل من الانقطاع. أفضل سلسلة لك ${toArabicDigits(best)} ${best == 1 ? 'يوم' : 'أيام'}، فلنتخطّها.'
        );
      }
      return (
        title: 'ابدأ بأسهل تحدٍّ',
        sub: 'خطوة صغيرة اليوم تصنع عادة دائمة.'
      );
    }
    return (
      title: 'أحسنت، واصل',
      sub:
          'أنجزت ${toArabicDigits(done)} من ${toArabicDigits(total)}. الدوام خيرٌ من الكثرة.'
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final msg = _message();
    final active = a.activeDates;
    final start = weekStart(now);
    final today = DateTime(now.year, now.month, now.day);
    final value = total == 0 ? 0.0 : done / total;

    // نفس بطاقة الأذكار: خلفية نعناعية + نقش إسلامي + مسجد.
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: tk.mint,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: IslamicPatternPainter(opacity: .22)),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: MosqueArt(width: 96, tokens: tk),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: value),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => CustomPaint(
                            painter: _RingPainter(v,
                                complete: done >= total,
                                track: tk.mintInk.withValues(alpha: .14),
                                arc: tk.gold,
                                doneArc: tk.leaf),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(toArabicDigits(done),
                                      style: cairoStyle(28,
                                          weight: 700,
                                          color: tk.mintInk,
                                          height: 1.1)),
                                  Text('من ${toArabicDigits(total)}',
                                      style: cairoStyle(12,
                                          color: tk.mintInk
                                              .withValues(alpha: .75))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg.title,
                                style: amiriStyle(21,
                                    bold: true,
                                    color: tk.mintInk,
                                    height: 1.35)),
                            const SizedBox(height: 4),
                            Text(msg.sub,
                                style: cairoStyle(12.5,
                                    color: tk.mintInk.withValues(alpha: .8),
                                    height: 1.65)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: tk.card.withValues(alpha: .85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tk.line),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: _WeekDot(
                              letter: _dayInitial[addDays(start, i).weekday]!,
                              active:
                                  active.contains(dayKey(addDays(start, i))),
                              isToday: addDays(start, i) == today,
                              future: addDays(start, i).isAfter(today),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          size: 18, color: tk.gold),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          a.streak > 0
                              ? '${toArabicDigits(a.streak)} ${a.streak == 1 ? 'يوم متواصل' : 'أيام متواصلة'}'
                              : 'ابدأ سلسلتك اليوم',
                          style: cairoStyle(13, weight: 700, color: tk.mintInk),
                        ),
                      ),
                      if (a.bestStreak > 0)
                        Text('أفضل سلسلة ${toArabicDigits(a.bestStreak)}',
                            style: cairoStyle(12,
                                color: tk.mintInk.withValues(alpha: .75))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final bool complete;
  final Color track, arc, doneArc;
  const _RingPainter(this.value,
      {required this.complete,
      required this.track,
      required this.arc,
      required this.doneArc});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = complete ? doneArc : arc;
    canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * value.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.complete != complete ||
      old.track != track ||
      old.arc != arc;
}

class _WeekDot extends StatelessWidget {
  final String letter;
  final bool active, isToday, future;
  const _WeekDot(
      {required this.letter,
      required this.active,
      required this.isToday,
      required this.future});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? tk.gold : Colors.transparent,
            border: Border.all(
              color: isToday
                  ? tk.gold
                  : tk.line.withValues(alpha: future ? .6 : 1),
              width: isToday ? 1.8 : 1,
            ),
          ),
          child: active
              ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(letter,
            style: cairoStyle(11.5,
                weight: isToday ? 700 : 400,
                color: isToday ? tk.gold : tk.muted)),
      ],
    );
  }
}

// ───────────────────────── كرت التحدي ─────────────────────────

class _ChallengeCard extends StatelessWidget {
  final Challenge c;
  final ActivityProvider a;
  final DateTime now;
  final bool highlight;
  final int total; // عدد تحديات اليوم (لرسالة الإتمام)
  const _ChallengeCard({
    required this.c,
    required this.a,
    required this.now,
    required this.total,
    this.highlight = false,
  });

  void _onTap(BuildContext context) {
    final done = a.isDone(c, now);
    if (c.auto == null) {
      a.toggleManual(c, now);
      if (!done) {
        HapticFeedback.mediumImpact();
        if (c.period == 'day' && a.dailyDone(now) == total) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
                content:
                    Text('ما شاء الله! أتممت تحديات اليوم، تقبّل الله منك.')));
        }
      } else {
        HapticFeedback.selectionClick();
      }
      return;
    }
    if (done) return;
    final dest = _destinationFor(c);
    if (dest != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => dest));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final done = a.isDone(c, now);
    final auto = c.auto != null;
    final prog = a.progressOf(c, now);
    final ratio = auto ? (prog / c.goal).clamp(0.0, 1.0) : (done ? 1.0 : 0.0);
    final showBar = auto && c.goal > 1;
    final left = c.goal - prog;

    String? hint;
    if (!done && auto && c.goal > 1 && prog > 0) {
      hint = left <= (c.goal * 0.25).ceil()
          ? 'اقتربت! باقي ${toArabicDigits(left)}'
          : 'باقي ${toArabicDigits(left)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KitCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        onTap: () => _onTap(context),
        color: done ? tk.mint.withValues(alpha: .55) : tk.card,
        borderColor: highlight && !done
            ? tk.gold
            : (done ? tk.leaf.withValues(alpha: .5) : tk.line),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (highlight && !done)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 15, color: tk.gold),
                    const SizedBox(width: 5),
                    Text('خطوتك التالية',
                        style: cairoStyle(12, weight: 700, color: tk.gold)),
                  ],
                ),
              ),
            Row(
              children: [
                _CheckRing(done: done, ratio: ratio, auto: auto),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title,
                          style: cairoStyle(14.5,
                              weight: 700,
                              color: done ? tk.muted : tk.ink,
                              height: 1.5)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(_catIcon(c.cat), size: 14, color: tk.muted),
                          const SizedBox(width: 4),
                          Text(c.catName,
                              style: cairoStyle(11.5, color: tk.muted)),
                          if (auto) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.bolt_rounded, size: 14, color: tk.gold),
                            Text('تلقائي',
                                style: cairoStyle(11.5, color: tk.muted)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (done)
                  Icon(Icons.check_circle_rounded, color: tk.leaf, size: 22)
                else if (auto && _destinationFor(c) != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tk.mint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(prog > 0 ? 'أكمل' : 'ابدأ',
                        style:
                            cairoStyle(12.5, weight: 700, color: tk.mintInk)),
                  )
                else
                  Text('+${toArabicDigits(_xpFor(c.period))}',
                      style: cairoStyle(12, weight: 600, color: tk.muted)),
              ],
            ),
            if (showBar) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 7,
                    color: done ? tk.leaf : tk.gold,
                    backgroundColor: tk.line,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(
                      '${toArabicDigits(prog > c.goal ? c.goal : prog)} / ${toArabicDigits(c.goal)}',
                      style: cairoStyle(11.5, color: tk.muted)),
                  const Spacer(),
                  if (hint != null)
                    Text(hint,
                        style: cairoStyle(11.5, weight: 700, color: tk.gold)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckRing extends StatelessWidget {
  final bool done, auto;
  final double ratio;
  const _CheckRing(
      {required this.done, required this.ratio, required this.auto});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: done ? 32 : 28,
            height: done ? 32 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? tk.leaf : Colors.transparent,
              border: Border.all(color: done ? tk.leaf : tk.line, width: 2),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: done ? 1 : 0,
              child: const Icon(Icons.check_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
          if (!done && auto && ratio > 0)
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 3,
                color: tk.gold,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── المستوى والاقتباس ─────────────────────────

class _LevelTile extends StatelessWidget {
  final ActivityProvider a;
  const _LevelTile({required this.a});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return KitCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const StatsScreen())),
      child: Row(
        children: [
          const KitIcon(icon: Icons.bar_chart_rounded, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('المستوى ${toArabicDigits(a.level)}',
                        style: cairoStyle(14.5, weight: 700, color: tk.ink)),
                    const Spacer(),
                    Text(
                        '${toArabicDigits(a.xpInLevel)} / ${toArabicDigits(ActivityProvider.xpPerLevel)}',
                        style: cairoStyle(11.5, color: tk.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: a.xpInLevel / ActivityProvider.xpPerLevel,
                    minHeight: 6,
                    color: tk.gold,
                    backgroundColor: tk.line,
                  ),
                ),
                const SizedBox(height: 6),
                Text('الإحصائيات والإنجازات',
                    style: cairoStyle(12, weight: 600, color: tk.mintInk)),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: tk.gold, size: 26),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  final HomeTokens tk;
  const _Quote({required this.tk});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'أَحَبُّ الأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ',
          textAlign: TextAlign.center,
          style: amiriStyle(20, color: tk.ink, height: 1.9),
        ),
        Text('متفق عليه', style: cairoStyle(11.5, color: tk.muted)),
        const SizedBox(height: 10),
        Text('التحديات للتذكير والمتابعة، وليست أحكامًا شرعية',
            textAlign: TextAlign.center,
            style: cairoStyle(11.5, color: tk.muted)),
      ],
    );
  }
}
