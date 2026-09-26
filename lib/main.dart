import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/azkar_provider.dart';
import 'providers/notification_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const AzkarApp());
}

class AzkarApp extends StatelessWidget {
  const AzkarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AzkarProvider()..init(),
      child: Consumer<AzkarProvider>(
        builder: (context, provider, _) {
          final baseTextTheme = GoogleFonts.notoNaskhArabicTextTheme();
          final seed = const Color(0xFF2E7D5B); // أخضر هادئ

          return MaterialApp(
            title: 'أذكاري',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: seed),
              textTheme: baseTextTheme,
              scaffoldBackgroundColor: const Color(0xFFF6F4EF),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.dark,
              ),
              textTheme: baseTextTheme,
              scaffoldBackgroundColor: const Color(0xFF121212),
            ),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
