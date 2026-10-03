import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/notification_service.dart';
import '../../providers/quran_audio_provider.dart';

/// شاشة فحص بسيطة: تقول بالضبط لماذا لا يظهر إشعار الميديا أو لا يعمل الأذان.
class NotificationCheckScreen extends StatefulWidget {
  const NotificationCheckScreen({super.key});

  @override
  State<NotificationCheckScreen> createState() =>
      _NotificationCheckScreenState();
}

class _NotificationCheckScreenState extends State<NotificationCheckScreen> {
  late Future<NotificationStatus> _status = NotificationService.status();

  void _refresh() => setState(() => _status = NotificationService.status());

  Widget _row({
    required bool? ok,
    required String title,
    required String detail,
    Widget? action,
  }) {
    final color = ok == null
        ? Colors.grey
        : (ok ? Colors.green.shade700 : Colors.red.shade700);
    return Card(
      child: ListTile(
        leading: Icon(
          ok == null
              ? Icons.help_outline_rounded
              : (ok ? Icons.check_circle_rounded : Icons.cancel_rounded),
          color: color,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
        trailing: action,
        isThreeLine: detail.length > 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaError = QuranAudioProvider.backgroundInitError;
    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص الأذان والإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<NotificationStatus>(
        future: _status,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _row(
                ok: s.notificationsEnabled,
                title: 'إذن الإشعارات',
                detail: s.notificationsEnabled == false
                    ? 'مغلق. بدونه لن يظهر إشعار الميديا ولن يعمل الأذان. افتح إعدادات التطبيق ← الإشعارات ← فعّلها.'
                    : 'مفعّل',
                action: s.notificationsEnabled == false
                    ? TextButton(
                        onPressed: () => Geolocator.openAppSettings(),
                        child: const Text('الإعدادات'),
                      )
                    : null,
              ),
              _row(
                ok: s.exactAlarms,
                title: 'التنبيه في الوقت الدقيق',
                detail: s.exactAlarms == false
                    ? 'غير مسموح؛ قد يتأخر الأذان. اسمح بـ «المنبهات والتذكيرات».'
                    : 'مسموح',
                action: s.exactAlarms == false
                    ? TextButton(
                        onPressed: () async {
                          await NotificationService.requestExactPermission();
                          _refresh();
                        },
                        child: const Text('السماح'),
                      )
                    : null,
              ),
              _row(
                ok: s.adhanSoundOk,
                title: 'ملف صوت الأذان داخل التطبيق',
                detail: s.adhanSoundOk
                    ? 'موجود (res/raw/adhan)'
                    : 'غير موجود في الـ APK؛ الأذان سيعمل بصوت النظام فقط. '
                        'شغّل tool/patch_android.py قبل البناء وتأكد من وجود assets/audio/adhan.ogg.',
              ),
              _row(
                ok: s.adhanChannel == null ? null : s.adhanChannel == 'مفعّلة',
                title: 'قناة الأذان',
                detail: s.adhanChannel ?? 'لم تُنشأ بعد',
              ),
              _row(
                ok: s.pending > 0,
                title: 'أذانات مجدولة',
                detail: s.pending > 0
                    ? '${s.pending} تنبيه في الانتظار'
                    : 'لا يوجد. اختر مدينتك من شاشة المواقيت وفعّل الأذان.',
              ),
              _row(
                ok: s.statIconOk,
                title: 'أيقونة إشعار الميديا',
                detail: s.statIconOk
                    ? 'موجودة (ic_stat_quran)'
                    : 'غير موجودة؛ استُخدمت أيقونة التطبيق بدلها. شغّل tool/patch_android.py وأعد البناء.',
              ),
              _row(
                ok: mediaError != null
                    ? false
                    : (s.mediaChannel == 'مفعّلة' && s.mediaActive == true
                        ? true
                        : (s.mediaChannel != null && s.mediaChannel != 'مفعّلة'
                            ? false
                            : null)),
                title: 'خدمة إشعار القرآن (ميديا)',
                detail: mediaError != null
                    ? 'فشلت التهيئة: $mediaError'
                    : (s.mediaChannel == null
                        ? 'لم تبدأ بعد. شغّل أي سورة ثم اضغط تحديث.'
                        : (s.mediaChannel != 'مفعّلة'
                            ? 'قناة الميديا ${s.mediaChannel}. فعّلها من إعدادات التطبيق ← الإشعارات ← تلاوة القرآن.'
                            : (s.mediaActive == true
                                ? 'تعمل. الإشعار ظاهر الآن.'
                                : 'القناة موجودة لكن لا يوجد إشعار ظاهر حاليًا. '
                                    'شغّل سورة ثم اضغط تحديث؛ لو لم يظهر فاسمح للتطبيق بالعمل في الخلفية بدون قيود بطارية.'))),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    final msg = await NotificationService.testAdhanNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg)));
                      _refresh();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذّر عرض الإشعار: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('جرّب الأذان الآن'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Geolocator.openAppSettings(),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('فتح إعدادات التطبيق'),
              ),
            ],
          );
        },
      ),
    );
  }
}
