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
  String _filter = 'all';

  List<DuaItem> _filtered(List<DuaItem> all) {
    return all.where((d) {
      final categoryOk = switch (_filter) {
        'quran' => d.category == 'quran',
        'prophets' => _prophetIds.contains(d.id),
        'prophetic' => d.category == 'prophetic',
        'general' => d.category == 'quran' && !_prophetIds.contains(d.id),
        _ => true,
      };
      return categoryOk;
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
              PageHeader(title: 'الأدعية', actions: [
                HeaderButton(
                  icon: ZikrIcons.search,
                  label: 'بحث',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DuasSearchScreen(future: _future))),
                ),
              ]),
              HomeHeroCard(
                tk: tk,
                icon: HomeIcons.hand,
                eyebrow: 'من القرآن والسنة الصحيحة',
                title: 'أدعية تلامس يومك',
                caption: 'نصوص موثقة مع مراجعها، للقراءة والنسخ والمشاركة',
                height: 116,
              ),
              const SizedBox(height: 10),
              _DuaTabs(
                value: _filter,
                onChanged: (value) => setState(() => _filter = value),
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
                        message: 'غيّر التصنيف',
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

}

class _DuaTabs extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DuaTabs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    const tabs = [
      ('all', 'الكل'),
      ('quran', 'القرآن'),
      ('prophets', 'الأنبياء'),
      ('prophetic', 'النبي ﷺ'),
      ('general', 'جامعة'),
    ];
    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: HomeChip(
              tk: tk,
              label: tabs[i].$2,
              selected: value == tabs[i].$1,
              onTap: () => onChanged(tabs[i].$1),
            ),
          ),
        ],
      ],
    );
  }
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

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DuaDetailsSheet(tk: tk, dua: dua),
    );
  }

  @override
  Widget build(BuildContext context) => KitCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(dua.title, style: cairoStyle(14, weight: 700, color: tk.ink))),
            TextButton.icon(
              onPressed: () => _showDetails(context),
              icon: Icon(Icons.info_outline_rounded, size: 16, color: tk.leaf),
              label: Text('تفاصيل', style: cairoStyle(11.5, weight: 700, color: tk.leaf)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 5)),
            ),
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

class _DuaDetailsSheet extends StatelessWidget {
  final HomeTokens tk;
  final DuaItem dua;
  const _DuaDetailsSheet({required this.tk, required this.dua});

  Widget _detail(String label, String value, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: tk.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: cairoStyle(12, weight: 700, color: tk.muted)),
              const SizedBox(height: 3),
              Text(value, style: cairoStyle(13.5, color: tk.ink, height: 1.65)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 70),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: tk.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: tk.line),
          ),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: tk.line, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              Text('تفاصيل الدعاء', style: cairoStyle(18, weight: 800, color: tk.ink)),
              const SizedBox(height: 6),
              Text(dua.title, style: amiriStyle(22, color: tk.leaf, height: 1.5)),
              const SizedBox(height: 16),
              _detail('القائل', dua.speaker, Icons.person_outline_rounded),
              _detail('المناسبة ولماذا يُقال', dua.occasion, Icons.auto_awesome_outlined),
              _detail('المصدر والمرجع', '${dua.source} · ${dua.reference}', Icons.menu_book_outlined),
            ]),
          ),
        ),
      );
}

/// بحث الأدعية: شاشة مستقلة تُفتح من زر البحث في الهيدر (مثل حكايات الوحي).
class DuasSearchScreen extends StatefulWidget {
  final Future<List<DuaItem>> future;
  const DuasSearchScreen({super.key, required this.future});
  @override
  State<DuasSearchScreen> createState() => _DuasSearchScreenState();
}

class _DuasSearchScreenState extends State<DuasSearchScreen> {
  final _c = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
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
              const PageHeader(title: 'البحث'),
              const SizedBox(height: 6),
              HomeSearchField(
                tk: tk,
                controller: _c,
                hint: 'ابحث في الأدعية أو المراجع',
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim()),
                onClear: () {
                  _c.clear();
                  setState(() => _q = '');
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<DuaItem>>(
                  future: widget.future,
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
                    final q = searchKey(_q);
                    if (q.replaceAll(' ', '').isEmpty) {
                      return HomeEmpty(
                        tk: tk,
                        icon: ZikrIcons.search,
                        title: 'ابحث في الأدعية',
                        message: 'اكتب كلمة من الدعاء أو مرجعه',
                      );
                    }
                    final items = snap.data!
                        .where((d) => searchKey('${d.title} ${d.text} ${d.reference}').contains(q))
                        .toList();
                    if (items.isEmpty) {
                      return HomeEmpty(
                        tk: tk,
                        icon: ZikrIcons.search,
                        title: 'لا توجد نتائج',
                        message: 'جرّب كلمة أخرى',
                      );
                    }
                    return ListView.separated(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(top: 4, bottom: 18),
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
}
