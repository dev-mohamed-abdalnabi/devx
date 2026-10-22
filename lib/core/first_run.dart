import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حالة أول تشغيل محفوظة في مكانين مستقلين حتى لا تعود شاشة الترحيب
/// بعد تحديث التطبيق أو تعذر قراءة أحد مخزني أندرويد مؤقتًا.
class FirstRun {
  FirstRun._();

  static const _key = 'onboarding_completed';
  static const _file = 'onboarding_done';

  static Future<File?> _marker() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$_file');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isCompleted() async {
    SharedPreferences? prefs;
    var prefsDone = false;
    try {
      prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      prefsDone = prefs.getBool(_key) ?? false;
    } catch (_) {}

    final marker = await _marker();
    var fileDone = false;
    try {
      fileDone = marker != null && await marker.exists();
    } catch (_) {}

    if (!prefsDone && !fileDone) return false;

    // ترميم المكان الناقص، لكن لا نجعل الترميم سببًا لتعليق التطبيق.
    try {
      if (!prefsDone) await prefs?.setBool(_key, true);
    } catch (_) {}
    try {
      if (!fileDone) await marker?.writeAsString('1', flush: true);
    } catch (_) {}
    return true;
  }

  static Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setBool(_key, true);
    } catch (_) {}
    try {
      final marker = await _marker();
      await marker?.parent.create(recursive: true);
      await marker?.writeAsString('1', flush: true);
    } catch (_) {}
  }
}
