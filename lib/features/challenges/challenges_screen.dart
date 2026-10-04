import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../data/challenges.dart';
import '../../providers/activity_provider.dart';
import '../../widgets/app_ui.dart';
import '../stats/stats_screen.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<ActivityProvider>();
    final now = DateTime.now();
    if (a.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final daily = a.dailyFor(now);
    final weekly = a.weeklyFor(now);
    final monthly = a.monthlyFor(now);
    final doneCount = a.dailyDone(now);
    final scheme = Theme.of(context).colorScheme;

    if (daily.isEmpty) {
      return const Scaffold(body: AppEmptyState(icon: Icons.task_alt_rounded, title: 'لا توجد تحديات اليوم'));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('التحديات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const AppSectionHeader(title: 'تحدياتك اليومية', subtitle: 'للتذكير والمتابعة، وليست أحكامًا شرعية'),
            const SizedBox(height: 16),
            AppCard(
              color: scheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppIconBadge(icon: Icons.emoji_events_rounded),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('تقدم اليوم', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                      Text('${toArabicDigits(doneCount)} / ${toArabicDigits(daily.length)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppProgressBar(value: doneCount / daily.length, color: scheme.primary),
                  const SizedBox(height: 10),
                  Text(a.streak > 0 ? 'أيام متواصلة: ${toArabicDigits(a.streak)}' : 'ابدأ اليوم لتبدأ سلسلة الأيام المتواصلة'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _Section('تحديات اليوم'),
            for (final c in daily) _Tile(c: c, a: a, now: now),
            const SizedBox(height: 14),
            const _Section('تحديات الأسبوع'),
            for (final c in weekly) _Tile(c: c, a: a, now: now),
            const SizedBox(height: 14),
            const _Section('هدف الشهر'),
            for (final c in monthly) _Tile(c: c, a: a, now: now),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
              icon: const Icon(Icons.bar_chart_rounded),
              label: const Text('الإحصائيات والإنجازات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _Tile extends StatelessWidget {
  final Challenge c;
  final ActivityProvider a;
  final DateTime now;
  const _Tile({required this.c, required this.a, required this.now});

  @override
  Widget build(BuildContext context) {
    final done = a.isDone(c, now);
    final auto = c.auto != null;
    final prog = a.progressOf(c, now);
    final showBar = auto && c.goal > 1;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: auto ? null : () => a.toggleManual(c, now),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(auto ? '${c.catName} · يُحتسب تلقائيًا' : c.catName),
                  if (showBar) ...[
                    const SizedBox(height: 7),
                    AppProgressBar(value: prog / c.goal),
                    const SizedBox(height: 3),
                    Text('${toArabicDigits(prog > c.goal ? c.goal : prog)} / ${toArabicDigits(c.goal)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (done) const Icon(Icons.check_rounded, color: Colors.green),
          ],
        ),
      ),
    );
  }
}
