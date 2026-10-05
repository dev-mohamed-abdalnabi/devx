const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// يحوّل رقمًا إلى أرقام عربية (هندية).
String toArabicDigits(int n) => n
    .toString()
    .split('')
    .map((c) => c == '-' ? '-' : _digits[int.parse(c)])
    .join();

/// يزيل التشكيل وعلامات المصحف ويوحّد الألفات والياء لأغراض البحث.
String normalizeArabic(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x064B && r <= 0x065F) ||
        r == 0x0670 ||
        r == 0x0640 ||
        (r >= 0x06D6 && r <= 0x06ED)) {
      continue;
    }
    switch (r) {
      case 0x0671:
      case 0x0623:
      case 0x0625:
      case 0x0622:
        b.writeCharCode(0x0627);
        break;
      case 0x0649:
        b.writeCharCode(0x064A);
        break;
      default:
        b.writeCharCode(r);
    }
  }
  return b.toString().trim();
}

/// مفتاح بحث متسامح: يوحّد الرسم العثماني والإملائي
/// («الصلوة» = «الصلاة»، «الرحمٰن» = «الرحمن») بحذف الألفات والهمزات
/// وتوحيد التاء المربوطة والهاء والألف المقصورة والياء.
String searchKey(String s) {
  final b = StringBuffer();
  // واو الرسم العثماني مع الألف الخنجرية (الصلوٰة، الزكوٰة، الحيوٰة) = ألف.
  final raw = s.replaceAll('\u0648\u0670', '\u0627');
  for (final r in normalizeArabic(raw).runes) {
    switch (r) {
      case 0x0627: // ا
      case 0x0621: // ء
      case 0x0670:
        break;
      case 0x0629: // ة → ه
        b.writeCharCode(0x0647);
        break;
      case 0x0624: // ؤ → و
        b.writeCharCode(0x0648);
        break;
      case 0x0626: // ئ → ي
        b.writeCharCode(0x064A);
        break;
      default:
        b.writeCharCode(r);
    }
  }
  return b.toString();
}

const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد'
];
const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر'
];

String arabicDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}، ${toArabicDigits(d.day)} ${_months[d.month - 1]} ${toArabicDigits(d.year)}';

String greetingFor(DateTime d) {
  final h = d.hour;
  if (h >= 4 && h < 12) return 'صباح الخير';
  if (h >= 12 && h < 17) return 'طاب يومك';
  if (h >= 17 && h < 22) return 'مساء الخير';
  return 'تصبح على خير';
}

/// يحوّل كل الأرقام في نص إلى أرقام عربية، ويستبدل الفاصلة العشرية بـ «٫».
String toArabicDigitsStr(String s) {
  final b = StringBuffer();
  for (final c in s.split('')) {
    final code = c.codeUnitAt(0);
    if (code >= 48 && code <= 57) {
      b.write(_digits[code - 48]);
    } else if (c == '.') {
      b.write('٫');
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

String _two2(int n) => toArabicDigits(n).padLeft(2, '٠');

/// ساعة بنظام 12 ساعة: «٥:٠٥ ص».
String formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${toArabicDigits(h)}:${_two2(t.minute)} ${t.hour < 12 ? 'ص' : 'م'}';
}

/// عدّاد تنازلي «٠٢:٠٥:١٠».
String formatCountdown(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${_two2(total ~/ 3600)}:${_two2((total % 3600) ~/ 60)}:${_two2(total % 60)}';
}
