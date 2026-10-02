import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import '../widgets/zikr_card.dart';

class ZikrListScreen extends StatefulWidget {
  final String categoryId;
  const ZikrListScreen({super.key, required this.categoryId});

  @override
  State<ZikrListScreen> createState() => _ZikrListScreenState();
}

class _ZikrListScreenState extends State<ZikrListScreen> {
  final _scrollController = ScrollController();
  bool _restoredPosition = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNext(int index, int length) {
    if (index >= length - 1 || !_scrollController.hasClients) return;
    final nextOffset = ((index + 1) * 250.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          nextOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final cat = provider.categoryById(widget.categoryId);

    if (!_restoredPosition) {
      _restoredPosition = true;
      final firstPending = cat.azkar.indexWhere((z) => z.remaining > 0);
      if (firstPending > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              (firstPending * 250.0).clamp(0.0, _scrollController.position.maxScrollExtent),
            );
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(cat.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تعيين العداد',
            onPressed: () => provider.resetCategory(widget.categoryId),
          ),
        ],
      ),
      body: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: cat.azkar.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => ZikrCard(
          zikr: cat.azkar[i],
          onCompleted: () => _scrollToNext(i, cat.azkar.length),
        ),
      ),
    );
  }
}
