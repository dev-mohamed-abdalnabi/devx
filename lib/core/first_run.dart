import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// هل أنهى المستخدم شاشة الترحيب من قبل؟
///
/// نخزّن العلامة في مكانين مستقلين: SharedPreferences وملف صغير في مجلد التطبيق.
/// إن قرأنا أيًّا منهما صحيحًا نعدّه منتهيًا ونرمّم الآخر، فلا يعود الترحيب بسبب
/// فشل قراءة مؤقت في أحدهما. وعند فشل القراءة كليًا لا نعيد المستخدم القديم للترحيب
/// إن كانت لديه بيانات محفوظة سابقة.
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
    var prefsDone = false;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      prefsDone = prefs.getBool(_key) ?? false;
    } catch (_) {}
    var fileDone = false;
    final f = await _marker();
    try {
      fileDone = f != null && await f.exists();
    } catch (_) {}
    if (prefsDone || fileDone) {
      // ترميم المكان الناقص.
      try {
        if (!prefsDone) await prefs?.setBool(_key, true);
        if (!fileDone && f != null) await f.writeAsString('1', flush: true);
      } catch (_) {}
      return true;
    }
    return false;
  }

  static Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {}
    try {
      final f = await _marker();
      await f?.writeAsString('1', flush: true);
    } catch (_) {}
  }
}
