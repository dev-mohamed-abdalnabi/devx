import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openDeveloper(BuildContext context) async {
    final uri = Uri.parse('https://mohamed-abdalnaby.is-a.dev/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح الموقع حاليًا')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('عن ذكر')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [scheme.primary, scheme.primary.withValues(alpha: .78)]),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(children: [
              Container(width: 78, height: 78, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(24)), child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/brand/app_icon.png', fit: BoxFit.cover))),
              const SizedBox(width: 18),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ذكر', style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('عبادة يومية بهدوء ووضوح', style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .86)))])),
            ]),
          ),
          const SizedBox(height: 28),
          Text('عن التطبيق', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text('ذكر مساحة هادئة تجمع الأذكار والقرآن ومواقيت الصلاة وأدوات العبادة اليومية، لتصل إلى ما تحتاجه بسرعة وبدون تشتيت.', style: text.bodyLarge?.copyWith(height: 1.7, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          Text('معلومات التطبيق', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _InfoPanel(children: [
            const _InfoRow(icon: Icons.person_outline_rounded, title: 'المطور', value: 'محمد عبد النبي'),
            const _InfoDivider(),
            _InfoRow(icon: Icons.language_rounded, title: 'الموقع الشخصي', value: 'mohamed-abdalnaby.is-a.dev', onTap: () => _openDeveloper(context)),
            const _InfoDivider(),
            const _InfoRow(icon: Icons.new_releases_outlined, title: 'الإصدار', value: '1.3.0'),
          ]),
          const SizedBox(height: 14),
          Material(
            color: scheme.primaryContainer.withValues(alpha: .48),
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              borderRadius: BorderRadius.circular(22),
              child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(Icons.shield_outlined, color: scheme.primary, size: 26), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('الخصوصية والبيانات', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('اعرف كيف يتعامل ذكر مع الموقع والإشعارات وبياناتك', style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45))])), const Icon(Icons.chevron_left_rounded)])),
            ),
          ),
          const SizedBox(height: 28),
          Center(child: Text('صُمّم ليكون أبسط طريق إلى الذكر', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final List<Widget> children;
  const _InfoPanel({required this.children});
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), child: Column(children: children)));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  const _InfoRow({required this.icon, required this.title, required this.value, this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [Icon(icon, color: scheme.primary, size: 22), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))])), if (onTap != null) Icon(Icons.open_in_new_rounded, size: 18, color: scheme.primary)]));
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: row);
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) => Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45));
}
