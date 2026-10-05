import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/home_tokens.dart';
import '../core/page_background.dart';
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

  /// تاريخ التبويبات اللي زرتها (عشان زر الرجوع يرجّعك خطوة خطوة).
  final List<int> _history = [];

  /// وقت أول ضغطة رجوع في آخر خطوة (للخروج بضغطتين).
  DateTime? _lastBack;

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _history.add(_index);
      _index = i;
    });
  }

  void _onBack() {
    if (_history.isNotEmpty) {
      setState(() => _index = _history.removeLast());
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null &&
        now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(const SnackBar(
      content:
          Text('اضغط مرة أخرى للخروج من التطبيق', textAlign: TextAlign.center),
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeDashboard(onSwitchTab: _go),
      const QuranHomeScreen(),
      const ForumScreen(),
      const MoreScreen(),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: PatternedBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: HomeBottomNav(index: _index, onTap: _go),
        ),
      ),
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
    const items = [
      (HomeIcons.home, 'الرئيسية'),
      (HomeIcons.quran, 'القرآن'),
      (HomeIcons.forum, 'المنتدى'),
      (HomeIcons.more, 'المزيد'),
    ];
    final scale = MediaQuery.of(context).textScaler.clamp(maxScaleFactor: 1.15);
    return Container(
      color: Colors.transparent,
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
