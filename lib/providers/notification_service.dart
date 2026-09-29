import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'azkar_reminders';
  static const _channelName = 'تذكيرات الأذكار';
  static const _channelDesc = 'تذكيرات الأذكار والقرآن والتحديات في مواعيدها';

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // نبقى على tz.local الافتراضي (UTC)؛ سيظهر الخطأ كتأخر في المواعيد فقط.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    ));
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

  static Future<void> showTest() async {
    await _plugin.show(999999, 'إشعار تجريبي', 'التذكيرات تعمل على هذا الجهاز', _details('التذكيرات تعمل على هذا الجهاز'));
  }

  /// كل تذكير يستخدم المعرفات id*10 … id*10+7 (0 لكل الأيام، و1..7 لأيام محددة).
  static Future<void> cancel(int reminderId) async {
    for (var i = 0; i <= 7; i++) {
      await _plugin.cancel(reminderId * 10 + i);
    }
  }

  static Future<void> schedule(Reminder r) async {
    await cancel(r.id);
    if (!r.enabled || r.days.isEmpty) return;

    final exact = await canScheduleExact();
    final mode =
        exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    final details = _details(r.body);

    if (r.days.length == 7) {
      await _plugin.zonedSchedule(
        r.id * 10,
        r.title,
        r.body,
        _next(r.hour, r.minute, null),
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return;
    }
    for (final d in r.days) {
      await _plugin.zonedSchedule(
        r.id * 10 + d,
        r.title,
        r.body,
        _next(r.hour, r.minute, d),
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static tz.TZDateTime _next(int hour, int minute, int? weekday) {
    final now = tz.TZDateTime.now(tz.local);
    for (var add = 0; add <= 8; add++) {
      final c = tz.TZDateTime(tz.local, now.year, now.month, now.day + add, hour, minute);
      if (!c.isAfter(now)) continue;
      if (weekday != null && c.weekday != weekday) continue;
      return c;
    }
    return tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, hour, minute);
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
