import 'package:flutter/material.dart';
import '../features/home/home_screen.dart';
import '../features/more/more_screen.dart';
import '../features/prayer/prayer_screen.dart';
import '../features/quran/quran_home_screen.dart';
import 'categories_screen.dart';

/// الهيكل الرئيسي للتطبيق: خمسة أقسام أساسية واضحة.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeDashboard(onSwitchTab: _go),
      const QuranHomeScreen(),
      const SafeArea(child: CategoriesScreen()),
      const PrayerScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'القرآن'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'الأذكار'),
          NavigationDestination(
              icon: Icon(Icons.access_time_outlined),
              selectedIcon: Icon(Icons.access_time_filled),
              label: 'الصلاة'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'المزيد'),
        ],
      ),
    );
  }
}
