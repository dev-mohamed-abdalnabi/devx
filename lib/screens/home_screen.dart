import 'package:flutter/cupertino.dart';
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
              icon: Icon(CupertinoIcons.house), selectedIcon: Icon(CupertinoIcons.house_fill), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(CupertinoIcons.book),
              selectedIcon: Icon(CupertinoIcons.book_fill),
              label: 'القرآن'),
          NavigationDestination(
              icon: Icon(CupertinoIcons.sparkles),
              selectedIcon: Icon(CupertinoIcons.sparkles),
              label: 'الأذكار'),
          NavigationDestination(
              icon: Icon(CupertinoIcons.clock),
              selectedIcon: Icon(CupertinoIcons.clock_fill),
              label: 'الصلاة'),
          NavigationDestination(
              icon: Icon(CupertinoIcons.square_grid_2x2),
              selectedIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
              label: 'المزيد'),
        ],
      ),
    );
  }
}
