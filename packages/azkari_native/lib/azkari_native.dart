/// موارد وإعدادات أندرويد الأصلية + أداة تشخيص تقول بالضبط لماذا لا يظهر إشعار الميديا.
library azkari_native;

import 'dart:async';
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

  /// تجربة الأذان الآن: يفتح شاشة الأذان الكاملة ويشغّل الصوت والفيديو معًا.
  static Future<bool> testAdhan(String name) =>
      _bool('testAdhan', {'name': name});

  /// أندرويد 14+: هل يسمح النظام بعرض الأذان بملء الشاشة فوق القفل؟
  static Future<bool> canUseFullScreenIntent() =>
      _bool('canUseFullScreenIntent');
  static Future<bool> requestFullScreenIntent() =>
      _bool('requestFullScreenIntent');

  static Future<bool> cancelAdhan() => _bool('cancelAdhan');
  static Future<bool> stopAdhan() => _bool('stopAdhan');

  /// قفل CPU جزئي أثناء تشغيل التلاوة.
  static Future<bool> setKeepAwake(bool on) =>
      _bool('setKeepAwake', {'on': on});

  /// true = مستثنى من توفير البطارية؛ false = فُتحت نافذة النظام لطلب ذلك.
  static Future<bool> requestIgnoreBatteryOptimizations() =>
      _bool('requestIgnoreBatteryOptimizations');

  // ===== ودجتس الشاشة الرئيسية للهاتف =====

  /// يحفظ لقطة البيانات (JSON) للجانب الأصلي ويحدّث الودجتس فورًا. الودجتس تقرأها محليًا فقط.
  static Future<bool> updateWidgets(String json) =>
      _bool('updateWidgets', {'json': json});

  /// يطلب من اللانشر إضافة ودجت: kind = hero | ayah | prayer. false لو غير مدعوم (أندرويد < 8 أو لانشر قديم).
  static Future<bool> pinWidget(String kind) =>
      _bool('pinWidget', {'kind': kind});

  /// عدد النسخ المضافة من كل ودجت: {hero, ayah, prayer}.
  static Future<Map<String, int>> widgetCounts() async {
    try {
      final raw =
          await _channel.invokeMapMethod<String, dynamic>('widgetCounts');
      return {
        for (final k in const ['hero', 'ayah', 'prayer'])
          k: (raw?[k] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return const {'hero': 0, 'ayah': 0, 'prayer': 0};
    }
  }

  /// الوجهة التي طلبها ضغط ودجت (azkar | ayah | prayer) أو null. تُقرأ مرة واحدة.
  static Future<String?> takeWidgetTarget() async {
    try {
      return await _channel.invokeMethod<String>('takeWidgetTarget');
    } catch (_) {
      return null;
    }
  }

  static final StreamController<void> _targetPings =
      StreamController<void>.broadcast();
  static bool _handlerSet = false;

  /// ينبّه عند ضغط ودجت والتطبيق شغّال (ثم استدعِ [takeWidgetTarget]).
  static Stream<void> get widgetTargetPings {
    if (!_handlerSet) {
      _handlerSet = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'widgetTarget') _targetPings.add(null);
      });
    }
    return _targetPings.stream;
  }
}
