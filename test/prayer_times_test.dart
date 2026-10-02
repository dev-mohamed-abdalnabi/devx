import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/core/prayer_times.dart';

int _min(DateTime? t) => t == null ? -9999 : t.hour * 60 + t.minute;

void main() {
  test('القاهرة شتاءً (توقيت +2) — قيم مرجعية بتسامح دقيقتين', () {
    final d = computePrayerTimes(
      date: DateTime(2026, 1, 15),
      lat: 30.0444,
      lng: 31.2357,
      method: methodById('egyptian'),
      utcOffsetHours: 2,
    );
    expect((_min(d.fajr) - (5 * 60 + 21)).abs(), lessThanOrEqualTo(2));
    expect((_min(d.sunrise) - (6 * 60 + 52)).abs(), lessThanOrEqualTo(2));
    expect((_min(d.dhuhr) - (12 * 60 + 4)).abs(), lessThanOrEqualTo(2));
    expect((_min(d.asr) - (14 * 60 + 58)).abs(), lessThanOrEqualTo(2));
    expect((_min(d.maghrib) - (17 * 60 + 17)).abs(), lessThanOrEqualTo(2));
    expect((_min(d.isha) - (18 * 60 + 39)).abs(), lessThanOrEqualTo(2));
  });

  test('ترتيب الأوقات منطقي', () {
    final d = computePrayerTimes(
      date: DateTime(2026, 9, 30),
      lat: 30.0444,
      lng: 31.2357,
      method: methodById('mwl'),
      utcOffsetHours: 3,
    );
    final e = d.entries.map((x) => x.time).toList();
    expect(e.length, 6);
    for (var i = 1; i < e.length; i++) {
      expect(e[i].isAfter(e[i - 1]), isTrue);
    }
    expect(d.prayers.length, 5);
  });

  test('العصر الحنفي بعد العصر الشافعي', () {
    DateTime? asr(bool h) => computePrayerTimes(
          date: DateTime(2026, 6, 1),
          lat: 30.0444,
          lng: 31.2357,
          method: methodById('egyptian'),
          hanafi: h,
          utcOffsetHours: 3,
        ).asr;
    expect(asr(true)!.isAfter(asr(false)!), isTrue);
  });

  test('أم القرى: العشاء بعد المغرب بـ 90 دقيقة خارج رمضان', () {
    final d = computePrayerTimes(
      date: DateTime(2026, 9, 30),
      lat: 21.4225,
      lng: 39.8262,
      method: methodById('makkah'),
      utcOffsetHours: 3,
    );
    expect(d.isha!.difference(d.maghrib!).inMinutes, 90);
  });

  test('خط عرض عالٍ صيفًا: أوقات غير معرّفة تصبح null ولا تنهار', () {
    final d = computePrayerTimes(
      date: DateTime(2026, 6, 21),
      lat: 69.6,
      lng: 18.9,
      method: methodById('mwl'),
      utcOffsetHours: 2,
    );
    expect(d.fajr, isNull);
    expect(d.dhuhr, isNotNull);
  });

  test('اتجاه القبلة', () {
    expect(qiblaBearing(30.0444, 31.2357), closeTo(136.1, 0.5)); // القاهرة
    expect(qiblaBearing(51.5074, -0.1278), closeTo(119.0, 0.5)); // لندن
    expect(qiblaBearing(40.7128, -74.0060), closeTo(58.5, 0.5)); // نيويورك
  });

  test('المسافة إلى الكعبة', () {
    expect(distanceToKaabaKm(21.4225, 39.8262), lessThan(1));
    expect(distanceToKaabaKm(30.0444, 31.2357), closeTo(1287, 30)); // القاهرة
  });
}
