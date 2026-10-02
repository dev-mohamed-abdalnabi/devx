import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/azkar_provider.dart';
import '../widgets/zikr_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final results = provider.search(_query);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث عن ذكر أو دعاء...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _query.isEmpty
                ? const Center(child: Text('اكتب كلمة للبحث في كل الأذكار', style: TextStyle(color: Colors.grey)))
                : results.isEmpty
                    ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => ZikrCard(zikr: results[i]),
                      ),
          ),
        ],
      ),
    );
  }
}
