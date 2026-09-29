import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import 'notification_service.dart';

class RemindersProvider extends ChangeNotifier {
  final List<Reminder> items = [];
  bool loading = true;
  bool exactAllowed = true;
  String? lastError;

  SharedPreferences? _prefs;
  static const _key = 'reminders_v1';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List) {
          items.add(Reminder.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        await _prefs!.setString('${_key}_corrupt', raw);
        items.clear();
      }
    }
    if (items.isEmpty) items.addAll(defaultReminders());
    // نعيد الجدولة عند كل تشغيل: يصلح تغيّر المنطقة الزمنية أو فقدان الجداول.
    await rescheduleAll();
    exactAllowed = await NotificationService.canScheduleExact();
    loading = false;
    notifyListeners();
  }

  Future<void> rescheduleAll() async {
    for (final r in items) {
      try {
        await NotificationService.schedule(r);
      } catch (e) {
        lastError = 'تعذّرت جدولة «${r.title}»: $e';
      }
    }
  }

  Future<void> refreshExact() async {
    exactAllowed = await NotificationService.canScheduleExact();
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs?.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> _apply(Reminder r) async {
    await _save();
    try {
      await NotificationService.schedule(r);
      lastError = null;
    } catch (e) {
      lastError = 'تعذّرت جدولة «${r.title}»: $e';
    }
    notifyListeners();
  }

  /// يعيد false إن رفض المستخدم إذن الإشعارات.
  Future<bool> setEnabled(Reminder r, bool on) async {
    if (on && !await NotificationService.requestPermission()) return false;
    r.enabled = on;
    await _apply(r);
    return true;
  }

  Future<void> setTime(Reminder r, int hour, int minute) async {
    r.hour = hour;
    r.minute = minute;
    await _apply(r);
  }

  Future<void> toggleDay(Reminder r, int weekday) async {
    final next = {...r.days};
    if (!next.remove(weekday)) next.add(weekday);
    if (next.isEmpty) return; // يوم واحد على الأقل
    r.days = next;
    await _apply(r);
  }

  Future<void> addCustom(String title, int hour, int minute) async {
    var id = 100;
    for (final r in items) {
      if (r.id >= id) id = r.id + 1;
    }
    final t = title.trim().isEmpty ? 'تذكير' : title.trim();
    final r = Reminder(id: id, kind: 'custom', title: t, body: t, hour: hour, minute: minute);
    items.add(r);
    await setEnabled(r, true);
  }

  Future<void> rename(Reminder r, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    r.title = t;
    r.body = t;
    await _apply(r);
  }

  Future<void> remove(Reminder r) async {
    items.remove(r);
    await NotificationService.cancel(r.id);
    await _save();
    notifyListeners();
  }
}
