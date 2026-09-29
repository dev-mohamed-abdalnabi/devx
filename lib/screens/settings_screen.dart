import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import '../features/reminders/reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('الإعدادات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _SectionCard(
          child: SwitchListTile(
            title: const Text('الوضع الليلي'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: provider.isDarkMode,
            onChanged: (_) => provider.toggleDarkMode(),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [Icon(Icons.text_fields), SizedBox(width: 12), Text('حجم الخط')],
                ),
                Slider(
                  value: provider.fontScale,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  label: '${(provider.fontScale * 100).round()}%',
                  onChanged: (v) => provider.setFontScale(v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('التذكيرات'),
            subtitle: const Text('الأذكار والقرآن والتحديات وتذكيرات مخصصة'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RemindersScreen())),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text('يعمل بالكامل بدون إنترنت', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
