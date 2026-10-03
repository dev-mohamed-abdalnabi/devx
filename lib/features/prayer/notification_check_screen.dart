import 'package:azkari_native/azkari_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_service.dart';
import '../../providers/quran_audio_provider.dart';
import '../../services/quran_audio_handler.dart';

class _Snapshot {
  final NotificationStatus status;
  final Map<String, dynamic> native;
  const _Snapshot(this.status, this.native);

  bool? flag(String key) {
    final v = native[key];
    return v is bool ? v : null;
  }

  int? number(String key) {
    final v = native[key];
    return v is int ? v : null;
  }

  /// هل يوجد إشعار ظاهر الآن على قناة التلاوة؟
  bool? get mediaNotificationShown {
    final list = native['activeNotifications'];
    if (list is! List) return status.mediaActive;
    return list.any((e) => e.toString().endsWith('|${NotificationService.mediaChannelId}'));
  }
}

/// شاشة فحص: تقول بالضبط لماذا لا يظهر إشعار الميديا أو لا يعمل الأذان.
class NotificationCheckScreen extends StatefulWidget {
  const NotificationCheckScreen({super.key});

  @override
  State<NotificationCheckScreen> createState() => _NotificationCheckScreenState();
}

class _NotificationCheckScreenState extends State<NotificationCheckScreen> {
  late Future<_Snapshot> _snapshot = _load();
  _Snapshot? _last;

  Future<_Snapshot> _load() async {
    final status = await NotificationService.status();
    final native = await AzkariNative.diagnose();
    final snap = _Snapshot(status, native);
    _last = snap;
    return snap;
  }

  void _refresh() => setState(() => _snapshot = _load());

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _row({
    required bool? ok,
    required String title,
    required String detail,
    Widget? action,
  }) {
    final color = ok == null ? Colors.grey : (ok ? Colors.green.shade700 : Colors.red.shade700);
    return Card(
      child: ListTile(
        leading: Icon(
          ok == null ? Icons.help_outline_rounded : (ok ? Icons.check_circle_rounded : Icons.cancel_rounded),
          color: color,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
        trailing: action,
        isThreeLine: detail.length > 60,
      ),
    );
  }

  Future<void> _testMedia() async {
    final audio = context.read<QuranAudioProvider>();
    if (!audio.hasAnyAudio) {
      _toast('نزّل التلاوة أولًا من شاشة «القرآن صوتيًا» ثم جرّب مرة أخرى.');
      return;
    }
    final surah = audio.hasSurah(2) ? 2 : audio.availableSurahs.first;
    await audio.playSurah(surah);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _refresh();
    _toast(audio.error ?? 'بدأ تشغيل سورة ${QuranAudioProvider.surahName(surah)} — راجع صف «إشعار التلاوة الآن».');
  }

  String _report(_Snapshot s) {
    final b = StringBuffer('تقرير فحص ذكر\n');
    b.writeln('audio handler ready: ${QuranAudioService.handler != null}');
    b.writeln('audio init error: ${QuranAudioService.initError}');
    b.writeln('notifications enabled: ${s.status.notificationsEnabled}');
    b.writeln('exact alarms: ${s.status.exactAlarms}');
    b.writeln('media channel: ${s.status.mediaChannel}');
    b.writeln('media notification shown: ${s.mediaNotificationShown}');
    b.writeln('adhan sound ok: ${s.status.adhanSoundOk}');
    s.native.forEach((k, v) => b.writeln('native.$k: $v'));
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final handlerReady = QuranAudioService.handler != null;
    final initError = QuranAudioService.initError;
    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص الأذان والإشعارات'),
        actions: [
          IconButton(
            tooltip: 'نسخ التقرير',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final snap = _last;
              if (snap == null) return;
              await Clipboard.setData(ClipboardData(text: _report(snap)));
              _toast('تم نسخ التقرير');
            },
          ),
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<_Snapshot>(
        future: _snapshot,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data!;
          final st = s.status;
          final activityOk = s.flag('activityIsAudioService');
          final serviceDeclared = s.flag('audioServiceDeclared');
          final serviceMedia = s.flag('audioServiceMediaType');
          final iconId = s.number('statIconId');
          final fgsPermission = s.flag('fgsMediaPermission');
          final battery = s.flag('ignoringBatteryOptimizations');
          final shown = s.mediaNotificationShown;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _row(
                ok: st.notificationsEnabled,
                title: 'إذن الإشعارات',
                detail: st.notificationsEnabled == false
                    ? 'مغلق. بدونه لن يظهر إشعار الميديا ولن يعمل الأذان. افتح إعدادات التطبيق ← الإشعارات ← فعّلها.'
                    : 'مفعّل',
                action: st.notificationsEnabled == false
                    ? TextButton(
                        onPressed: () => Geolocator.openAppSettings(),
                        child: const Text('الإعدادات'),
                      )
                    : null,
              ),
              _row(
                ok: st.exactAlarms,
                title: 'التنبيه في الوقت الدقيق',
                detail: st.exactAlarms == false
                    ? 'غير مسموح؛ قد يتأخر الأذان. اسمح بـ «المنبهات والتذكيرات».'
                    : 'مسموح',
                action: st.exactAlarms == false
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
                ok: st.adhanSoundOk,
                title: 'ملف صوت الأذان داخل التطبيق',
                detail: st.adhanSoundOk
                    ? 'موجود (res/raw/adhan)'
                    : 'غير موجود في الـ APK؛ الأذان سيعمل بصوت النظام فقط.',
              ),
              _row(
                ok: st.adhanChannel == null ? null : st.adhanChannel == 'مفعّلة',
                title: 'قناة الأذان',
                detail: st.adhanChannel ?? 'لم تُنشأ بعد',
              ),
              _row(
                ok: st.pending > 0,
                title: 'أذانات مجدولة',
                detail: st.pending > 0
                    ? '${st.pending} تنبيه في الانتظار'
                    : 'لا يوجد. اختر مدينتك من شاشة المواقيت وفعّل الأذان.',
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 14, 4, 4),
                child: Text('إشعار التلاوة (ميديا)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              _row(
                ok: handlerReady,
                title: 'خدمة الميديا (audio_service)',
                detail: handlerReady ? 'تعمل' : 'فشلت التهيئة: ${initError ?? 'سبب غير معروف'}',
              ),
              _row(
                ok: activityOk,
                title: 'النشاط الرئيسي MainActivity',
                detail: activityOk == null
                    ? 'تعذّر الفحص'
                    : (activityOk
                        ? 'مرتبط بـ AudioServiceActivity'
                        : 'ليس AudioServiceActivity (${s.native['activityClass']}). شغّل tool/patch_android.py ثم أعد البناء.'),
              ),
              _row(
                ok: serviceDeclared == null ? null : (serviceDeclared && serviceMedia != false),
                title: 'خدمة الميديا في المانيفست',
                detail: serviceDeclared == null
                    ? 'تعذّر الفحص'
                    : (!serviceDeclared
                        ? 'AudioService غير موجودة في المانيفست النهائي'
                        : (serviceMedia == false
                            ? 'موجودة لكن بدون نوع mediaPlayback (أندرويد 14+ يرفضها)'
                            : 'موجودة بنوع mediaPlayback')),
              ),
              _row(
                ok: fgsPermission,
                title: 'إذن خدمة تشغيل الميديا',
                detail: fgsPermission == false
                    ? 'FOREGROUND_SERVICE_MEDIA_PLAYBACK غير موجود في المانيفست'
                    : 'موجود',
              ),
              _row(
                ok: iconId == null ? st.statIconOk : iconId > 0,
                title: 'أيقونة الإشعار الشفافة',
                detail: (iconId == null ? st.statIconOk : iconId > 0)
                    ? 'موجودة (ic_stat_blank)'
                    : 'غير موجودة في الـ APK؛ سيُستخدم رمز التطبيق بدلها.',
              ),
              _row(
                ok: st.mediaChannel == null ? null : st.mediaChannel == 'مفعّلة',
                title: 'قناة التلاوة',
                detail: st.mediaChannel == null
                    ? 'لم تُنشأ بعد. شغّل أي سورة ثم اضغط تحديث.'
                    : (st.mediaChannel == 'مفعّلة'
                        ? 'مفعّلة'
                        : 'قناة التلاوة ${st.mediaChannel}. فعّلها من إعدادات التطبيق ← الإشعارات ← تلاوة القرآن.'),
              ),
              _row(
                ok: shown,
                title: 'إشعار التلاوة الآن',
                detail: shown == true
                    ? 'ظاهر الآن ✔'
                    : 'غير ظاهر. شغّل سورة ثم اضغط تحديث (أو استخدم زر «جرّب إشعار التلاوة»).',
              ),
              _row(
                ok: battery,
                title: 'قيود البطارية',
                detail: battery == true
                    ? 'التطبيق مستثنى من توفير البطارية'
                    : 'التطبيق خاضع لتوفير البطارية؛ بعض الأجهزة توقف التلاوة في الخلفية. '
                        'اختر «بدون قيود» من إعدادات التطبيق ← البطارية.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _testMedia,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('جرّب إشعار التلاوة'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    final msg = await NotificationService.testAdhanNow();
                    if (!mounted) return;
                    _toast(msg);
                    _refresh();
                  } catch (e) {
                    _toast('تعذّر عرض الإشعار: $e');
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
