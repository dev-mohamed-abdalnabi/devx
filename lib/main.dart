import 'services/community_realtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'providers/quran_provider.dart';
import 'providers/quran_audio_provider.dart';
import 'services/quran_audio_handler.dart';
import 'providers/activity_provider.dart';
import 'providers/azkar_provider.dart';
import 'providers/notification_service.dart';
import 'providers/prayer_provider.dart';
import 'providers/reminders_provider.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_config.dart';
import 'services/widget_sync.dart';
import 'widgets/support_app_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // شريط حالة وشريط تنقل شفافان 100%: المحتوى يمتد خلفهما (edge-to-edge).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  ));
  SupabaseConfig.validate();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  // الإشعارات أولًا: تحدد هل أيقونة ic_stat_quran موجودة (غيابها يخفي إشعار الميديا بصمت).
  try {
    await NotificationService.init();
    // طلب إذن الإشعارات انتقل لشاشة الترحيب (اختياري) بدل الطلب المباشر عند أول فتح.
  } catch (_) {
    // فشل تهيئة الإشعارات لا يجب أن يمنع فتح التطبيق.
  }
  // خدمة الميديا (إشعار التلاوة). لا ترمي أخطاء: لو فشلت يعمل التشغيل بدون إشعار.
  await QuranAudioService.init();
  CommunityRealtime.start();
  runApp(const AzkarApp());
}

class AzkarApp extends StatelessWidget {
  const AzkarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AzkarProvider()..init()),
        ChangeNotifierProvider(create: (_) => QuranProvider()..init()),
        ChangeNotifierProvider(create: (_) => QuranAudioProvider()..init()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()..init()),
        ChangeNotifierProvider(create: (_) => PrayerProvider()..init()),
        ChangeNotifierProvider(create: (_) => RemindersProvider()..init()),
      ],
      child: WidgetSyncHost(
        child: Consumer<AzkarProvider>(
          builder: (context, provider, _) {
            return MaterialApp(
              title: 'ذكر',
              debugShowCheckedModeBanner: false,
              navigatorKey: appNavigatorKey,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // تجربة موحّدة على كل الأجهزة: نتجاهل مقياس الخط وحجم العرض في النظام
              // (وهما سبب الخط الصغير/الكبير جدًا) ونضبط الحجم حسب عرض الشاشة نفسه.
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                final scale =
                    (mq.size.shortestSide / 392).clamp(0.88, 1.15).toDouble();
                final dark = Theme.of(context).brightness == Brightness.dark;
                final icons = dark ? Brightness.light : Brightness.dark;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: icons,
                    statusBarBrightness:
                        dark ? Brightness.dark : Brightness.light,
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarIconBrightness: icons,
                    systemStatusBarContrastEnforced: false,
                    systemNavigationBarContrastEnforced: false,
                  ),
                  child: MediaQuery(
                    data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: child!,
                        ),
                      ),
                    ),
                  ),
                );
              },
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: provider.themeMode,
              home: const SplashScreen(),
            );
          },
        ),
      ),
    );
  }
}
