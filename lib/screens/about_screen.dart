import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_ui.dart';
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppSectionHeader(title: 'عن ذكر', subtitle: 'عبادة يومية بهدوء ووضوح'),
        const SizedBox(height: 24),
        Center(child: ClipRRect(borderRadius: BorderRadius.circular(32), child: Image.asset('assets/brand/app_icon.png', width: 112, height: 112))),
        const SizedBox(height: 16),
        Text('ذكر', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('تطبيق هادئ يجمع الأذكار والقرآن ومواقيت الصلاة وأدوات العبادة اليومية في مكان واحد.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        AppCard(child: Column(children: [
          const ListTile(leading: Icon(Icons.person_outline_rounded), title: Text('المطور'), subtitle: Text('محمد عبد النبي')),
          ListTile(leading: const Icon(Icons.language_rounded), title: const Text('الموقع الشخصي'), subtitle: const Text('mohamed-abdalnaby.is-a.dev'), onTap: () => _openDeveloper(context)),
          const ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('الإصدار'), subtitle: Text('1.2.0')),
        ])),
        const SizedBox(height: 12),
        AppCard(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())), child: const ListTile(leading: Icon(Icons.shield_outlined), title: Text('الخصوصية'), subtitle: Text('كيف يستخدم التطبيق الموقع والإشعارات والبيانات المحلية'), trailing: Icon(Icons.chevron_left_rounded))),
      ],
    );
  }
}
