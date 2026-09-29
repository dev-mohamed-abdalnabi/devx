import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../models/zikr.dart';
import '../../providers/activity_provider.dart';
import '../../providers/azkar_provider.dart';
import '../../providers/prayer_provider.dart';
import '../../providers/quran_provider.dart';
import '../../screens/zikr_list_screen.dart';
import '../prayer/prayer_screen.dart';
import '../quran/quran_home_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';

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
    final daily = activity.dailyFor(now);
    final scheme = Theme.of(context).colorScheme;

    final timeCategory = _categoryForTime(azkar, now);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(greetingFor(now),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(arabicDate(now),
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65))),
          const SizedBox(height: 2),
          Text(prayer.hijriFor(now).format(),
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65))),
          const SizedBox(height: 20),
          const PrayerHomeCard(),
          const SizedBox(height: 12),
          if (timeCategory != null) ...[
            _AzkarNowCard(category: timeCategory, provider: azkar),
            const SizedBox(height: 12),
          ],
          _QuranCard(quran: quran, onStart: () => onSwitchTab(1)),
          const SizedBox(height: 12),
          if (daily.isNotEmpty) ...[
            _ChallengesCard(
              done: activity.dailyDone(now),
              total: daily.length,
              streak: activity.streak,
              onTap: () => onSwitchTab(3),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _Shortcut(
                  icon: Icons.menu_book_outlined,
                  label: 'القرآن',
                  onTap: () => onSwitchTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Shortcut(
                  icon: Icons.auto_awesome_outlined,
                  label: 'الأذكار',
                  onTap: () => onSwitchTab(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Shortcut(
                  icon: Icons.touch_app_outlined,
                  label: 'التسبيح',
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const TasbeehScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  AzkarCategory? _categoryForTime(AzkarProvider p, DateTime now) {
    String? id;
    if (now.hour >= 3 && now.hour < 12) {
      id = 'morning';
    } else if (now.hour >= 15 && now.hour < 20) {
      id = 'evening';
    } else if (now.hour >= 21 || now.hour < 3) {
      id = 'sleep';
    }
    if (id == null) return null;
    for (final c in p.categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class _AzkarNowCard extends StatelessWidget {
  final AzkarCategory category;
  final AzkarProvider provider;
  const _AzkarNowCard({required this.category, required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = provider.categoryProgress(category.id);
    final done = progress >= 1;
    return Card(
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ZikrListScreen(categoryId: category.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('حان وقت', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 2),
              Text(category.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
              const SizedBox(height: 8),
              Text(done
                  ? 'أتممتها، تقبّل الله منك'
                  : 'أنجزت ${toArabicDigits((progress * 100).round())}٪ · اضغط للمتابعة'),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuranCard extends StatelessWidget {
  final QuranProvider quran;
  final VoidCallback onStart;
  const _QuranCard({required this.quran, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final data = quran.data;
    if (quran.loading || data == null) return const SizedBox.shrink();

    final page = quran.lastPage.clamp(1, data.pageCount);
    final first = data.byPage[page]?.first;
    final surahName = first == null ? '' : data.surahOf(first.surah).name;
    final started = quran.hasStartedReading;
    final read = quran.readPages.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => started ? openReader(context, page) : onStart(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(started ? 'تابع القراءة' : 'ابدأ القراءة',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(started
                  ? 'سورة $surahName · صفحة ${toArabicDigits(page)}'
                  : 'افتح المصحف من الفاتحة أو اختر السورة التي تريد'),
              if (read > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: quran.khatmaProgress, minHeight: 6),
                ),
                const SizedBox(height: 6),
                Text('قرأت ${toArabicDigits(read)} من ${toArabicDigits(data.pageCount)} صفحة',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengesCard extends StatelessWidget {
  final int done;
  final int total;
  final int streak;
  final VoidCallback onTap;
  const _ChallengesCard(
      {required this.done, required this.total, required this.streak, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('تحديات اليوم',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Text('${toArabicDigits(done)} / ${toArabicDigits(total)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: done / total, minHeight: 6),
              ),
              if (streak > 0) ...[
                const SizedBox(height: 8),
                Text('أيام متواصلة: ${toArabicDigits(streak)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
