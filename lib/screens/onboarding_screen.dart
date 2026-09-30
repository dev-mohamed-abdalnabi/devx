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
    (icon: Icons.auto_awesome_rounded, title: 'ذكر، يومك أقرب للطمأنينة', body: 'مساحة واحدة تجمع الأذكار والقرآن والصلاة، بتجربة هادئة تساعدك تبدأ وتكمل بسهولة.'),
    (icon: Icons.grid_view_rounded, title: 'كل ما تحتاجه في مكان واضح', body: 'ابدأ بأذكار الصباح والمساء، اقرأ القرآن، تابع الصلاة، واستخدم أدوات العبادة عند الحاجة.'),
    (icon: Icons.lock_outline_rounded, title: 'بياناتك تحت سيطرتك', body: 'تُحفظ تفضيلاتك وتقدمك محليًا. نطلب الموقع والإشعارات فقط للميزات التي تختارها.'),
    (icon: Icons.self_improvement_rounded, title: 'ابدأ رحلتك مع ذكر', body: 'لا تحتاج إلى إعداد طويل. يمكنك اختيار مدينتك وتفعيل ما يناسبك لاحقًا من الإعدادات.'),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isLast = _page == _slides.length - 1;
    return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 22), child: Column(children: [
      Row(children: [Container(width: 38, height: 38, padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(13)), child: ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/brand/app_icon.png', fit: BoxFit.cover))), const SizedBox(width: 10), Text('ذكر', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const Spacer(), TextButton(onPressed: _finish, child: const Text('تخطي'))]),
      Expanded(child: PageView.builder(controller: _controller, itemCount: _slides.length, onPageChanged: (value) => setState(() => _page = value), itemBuilder: (_, index) { final item = _slides[index]; return Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 224, height: 224, decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primaryContainer, boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .13), blurRadius: 35, offset: const Offset(0, 15))]), child: Center(child: index == 0 ? ClipRRect(borderRadius: BorderRadius.circular(42), child: Image.asset('assets/brand/app_icon.png', width: 122, height: 122, fit: BoxFit.cover)) : Icon(item.icon, size: 78, color: scheme.primary))), const SizedBox(height: 46), Text(item.title, textAlign: TextAlign.center, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.3)), const SizedBox(height: 16), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390), child: Text(item.body, textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(height: 1.75, color: scheme.onSurfaceVariant)))]); })),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_slides.length, (index) => AnimatedContainer(duration: const Duration(milliseconds: 220), margin: const EdgeInsets.symmetric(horizontal: 4), width: index == _page ? 28 : 8, height: 8, decoration: BoxDecoration(color: index == _page ? scheme.primary : scheme.outlineVariant, borderRadius: BorderRadius.circular(8))))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { if (isLast) { _finish(); } else { _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic); } }, icon: Icon(isLast ? Icons.arrow_forward_rounded : Icons.chevron_left_rounded), label: Text(isLast ? 'ابدأ الآن' : 'التالي'))),
    ]))));
  }
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});
  Future<bool> _completed() async { final prefs = await SharedPreferences.getInstance(); return prefs.getBool('onboarding_completed') ?? false; }
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(future: _completed(), builder: (context, snapshot) { if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator())); return snapshot.data! ? const HomeScreen() : const OnboardingScreen(); });
}
