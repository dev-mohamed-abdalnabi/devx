import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../providers/activity_provider.dart';
import '../../providers/quran_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<ActivityProvider>();
    final q = context.watch<QuranProvider>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final week = a.lastDays(7);
    final month = a.monthDays();
    const dayLetters = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']; // الإثنين ... الأحد
    final labels = week.map((d) => dayLetters[d.weekday - 1]).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات والإنجازات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المستوى ${toArabicDigits(a.level)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: a.xpInLevel / ActivityProvider.xpPerLevel, minHeight: 8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${toArabicDigits(a.xpInLevel)} من ${toArabicDigits(ActivityProvider.xpPerLevel)} نقطة للمستوى التالي'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Stat('الأيام المتواصلة', a.streak)),
              const SizedBox(width: 12),
              Expanded(child: _Stat('أطول سلسلة', a.bestStreak)),
            ]),
            const SizedBox(height: 20),
            const _Title('اليوم'),
            Row(children: [
              Expanded(child: _Stat('تسبيحات', a.tasbeehOn(now))),
              const SizedBox(width: 12),
              Expanded(child: _Stat('صفحات القرآن', a.pagesOn(now))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Stat('نقرات الأذكار', a.today.zikr)),
              const SizedBox(width: 12),
              Expanded(child: _Stat('تحديات مكتملة', a.challengesOn(now))),
            ]),
            const SizedBox(height: 20),
            const _Title('آخر ٧ أيام'),
            _Bars(title: 'التسبيح', values: week.map(a.tasbeehOn).toList(), labels: labels),
            _Bars(title: 'صفحات القرآن', values: week.map(a.pagesOn).toList(), labels: labels),
            _Bars(title: 'التحديات', values: week.map(a.challengesOn).toList(), labels: labels),
            const SizedBox(height: 12),
            const _Title('هذا الشهر'),
            Row(children: [
              Expanded(child: _Stat('تسبيحات', a.sumOver(month, (l) => l.tasbeehTotal))),
              const SizedBox(width: 12),
              Expanded(child: _Stat('صفحات', a.sumOver(month, (l) => l.pages.length))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Stat('تحديات يومية', a.challengesInMonth())),
              const SizedBox(width: 12),
              Expanded(child: _Stat('نقرات الأذكار', a.sumOver(month, (l) => l.zikr))),
            ]),
            const SizedBox(height: 20),
            const _Title('ختم القرآن'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: q.khatmaProgress, minHeight: 8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'قرأت ${toArabicDigits(q.readPages.length)} صفحة من ${toArabicDigits(q.data?.pageCount ?? 604)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _Title('الإنجازات'),
            for (final b in a.badges)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Icon(b.earned ? Icons.emoji_events : Icons.lock_outline,
                        color: b.earned ? scheme.secondary : null),
                    title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(b.desc),
                    trailing: Text(b.earned
                        ? 'مكتسب'
                        : '${toArabicDigits(math.min(b.current, b.target))}/${toArabicDigits(b.target)}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          child: Column(
            children: [
              Text(toArabicDigits(value),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _Bars extends StatelessWidget {
  final String title;
  final List<int> values;
  final List<String> labels;
  const _Bars({required this.title, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = values.fold<int>(1, math.max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < values.length; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(values[i] > 0 ? toArabicDigits(values[i]) : '',
                                style: Theme.of(context).textTheme.labelSmall),
                            const SizedBox(height: 2),
                            Container(
                              height: math.max(3.0, 60.0 * values[i] / maxV),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: values[i] > 0
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(labels[i], style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
