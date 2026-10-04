/// موارد وإعدادات أندرويد الأصلية + أداة تشخيص تقول بالضبط لماذا لا يظهر إشعار الميديا.
library azkari_native;

import 'package:flutter/services.dart';

class AzkariNative {
  AzkariNative._();

  static const MethodChannel _channel = MethodChannel('azkari_native');

  /// يعيد حالة الجانب الأصلي: نوع MainActivity، خدمة الميديا في المانيفست،
  /// الأيقونة الشفافة، الإذونات، الإشعارات الظاهرة، وقيود البطارية.
  /// لا يرمي أخطاء؛ عند الفشل يعيد {'error': ...}.
  static Future<Map<String, dynamic>> diagnose() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('diagnose');
      return raw ?? const <String, dynamic>{};
    } catch (e) {
      return <String, dynamic>{'error': e.toString()};
    }
  }

  static Future<bool> _bool(String m, [Map<String, dynamic>? args]) async {
    try {
      return (await _channel.invokeMethod<bool>(m, args)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// يجدول الأذان الكامل (منبّه دقيق + خدمة تشغيل). كل عنصر: id (int)، time (ms)، name.
  static Future<bool> scheduleAdhan(List<Map<String, Object>> entries) =>
      _bool('scheduleAdhan', {'entries': entries});

  static Future<bool> cancelAdhan() => _bool('cancelAdhan');
  static Future<bool> stopAdhan() => _bool('stopAdhan');

  /// قفل CPU جزئي أثناء تشغيل التلاوة.
  static Future<bool> setKeepAwake(bool on) => _bool('setKeepAwake', {'on': on});

  /// true = مستثنى من توفير البطارية؛ false = فُتحت نافذة النظام لطلب ذلك.
  static Future<bool> requestIgnoreBatteryOptimizations() =>
      _bool('requestIgnoreBatteryOptimizations');
}
