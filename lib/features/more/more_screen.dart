import 'package:flutter/material.dart';
import '../../widgets/app_ui.dart';
import '../challenges/challenges_screen.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/search_screen.dart';
import '../../screens/settings_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';
import '../prayer/prayer_screen.dart';
import '../prayer/qibla_screen.dart';
import '../reminders/reminders_screen.dart';
import 'bookmarks_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _push(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(child: body),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const AppSectionHeader(
            title: 'المزيد',
            subtitle: 'كل أدواتك الإسلامية في مكان واحد',
          ),
          const SizedBox(height: 24),
          const AppSectionHeader(title: 'العبادة اليومية'),
          const SizedBox(height: 10),
          _Tile(icon: Icons.task_alt_rounded, title: 'التحديات والإنجازات', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen()))),
          _Tile(icon: Icons.touch_app_rounded, title: 'التسبيح', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasbeehScreen()))),
          _Tile(icon: Icons.notifications_active_outlined, title: 'التذكيرات', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersScreen()))),
          const SizedBox(height: 18),
          const AppSectionHeader(title: 'الموقع والصلاة'),
          const SizedBox(height: 10),
          _Tile(icon: Icons.access_time_rounded, title: 'مواقيت الصلاة', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrayerScreen()))),
          _Tile(icon: Icons.explore_outlined, title: 'القبلة', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QiblaScreen()))),
          const SizedBox(height: 18),
          const AppSectionHeader(title: 'المكتبة والتخصيص'),
          const SizedBox(height: 10),
          _Tile(icon: Icons.bookmark_border_rounded, title: 'علامات القرآن', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookmarksScreen()))),
          _Tile(icon: Icons.favorite_border_rounded, title: 'أذكاري المفضلة', onTap: () => _push(context, 'المفضلة', const FavoritesScreen())),
          _Tile(icon: Icons.search_rounded, title: 'البحث في الأذكار', onTap: () => _push(context, 'البحث', const SearchScreen())),
          _Tile(icon: Icons.settings_outlined, title: 'الإعدادات', onTap: () => _push(context, 'الإعدادات', const SettingsScreen())),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: onTap,
        child: Row(
          children: [
            AppIconBadge(icon: icon),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }
}
