import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import '../widgets/zikr_card.dart';

class ZikrListScreen extends StatelessWidget {
  final String categoryId;
  const ZikrListScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final cat = provider.categoryById(categoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text(cat.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تعيين العداد',
            onPressed: () => provider.resetCategory(categoryId),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: cat.azkar.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => ZikrCard(zikr: cat.azkar[i]),
      ),
    );
  }
}
