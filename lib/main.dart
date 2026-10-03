import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'providers/quran_provider.dart';
import 'providers/quran_audio_provider.dart';
import 'providers/activity_provider.dart';
import 'providers/azkar_provider.dart';
import 'providers/notification_service.dart';
import 'providers/prayer_provider.dart';
import 'providers/reminders_provider.dart';
import 'screens/onboarding_screen.dart';
import 'services/supabase_config.dart';
import 'widgets/support_app_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.validate();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  final normalAudioPlatform = JustAudioPlatform.instance;
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.azkarapp.quran_audio',
      androidNotificationChannelName: 'تلاوة القرآن',
      androidNotificationChannelDescription: 'التحكم في تلاوة القرآن من الإشعارات',
      // إشعار الوسائط يجب أن يبقى ظاهرًا خارج التطبيق حتى بعد الضغط على إيقاف.
      // هذا يتيح استكمال التشغيل والتحكم في السابق/التالي من شريط الإشعارات.
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidResumeOnClick: true,
      androidNotificationClickStartsActivity: true,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'drawable/ic_stat_quran',
      notificationColor: const Color(0xFF2F6B55),
      fastForwardInterval: const Duration(seconds: 10),
      rewindInterval: const Duration(seconds: 10),
      preloadArtwork: true,
    );
  } catch (e) {
    // إذا فشلت خدمة الخلفية، أعد المشغل العادي حتى لا ينهار عند أول تشغيل،
    // واحفظ السبب ليظهر في شاشة «القرآن صوتيًا» بدل أن يختفي الإشعار بصمت.
    QuranAudioProvider.backgroundInitError = e.toString();
    JustAudioPlatform.instance = normalAudioPlatform;
  }
  try {
    await NotificationService.init();
    await NotificationService.requestPermission();
  } catch (_) {
    // فشل تهيئة الإشعارات لا يجب أن يمنع فتح التطبيق.
  }
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
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const StartupScreen(),
          );
        },
      ),
    );
  }
}
