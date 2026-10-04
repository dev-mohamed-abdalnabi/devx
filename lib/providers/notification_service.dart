import 'dart:io' show Platform;
import 'package:azkari_native/azkari_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import '../core/prayer_times.dart';
import '../features/prayer/adhan_screen.dart';
import '../widgets/support_app_button.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'azkar_reminders';
  static const _channelName = 'تذكيرات الأذكار';
  static const _channelDesc = 'تذكيرات الأذكار والقرآن والتحديات في مواعيدها';
  // قنوات أندرويد لا تتغير إعداداتها بعد إنشائها؛ لذلك معرّف جديد (v3) يضمن صوت الأذان
  // حتى لو كانت v2 اتأنشأت قبل ما يكون ملف adhan موجود داخل التطبيق.
  static const _adhanChannelId = 'adhan_times_v3';
  static const _oldAdhanChannelIds = ['adhan_times', 'adhan_times_v2'];
  static const _fallbackChannelId = 'adhan_fallback_v1';
  static const _probeId = 69999;
  static const _statIcon = 'ic_stat_blank';
  static const _launcherIcon = '@mipmap/ic_launcher';

  /// نفس معرّف قناة إشعار الميديا في main.dart (يستخدمه فحص الحالة).
  static const mediaChannelId = 'com.azkarapp.quran_media_playback_v2';

  /// أيقونة إشعار الميديا: الأيقونة الشفافة لو موجودة في الـ APK، وإلا أيقونة التطبيق.
  /// (لو الأيقونة غير موجودة يرفض أندرويد إشعار الميديا بصمت.)
  static String mediaIcon = 'mipmap/ic_launcher';
  static bool statIconAvailable = false;

  /// هل ملف الأذان (res/raw/adhan) موجود فعلًا داخل الـ APK؟
  static bool adhanSoundAvailable = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // نبقى على tz.local الافتراضي (UTC)؛ سيظهر الخطأ كتأخر في المواعيد فقط.
    }
    // الإضافة ترفض initialize لو الأيقونة غير موجودة، فنستخدمها كاختبار لوجود الأيقونة الشفافة.
    try {
      await _plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings(_statIcon)),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      statIconAvailable = true;
    } catch (_) {
      statIconAvailable = false;
    }
    // باقي الإشعارات (التذكيرات والأذان) تبقى بأيقونة التطبيق العادية.
    await _plugin.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings(_launcherIcon)),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    mediaIcon =
        statIconAvailable ? 'drawable/ic_stat_blank' : 'mipmap/ic_launcher';

    try {
      await _android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ));
    } catch (_) {}
    for (final old in _oldAdhanChannelIds) {
      try {
        await _android?.deleteNotificationChannel(old);
      } catch (_) {}
    }

    adhanSoundAvailable = await _probeAdhanSound();
    try {
      if (adhanSoundAvailable) {
        await _android
            ?.createNotificationChannel(const AndroidNotificationChannel(
          _adhanChannelId,
          'الأذان ومواقيت الصلاة',
          description: 'تنبيه عند دخول وقت الصلاة',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('adhan'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ));
      } else {
        // لا نترك قناة بصوت معطوب؛ نحذفها وننشئ قناة بصوت النظام كبديل.
        await _android?.deleteNotificationChannel(_adhanChannelId);
        await _android
            ?.createNotificationChannel(const AndroidNotificationChannel(
          _fallbackChannelId,
          'الأذان (صوت النظام)',
          description: 'تنبيه عند دخول وقت الصلاة',
          importance: Importance.max,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ));
      }
    } catch (_) {}
  }

  /// يتأكد أن مورد الصوت adhan موجود: جدولة تجريبية بعيدة ثم إلغاؤها.
  /// الإضافة ترمي PlatformException(invalid_sound) لو المورد ناقص.
  static Future<bool> _probeAdhanSound() async {
    try {
      await _plugin.zonedSchedule(
        _probeId,
        'probe',
        'probe',
        tz.TZDateTime.now(tz.local).add(const Duration(days: 3650)),
        _adhanDetails('probe', custom: true),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      await _plugin.cancel(_probeId);
      return true;
    } on PlatformException catch (e) {
      return e.code != 'invalid_sound';
    } catch (_) {
      return true;
    }
  }

  /// يطلب إذن الإشعارات (أندرويد 13+). يعيد true إن كان ممنوحًا.
  static Future<bool> requestPermission() async {
    try {
      return (await _android?.requestNotificationsPermission()) ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canScheduleExact() async {
    try {
      return (await _android?.canScheduleExactNotifications()) ?? true;
    } catch (_) {
      return false;
    }
  }

  /// يفتح شاشة إذن «التنبيهات والتذكيرات» في إعدادات النظام.
  static Future<void> requestExactPermission() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  static NotificationDetails _details(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  /// [custom]: true = صوت الأذان من res/raw، false = صوت النظام، null = حسب نتيجة الفحص.
  static NotificationDetails _adhanDetails(String body, {bool? custom}) {
    final useCustom = custom ?? adhanSoundAvailable;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        useCustom ? _adhanChannelId : _fallbackChannelId,
        useCustom ? 'الأذان ومواقيت الصلاة' : 'الأذان (صوت النظام)',
        channelDescription: 'تنبيه عند دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: useCustom ? const RawResourceAndroidNotificationSound('adhan') : null,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('adhan:')) return;
    final prayer = payload.substring('adhan:'.length).trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) =>
              AdhanScreen(prayerName: prayer.isEmpty ? 'الصلاة' : prayer)));
    });
  }

  static Future<void> showTest() async {
    await _plugin.show(999999, 'إشعار تجريبي', 'التذكيرات تعمل على هذا الجهاز',
        _details('التذكيرات تعمل على هذا الجهاز'));
  }

  static Future<int> pendingCount() async {
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> cancelAdhan() async {
    try {
      await _plugin.cancel(_probeId);
    } catch (_) {}
    for (var i = 0; i < 42; i++) {
      try {
        await _plugin.cancel(70000 + i);
      } catch (_) {}
    }
    if (Platform.isAndroid) await AzkariNative.cancelAdhan();
  }

  /// [modes]: لكل صلاة (بالمعرّف) 0 = أذان بصوت، 1 = بدون صوت، 2 = بدون تنبيه.
  static Future<void> scheduleAdhan(Iterable<PrayerEntry> entries,
      {Map<String, int> modes = const {}}) async {
    final list = entries
        .where((e) =>
            e.isPrayer &&
            e.time.isAfter(DateTime.now()) &&
            (modes[e.id] ?? 0) != 2)
        .toList();

    // الأذان بصوت: خدمة أصلية تشغّل الملف كاملًا (منبّه دقيق)، بدل صوت قناة الإشعار الذي
    // يقطعه النظام. لو فشلت (أو منصة غير أندرويد) نرجع للإشعار القديم.
    Future<bool> scheduleNative() async {
      if (!Platform.isAndroid) return false;
      final loud = <Map<String, Object>>[
        for (var i = 0; i < list.length; i++)
          if ((modes[list[i].id] ?? 0) == 0)
            {
              'id': 80000 + i,
              'time': list[i].time.millisecondsSinceEpoch,
              'name': list[i].name,
            }
      ];
      if (loud.isEmpty) return false;
      return AzkariNative.scheduleAdhan(loud);
    }

    Future<void> run({required bool exact, required bool custom}) async {
      await cancelAdhan();
      final nativeOk = await scheduleNative();
      var index = 0;
      for (final entry in list) {
        if (index >= 42) break;
        final silent = (modes[entry.id] ?? 0) == 1;
        if (nativeOk && !silent) {
          index++;
          continue;
        }
        final body = silent
            ? 'حافظ على صلاتك في وقتها، تقبّل الله منك'
            : 'حان الآن وقت صلاة ${entry.name}';
        await _scheduleOne(
          70000 + index++,
          silent ? 'وقت صلاة ${entry.name}' : 'أذان ${entry.name}',
          body,
          tz.TZDateTime.from(entry.time, tz.local),
          silent ? _silentDetails(body) : _adhanDetails(body, custom: custom ? null : false),
          mode: exact
              ? AndroidScheduleMode.alarmClock
              : AndroidScheduleMode.inexactAllowWhileIdle,
          match: null,
          payload: silent ? 'prayer:${entry.name}' : 'adhan:${entry.name}',
        );
      }
    }

    try {
      await run(exact: await canScheduleExact(), custom: true);
    } catch (_) {
      // لا يجوز أن ينهار التطبيق إذا رفض الجهاز صوت الأذان أو المنبه الدقيق.
      // نعيد المحاولة بإشعار عادي وصوت النظام.
      try {
        await run(exact: false, custom: false);
      } catch (_) {}
    }
  }

  /// إشعار الصلاة بدون صوت ولا اهتزاز.
  static NotificationDetails _silentDetails(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_silent_v1',
          'تنبيه الصلاة (بدون صوت)',
          channelDescription: 'إشعار هادئ عند دخول وقت الصلاة',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  /// كل تذكير يستخدم المعرفات id*10 … id*10+7 (0 لكل الأيام، و1..7 لأيام محددة).
  static Future<void> cancel(int reminderId) async {
    for (var i = 0; i <= 7; i++) {
      await _plugin.cancel(reminderId * 10 + i);
    }
  }

  static Future<void> schedule(Reminder r) async {
    try {
      await cancel(r.id);
    } catch (_) {
      // بيانات جدولة قديمة تالفة لا تمنع إنشاء الجدولة الجديدة.
    }
    if (!r.enabled || r.days.isEmpty) return;

    final exact = await canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final details = _details(r.body);

    if (r.days.length == 7) {
      await _scheduleOne(
        r.id * 10,
        r.title,
        r.body,
        _next(r.hour, r.minute, null),
        details,
        mode: mode,
        match: DateTimeComponents.time,
      );
      return;
    }
    for (final d in r.days) {
      await _scheduleOne(
        r.id * 10 + d,
        r.title,
        r.body,
        _next(r.hour, r.minute, d),
        details,
        mode: mode,
        match: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> _scheduleOne(
    int id,
    String title,
    String body,
    tz.TZDateTime date,
    NotificationDetails details, {
    required AndroidScheduleMode mode,
    required DateTimeComponents? match,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        date,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
        payload: payload,
      );
    } catch (e) {
      if (mode != AndroidScheduleMode.alarmClock) rethrow;
      // بعض الأجهزة تعلن السماح بالتنبيه الدقيق ثم ترفضه فعليًا؛ لا نفقد التذكير.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        date,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
        payload: payload,
      );
    }
  }

  static tz.TZDateTime _next(int hour, int minute, int? weekday) {
    final now = tz.TZDateTime.now(tz.local);
    for (var add = 0; add <= 8; add++) {
      final c = tz.TZDateTime(
          tz.local, now.year, now.month, now.day + add, hour, minute);
      if (!c.isAfter(now)) continue;
      if (weekday != null && c.weekday != weekday) continue;
      return c;
    }
    return tz.TZDateTime(
        tz.local, now.year, now.month, now.day + 1, hour, minute);
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
