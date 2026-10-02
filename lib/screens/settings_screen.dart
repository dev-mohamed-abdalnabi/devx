import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import '../features/reminders/reminders_screen.dart';
import '../widgets/app_ui.dart';
import 'about_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppSectionHeader(title: 'الإعدادات', subtitle: 'خصص تجربة القراءة والذكر كما تحب'),
        const SizedBox(height: 24),
        const AppSectionHeader(title: 'المظهر والقراءة'),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('الوضع الليلي', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('مظهر مريح للعين في الإضاءة المنخفضة'),
                secondary: const AppIconBadge(icon: Icons.dark_mode_rounded),
                value: provider.isDarkMode,
                onChanged: (_) => provider.toggleDarkMode(),
              ),
              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.45)),
              SwitchListTile(
                title: const Text('إظهار مصدر الذكر', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('عرض حصن المسلم ورقم الذكر المرجعي'),
                secondary: const AppIconBadge(icon: Icons.menu_book_rounded),
                value: provider.showSources,
                onChanged: (_) => provider.toggleSources(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.text_fields_rounded), SizedBox(width: 12), Text('حجم خط الأذكار', style: TextStyle(fontWeight: FontWeight.w700))]),
                    Slider(
                      value: provider.fontScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      label: '${(provider.fontScale * 100).round()}%',
                      onChanged: provider.setFontScale,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const AppSectionHeader(title: 'التنبيهات'),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersScreen())),
          child: const ListTile(
            leading: AppIconBadge(icon: Icons.notifications_active_rounded),
            title: Text('التذكيرات', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('الأذكار والقرآن والتحديات وتذكيرات مخصصة'),
            trailing: Icon(Icons.chevron_left_rounded),
          ),
        ),
        const SizedBox(height: 22),
        const AppSectionHeader(title: 'حول التطبيق'),
        const SizedBox(height: 10),
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/brand/app_icon.png', width: 48, height: 48)),
              const SizedBox(width: 14),
              Expanded(child: Text('عن ذكر\nيعمل بالكامل بدون إنترنت', style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5))),
              Text('1.2.0', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppIconBadge(icon: Icons.shield_outlined),
            title: Text('الخصوصية', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('الموقع والإشعارات والبيانات المحلية'),
            trailing: Icon(Icons.chevron_left_rounded),
          ),
        ),
      ],
    );
  }
}
