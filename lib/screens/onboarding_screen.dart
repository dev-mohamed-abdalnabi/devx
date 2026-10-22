import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/first_run.dart';
import '../core/home_tokens.dart';
import '../core/page_background.dart';
import '../core/star_shape.dart';
import '../features/home/home_art.dart';
import '../providers/notification_service.dart';
import '../widgets/page_kit.dart';
import 'home_screen.dart';

enum _Art { welcome, features, ready }

class _Slide {
  final _Art art;
  final String title;
  final String body;
  const _Slide(this.art, this.title, this.body);
}

/// ثلاث شاشات فقط: ترحيب، المميزات (مع الخصوصية)، ثم الجاهزية والإشعارات.
const _slides = [
  _Slide(_Art.welcome, 'ذِكر، يومك أقرب للطمأنينة',
      'مساحة واحدة تجمع الأذكار والقرآن والصلاة، بتجربة هادئة تساعدك تبدأ وتكمل بسهولة.'),
  _Slide(_Art.features, 'كل ما تحتاجه في مكان واحد',
      'أدوات يومك الإيمانية بتصميم واضح، وبياناتك محفوظة على جهازك.'),
  _Slide(_Art.ready, 'جاهز تبدأ؟',
      'لا حاجة لإعداد طويل. فعّل التذكيرات إن أحببت، وغيّر أي شيء لاحقًا من الإعدادات.'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _notif = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_busy) return;
    _busy = true;
    await FirstRun.markCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  Future<void> _toggleNotif() async {
    HapticFeedback.selectionClick();
    if (_notif) {
      setState(() => _notif = false);
      return;
    }
    bool ok = false;
    try {
      ok = await NotificationService.requestPermission();
    } catch (_) {}
    if (mounted) setState(() => _notif = ok);
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    }
  }

  void _prev() => _controller.previousPage(
      duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final isLast = _page == _slides.length - 1;
    return PopScope(
      // زر الرجوع يرجّع للشاشة السابقة، وفي الأولى يخرج من التطبيق.
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prev();
      },
      child: PatternedBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Text('ذِكر',
                        style: amiriStyle(28, bold: true, color: tk.ink)),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: isLast ? null : _finish,
                        child: Text('تخطي',
                            style:
                                cairoStyle(14, weight: 600, color: tk.muted)),
                      ),
                    ),
                  ]),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (v) => setState(() => _page = v),
                  itemBuilder: (_, i) => AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      var d = 0.0;
                      if (_controller.hasClients &&
                          _controller.position.haveDimensions) {
                        d = ((_controller.page ?? _page.toDouble()) - i)
                            .abs()
                            .clamp(0.0, 1.0);
                      } else {
                        d = (_page - i).abs().toDouble().clamp(0.0, 1.0);
                      }
                      return Opacity(
                        opacity: 1 - d * .7,
                        child: Transform.scale(
                          scale: 1 - d * .06,
                          child: _SlideView(
                            slide: _slides[i],
                            tk: tk,
                            notif: _notif,
                            onNotif: _toggleNotif,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? tk.gold : tk.line,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 22),
                  KitPrimaryButton(
                    label: isLast ? 'ابدأ الآن' : 'التالي',
                    icon:
                        isLast ? Icons.check_rounded : Icons.arrow_back_rounded,
                    onPressed: _next,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final HomeTokens tk;
  final bool notif;
  final VoidCallback onNotif;
  const _SlideView(
      {required this.slide,
      required this.tk,
      required this.notif,
      required this.onNotif});

  Widget _art(double s) {
    switch (slide.art) {
      case _Art.welcome:
        return _Disc(
            size: s,
            tk: tk,
            child: Padding(
              padding: EdgeInsets.only(top: s * .06),
              child: MosqueArt(width: s * .72, tokens: tk),
            ));
      case _Art.features:
        return _FeatureList(tk: tk);
      case _Art.ready:
        return _Disc(
            size: s,
            tk: tk,
            child: IslamicStar(
              size: s * .56,
              color: tk.mint,
              child: Icon(Icons.favorite_rounded, size: s * .2, color: tk.gold),
            ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = math.min(240.0, math.max(150.0, c.maxHeight * .36));
      final compact = c.maxHeight < 520;
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _art(s),
              SizedBox(height: compact ? 22 : 34),
              Text(slide.title,
                  textAlign: TextAlign.center,
                  style:
                      amiriStyle(30, bold: true, color: tk.ink, height: 1.3)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(slide.body,
                    textAlign: TextAlign.center,
                    style: cairoStyle(15, color: tk.muted, height: 1.8)),
              ),
              if (slide.art == _Art.ready) ...[
                const SizedBox(height: 22),
                _NotifRow(tk: tk, on: notif, onTap: onNotif),
              ],
            ]),
          ),
        ),
      );
    });
  }
}

/// قائمة المميزات في كرت واحد بنفس أسلوب الرئيسية.
class _FeatureList extends StatelessWidget {
  final HomeTokens tk;
  const _FeatureList({required this.tk});

  @override
  Widget build(BuildContext context) {
    const items = <(IconData?, String?, String, String)>[
      (Icons.menu_book_rounded, null, 'المصحف', 'قراءة واستماع وتفسير'),
      (null, HomeIcons.misbaha, 'الأذكار', 'أذكار الصباح والمساء وغيرها'),
      (
        Icons.access_time_rounded,
        null,
        'الصلاة والقبلة',
        'مواقيت دقيقة واتجاه القبلة'
      ),
      (Icons.touch_app_rounded, null, 'التسبيح', 'عدّاد بسيط يحفظ تقدّمك'),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: KitCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: tk.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                KitIcon(icon: items[i].$1, svg: items[i].$2, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].$3,
                          style: cairoStyle(15, weight: 700, color: tk.ink)),
                      Text(items[i].$4,
                          style: cairoStyle(12.5, color: tk.muted)),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  final double size;
  final HomeTokens tk;
  final Widget child;
  const _Disc({required this.size, required this.tk, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tk.mint,
          border: Border.all(color: tk.gold.withValues(alpha: .55), width: 1.4),
          boxShadow: [
            BoxShadow(
                color: tk.gold.withValues(alpha: .14),
                blurRadius: 40,
                offset: const Offset(0, 16)),
          ],
        ),
        child: Center(child: child),
      );
}

class _NotifRow extends StatelessWidget {
  final HomeTokens tk;
  final bool on;
  final VoidCallback onTap;
  const _NotifRow({required this.tk, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: KitCard(
        onTap: onTap,
        borderColor: on ? tk.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          KitIcon(
              icon: on
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              size: 40),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تذكير بالأذكار والصلاة',
                  style: cairoStyle(14, weight: 700, color: tk.ink)),
              Text(on ? 'تم التفعيل' : 'اضغط للسماح بالإشعارات',
                  style: cairoStyle(12, color: tk.muted)),
            ]),
          ),
          Switch(
            value: on,
            onChanged: (_) => onTap(),
            thumbColor: WidgetStatePropertyAll(tk.gold),
          ),
        ]),
      ),
    );
  }
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});
  Future<bool> _completed() => FirstRun.isCompleted();

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: _completed(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        return snapshot.data! ? const HomeScreen() : const OnboardingScreen();
      });
}
