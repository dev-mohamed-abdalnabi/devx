import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/home_tokens.dart';
import '../core/text_utils.dart';
import '../core/page_background.dart';
import '../services/widget_sync.dart' show WidgetLinks;
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// شاشة الفتح: شعار «ذِكر» (قبة + هلال + «ذكر») على نفس خلفية ونقش وألوان الرئيسية.
/// تظهر لحظات أثناء قراءة الإعدادات، ثم تنتقل بتلاشي إلى الترحيب أو الرئيسية.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    _go(reduce ? 300 : 1300);
  }

  Future<void> _go(int minMs) async {
    var done = false;
    try {
      final results = await Future.wait<Object?>([
        SharedPreferences.getInstance()
            .timeout(const Duration(seconds: 3))
            .then((p) => p.getBool('onboarding_completed') ?? false),
        Future<void>.delayed(Duration(milliseconds: minMs)),
      ]).timeout(Duration(milliseconds: minMs + 4000));
      done = results.first == true;
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) =>
          done ? const HomeScreen() : const OnboardingScreen(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
    if (done) WidgetLinks.homeReady.value = true;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b,
          [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // الشعار الأصلي كريمي (شفاف الخلفية): نلوّنه بحسب الوضع ليظهر على خلفية الرئيسية.
    final logoColor = dark ? tk.ink : const Color(0xFF08302D);
    final size = MediaQuery.of(context).size;
    final logoW =
        math.min(210.0, math.min(size.shortestSide * .5, size.height * .3));
    final logo = _iv(.05, .6, Curves.easeOutCubic);
    final line = _iv(.5, .75);
    final verse = _iv(.6, .9);
    final foot = _iv(.85, 1);

    return PatternedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          Align(
            alignment: const Alignment(0, -.38),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FadeTransition(
                  opacity: logo,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0, .06), end: Offset.zero)
                            .animate(logo),
                    child: ScaleTransition(
                      scale: Tween(begin: .88, end: 1.0).animate(logo),
                      child: ColorFiltered(
                        colorFilter:
                            ColorFilter.mode(logoColor, BlendMode.srcIn),
                        child: Image.asset('assets/brand/logo_mark.png',
                            width: logoW, filterQuality: FilterQuality.high),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                AnimatedBuilder(
                  animation: line,
                  builder: (_, __) => Container(
                    width: 46 * line.value,
                    height: 2,
                    decoration: BoxDecoration(
                      color: tk.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: verse,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0, .25), end: Offset.zero)
                            .animate(verse),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(children: [
                        Text(
                            '﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: amiriStyle(21, color: tk.ink, height: 1.7)),
                        const SizedBox(height: 4),
                        Text('سورة الرعد · ${toArabicDigits(28)}',
                            style: cairoStyle(12.5, color: tk.muted)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 28,
            child: FadeTransition(
              opacity: foot,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final w in const ['أذكار', 'قرآن', 'صلاة']) ...[
                  if (w != 'أذكار')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                              color: tk.gold, shape: BoxShape.circle)),
                    ),
                  Text(w, style: cairoStyle(13, weight: 600, color: tk.muted)),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
