import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/home_tokens.dart';
import 'core/theme.dart';
import 'providers/quran_provider.dart';
import 'providers/quran_audio_provider.dart';
import 'services/quran_audio_handler.dart';
import 'providers/activity_provider.dart';
import 'providers/azkar_provider.dart';
import 'providers/notification_service.dart';
import 'providers/prayer_provider.dart';
import 'providers/reminders_provider.dart';
import 'providers/stories_provider.dart';
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
  // كل الاتجاهات مدعومة: الشاشات تتكيّف مع الأفقي (لوحتان) والعمودي.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  // لا ننتظر الخدمات الاختيارية قبل runApp؛ تعليق الشبكة أو Android service
  // كان يترك التطبيق على شاشة سوداء قبل أن تظهر حتى شاشة البداية.
  runApp(const AzkarApp());
  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  // Supabase مطلوب فقط عند فتح ميزات المجتمع، ولا يجب أن يمنع العمل Offline.
  try {
    SupabaseConfig.validate();
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    ).timeout(const Duration(seconds: 5));
  } catch (_) {
    // التطبيق الأساسي يعمل بدون اتصال أو إعداد Supabase صالح.
  }

  // الإشعارات اختيارية، وتطلب صلاحياتها لاحقًا من شاشة الترحيب.
  try {
    await NotificationService.init().timeout(const Duration(seconds: 5));
  } catch (_) {
    // فشل الإشعارات لا يمنع فتح التطبيق.
  }

  // خدمة الميديا اختيارية؛ لا نسمح لها بتعطيل الواجهة عند بطء Android.
  try {
    await QuranAudioService.init().timeout(const Duration(seconds: 5));
  } catch (_) {
    // التشغيل الأساسي يعمل حتى بدون إشعار الميديا.
  }
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
        // لا نقرأ SharedPreferences أثناء الإقلاع؛ تهيئة القصص تبدأ عند فتحها.
        ChangeNotifierProvider(create: (_) => StoriesProvider()),
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
                // عمود المحتوى: على التابلت لا يتجاوز 600dp، وعلى الهاتف يملأ الشاشة. نمرّر للشاشات
                // العرض الحقيقي للعمود (وليس عرض الجهاز) حتى تحسب تخطيطها صح،
                // ونصفّر حواف الشاشة الجانبية لأن العمود لا يلمسها.
                // الهاتف يملأ الشاشة كلها؛ الحد الأقصى للعرض للتابلت فقط.
                final isTablet = mq.size.shortestSide >= 600;
                final landscape = mq.size.width > mq.size.height;
                final colW = isTablet
                    ? math.min(mq.size.width, landscape ? 1000.0 : 600.0)
                    : mq.size.width;
                final narrowed = mq.size.width > colW;
                final fitted = mq.copyWith(
                  size: Size(colW, mq.size.height),
                  textScaler: TextScaler.linear(scale),
                  padding:
                      narrowed ? mq.padding.copyWith(left: 0, right: 0) : null,
                  viewPadding: narrowed
                      ? mq.viewPadding.copyWith(left: 0, right: 0)
                      : null,
                );
                final sideBg = HomeTokens.of(context).bg;
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
                    data: fitted,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      // خلفية تملأ الجانبين على التابلت بدل الفراغ الأسود/الأبيض.
                      child: ColoredBox(
                        color: sideBg,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: colW,
                            height: mq.size.height,
                            child: child!,
                          ),
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
