import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/hijri.dart';
import '../core/prayer_times.dart';
import '../data/cities.dart';
import 'notification_service.dart';

class NextPrayer {
  final String id;
  final String name;
  final DateTime time;
  const NextPrayer(this.id, this.name, this.time);
}

class PrayerProvider extends ChangeNotifier {
  double? lat;
  double? lng;
  String placeName = '';
  bool usingGps = false;
  String methodId = 'egyptian';
  bool hanafi = false;
  bool adhanEnabled = false;
  int hijriAdjust = 0;
  bool loading = true;
  bool locating = false;

  SharedPreferences? _prefs;
  static const _key = 'prayer_v1';

  bool get hasLocation => lat != null && lng != null;
  CalcMethodInfo get method => methodById(methodId);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        lat = (j['lat'] as num?)?.toDouble();
        lng = (j['lng'] as num?)?.toDouble();
        placeName = (j['place'] as String?) ?? '';
        usingGps = (j['gps'] as bool?) ?? false;
        methodId = (j['method'] as String?) ?? 'egyptian';
        hanafi = (j['hanafi'] as bool?) ?? false;
        adhanEnabled = (j['adhan'] as bool?) ?? false;
        hijriAdjust = (j['hijri'] as int?) ?? 0;
      } catch (_) {
        await _prefs!.setString('${_key}_corrupt', raw);
      }
    }
    loading = false;
    if (adhanEnabled && hasLocation) await syncAdhan();
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs?.setString(
      _key,
      jsonEncode({
        'lat': lat,
        'lng': lng,
        'place': placeName,
        'gps': usingGps,
        'method': methodId,
        'hanafi': hanafi,
        'adhan': adhanEnabled,
        'hijri': hijriAdjust,
      }),
    );
  }

  PrayerDay? timesFor(DateTime date) {
    if (!hasLocation) return null;
    return computePrayerTimes(
        date: date, lat: lat!, lng: lng!, method: method, hanafi: hanafi);
  }

  NextPrayer? nextPrayer(DateTime now) {
    final today = timesFor(now);
    if (today == null) return null;
    for (final e in today.prayers) {
      if (e.time.isAfter(now)) return NextPrayer(e.id, e.name, e.time);
    }
    final tomorrow = timesFor(DateTime(now.year, now.month, now.day + 1));
    final f = tomorrow?.fajr;
    return f == null ? null : NextPrayer('fajr', 'الفجر', f);
  }

  HijriDate hijriFor(DateTime d) => HijriDate.fromGregorian(d, adjust: hijriAdjust);

  double? get qibla => hasLocation ? qiblaBearing(lat!, lng!) : null;

  void selectCity(City c) {
    lat = c.lat;
    lng = c.lng;
    placeName = '${c.name}، ${c.country}';
    usingGps = false;
    _save();
    if (adhanEnabled) syncAdhan();
    notifyListeners();
  }

  /// يحدد الموقع من الجهاز. يعيد NULL عند النجاح أو رسالة الخطأ بالعربية.
  Future<String?> useGps() async {
    if (locating) return null;
    locating = true;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'خدمة الموقع مغلقة في الجهاز. فعّلها أو اختر مدينتك يدويًا.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return 'لم يُمنح إذن الموقع. يمكنك اختيار مدينتك يدويًا.';
      }
      if (perm == LocationPermission.deniedForever) {
        return 'إذن الموقع مرفوض نهائيًا. فعّله من إعدادات التطبيق في النظام أو اختر مدينتك.';
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return 'تعذّر تحديد موقعك الآن. جرّب مرة أخرى أو اختر مدينتك.';
      lat = pos.latitude;
      lng = pos.longitude;
      final near = nearestCity(pos.latitude, pos.longitude);
      placeName = near == null ? 'موقعك الحالي' : 'موقعك الحالي (قرب ${near.name})';
      usingGps = true;
      await _save();
      if (adhanEnabled) await syncAdhan();
      return null;
    } catch (_) {
      return 'تعذّر تحديد موقعك. اختر مدينتك يدويًا.';
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  void setMethod(String id) {
    methodId = id;
    _save();
    if (adhanEnabled) syncAdhan();
    notifyListeners();
  }

  void setHanafi(bool v) {
    hanafi = v;
    _save();
    if (adhanEnabled) syncAdhan();
    notifyListeners();
  }

  void setHijriAdjust(int v) {
    hijriAdjust = v.clamp(-2, 2);
    _save();
    notifyListeners();
  }

  Future<bool> setAdhanEnabled(bool value) async {
    if (value) {
      if (!await NotificationService.requestPermission()) return false;
      if (!await NotificationService.canScheduleExact()) {
        await NotificationService.requestExactPermission();
      }
    }
    adhanEnabled = value;
    await _save();
    if (value && hasLocation) {
      await syncAdhan();
    } else if (!value) {
      await NotificationService.cancelAdhan();
    }
    notifyListeners();
    return true;
  }

  Future<void> syncAdhan() async {
    if (!adhanEnabled || !hasLocation) return;
    final entries = <PrayerEntry>[];
    final today = DateTime.now();
    for (var i = 0; i < 8; i++) {
      final day = timesFor(DateTime(today.year, today.month, today.day + i));
      if (day != null) entries.addAll(day.prayers);
    }
    await NotificationService.scheduleAdhan(entries);
  }
}
