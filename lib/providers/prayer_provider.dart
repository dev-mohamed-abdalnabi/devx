import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/dates.dart';
import '../core/hijri.dart';
import '../core/prayer_times.dart';
import '../data/cities.dart';
import '../features/prayer/adhan_styles.dart';
import '../services/adhan_sounds.dart';
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
  bool adhanEnabled = true;
  int hijriAdjust = 0;

  /// نمط التنبيه لكل صلاة: 0 = أذان بصوت، 1 = إشعار بدون صوت، 2 = بدون تنبيه.
  Map<String, int> prayerModes = {};
  int modeOf(String id) => prayerModes[id] ?? 0;
  bool loading = true;
  bool locating = false;

  // ===== إعدادات الأذان المتقدمة =====
  /// شكل شاشة الأذان (0..4).
  int adhanStyle = 0;

  /// معرّف صوت الأذان المختار (انظر AdhanSounds.all).
  String adhanSoundId = AdhanSounds.defaultId;
  String adhanSoundPath = '';

  /// أين تظهر شاشة الأذان: adhanDisplayOverApps / adhanDisplayLockOnly.
  int adhanDisplay = adhanDisplayLockOnly;

  /// تذكير قبل الصلاة بعدد دقائق (0 = مغلق).
  int preReminderMinutes = 0;

  /// تقدّم تحميل الأصوات (id → 0..1).
  final Map<String, double> downloading = {};

  SharedPreferences? _prefs;
  final Set<String> _done = {};
  static const _doneKey = 'prayer_done_v1';
  static const fivePrayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _key = 'prayer_v1';

  bool get hasLocation => lat != null && lng != null;
  CalcMethodInfo get method => methodById(methodId);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _done.addAll(_prefs!.getStringList(_doneKey) ?? const []);
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
        adhanEnabled = (j['adhan'] as bool?) ?? true;
        hijriAdjust = (j['hijri'] as int?) ?? 0;
        adhanStyle = ((j['style'] as int?) ?? 0).clamp(0, 4);
        adhanSoundId = (j['sound'] as String?) ?? AdhanSounds.defaultId;
        adhanDisplay = (j['display'] as int?) ?? adhanDisplayLockOnly;
        preReminderMinutes = (j['pre'] as int?) ?? 0;
        final m = j['modes'];
        if (m is Map) {
          prayerModes = {
            for (final e in m.entries)
              if (e.value is int) e.key.toString(): e.value as int,
          };
        }
      } catch (_) {
        await _prefs!.setString('${_key}_corrupt', raw);
      }
    }
    // لو الصوت المختار لم يعد موجودًا على الجهاز نرجع للأساسي.
    adhanSoundPath = await AdhanSounds.localPath(adhanSoundId) ?? '';
    if (!AdhanSounds.byId(adhanSoundId).bundled && adhanSoundPath.isEmpty) {
      adhanSoundId = AdhanSounds.defaultId;
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
        'modes': prayerModes,
        'style': adhanStyle,
        'sound': adhanSoundId,
        'display': adhanDisplay,
        'pre': preReminderMinutes,
      }),
    );
    // مفاتيح مسطّحة تقرأها الخدمة الأصلية (FlutterSharedPreferences: flutter.adhan_*).
    await _prefs?.setInt('adhan_style', adhanStyle);
    await _prefs?.setInt('adhan_display', adhanDisplay);
    await _prefs?.setString('adhan_sound_path', adhanSoundPath);
  }

  // ===== تتبّع الصلوات (صليت / لم أصلِّ) =====
  bool isDone(DateTime d, String id) => _done.contains('${dayKey(d)}:$id');

  int doneCount(DateTime d) => fivePrayers.where((id) => isDone(d, id)).length;

  Future<void> toggleDone(DateTime d, String id) async {
    final k = '${dayKey(d)}:$id';
    if (!_done.remove(k)) _done.add(k);
    // نحتفظ بآخر ٩٠ يومًا فقط
    final limit = dayKey(addDays(DateTime.now(), -90));
    _done.removeWhere((e) => e.split(':').first.compareTo(limit) < 0);
    notifyListeners();
    await _prefs?.setStringList(_doneKey, _done.toList());
  }

  /// أيام متتالية أُكملت فيها الصلوات الخمس (اليوم يُحتسب إن اكتمل، وإلا نبدأ من أمس).
  int fullDaysStreak(DateTime today) {
    var d = DateTime(today.year, today.month, today.day);
    if (doneCount(d) < 5) d = addDays(d, -1);
    var n = 0;
    while (doneCount(d) == 5) {
      n++;
      d = addDays(d, -1);
    }
    return n;
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

  HijriDate hijriFor(DateTime d) =>
      HijriDate.fromGregorian(d, adjust: hijriAdjust);

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
      if (pos == null) {
        return 'تعذّر تحديد موقعك الآن. جرّب مرة أخرى أو اختر مدينتك.';
      }
      lat = pos.latitude;
      lng = pos.longitude;
      final near = nearestCity(pos.latitude, pos.longitude);
      placeName =
          near == null ? 'موقعك الحالي' : 'موقعك الحالي (قرب ${near.name})';
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

  Future<void> setPrayerMode(String id, int mode) async {
    prayerModes[id] = mode;
    await _save();
    if (adhanEnabled) await syncAdhan();
    notifyListeners();
  }

  Future<void> setAdhanStyle(int v) async {
    adhanStyle = v.clamp(0, 4);
    notifyListeners();
    await _save();
  }

  Future<void> setAdhanDisplay(int v) async {
    adhanDisplay = v;
    notifyListeners();
    await _save();
    if (adhanEnabled) await syncAdhan();
  }

  Future<void> setPreReminder(int minutes) async {
    preReminderMinutes = minutes;
    notifyListeners();
    await _save();
    if (adhanEnabled) await syncAdhan();
  }

  /// يختار صوتًا (لازم يكون محمَّلًا أو مدمجًا).
  Future<bool> selectSound(String id) async {
    final path = await AdhanSounds.localPath(id);
    if (!AdhanSounds.byId(id).bundled && path == null) return false;
    adhanSoundId = id;
    adhanSoundPath = path ?? '';
    notifyListeners();
    await _save();
    if (adhanEnabled) await syncAdhan();
    return true;
  }

  /// يحمّل صوتًا؛ يعيد null عند النجاح أو رسالة الخطأ.
  Future<String?> downloadSound(String id) async {
    if (downloading.containsKey(id)) return null;
    downloading[id] = 0;
    notifyListeners();
    try {
      await AdhanSounds.download(id, onProgress: (v) {
        downloading[id] = v;
        notifyListeners();
      });
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      downloading.remove(id);
      notifyListeners();
    }
  }

  Future<void> deleteSound(String id) async {
    await AdhanSounds.delete(id);
    if (adhanSoundId == id) await selectSound(AdhanSounds.defaultId);
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
    try {
      final entries = <PrayerEntry>[];
      final today = DateTime.now();
      for (var i = 0; i < 8; i++) {
        final day = timesFor(DateTime(today.year, today.month, today.day + i));
        if (day != null) entries.addAll(day.prayers);
      }
      await NotificationService.scheduleAdhan(
        entries,
        modes: prayerModes,
        style: adhanStyle,
        display: adhanDisplay,
        soundPath: adhanSoundPath,
        preMinutes: preReminderMinutes,
      );
    } catch (_) {
      // فشل الجدولة لا يجب أن يغلق التطبيق، ويمكن إعادة المحاولة عند تغيير المدينة.
    }
  }
}
