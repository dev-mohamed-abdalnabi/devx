import '../data/quran_data.dart';
import 'daily_ayah.dart';
import 'dates.dart';
import 'prayer_times.dart';
import 'text_utils.dart';

/// معرّفات الصلوات الخمس بترتيب الودجت: فجر، ظهر، عصر، مغرب، عشاء.
const _fiveIds = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

/// لقطة البيانات التي يقرؤها ودجت أندرويد محليًا (٤٠ يومًا من المواقيت وآية كل يوم).
/// تُبنى هنا بدالة نقية كي تُختبر؛ الجانب الأصلي (WidgetData.java) يقرأ نفس المفاتيح.
Map<String, dynamic> buildWidgetSnapshot({
  required DateTime now,
  required String theme, // system | light | dark
  required List<double> azkar, // صباح، مساء، نوم
  required bool hasLocation,
  required String place,
  required PrayerDay? Function(DateTime) timesFor,
  required String Function(DateTime) hijriFor,
  required bool Function(DateTime, String) isDone,
  required List<Ayah> ayahs,
  required String Function(int surah) surahName,
  int days = 40,
}) {
  final pool = ayahs.isEmpty ? const <Ayah>[] : dailyAyahPool(ayahs);
  int ms(DateTime? t) => t?.millisecondsSinceEpoch ?? 0;

  final dayList = <Map<String, dynamic>>[];
  final ayahList = <Map<String, dynamic>>[];
  for (var i = 0; i < days; i++) {
    final d = addDays(DateTime(now.year, now.month, now.day), i);
    final p = timesFor(d);
    dayList.add({
      'd': dayKey(d),
      'h': hijriFor(d),
      't': [
        ms(p?.fajr),
        ms(p?.sunrise),
        ms(p?.dhuhr),
        ms(p?.asr),
        ms(p?.maghrib),
        ms(p?.isha),
      ],
      'done': [for (final id in _fiveIds) isDone(d, id) ? 1 : 0],
    });
    if (pool.isNotEmpty) {
      final a = pickDailyAyah(pool, d);
      ayahList.add({
        'd': dayKey(d),
        't': a.text,
        'r': 'سورة ${surahName(a.surah)} · ${toArabicDigits(a.number)}',
      });
    }
  }

  return {
    'v': 1,
    'theme': theme,
    'azkarDay': dayKey(now),
    'azkar': [
      for (final v in azkar.take(3))
        double.parse(v.clamp(0.0, 1.0).toStringAsFixed(3))
    ],
    'loc': hasLocation,
    'place': place,
    'days': dayList,
    'ayahs': ayahList,
  };
}
