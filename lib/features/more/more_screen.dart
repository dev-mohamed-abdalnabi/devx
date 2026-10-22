import 'dart:io' show Platform;
import 'package:azkari_native/azkari_native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/home_tokens.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';
import '../challenges/challenges_screen.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/search_screen.dart';
import '../../screens/settings_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';
import '../prayer/prayer_screen.dart';
import '../prayer/qibla_screen.dart';
import '../reminders/reminders_screen.dart';
import '../../screens/categories_screen.dart';
import '../fiqh/fiqh_screens.dart';
import '../library/library_screen.dart';
import '../stories/stories_screens.dart';
import '../duas/duas_screen.dart';
import 'bookmarks_screen.dart';
import 'sources_screen.dart';
import 'support_screen.dart';

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

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);

    Widget grid(List<_Item> items) => GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 84,
          ),
          padding: EdgeInsets.zero,
          children: [for (final i in items) _MoreCard(tk: tk, item: i)],
        );

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          children: [
            const PageHeader(title: 'المزيد'),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
              child: Text('كل أدواتك الإسلامية في مكان واحد',
                  style: cairoStyle(13.5, color: tk.muted)),
            ),
            _Heading(tk: tk, text: 'العبادة اليومية'),
            grid([
              _Item(Icons.task_alt_rounded, 'التحديات', 'أهدافك وإنجازاتك',
                  () => _go(context, const ChallengesScreen())),
              _Item(null, 'الأذكار', 'حصن المسلم',
                  () => _go(context, const CategoriesScreen()),
                  svg: HomeIcons.misbaha),
              _Item(Icons.touch_app_rounded, 'التسبيح', 'سبحة إلكترونية',
                  () => _go(context, const TasbeehScreen())),
              _Item(
                  Icons.notifications_active_outlined,
                  'التذكيرات',
                  'تنبيهات الأذكار',
                  () => _go(context, const RemindersScreen())),
            ]),
            const SizedBox(height: 20),
            _Heading(tk: tk, text: 'الصلاة والموقع'),
            grid([
              _Item(Icons.access_time_rounded, 'مواقيت الصلاة', 'حسب موقعك',
                  () => _go(context, const PrayerScreen())),
              _Item(Icons.explore_outlined, 'القبلة', 'اتجاه الكعبة',
                  () => _go(context, const QiblaScreen())),
            ]),
            if (!kIsWeb && Platform.isAndroid) ...[
              const SizedBox(height: 20),
              _Heading(tk: tk, text: 'ودجتس الشاشة الرئيسية'),
              _WidgetsSection(tk: tk),
            ],
            const SizedBox(height: 20),
            _Heading(tk: tk, text: 'مكتبتي'),
            grid([
              _Item(null, 'الأدعية', 'القرآن والسنة الصحيحة',
                  () => _go(context, const DuasScreen()),
                  svg: HomeIcons.hand),
              _Item(null, 'حكايات الوحي', 'قصص القرآن · على خُطى الأنبياء · السيرة العَطِرة',
                  () => _go(context, const StoriesHomeScreen()),
                  svg: HomeIcons.crescentStar),
              _Item(null, 'المكتبة', 'كتب الحديث',
                  () => _go(context, const LibraryScreen()),
                  svg: HomeIcons.books),
              _Item(null, 'الأحكام الفقهية', 'المذاهب الأربعة',
                  () => _go(context, const FiqhScreen()),
                  svg: HomeIcons.scale),
              _Item(
                  Icons.bookmark_border_rounded,
                  'علامات القرآن',
                  'آياتك المحفوظة',
                  () => _go(context, const BookmarksScreen())),
              _Item(Icons.favorite_border_rounded, 'المفضلة', 'أذكارك المفضلة',
                  () => _go(context, const FavoritesScreen())),
              _Item(Icons.search_rounded, 'البحث', 'في كل الأذكار',
                  () => _go(context, const SearchScreen())),
            ]),
            const SizedBox(height: 20),
            _Heading(tk: tk, text: 'التطبيق'),
            _RowCard(
              tk: tk,
              icon: Icons.volunteer_activism_outlined,
              title: 'ادعم التطبيق',
              subtitle: 'شارك، ادعُ لنا، أو تواصل معنا',
              highlight: true,
              onTap: () => _go(context, const SupportScreen()),
            ),
            const SizedBox(height: 10),
            _RowCard(
              tk: tk,
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
              subtitle: 'المظهر والإشعارات والمزيد',
              onTap: () => _push(context, 'الإعدادات', const SettingsScreen()),
            ),
            const SizedBox(height: 10),
            _RowCard(
              tk: tk,
              icon: Icons.verified_outlined,
              title: 'المصادر والتراخيص',
              subtitle: 'مصدر القرآن والتفسير والأذكار والتلاوات',
              onTap: () => _go(context, const SourcesScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item {
  final IconData? icon;
  final String? svg; // أيقونة SVG مخصّصة بدل IconData
  final String title, subtitle;
  final VoidCallback onTap;
  const _Item(this.icon, this.title, this.subtitle, this.onTap, {this.svg});
}

class _Heading extends StatelessWidget {
  final HomeTokens tk;
  final String text;
  const _Heading({required this.tk, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: tk.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(text, style: cairoStyle(15, weight: 700, color: tk.ink)),
          ],
        ),
      );
}

class _MoreCard extends StatelessWidget {
  final HomeTokens tk;
  final _Item item;
  const _MoreCard({required this.tk, required this.item});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: item.onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pressed ? tk.gold : tk.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: tk.mint, shape: BoxShape.circle),
              child: item.svg != null
                  ? Center(
                      child: HomeIcon(item.svg!, size: 21, color: tk.mintInk))
                  : Icon(item.icon, size: 21, color: tk.mintInk),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairoStyle(14.5,
                          weight: 700, color: tk.ink, height: 1.25)),
                  const SizedBox(height: 2),
                  Text(item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairoStyle(11.5, color: tk.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final HomeTokens tk;
  final IconData icon;
  final String title, subtitle;
  final bool highlight;
  final VoidCallback onTap;
  const _RowCard({
    required this.tk,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? tk.mint : tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (pressed || highlight)
                ? tk.gold.withValues(alpha: pressed ? 1 : .6)
                : tk.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: highlight ? tk.card : tk.mint,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(icon, size: 22, color: highlight ? tk.gold : tk.mintInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: cairoStyle(15,
                          weight: 700, color: highlight ? tk.mintInk : tk.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: cairoStyle(12,
                          color: highlight
                              ? tk.mintInk.withValues(alpha: .75)
                              : tk.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: tk.gold, size: 26),
          ],
        ),
      ),
    );
  }
}

/// إضافة ودجتس الهاتف من داخل التطبيق (بديلها: ضغطة مطوّلة على الشاشة الرئيسية ← الودجتس ← ذِكر).
class _WidgetsSection extends StatefulWidget {
  final HomeTokens tk;
  const _WidgetsSection({required this.tk});

  @override
  State<_WidgetsSection> createState() => _WidgetsSectionState();
}

class _WidgetsSectionState extends State<_WidgetsSection>
    with WidgetsBindingObserver {
  Map<String, int> _counts = const {'hero': 0, 'ayah': 0, 'prayer': 0};

  static const _items = [
    (
      'hero',
      Icons.wb_twilight_rounded,
      'كارت أذكار الوقت',
      'نفس كارت الرئيسية بمشاهده المتغيّرة'
    ),
    ('ayah', Icons.menu_book_rounded, 'آية اليوم', 'آية جديدة كل يوم'),
    (
      'prayer',
      Icons.access_time_rounded,
      'الصلاة القادمة',
      'عدّاد حي وتاريخ هجري ونصيحة'
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final c = await AzkariNative.widgetCounts();
    if (mounted) setState(() => _counts = c);
  }

  Future<void> _add(String kind) async {
    final ok = await AzkariNative.pinWidget(kind);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'لانشر هاتفك لا يدعم الإضافة المباشرة. اضغط مطوّلًا على الشاشة الرئيسية ← الودجتس ← ذِكر.'),
      ));
    }
    // بعد التأكيد من نافذة النظام نحدّث العدّاد.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _RowCard(
            tk: widget.tk,
            icon: _items[i].$2,
            title: _items[i].$3,
            subtitle: (_counts[_items[i].$1] ?? 0) > 0
                ? 'مضاف ×${_counts[_items[i].$1]} · اضغط لإضافة نسخة أخرى'
                : '${_items[i].$4} · اضغط للإضافة',
            onTap: () => _add(_items[i].$1),
          ),
        ],
      ],
    );
  }
}
