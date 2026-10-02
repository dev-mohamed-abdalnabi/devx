import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/core/dates.dart';

void main() {
  test('مفتاح اليوم وتحليله', () {
    expect(dayKey(DateTime(2026, 3, 5)), '2026-03-05');
    expect(parseDayKey('2026-03-05'), DateTime(2026, 3, 5));
  });

  test('بداية الأسبوع سبت', () {
    // 2026-09-30 يوم أربعاء، والسبت السابق هو 2026-09-26
    expect(weekStart(DateTime(2026, 9, 30)), DateTime(2026, 9, 26));
    expect(weekStart(DateTime(2026, 9, 26)), DateTime(2026, 9, 26));
    expect(weekStart(DateTime(2026, 9, 25)), DateTime(2026, 9, 19));
  });

  test('السلسلة الحالية والأطول', () {
    final active = {'2026-09-27', '2026-09-28', '2026-09-29', '2026-09-20', '2026-09-21'};
    expect(currentStreak(active, DateTime(2026, 9, 29)), 3);
    // اليوم غير نشط بعد: تُحسب من أمس
    expect(currentStreak(active, DateTime(2026, 9, 30)), 3);
    expect(currentStreak(active, DateTime(2026, 10, 2)), 0);
    expect(longestStreak(active), 3);
    expect(longestStreak({}), 0);
  });
}
