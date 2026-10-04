import 'package:flutter/material.dart';
import '../core/home_tokens.dart';
import '../features/home/home_art.dart';
import '../features/home/home_screen.dart';
import '../features/more/more_screen.dart';
import '../features/community/forum_screen.dart';
import '../features/quran/quran_home_screen.dart';

/// الهيكل الرئيسي: أربعة أقسام (الرئيسية، القرآن، المنتدى، المزيد).
/// الأذكار صارت كارت في الرئيسية وتحت «المزيد».
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
      const ForumScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: HomeBottomNav(index: _index, onTap: _go),
    );
  }
}

/// Bottom Nav: ارتفاع 62 + safe area، خط علوي 1dp، بنفس لون الخلفية.
class HomeBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const HomeBottomNav({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final items = const [
      (HomeIcons.home, 'الرئيسية'),
      (HomeIcons.quran, 'القرآن'),
      (HomeIcons.forum, 'المنتدى'),
      (HomeIcons.more, 'المزيد'),
    ];
    final scale = MediaQuery.of(context).textScaler.clamp(maxScaleFactor: 1.15);
    return Container(
      color: tk.bg,
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tk.line)),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HomeIcon(items[i].$1,
                            size: 21, color: i == index ? tk.gold : tk.muted),
                        const SizedBox(height: 3),
                        Text(items[i].$2,
                            maxLines: 1,
                            style: cairoStyle(11.5,
                                weight: 600,
                                color: i == index ? tk.ink : tk.muted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
