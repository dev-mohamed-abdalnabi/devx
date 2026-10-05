import '../data/quran_data.dart';

/// آيات قصيرة (≤ ٩٠ حرفًا) تصلح للكارت والودجت.
List<Ayah> dailyAyahPool(List<Ayah> all) {
  final pool = all.where((a) => a.text.length <= 90).toList();
  return pool.isEmpty ? all : pool;
}

/// آية اليوم: نفس الاختيار في كارت الرئيسية وودجت الشاشة (يُحسب عند الظهر لتفادي فروق التوقيت الصيفي).
Ayah pickDailyAyah(List<Ayah> pool, DateTime when) {
  final noon = DateTime(when.year, when.month, when.day, 12);
  final doy = noon.difference(DateTime(when.year, 1, 1, 12)).inDays;
  return pool[(doy + when.year * 7) % pool.length];
}
