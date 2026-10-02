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

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(provider.error?.toString() ?? 'لا توجد أذكار متاحة حاليًا', textAlign: TextAlign.center),
        ),
      );
    }

    return CustomScrollView(
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
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: OrnamentDivider(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final cat = provider.categories[i];
                final progress = provider.categoryProgress(cat.id);
                return AppGridTile(
                  leading: AppIconBadge(icon: _icons[cat.icon] ?? Icons.menu_book_rounded, size: 52),
                  title: cat.title,
                  subtitle: '${cat.azkar.length} أذكار',
                  footer: AppProgressBar(value: progress),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ZikrListScreen(categoryId: cat.id)),
                  ),
                );
              },
              childCount: provider.categories.length,
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                    Text('$count أذكار', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
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
