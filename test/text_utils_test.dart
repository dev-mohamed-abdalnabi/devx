import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/core/text_utils.dart';

void main() {
  test('الأرقام العربية', () {
    expect(toArabicDigits(0), '٠');
    expect(toArabicDigits(604), '٦٠٤');
  });

  test('توحيد النص للبحث يزيل التشكيل ويوحّد الألف', () {
    expect(normalizeArabic('ٱللَّهُ'), 'الله');
    expect(normalizeArabic('أَعُوذُ'), 'اعوذ');
  });

  test('تنظيف النص المستورد يزيل الوسوم الإنجليزية التقنية', () {
    expect(cleanImportedText('AUTO قصة آدم AUT NOTMATCH UNMATCHED'), 'قصة آدم');
    expect(cleanImportedText('### قصة يوسف عليه السلام'), 'قصة يوسف عليه السلام');
  });

  test('التحية حسب الوقت', () {
    expect(greetingFor(DateTime(2026, 1, 1, 6)), 'صباح الخير');
    expect(greetingFor(DateTime(2026, 1, 1, 19)), 'مساء الخير');
  });
}
