import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/home_tokens.dart';
import '../providers/azkar_provider.dart';
import '../widgets/home_style.dart';
import '../widgets/zikr_card.dart';

/// البحث في كل الأذكار — نفس هيدر وكروت الرئيسية.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final provider = context.watch<AzkarProvider>();
    final results = provider.search(_query);

    Widget body;
    if (_query.isEmpty) {
      body = HomeEmpty(
        tk: tk,
        icon: ZikrIcons.search,
        title: 'ابحث في كل الأذكار',
        message: 'اكتب كلمة من الذكر أو الدعاء',
      );
    } else if (results.isEmpty) {
      body = HomeEmpty(tk: tk, icon: ZikrIcons.search, title: 'لا توجد نتائج');
    } else {
      body = ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => ZikrCard(zikr: results[i]),
      );
    }

    return Scaffold(
      body: MediaQuery(
        data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                const PageHeader(title: 'البحث'),
                const SizedBox(height: 6),
                HomeSearchField(
                  tk: tk,
                  controller: _controller,
                  hint: 'ابحث عن ذكر أو دعاء...',
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                ),
                const SizedBox(height: 10),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
