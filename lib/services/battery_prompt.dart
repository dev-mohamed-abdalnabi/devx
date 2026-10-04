import 'dart:io' show Platform;
import 'package:azkari_native/azkari_native.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/support_app_button.dart';

/// بعض الأجهزة (شاومي، أوبو، سامسونج…) توقف التطبيق في الخلفية لتوفير البطارية،
/// فتنقطع التلاوة وتفشل أزرار الإشعار. نشرح ذلك مرة واحدة ونفتح إعداد الاستثناء.
class BatteryPrompt {
  BatteryPrompt._();
  static const _key = 'battery_prompt_shown_v1';
  static bool _showing = false;

  static Future<void> maybeAsk() async {
    if (!Platform.isAndroid || _showing) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key) ?? false) return;
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      _showing = true;
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (c) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('استمرار التلاوة في الخلفية'),
            content: const Text(
                'حتى لا يوقف الجهاز التلاوة أو الأذان بعد خروجك من التطبيق، اسمح لـ«ذكر» '
                'بالعمل دون قيود البطارية. ستظهر لك نافذة من النظام، اختر «سماح».'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(false), child: const Text('لاحقًا')),
              FilledButton(
                  onPressed: () => Navigator.of(c).pop(true), child: const Text('متابعة')),
            ],
          ),
        ),
      );
      _showing = false;
      // نسجّل أنه عُرض في الحالتين حتى لا نزعج المستخدم في كل تشغيل.
      await prefs.setBool(_key, true);
      if (ok == true) await AzkariNative.requestIgnoreBatteryOptimizations();
    } catch (_) {
      _showing = false;
    }
  }
}
