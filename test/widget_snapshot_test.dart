import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/core/daily_ayah.dart';
import 'package:azkar_app/core/prayer_times.dart';
import 'package:azkar_app/core/widget_snapshot.dart';
import 'package:azkar_app/data/quran_data.dart';

void main() {
  final ayahs = [
    for (var i = 1; i <= 50; i++) Ayah(1, i, 'آية رقم $i', 1, 1, 1, false),
    Ayah(2, 1, 'ا' * 200, 1, 2, 1, false), // أطول من ٩٠ حرفًا: تُستبعد
  ];
  PrayerDay? times(DateTime d) => PrayerDay(
        d,
        DateTime(d.year, d.month, d.day, 4, 30),
        DateTime(d.year, d.month, d.day, 6),
        DateTime(d.year, d.month, d.day, 12),
        DateTime(d.year, d.month, d.day, 15, 30),
        DateTime(d.year, d.month, d.day, 18),
        DateTime(d.year, d.month, d.day, 19, 30),
      );

  Map<String, dynamic> snap(DateTime now, {bool loc = true}) =>
      buildWidgetSnapshot(
        now: now,
        theme: 'system',
        azkar: const [.5, 0, 2],
        hasLocation: loc,
        place: 'القاهرة',
        timesFor: loc ? times : (_) => null,
        hijriFor: (d) => 'هجري ${d.day}',
        isDone: (d, id) => id == 'fajr',
        ayahs: ayahs,
        surahName: (s) => 'س$s',
      );

  test('اللقطة تحتوي ٤٠ يومًا بالمفاتيح التي يقرؤها الجانب الأصلي', () {
    final s = snap(DateTime(2026, 10, 6, 9));
    final days = s['days'] as List;
    expect(days.length, 40);
    expect(days.first['d'], '2026-10-06');
    expect(days.last['d'], '2026-11-14');
    expect((days.first['t'] as List).length, 6);
    expect((days.first['done'] as List).first, 1);
    expect((s['ayahs'] as List).length, 40);
    expect(s['azkarDay'], '2026-10-06');
    expect((s['azkar'] as List).last, 1.0); // يُقصّ إلى ١
  });

  test('بدون موقع: الأوقات أصفار والتاريخ الهجري يبقى', () {
    final s = snap(DateTime(2026, 10, 6), loc: false);
    final first = (s['days'] as List).first;
    expect((first['t'] as List).every((e) => e == 0), isTrue);
    expect(first['h'], isNotEmpty);
  });

  test('آية اليوم ثابتة طوال اليوم وتتجاهل الآيات الطويلة', () {
    final pool = dailyAyahPool(ayahs);
    expect(pool.length, 50);
    final a = pickDailyAyah(pool, DateTime(2026, 10, 6, 0, 30));
    final b = pickDailyAyah(pool, DateTime(2026, 10, 6, 23, 59));
    expect(a.number, b.number);
    final s = snap(DateTime(2026, 10, 6, 15));
    expect((s['ayahs'] as List).first['t'], a.text);
  });
}
