import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/models/reminder.dart';
import 'package:azkar_app/core/text_utils.dart';

void main() {
  test('تحويل التذكير إلى JSON وإعادته', () {
    final r = Reminder(
        id: 101,
        kind: 'custom',
        title: 'ورد',
        body: 'ورد',
        hour: 7,
        minute: 5,
        days: {6, 7},
        enabled: true);
    final back = Reminder.fromJson(r.toJson());
    expect(back.id, 101);
    expect(back.days, {6, 7});
    expect(back.enabled, isTrue);
    expect(back.isCustom, isTrue);
  });

  test('التذكيرات الافتراضية: معرّفات فريدة ومفعّلة', () {
    final list = defaultReminders();
    expect(list.map((e) => e.id).toSet().length, list.length);
    expect(list.every((e) => e.enabled), isTrue);
    expect(list.map((e) => e.kind).toSet(),
        {'morning', 'evening', 'sleep', 'quran', 'challenges'});
  });

  test('وصف الأيام', () {
    expect(
        Reminder(id: 1, kind: 'x', title: '', body: '', hour: 0, minute: 0)
            .daysLabel,
        'كل يوم');
    expect(
        Reminder(
            id: 1,
            kind: 'x',
            title: '',
            body: '',
            hour: 0,
            minute: 0,
            days: {5}).daysLabel,
        'الجمعة');
  });

  test('تنسيق الساعة والعدّاد', () {
    expect(formatClock(DateTime(2026, 1, 1, 5, 5)), '٥:٠٥ ص');
    expect(formatClock(DateTime(2026, 1, 1, 0, 0)), '١٢:٠٠ ص');
    expect(formatClock(DateTime(2026, 1, 1, 12, 30)), '١٢:٣٠ م');
    expect(formatClock(DateTime(2026, 1, 1, 17, 0)), '٥:٠٠ م');
    expect(formatCountdown(const Duration(hours: 2, minutes: 5, seconds: 10)),
        '٠٢:٠٥:١٠');
    expect(toArabicDigitsStr('19.5'), '١٩٫٥');
  });
}
