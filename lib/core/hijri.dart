import 'text_utils.dart';

const hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
];

/// تاريخ هجري بالحساب الجدولي (خوارزمية الكويت).
/// قد يختلف يومًا واحدًا عن تقويم أم القرى أو رؤية الهلال، ولهذا يوجد تصحيح ±٢ يوم.
class HijriDate {
  final int year;
  final int month; // 1..12
  final int day;
  const HijriDate(this.year, this.month, this.day);

  static int _jdn(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final y2 = y + 4800 - a;
    final m2 = m + 12 * a - 3;
    return d + (153 * m2 + 2) ~/ 5 + 365 * y2 + y2 ~/ 4 - y2 ~/ 100 + y2 ~/ 400 - 32045;
  }

  factory HijriDate.fromGregorian(DateTime date, {int adjust = 0}) {
    final base = DateTime(date.year, date.month, date.day + adjust);
    final jd = _jdn(base.year, base.month, base.day);
    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
    final m = (24 * l) ~/ 709;
    final d = l - (709 * m) ~/ 24;
    final y = 30 * n + j - 30;
    return HijriDate(y, m, d);
  }

  String get monthName => hijriMonths[month - 1];

  String format() => '${toArabicDigits(day)} $monthName ${toArabicDigits(year)} هـ';
}
