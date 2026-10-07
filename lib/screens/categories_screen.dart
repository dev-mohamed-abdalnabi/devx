import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/category_groups.dart';
import '../core/home_tokens.dart';
import '../core/short_titles.dart' hide normalizeArabic;
import '../core/text_utils.dart';
import '../features/home/home_art.dart';
import '../features/home/home_screen.dart' show HomeTile;
import '../providers/azkar_provider.dart';
import '../widgets/home_style.dart';
import 'search_screen.dart';
import 'zikr_list_screen.dart';

/// «ذكر ٣ أذكار / ذكران / ٥ أذكار / ١٢ ذكرًا»
String _countLabel(int n) {
  if (n == 1) return 'ذكر واحد';
  if (n == 2) return 'ذكران';
  if (n <= 10) return '${toArabicDigits(n)} أذكار';
  return '${toArabicDigits(n)} ذكرًا';
}

/// صفحة أقسام الأذكار — بنفس ألوان ونسب وكروت الشاشة الرئيسية.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _group = -1; // -1 = الكل

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final provider = context.watch<AzkarProvider>();

    final header = PageHeader(
      title: 'الأذكار',
      actions: [
        HeaderButton(
          icon: ZikrIcons.search,
          label: 'البحث في كل الأذكار',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
      ],
    );

    Widget body;
    if (provider.loading) {
      body = Center(child: CircularProgressIndicator(color: tk.leaf));
    } else if (provider.categories.isEmpty) {
      body = HomeEmpty(
        tk: tk,
        icon: HomeIcons.misbaha,
        title: 'لا توجد أذكار متاحة حاليًا',
        message: provider.error?.toString(),
      );
    } else {
      body = _buildContent(context, tk, provider);
    }

    return Scaffold(
      body: MediaQuery(
        data:
            mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                header,
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, HomeTokens tk, AzkarProvider provider) {
    const pinned = ['hisn-27', 'hisn-27e', 'hisn-28', 'hisn-25'];
    final ordered = [
      for (final id in pinned) ...provider.categories.where((c) => c.id == id),
      ...provider.categories.where((c) => !pinned.contains(c.id)),
    ];
    final base = _group < 0
        ? ordered
        : provider.categories.where((c) {
            final n = hisnNumber(c.id);
            return n != null && kCategoryGroups[_group].$2.contains(n);
          }).toList();
    final cats = base;

    return Column(
      children: [
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = -1; i < kCategoryGroups.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: HomeChip(
                    tk: tk,
                    label: i < 0 ? 'الكل' : kCategoryGroups[i].$1,
                    selected: _group == i,
                    onTap: () => setState(() => _group = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (_group < 0) ...[
                SliverToBoxAdapter(
                  child: HomeHeroCard(
                    tk: tk,
                    icon: HomeIcons.misbaha,
                    eyebrow: 'اختر بابًا للبدء',
                    title: 'حفظكم الله بذكره',
                    caption:
                        '${toArabicDigits(provider.categories.length)} بابًا من حصن المسلم',
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
              ],
              if (cats.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: HomeEmpty(
                    tk: tk,
                    icon: ZikrIcons.search,
                    title: 'لا توجد أقسام في هذه المجموعة',
                  ),
                )
              else
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 112,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final cat = cats[i];
                      return HomeTile(
                        tk: tk,
                        compact: false,
                        icon: ZikrIcons.forKey(cat.icon),
                        title: shortCategoryTitle(cat.id, cat.title),
                        subtitle: _countLabel(cat.azkar.length),
                        progress: provider.categoryProgress(cat.id),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ZikrListScreen(categoryId: cat.id)),
                        ),
                      );
                    },
                    childCount: cats.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}
