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
  // أي تهيئة تتعثر (شبكة، إشعارات، ميديا) لا يجوز أن تُبقي الشاشة سوداء:
  // نحدّد لكل خطوة مهلة ونتجاوز فشلها، ثم نفتح التطبيق دائمًا.
  try {
    SupabaseConfig.validate();
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    ).timeout(const Duration(seconds: 8));
  } catch (_) {
    // المجتمع فقط يتأثر؛ باقي التطبيق يعمل بدون Supabase.
  }
  // الإشعارات أولًا: تحدد هل أيقونة ic_stat_quran موجودة (غيابها يخفي إشعار الميديا بصمت).
  try {
    await NotificationService.init().timeout(const Duration(seconds: 8));
  } catch (_) {
    // فشل تهيئة الإشعارات لا يجب أن يمنع فتح التطبيق.
  }
  // خدمة الميديا (إشعار التلاوة). لها مهلة داخلية 10 ثوانٍ؛ نغلّف الباقي أيضًا.
  try {
    await QuranAudioService.init();
  } catch (_) {}
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
        ChangeNotifierProvider(create: (_) => StoriesProvider()..init()),
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
