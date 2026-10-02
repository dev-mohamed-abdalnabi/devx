import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/core/hijri.dart';

void main() {
  test('30 سبتمبر 2026 = 17 ربيع الآخر 1448 (±يوم)', () {
    final h = HijriDate.fromGregorian(DateTime(2026, 9, 30));
    expect(h.year, 1448);
    expect(h.month, 4);
    expect((h.day - 17).abs(), lessThanOrEqualTo(1));
  });

  test('غرة رمضان 1446 قرب 1 مارس 2025', () {
    final h = HijriDate.fromGregorian(DateTime(2025, 3, 1));
    expect(h.year, 1446);
    expect(h.month, 9);
    expect(h.day, lessThanOrEqualTo(2));
    expect(HijriDate.fromGregorian(DateTime(2025, 3, 15)).month, 9);
  });

  test('غرة محرم 1448 قرب 17 يونيو 2026', () {
    final h = HijriDate.fromGregorian(DateTime(2026, 6, 17));
    expect(h.year, 1448);
    expect(h.month, 1);
    expect(h.day, lessThanOrEqualTo(2));
  });

  test('التصحيح ±1 يوم', () {
    final base = HijriDate.fromGregorian(DateTime(2026, 9, 30));
    final plus = HijriDate.fromGregorian(DateTime(2026, 9, 30), adjust: 1);
    expect(plus.day, base.day + 1);
  });

  test('التنسيق بالأرقام العربية', () {
    expect(const HijriDate(1448, 4, 17).format(), '١٧ ربيع الآخر ١٤٤٨ هـ');
  });
}
