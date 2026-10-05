import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/home_tokens.dart';
import '../features/home/home_art.dart';
import 'privacy_screen.dart';

const _version = '1.3.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('تعذّر فتح الرابط حاليًا')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('عن ذِكر')),
      body: MediaQuery(
        data:
            mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _Hero(tk: tk),
            const SizedBox(height: 20),
            _Heading(tk: tk, text: 'عن التطبيق'),
            _Panel(
              tk: tk,
              child: Text(
                'ذِكر مساحة هادئة تجمع الأذكار والقرآن ومواقيت الصلاة وأدوات العبادة اليومية، لتصل إلى ما تحتاجه بسرعة وبدون تشتيت.',
                style: cairoStyle(14, color: tk.ink, height: 1.9),
              ),
            ),
            const SizedBox(height: 20),
            _Heading(tk: tk, text: 'ماذا تجد فيه'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 76,
              padding: EdgeInsets.zero,
              children: [
                _Feature(
                    tk: tk,
                    icon: Icons.auto_awesome_outlined,
                    title: 'الأذكار',
                    sub: 'من حصن المسلم'),
                _Feature(
                    tk: tk,
                    icon: Icons.menu_book_rounded,
                    title: 'القرآن الكريم',
                    sub: 'قراءة واستماع'),
                _Feature(
                    tk: tk,
                    icon: Icons.access_time_rounded,
                    title: 'مواقيت الصلاة',
                    sub: 'والقبلة'),
                _Feature(
                    tk: tk,
                    icon: Icons.forum_outlined,
                    title: 'المجتمع',
                    sub: 'منتدى للتواصل'),
              ],
            ),
            const SizedBox(height: 20),
            _Heading(tk: tk, text: 'المطوّر'),
            _Panel(
              tk: tk,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoRow(
                    tk: tk,
                    icon: Icons.person_outline_rounded,
                    title: 'المطوّر',
                    value: 'محمد عبد النبي',
                  ),
                  Divider(height: 1, color: tk.line),
                  _InfoRow(
                    tk: tk,
                    icon: Icons.language_rounded,
                    title: 'الموقع الشخصي',
                    value: 'mohamed-abdalnaby.is-a.dev',
                    ltr: true,
                    onTap: () => _open(context,
                        Uri.parse('https://mohamed-abdalnaby.is-a.dev/')),
                  ),
                  Divider(height: 1, color: tk.line),
                  _InfoRow(
                    tk: tk,
                    icon: Icons.mail_outline_rounded,
                    title: 'البريد الإلكتروني',
                    value: 'dev.mohamed.abdalnabi@gmail.com',
                    ltr: true,
                    onTap: () => _open(
                        context,
                        Uri.parse(
                            'mailto:dev.mohamed.abdalnabi@gmail.com?subject=${Uri.encodeComponent('بخصوص تطبيق ذِكر')}')),
                  ),
                  Divider(height: 1, color: tk.line),
                  _InfoRow(
                    tk: tk,
                    icon: Icons.chat_rounded,
                    title: 'واتساب',
                    value: '01102855563',
                    ltr: true,
                    onTap: () =>
                        _open(context, Uri.parse('https://wa.me/201102855563')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PressableCard(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              builder: (context, pressed) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tk.mint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: tk.gold.withValues(alpha: pressed ? 1 : .55)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration:
                          BoxDecoration(color: tk.card, shape: BoxShape.circle),
                      child:
                          Icon(Icons.shield_outlined, size: 22, color: tk.gold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الخصوصية والبيانات',
                              style: cairoStyle(15,
                                  weight: 700, color: tk.mintInk)),
                          const SizedBox(height: 2),
                          Text(
                              'اعرف كيف يتعامل ذِكر مع الموقع والإشعارات وبياناتك',
                              style: cairoStyle(12,
                                  color: tk.mintInk.withValues(alpha: .75),
                                  height: 1.5)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_left_rounded, color: tk.gold, size: 26),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Center(
              child: Text('صُمّم ليكون أبسط طريق إلى الذكر',
                  style: cairoStyle(12.5, color: tk.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final HomeTokens tk;
  const _Hero({required this.tk});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0C2B31), Color(0xFF16473F)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: IslamicPatternPainter(opacity: .12)),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: const Color(0xFFE2BC63), width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE2BC63).withValues(alpha: .25),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/brand/app_icon.png',
                        width: 84, height: 84, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
                Text('ذِكر',
                    style: amiriStyle(38,
                        bold: true,
                        color: const Color(0xFFF1EEE2),
                        height: 1.2)),
                const SizedBox(height: 4),
                Text('عبادة يومية بهدوء ووضوح',
                    style: cairoStyle(14, color: const Color(0xFFB9D3C6))),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFE2BC63).withValues(alpha: .6)),
                  ),
                  child: Text('الإصدار $_version',
                      style: cairoStyle(12.5,
                          weight: 700, color: const Color(0xFFE2BC63))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final HomeTokens tk;
  final String text;
  const _Heading({required this.tk, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: tk.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(text, style: cairoStyle(15, weight: 700, color: tk.ink)),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  final HomeTokens tk;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Panel(
      {required this.tk,
      required this.child,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tk.line),
        ),
        child: child,
      );
}

class _Feature extends StatelessWidget {
  final HomeTokens tk;
  final IconData icon;
  final String title, sub;
  const _Feature(
      {required this.tk,
      required this.icon,
      required this.title,
      required this.sub});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tk.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tk.mint, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: tk.mintInk),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairoStyle(14,
                          weight: 700, color: tk.ink, height: 1.25)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairoStyle(11.5, color: tk.muted)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final HomeTokens tk;
  final IconData icon;
  final String title, value;
  final bool ltr;
  final VoidCallback? onTap;
  const _InfoRow({
    required this.tk,
    required this.icon,
    required this.title,
    required this.value,
    this.ltr = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: tk.mint, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: tk.mintInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: cairoStyle(13.5, weight: 700, color: tk.ink)),
                const SizedBox(height: 1),
                Text(value,
                    textDirection: ltr ? TextDirection.ltr : null,
                    style: cairoStyle(12.5, color: tk.muted)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.open_in_new_rounded, size: 18, color: tk.gold),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
