import 'package:flutter/material.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/search_screen.dart';
import '../../screens/settings_screen.dart';
import '../stats/stats_screen.dart';
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
        padding: const EdgeInsets.all(16),
        children: [
          Text('المزيد',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _Tile(
            icon: Icons.access_time,
            title: 'مواقيت الصلاة',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrayerScreen())),
          ),
          _Tile(
            icon: Icons.explore_outlined,
            title: 'القبلة',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const QiblaScreen())),
          ),
          _Tile(
            icon: Icons.notifications_active_outlined,
            title: 'التذكيرات',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RemindersScreen())),
          ),
          _Tile(
            icon: Icons.touch_app_outlined,
            title: 'التسبيح',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TasbeehScreen())),
          ),
          _Tile(
            icon: Icons.bar_chart,
            title: 'الإحصائيات والإنجازات',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          _Tile(
            icon: Icons.bookmark_border,
            title: 'علامات القرآن',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BookmarksScreen())),
          ),
          _Tile(
            icon: Icons.favorite_border,
            title: 'أذكاري المفضلة',
            onTap: () => _push(context, 'المفضلة', const FavoritesScreen()),
          ),
          _Tile(
            icon: Icons.search,
            title: 'البحث في الأذكار',
            onTap: () => _push(context, 'البحث', const SearchScreen()),
          ),
          _Tile(
            icon: Icons.settings_outlined,
            title: 'الإعدادات',
            onTap: () => _push(context, 'الإعدادات', const SettingsScreen()),
          ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: ListTile(
          minVerticalPadding: 14,
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      ),
    );
  }
}
