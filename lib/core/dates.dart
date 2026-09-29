String _two(int n) => n.toString().padLeft(2, '0');

String dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String monthKey(DateTime d) => '${d.year}-${_two(d.month)}';

DateTime parseDayKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// بداية الأسبوع (السبت).
DateTime weekStart(DateTime d) => addDays(DateTime(d.year, d.month, d.day), -((d.weekday + 1) % 7));

/// عدد الأيام المتتالية المنتهية باليوم (أو أمس إن لم يكن اليوم نشطًا بعد).
int currentStreak(Set<String> active, DateTime today) {
  var d = DateTime(today.year, today.month, today.day);
  if (!active.contains(dayKey(d))) d = addDays(d, -1);
  var n = 0;
  while (active.contains(dayKey(d))) {
    n++;
    d = addDays(d, -1);
  }
  return n;
}

int longestStreak(Set<String> active) {
  if (active.isEmpty) return 0;
  final dates = active.map(parseDayKey).toList()..sort();
  var best = 1;
  var cur = 1;
  for (var i = 1; i < dates.length; i++) {
    if (dates[i] == addDays(dates[i - 1], 1)) {
      cur++;
      if (cur > best) best = cur;
    } else {
      cur = 1;
    }
  }
  return best;
}
