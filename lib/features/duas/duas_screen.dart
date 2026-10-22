import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/duas_data.dart';
import '../../features/home/home_art.dart';
import '../../widgets/home_style.dart';
import '../../widgets/page_kit.dart';

const _prophetIds = <String>{
  'q-2-127-0', 'q-2-128-1', 'q-7-23-9', 'q-7-126-10', 'q-7-89-11',
  'q-14-40-17', 'q-21-83-21', 'q-21-87-22', 'q-21-89-23', 'q-26-83-16',
  'q-28-24-24', 'q-37-100-19',
};

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});
  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  late final Future<List<DuaItem>> _future = DuasRepo.load();
  final _search = TextEditingController();
  String _filter = 'all';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DuaItem> _filtered(List<DuaItem> all) {
    final q = searchKey(_query);
    return all.where((d) {
      final categoryOk = switch (_filter) {
        'quran' => d.category == 'quran',
        'prophets' => _prophetIds.contains(d.id),
        'prophetic' => d.category == 'prophetic',
        'general' => d.category == 'quran' && !_prophetIds.contains(d.id),
        _ => true,
      };
      if (!categoryOk) return false;
      if (q.isEmpty) return true;
      return searchKey('${d.title} ${d.text} ${d.reference}').contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    return Scaffold(
      body: MediaQuery(
        data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              const PageHeader(title: 'الأدعية'),
              HomeHeroCard(
                tk: tk,
                icon: HomeIcons.hand,
                eyebrow: 'من القرآن والسنة الصحيحة',
                title: 'أدعية تلامس يومك',
                caption: 'نصوص موثقة مع مراجعها، للقراءة والنسخ والمشاركة',
                height: 116,
              ),
              const SizedBox(height: 10),
              HomeSearchField(
                tk: tk,
                controller: _search,
                hint: 'ابحث في الأدعية أو المراجع',
                onChanged: (v) => setState(() => _query = v.trim()),
                onClear: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  children: [
                    _chip(tk, 'all', 'الكل'),
                    _chip(tk, 'quran', 'أدعية القرآن'),
                    _chip(tk, 'prophets', 'أدعية الأنبياء'),
                    _chip(tk, 'prophetic', 'أدعية النبي ﷺ'),
                    _chip(tk, 'general', 'أدعية جامعة'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: FutureBuilder<List<DuaItem>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return HomeEmpty(
                        tk: tk,
                        icon: HomeIcons.hand,
                        title: 'تعذّر تحميل الأدعية',
                        message: 'أعد فتح التطبيق ثم حاول مرة أخرى',
                      );
                    }
                    if (!snap.hasData) {
                      return Center(child: CircularProgressIndicator(color: tk.leaf));
                    }
                    final items = _filtered(snap.data!);
                    if (items.isEmpty) {
                      return HomeEmpty(
                        tk: tk,
                        icon: ZikrIcons.search,
                        title: 'لا توجد نتائج',
                        message: 'جرّب كلمة أخرى أو غيّر التصنيف',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 18),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _DuaCard(tk: tk, dua: items[i]),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(HomeTokens tk, String id, String label) => Padding(
        padding: const EdgeInsets.only(left: 7),
        child: ChoiceChip(
          label: Text(label, style: cairoStyle(12.5, weight: 600, color: _filter == id ? tk.card : tk.ink)),
          selected: _filter == id,
          onSelected: (_) => setState(() => _filter = id),
          selectedColor: tk.leaf,
          backgroundColor: tk.card,
          side: BorderSide(color: _filter == id ? tk.leaf : tk.line),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      );
}

class _DuaCard extends StatelessWidget {
  final HomeTokens tk;
  final DuaItem dua;
  const _DuaCard({required this.tk, required this.dua});

  String get _shareText => '${dua.title}\n\n${dua.text}\n\n${dua.source} · ${dua.reference}';

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _shareText));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الدعاء')));
  }

  @override
  Widget build(BuildContext context) => KitCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(dua.title, style: cairoStyle(14, weight: 700, color: tk.ink))),
            IconButton(icon: Icon(Icons.copy_rounded, size: 19, color: tk.muted), tooltip: 'نسخ', onPressed: () => _copy(context)),
            IconButton(icon: Icon(Icons.share_rounded, size: 19, color: tk.muted), tooltip: 'مشاركة', onPressed: () => Share.share(_shareText)),
          ]),
          const SizedBox(height: 5),
          Text(dua.text, textAlign: TextAlign.right, style: amiriStyle(21, color: tk.ink, height: 1.85)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.verified_outlined, size: 15, color: tk.gold),
            const SizedBox(width: 5),
            Expanded(child: Text('${dua.source} · ${dua.reference}', style: cairoStyle(11.5, color: tk.muted))),
          ]),
        ]),
      );
}
