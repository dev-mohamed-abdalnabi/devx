import 'dart:math' as math;
import 'hijri.dart';
import 'text_utils.dart';

/// طريقة حساب: زاويتا الفجر والعشاء (أو دقائق بعد المغرب).
class CalcMethodInfo {
  final String id;
  final String name;
  final double fajrAngle;
  final double ishaAngle;
  final int ishaMinutes; // أكبر من صفر: العشاء بعد المغرب بهذه الدقائق
  const CalcMethodInfo(this.id, this.name, this.fajrAngle, this.ishaAngle, {this.ishaMinutes = 0});

  String get summary {
    final f = 'الفجر ${toArabicDigitsStr(fajrAngle.toString())}°';
    if (ishaMinutes > 0) {
      return '$f · العشاء بعد المغرب بـ ${toArabicDigits(ishaMinutes)} دقيقة';
    }
    return '$f · العشاء ${toArabicDigitsStr(ishaAngle.toString())}°';
  }
}

const calcMethods = <CalcMethodInfo>[
  CalcMethodInfo('egyptian', 'الهيئة المصرية العامة للمساحة', 19.5, 17.5),
  CalcMethodInfo('makkah', 'أم القرى (مكة المكرمة)', 18.5, 0, ishaMinutes: 90),
  CalcMethodInfo('mwl', 'رابطة العالم الإسلامي', 18, 17),
  CalcMethodInfo('kuwait', 'وزارة الأوقاف الكويتية', 18, 17.5),
  CalcMethodInfo('karachi', 'جامعة العلوم الإسلامية، كراتشي', 18, 18),
  CalcMethodInfo('isna', 'أمريكا الشمالية (ISNA)', 15, 15),
];

CalcMethodInfo methodById(String id) =>
    calcMethods.firstWhere((m) => m.id == id, orElse: () => calcMethods.first);

class PrayerEntry {
  final String id; // fajr | sunrise | dhuhr | asr | maghrib | isha
  final String name;
  final DateTime time;
  final bool isPrayer; // الشروق ليس صلاة
  const PrayerEntry(this.id, this.name, this.time, this.isPrayer);
}

class PrayerDay {
  final DateTime date;
  final DateTime? fajr, sunrise, dhuhr, asr, maghrib, isha;
  const PrayerDay(this.date, this.fajr, this.sunrise, this.dhuhr, this.asr, this.maghrib, this.isha);

  List<PrayerEntry> get entries => [
        if (fajr != null) PrayerEntry('fajr', 'الفجر', fajr!, true),
        if (sunrise != null) PrayerEntry('sunrise', 'الشروق', sunrise!, false),
        if (dhuhr != null) PrayerEntry('dhuhr', 'الظهر', dhuhr!, true),
        if (asr != null) PrayerEntry('asr', 'العصر', asr!, true),
        if (maghrib != null) PrayerEntry('maghrib', 'المغرب', maghrib!, true),
        if (isha != null) PrayerEntry('isha', 'العشاء', isha!, true),
      ];

  List<PrayerEntry> get prayers => entries.where((e) => e.isPrayer).toList();
}

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;
double _sin(double d) => math.sin(_rad(d));
double _cos(double d) => math.cos(_rad(d));
double _tan(double d) => math.tan(_rad(d));
double _asin(double x) => _deg(math.asin(x));
double _acos(double x) => (x < -1 || x > 1) ? double.nan : _deg(math.acos(x));
double _atan2(double y, double x) => _deg(math.atan2(y, x));
double _acot(double x) => _deg(math.atan(1 / x));
double _fixAngle(double a) => a - 360 * (a / 360).floorToDouble();
double _fixHour(double a) => a - 24 * (a / 24).floorToDouble();

double _julian(int year, int month, int day) {
  var y = year, m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + day + b - 1524.5;
}

/// [ميل الشمس، معادلة الزمن بالساعات]
List<double> _sunPosition(double jd) {
  final d = jd - 2451545.0;
  final g = _fixAngle(357.529 + 0.98560028 * d);
  final q = _fixAngle(280.459 + 0.98564736 * d);
  final l = _fixAngle(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
  final e = 23.439 - 0.00000036 * d;
  final ra = _fixHour(_atan2(_cos(e) * _sin(l), _cos(l)) / 15);
  return [_asin(_sin(e) * _sin(l)), q / 15 - ra];
}

DateTime? _toDateTime(DateTime date, double hours) {
  if (hours.isNaN || hours.isInfinite) return null;
  return DateTime(date.year, date.month, date.day, 0, (hours * 60).round());
}

/// يحسب مواقيت يوم كامل محليًا بدون إنترنت.
/// [utcOffsetHours] للاختبار فقط؛ الافتراضي فرق توقيت الجهاز في ذلك اليوم.
/// الأوقات المرجعة NULL إن لم تُعرَّف الزاوية في هذا الموقع (خطوط العرض العالية).
PrayerDay computePrayerTimes({
  required DateTime date,
  required double lat,
  required double lng,
  required CalcMethodInfo method,
  bool hanafi = false,
  double? utcOffsetHours,
}) {
  final tz = utcOffsetHours ??
      DateTime(date.year, date.month, date.day, 12).timeZoneOffset.inMinutes / 60.0;
  final jd = _julian(date.year, date.month, date.day) - lng / (15 * 24);

  double midDay(double t) => _fixHour(12 - _sunPosition(jd + t)[1]);

  double angleTime(double angle, double t, {bool ccw = false}) {
    final decl = _sunPosition(jd + t)[0];
    final noon = midDay(t);
    final a = _acos((-_sin(angle) - _sin(decl) * _sin(lat)) / (_cos(decl) * _cos(lat))) / 15;
    return noon + (ccw ? -a : a);
  }

  double asrTime(double factor, double t) {
    final decl = _sunPosition(jd + t)[0];
    final angle = -_acot(factor + _tan((lat - decl).abs()));
    return angleTime(angle, t);
  }

  double adj(double h) => h + tz - lng / 15;

  final fajr = adj(angleTime(method.fajrAngle, 5 / 24, ccw: true));
  final sunrise = adj(angleTime(0.833, 6 / 24, ccw: true));
  final dhuhr = adj(midDay(12 / 24));
  final asr = adj(asrTime(hanafi ? 2 : 1, 13 / 24));
  final maghrib = adj(angleTime(0.833, 18 / 24));
  double isha;
  if (method.ishaMinutes > 0) {
    final ramadan = method.id == 'makkah' && HijriDate.fromGregorian(date).month == 9;
    isha = maghrib + (ramadan ? 120 : method.ishaMinutes) / 60;
  } else {
    isha = adj(angleTime(method.ishaAngle, 18 / 24));
  }

  return PrayerDay(date, _toDateTime(date, fajr), _toDateTime(date, sunrise),
      _toDateTime(date, dhuhr), _toDateTime(date, asr), _toDateTime(date, maghrib),
      _toDateTime(date, isha));
}

const kaabaLat = 21.4225;
const kaabaLng = 39.8262;

/// اتجاه القبلة بالدرجات من الشمال الحقيقي (0..360).
double qiblaBearing(double lat, double lng) {
  final p1 = _rad(lat);
  final k = _rad(kaabaLat);
  final dl = _rad(kaabaLng - lng);
  final y = math.sin(dl);
  final x = math.cos(p1) * math.tan(k) - math.sin(p1) * math.cos(dl);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// المسافة إلى الكعبة بالكيلومتر (هافرساين).
double distanceToKaabaKm(double lat, double lng) {
  const r = 6371.0;
  final dLat = _rad(kaabaLat - lat);
  final dLng = _rad(kaabaLng - lng);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat)) * math.cos(_rad(kaabaLat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}
