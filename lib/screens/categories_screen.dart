import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import 'zikr_list_screen.dart';

final _icons = {
  'wb_sunny': Icons.wb_sunny_rounded,
  'nightlight_round': Icons.nightlight_round,
  'bedtime': Icons.bedtime_rounded,
  'alarm': Icons.alarm,
  'mosque': Icons.mosque,
  'favorite': Icons.favorite,
  'home': Icons.home,
  'campaign': Icons.campaign,
  'water_drop': Icons.water_drop,
  'self_improvement': Icons.self_improvement,
  'restaurant': Icons.restaurant,
  'checkroom': Icons.checkroom,
  'flight': Icons.flight,
  'storefront': Icons.storefront,
  'healing': Icons.healing,
  'sentiment_stressed': Icons.sentiment_stressed,
  'mood_bad': Icons.mood_bad,
  'payments': Icons.payments,
  'thunderstorm': Icons.thunderstorm,
  'sick': Icons.sick,
  'back_hand': Icons.back_hand,
  'route': Icons.route,
  'wc': Icons.wc,
  'child_care': Icons.child_care,
};

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();

    if (provider.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أذكاري', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('حفظكم الله بذكره', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.separated(
            itemCount: provider.categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final cat = provider.categories[i];
              final progress = provider.categoryProgress(cat.id);
              return _CategoryCard(
                title: cat.title,
                icon: _icons[cat.icon] ?? Icons.menu_book,
                progress: progress,
                count: cat.azkar.length,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ZikrListScreen(categoryId: cat.id)),
                ),
              );
            },
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
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
