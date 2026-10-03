import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static final Uri _policyUri = Uri.parse('https://azkar-privacy-terms.vercel.app/');

  Future<void> _openPolicy(BuildContext context) async {
    final opened = await launchUrl(_policyUri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح سياسة الخصوصية حاليًا')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية والشروط')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        children: [
          Icon(Icons.verified_user_outlined, size: 54, color: scheme.primary),
          const SizedBox(height: 16),
          const Text(
            'سياسة الخصوصية وشروط الاستخدام',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'يمكنك قراءة النسخة المنشورة والمحدّثة من سياسة الخصوصية وشروط استخدام تطبيق ذكر عبر الرابط الرسمي.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.7),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openPolicy(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('فتح سياسة الخصوصية والشروط'),
          ),
          const SizedBox(height: 14),
          SelectableText(
            _policyUri.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.primary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
