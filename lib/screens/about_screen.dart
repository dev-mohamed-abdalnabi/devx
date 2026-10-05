import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/home_tokens.dart';
import '../features/more/support_screen.dart';
import '../widgets/page_kit.dart';
import 'privacy_screen.dart';

const _version = '1.3.0';
const _site = 'https://mohamed-abdalnaby.is-a.dev/';
const _email = 'dev.mohamed.abdalnabi@gmail.com';
const _whatsapp = 'https://wa.me/201102855563';

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

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

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
            const _Hero(),
            const SizedBox(height: 22),
            const KitSectionTitle(text: 'عن التطبيق'),
            KitCard(
              child: Text(
                'ذِكر مساحة هادئة تجمع الأذكار والقرآن ومواقيت الصلاة وأدوات العبادة اليومية، لتصل إلى ما تحتاجه بسرعة وبدون تشتيت.',
                style: cairoStyle(14, color: tk.ink, height: 1.9),
              ),
            ),
            const SizedBox(height: 22),
            const KitSectionTitle(text: 'ماذا تجد فيه'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 76,
              padding: EdgeInsets.zero,
              children: const [
                _Feature(
                    icon: Icons.auto_awesome_outlined,
                    title: 'الأذكار',
                    sub: 'من حصن المسلم'),
                _Feature(
                    icon: Icons.menu_book_rounded,
                    title: 'القرآن الكريم',
                    sub: 'قراءة واستماع'),
                _Feature(
                    icon: Icons.access_time_rounded,
                    title: 'مواقيت الصلاة',
                    sub: 'والقبلة'),
                _Feature(
                    icon: Icons.forum_outlined,
                    title: 'المجتمع',
                    sub: 'منتدى للتواصل'),
              ],
            ),
            const SizedBox(height: 22),
            const KitSectionTitle(text: 'المطوّر'),
            _DeveloperCard(
              onSite: () => _open(context, Uri.parse(_site)),
              onMail: () => _open(
                  context,
                  Uri.parse(
                      'mailto:$_email?subject=${Uri.encodeComponent('بخصوص تطبيق ذِكر')}')),
              onWhatsapp: () => _open(context, Uri.parse(_whatsapp)),
            ),
            const SizedBox(height: 22),
            KitCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  KitTile(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'ادعم التطبيق',
                    subtitle: 'شارك، ادعُ لنا، أو تواصل معنا',
                    onTap: () => _push(context, const SupportScreen()),
                  ),
                  const KitDivider(),
                  KitTile(
                    icon: Icons.shield_outlined,
                    title: 'الخصوصية والبيانات',
                    subtitle: 'كيف يتعامل ذِكر مع الموقع والإشعارات',
                    onTap: () => _push(context, const PrivacyScreen()),
                  ),
                ],
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
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return KitHero(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kHeroGold, width: 1.6),
                boxShadow: [
                  BoxShadow(
                      color: kHeroGold.withValues(alpha: .25), blurRadius: 28),
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
                style:
                    amiriStyle(38, bold: true, color: kHeroInk, height: 1.2)),
            const SizedBox(height: 4),
            Text('عبادة يومية بهدوء ووضوح',
                style: cairoStyle(14, color: kHeroSoft)),
            const SizedBox(height: 14),
            const KitHeroPill(text: 'الإصدار $_version'),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _Feature({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return KitCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          KitIcon(icon: icon, size: 40),
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
}

class _DeveloperCard extends StatelessWidget {
  final VoidCallback onSite, onMail, onWhatsapp;
  const _DeveloperCard(
      {required this.onSite, required this.onMail, required this.onWhatsapp});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return KitCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tk.mint,
                  shape: BoxShape.circle,
                  border: Border.all(color: tk.gold.withValues(alpha: .6)),
                ),
                child: Text('م',
                    style: amiriStyle(26, bold: true, color: tk.mintInk)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('محمد عبد النبي',
                        style: cairoStyle(16, weight: 700, color: tk.ink)),
                    Text('مطوّر التطبيق',
                        style: cairoStyle(12.5, color: tk.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: tk.line),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _Action(
                      icon: Icons.language_rounded,
                      label: 'الموقع',
                      onTap: onSite)),
              Expanded(
                  child: _Action(
                      icon: Icons.mail_outline_rounded,
                      label: 'البريد',
                      onTap: onMail)),
              Expanded(
                  child: _Action(
                      icon: Icons.chat_rounded,
                      label: 'واتساب',
                      onTap: onWhatsapp)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KitIcon(icon: icon, size: 44),
            const SizedBox(height: 6),
            Text(label, style: cairoStyle(12.5, weight: 600, color: tk.ink)),
          ],
        ),
      ),
    );
  }
}
