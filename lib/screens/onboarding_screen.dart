import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.auto_awesome_rounded,
      title: 'ذكر، يومك أقرب للطمأنينة',
      body: 'مساحة واحدة تجمع الأذكار والقرآن والصلاة، بتجربة هادئة تساعدك تبدأ وتكمل بسهولة.',
    ),
    (
      icon: Icons.grid_view_rounded,
      title: 'كل ما تحتاجه في مكان واضح',
      body: 'ابدأ بأذكار الصباح والمساء، اقرأ القرآن، تابع الصلاة، واستخدم التسبيح والتحديات والقبلة عند الحاجة.',
    ),
    (
      icon: Icons.lock_outline_rounded,
      title: 'بياناتك تحت سيطرتك',
      body: 'تُحفظ تفضيلاتك وتقدمك محليًا. نطلب الموقع للصلاة والقبلة، والإشعارات فقط للتنبيهات التي تختارها.',
    ),
    (
      icon: Icons.self_improvement_rounded,
      title: 'ابدأ رحلتك مع ذكر',
      body: 'لا تحتاج إلى إعداد طويل. يمكنك اختيار مدينتك وتفعيل ما يناسبك لاحقًا من الإعدادات.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('تخطي'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (_, index) {
                    final item = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 136,
                          height: 136,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(42),
                          ),
                          child: index == 0
                              ? ClipRRect(borderRadius: BorderRadius.circular(42), child: Image.asset('assets/brand/app_icon.png'))
                              : Icon(item.icon, size: 64, color: scheme.primary),
                        ),
                        const SizedBox(height: 36),
                        Text(item.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        Text(item.body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65, color: scheme.onSurfaceVariant)),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: index == _page ? scheme.primary : scheme.outlineVariant, borderRadius: BorderRadius.circular(8)),
                )),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_page == _slides.length - 1) {
                      _finish();
                    } else {
                      _controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
                    }
                  },
                  child: Text(_page == _slides.length - 1 ? 'ابدأ الآن' : 'التالي'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  Future<bool> _completed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completed(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return snapshot.data! ? const HomeScreen() : const OnboardingScreen();
      },
    );
  }
}
