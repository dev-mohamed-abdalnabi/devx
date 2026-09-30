import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/dates.dart';
import '../../core/text_utils.dart';
import '../../core/prayer_times.dart';
import '../../providers/prayer_provider.dart';
import 'city_picker_screen.dart';
import 'qibla_screen.dart';
import 'tick_builder.dart';

IconData _iconFor(String id) {
  switch (id) {
    case 'fajr':
      return Icons.nights_stay_rounded;
    case 'sunrise':
      return Icons.wb_twilight_rounded;
    case 'dhuhr':
      return Icons.wb_sunny_rounded;
    case 'asr':
      return Icons.wb_cloudy_rounded;
    case 'maghrib':
      return Icons.wb_twilight_rounded;
    default:
      return Icons.bedtime_rounded;
  }
}

/// بطاقة الرئيسية: الصلاة القادمة والوقت المتبقي.
class PrayerHomeCard extends StatelessWidget {
  const PrayerHomeCard({super.key});

  void _open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const PrayerScreen()));

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PrayerProvider>();
    if (p.loading) return const SizedBox.shrink();
    final title = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

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
                      Text('الصلاة القادمة', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text('${next.name} · ${formatClock(next.time)}', style: title),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('المتبقي', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      formatCountdown(next.time.difference(now)),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

  Future<void> _gps() async {
    final err = await context.read<PrayerProvider>().useGps();
    if (!mounted || err == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  void _pickMethod(PrayerProvider p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('طريقة الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            for (final m in calcMethods)
              ListTile(
                title: Text(m.name),
                subtitle: Text(m.summary),
                trailing: m.id == p.methodId ? const Icon(Icons.check) : null,
                onTap: () {
                  p.setMethod(m.id);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PrayerProvider>();
    final scheme = Theme.of(context).colorScheme;
    final day = p.timesFor(_date);
    final isToday = dayKey(_date) == dayKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(
            tooltip: 'القبلة',
            icon: const Icon(Icons.explore_rounded),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const QiblaScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.hasLocation ? p.placeName : 'لم يُحدَّد الموقع بعد',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: p.locating ? null : _gps,
                        icon: p.locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location),
                        label: const Text('تحديد تلقائي'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const CityPickerScreen())),
                        icon: const Icon(Icons.location_city),
                        label: const Text('اختيار مدينة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!p.hasLocation)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('اختر مدينتك أو اسمح بتحديد الموقع لعرض المواقيت.',
                  textAlign: TextAlign.center),
            )
          else ...[
            const SizedBox(height: 12),
            if (isToday)
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TickBuilder(builder: (context, now) {
                    final next = p.nextPrayer(now);
                    if (next == null) return const Text('تعذّر حساب المواقيت لهذا الموقع');
                    return Column(
                      children: [
                        Text('الصلاة القادمة: ${next.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 6),
                        Text(
                          formatCountdown(next.time.difference(now)),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                        ),
                        Text('عند ${formatClock(next.time)}'),
                      ],
                    );
                  }),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                    tooltip: 'اليوم السابق',
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_right)),
                Expanded(
                  child: Column(
                    children: [
                      Text(arabicDate(_date),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(p.hijriFor(_date).format(),
                          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65))),
                    ],
                  ),
                ),
                IconButton(
                    tooltip: 'اليوم التالي',
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_left)),
              ],
            ),
            if (day == null || day.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('تعذّر حساب المواقيت لهذا الموقع في هذا اليوم.'),
              )
            else
              ..._rows(context, day, isToday ? p.nextPrayer(DateTime.now())?.id : null, scheme),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calculate_outlined),
                    title: const Text('طريقة الحساب'),
                    subtitle: Text('${p.method.name}\n${p.method.summary}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _pickMethod(p),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.filter_2_outlined),
                    title: const Text('العصر بالمذهب الحنفي'),
                    subtitle: const Text('ظل الشيء مثلاه بدل مثله'),
                    value: p.hanafi,
                    onChanged: p.setHanafi,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('تصحيح التاريخ الهجري'),
                    subtitle: const Text('لموافقة الرؤية في بلدك'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            tooltip: 'يوم أقل',
                            onPressed: () => p.setHijriAdjust(p.hijriAdjust - 1),
                            icon: const Icon(Icons.remove_circle_outline)),
                        Text(p.hijriAdjust == 0
                            ? '٠'
                            : (p.hijriAdjust > 0 ? '+' : '-') + toArabicDigits(p.hijriAdjust.abs())),
                        IconButton(
                            tooltip: 'يوم أكثر',
                            onPressed: () => p.setHijriAdjust(p.hijriAdjust + 1),
                            icon: const Icon(Icons.add_circle_outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'تُحسب المواقيت فلكيًا على جهازك بدون إنترنت، وقد تختلف دقيقة أو دقيقتين عن '
              'التقويم الرسمي في بلدك. والتاريخ الهجري بالحساب الجدولي وقد يختلف يومًا عن الرؤية.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, PrayerDay day, String? nextId, ColorScheme scheme) {
    return [
      for (final e in day.entries)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: e.id == nextId
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: Icon(_iconFor(e.id), color: e.isPrayer ? scheme.primary : scheme.secondary),
            title: Text(e.name,
                style: TextStyle(fontWeight: e.isPrayer ? FontWeight.bold : FontWeight.normal)),
            trailing: Text(formatClock(e.time),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ),
    ];
  }
}
