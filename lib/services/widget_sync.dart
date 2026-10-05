import 'dart:async';
import 'dart:convert';

import 'package:azkari_native/azkari_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/widget_snapshot.dart';
import '../models/zikr.dart';
import '../providers/azkar_provider.dart';
import '../providers/prayer_provider.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/quran_provider.dart';

/// يرسل لقطة البيانات لودجتس الشاشة الرئيسية للهاتف (أندرويد فقط).
/// خفيف عمدًا: تأخير ٣ ثوانٍ لتجميع التغييرات، ولا يرسل إن لم تتغيّر اللقطة،
/// ويرسل فورًا عند مغادرة التطبيق كي يظهر آخر تقدّم على الودجت.
class WidgetSyncHost extends StatefulWidget {
  final Widget child;
  const WidgetSyncHost({super.key, required this.child});

  @override
  State<WidgetSyncHost> createState() => _WidgetSyncHostState();
}

class _WidgetSyncHostState extends State<WidgetSyncHost>
    with WidgetsBindingObserver {
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Timer? _debounce;
  String _last = '';
  late final List<ChangeNotifier> _watched;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    _watched = [
      context.read<AzkarProvider>(),
      context.read<PrayerProvider>(),
      context.read<QuranProvider>(),
    ];
    for (final n in _watched) {
      n.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void dispose() {
    if (_supported) {
      WidgetsBinding.instance.removeObserver(this);
      for (final n in _watched) {
        n.removeListener(_schedule);
      }
    }
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
    } else {
      _debounce?.cancel();
      unawaited(_send());
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => unawaited(_send()));
  }

  double _slotProgress(AzkarProvider p, String id, List<String> titles) {
    AzkarCategory? cat;
    for (final c in p.categories) {
      if (c.id == id) cat = c;
    }
    if (cat == null) {
      outer:
      for (final t in titles) {
        for (final c in p.categories) {
          if (c.title.contains(t)) {
            cat = c;
            break outer;
          }
        }
      }
    }
    return cat == null ? 0.0 : p.categoryProgress(cat.id);
  }

  Future<void> _send() async {
    if (!mounted) return;
    try {
      final azkar = context.read<AzkarProvider>();
      final prayer = context.read<PrayerProvider>();
      final quran = context.read<QuranProvider>();
      if (prayer.loading) return; // لم تُقرأ الإعدادات بعد: لا نرسل لقطة ناقصة

      final snap = buildWidgetSnapshot(
        now: DateTime.now(),
        theme: switch (azkar.themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
        azkar: [
          _slotProgress(azkar, 'hisn-27', const ['أذكار الصباح', 'الصباح']),
          _slotProgress(azkar, 'hisn-27e', const ['أذكار المساء', 'المساء']),
          _slotProgress(azkar, 'hisn-28', const ['النوم']),
        ],
        hasLocation: prayer.hasLocation,
        place: prayer.placeName,
        timesFor: prayer.timesFor,
        hijriFor: (d) => prayer.hijriFor(d).format(),
        isDone: prayer.isDone,
        ayahs: quran.data?.ayahs ?? const [],
        surahName: QuranAudioProvider.surahName,
      );
      final json = jsonEncode(snap);
      if (json == _last) return;
      if (await AzkariNative.updateWidgets(json)) _last = json;
    } catch (_) {
      // الودجتس ميزة إضافية: فشلها لا يجب أن يؤثر على التطبيق.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
