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
}
