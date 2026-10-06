import 'dart:async';
import 'dart:convert';

import 'package:azkari_native/azkari_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/daily_ayah.dart';
import '../core/widget_snapshot.dart';
import '../features/prayer/prayer_screen.dart';
import '../features/quran/quran_home_screen.dart' show openReader;
import '../screens/categories_screen.dart';
import '../screens/zikr_list_screen.dart';
import '../widgets/support_app_button.dart' show appNavigatorKey;
import '../models/zikr.dart';
import '../providers/azkar_provider.dart';
import '../providers/prayer_provider.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/quran_provider.dart';

/// يُضبط true حين تظهر الرئيسية (بعد الشاشة الافتتاحية)، فتُفتح وجهة الودجت بعدها.
class WidgetLinks {
  WidgetLinks._();
  static final ValueNotifier<bool> homeReady = ValueNotifier<bool>(false);
}

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
  Timer? _retry;
  StreamSubscription<void>? _pings;
  String? _pending;
  int _tries = 0;
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
    _pings = AzkariNative.widgetTargetPings.listen((_) => _consume());
    _consume();
  }

  @override
  void dispose() {
    _pings?.cancel();
    _retry?.cancel();
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

  // ===== فتح وجهة الودجت =====
  Future<void> _consume() async {
    final t = await AzkariNative.takeWidgetTarget();
    if (t == null || !mounted) return;
    _pending = t;
    _tries = 0;
    _retry?.cancel();
    // الشاشة الافتتاحية أو تحميل القرآن قد يتأخران: نعيد المحاولة كل ٣٠٠ms حتى ٩ ثوانٍ.
    _retry = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_open() || ++_tries > 30) timer.cancel();
    });
  }

  bool _open() {
    final t = _pending;
    if (t == null) return true;
    if (!WidgetLinks.homeReady.value) return false;
    final nav = appNavigatorKey.currentState;
    final ctx = appNavigatorKey.currentContext;
    if (nav == null || ctx == null || !mounted) return false;

    Widget? page;
    switch (t) {
      case 'prayer':
        page = const PrayerScreen();
        break;
      case 'azkar':
        final azkar = context.read<AzkarProvider>();
        final h = DateTime.now().hour;
        final cat = h >= 3 && h < 15
            ? _category(azkar, 'hisn-27', const ['أذكار الصباح', 'الصباح'])
            : h >= 15 && h < 21
                ? _category(azkar, 'hisn-27e', const ['أذكار المساء', 'المساء'])
                : _category(azkar, 'hisn-28', const ['النوم']);
        page = cat == null
            ? const CategoriesScreen()
            : ZikrListScreen(categoryId: cat.id);
        break;
      case 'ayah':
        final data = context.read<QuranProvider>().data;
        if (data == null || data.ayahs.isEmpty) return false; // لم يُحمَّل بعد
        final a = pickDailyAyah(dailyAyahPool(data.ayahs), DateTime.now());
        _pending = null;
        nav.popUntil((r) => r.isFirst);
        openReader(ctx, a.page, highlight: '${a.surah}:${a.number}');
        return true;
    }
    _pending = null;
    nav.popUntil((r) => r.isFirst);
    if (page != null) {
      final w = page;
      nav.push(MaterialPageRoute(builder: (_) => w));
    }
    return true;
  }

  AzkarCategory? _category(AzkarProvider p, String id, List<String> titles) {
    for (final c in p.categories) {
      if (c.id == id) return c;
    }
    for (final t in titles) {
      for (final c in p.categories) {
        if (c.title.contains(t)) return c;
      }
    }
    return null;
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
