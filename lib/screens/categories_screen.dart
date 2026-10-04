import '../core/category_groups.dart';
import '../core/short_titles.dart';
import '../core/star_shape.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import '../widgets/app_ui.dart';
import 'zikr_list_screen.dart';

final _icons = {
  'wb_sunny': Icons.wb_sunny_rounded,
  'nightlight_round': Icons.nightlight_round,
  'bedtime': Icons.bedtime_rounded,
  'alarm': Icons.alarm_rounded,
  'mosque': Icons.mosque_outlined,
  'favorite': Icons.favorite_rounded,
  'home': Icons.home_rounded,
  'campaign': Icons.campaign_rounded,
  'water_drop': Icons.water_drop_rounded,
  'self_improvement': Icons.self_improvement_rounded,
  'restaurant': Icons.restaurant_rounded,
  'checkroom': Icons.checkroom_rounded,
  'flight': Icons.flight_rounded,
  'storefront': Icons.storefront_rounded,
  'healing': Icons.healing_rounded,
  'sentiment_stressed': Icons.sentiment_very_dissatisfied,
  'mood_bad': Icons.mood_bad_rounded,
  'payments': Icons.payments_rounded,
  'thunderstorm': Icons.thunderstorm_rounded,
  'sick': Icons.sick_rounded,
  'back_hand': Icons.back_hand_rounded,
  'route': Icons.route_rounded,
  'wc': Icons.wc_rounded,
  'child_care': Icons.child_care_rounded,
};

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _search = TextEditingController();
  String _q = '';
  int _group = -1; // -1 = الكل

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
              provider.error?.toString() ?? 'لا توجد أذكار متاحة حاليًا',
              textAlign: TextAlign.center),
        ),
      );
    }

    final q = normalizeArabic(_q);
    const pinned = ['hisn-27', 'hisn-28', 'hisn-25'];
    final ordered = [
      for (final id in pinned)
        ...provider.categories.where((c) => c.id == id),
      ...provider.categories.where((c) => !pinned.contains(c.id)),
    ];
    final base = _group < 0
        ? ordered
        : provider.categories.where((c) {
            final n = hisnNumber(c.id);
            return n != null && kCategoryGroups[_group].$2.contains(n);
          }).toList();
    final cats = q.isEmpty
        ? base
        : base.where((c) {
            return normalizeArabic(c.title).contains(q) ||
                normalizeArabic(shortCategoryTitle(c.id, c.title)).contains(q);
          }).toList();

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: const AppSectionHeader(
              title: 'ذكر',
              subtitle: 'حفظكم الله بذكره · اختر بابًا للبدء',
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث في الأذكار...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() => _q = '');
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                for (var i = -1; i < kCategoryGroups.length; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(i < 0 ? 'الكل' : kCategoryGroups[i].$1),
                      selected: _group == i,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _group = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (cats.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('لا توجد نتائج لـ «$_q»',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 100,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final cat = cats[i];
                  final progress = provider.categoryProgress(cat.id);
                  return AppGridTile(
                    leading: IslamicStar(
                      size: 50,
                      color: scheme.primaryContainer,
                      child: Icon(_icons[cat.icon] ?? Icons.menu_book_rounded,
                          size: 21, color: scheme.onPrimaryContainer),
                    ),
                    titleMaxLines: 2,
                    title: shortCategoryTitle(cat.id, cat.title),
                    subtitle: '${cat.azkar.length} أذكار',
                    footer: AppProgressBar(value: progress),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ZikrListScreen(categoryId: cat.id)),
                    ),
                  );
                },
                childCount: cats.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double progress;
  final int count;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.progress,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IslamicStar(
                size: 54,
                color: scheme.primaryContainer,
                child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$count أذكار',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}
