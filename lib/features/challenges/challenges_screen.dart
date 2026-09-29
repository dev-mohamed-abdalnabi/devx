import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../data/challenges.dart';
import '../../providers/activity_provider.dart';
import '../stats/stats_screen.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<ActivityProvider>();
    final now = DateTime.now();
    if (a.loading) return const Center(child: CircularProgressIndicator());

    final daily = a.dailyFor(now);
    final weekly = a.weeklyFor(now);
    final monthly = a.monthlyFor(now);
    final doneCount = a.dailyDone(now);
    final scheme = Theme.of(context).colorScheme;

    if (daily.isEmpty) {
      return const Center(child: Text('تعذّر تحميل التحديات'));
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('التحديات',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('هذه تحديات سلوكية للتذكير والمتابعة، وليست أحكامًا شرعية.',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65))),
          const SizedBox(height: 16),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('تقدم اليوم',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      Text('${toArabicDigits(doneCount)} / ${toArabicDigits(daily.length)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: doneCount / daily.length, minHeight: 8),
                  ),
                  const SizedBox(height: 10),
                  Text(a.streak > 0
                      ? 'أيام متواصلة: ${toArabicDigits(a.streak)}'
                      : 'ابدأ اليوم لتبدأ سلسلة الأيام المتواصلة'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Section('تحديات اليوم'),
          for (final c in daily) _Tile(c: c, a: a, now: now),
          const SizedBox(height: 16),
          _Section('تحديات الأسبوع'),
          for (final c in weekly) _Tile(c: c, a: a, now: now),
          const SizedBox(height: 16),
          _Section('هدف الشهر'),
          for (final c in monthly) _Tile(c: c, a: a, now: now),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const StatsScreen())),
            icon: const Icon(Icons.bar_chart),
            label: const Text('الإحصائيات والإنجازات'),
          ),
        ],
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
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          onTap: auto ? null : () => a.toggleManual(c, now),
          leading: Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(auto ? '${c.catName} · يُحتسب تلقائيًا' : c.catName),
              if (showBar) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(value: (prog / c.goal).clamp(0.0, 1.0).toDouble()),
                const SizedBox(height: 2),
                Text('${toArabicDigits(prog > c.goal ? c.goal : prog)} / ${toArabicDigits(c.goal)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
          trailing: done ? const Text('تم') : null,
        ),
      ),
    );
  }
}
