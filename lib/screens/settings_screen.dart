import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import '../providers/notification_service.dart';

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
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('تذكير أذكار الصباح'),
                subtitle: const Text('يومياً الساعة 6:00 ص'),
                trailing: Switch(
                  value: true,
                  onChanged: (v) async {
                    if (v) {
                      await NotificationService.scheduleDailyReminder(
                        id: 1,
                        title: 'حان وقت أذكار الصباح',
                        body: 'لا تنسَ أذكارك الصباحية 🌅',
                        hour: 6,
                        minute: 0,
                      );
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.nightlight_outlined),
                title: const Text('تذكير أذكار المساء'),
                subtitle: const Text('يومياً الساعة 5:00 م'),
                trailing: Switch(
                  value: true,
                  onChanged: (v) async {
                    if (v) {
                      await NotificationService.scheduleDailyReminder(
                        id: 2,
                        title: 'حان وقت أذكار المساء',
                        body: 'لا تنسَ أذكارك المسائية 🌙',
                        hour: 17,
                        minute: 0,
                      );
                    }
                  },
                ),
              ),
            ],
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
