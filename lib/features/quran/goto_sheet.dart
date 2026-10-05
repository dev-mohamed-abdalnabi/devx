import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../core/star_shape.dart';
import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../data/quran_data.dart';
import '../../providers/quran_audio_provider.dart';
import '../../providers/quran_provider.dart';
import '../more/bookmarks_screen.dart';
import 'quran_ui.dart';

class GotoResult {
  final int page;
  final String? ayahKey;
  const GotoResult(this.page, [this.ayahKey]);
}

/// «اذهب إلى»: سورة · جزء · صفحة · علامات.
Future<GotoResult?> showGotoSheet(BuildContext context, HomeTokens tk,
    {required int currentPage}) {
  return qSheet<GotoResult>(
    context,
    tk,
    (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (ctx, sc) =>
            _GotoBody(tk: tk, currentPage: currentPage, controller: sc),
      ),
    ),
  );
}

class _GotoBody extends StatefulWidget {
  final HomeTokens tk;
  final int currentPage;
  final ScrollController controller;
  const _GotoBody(
      {required this.tk, required this.currentPage, required this.controller});

  @override
  State<_GotoBody> createState() => _GotoBodyState();
}

class _GotoBodyState extends State<_GotoBody> {
  int _tab = 0;
  String _filter = '';
  String _ayahQuery = '';
  final _pageCtl = TextEditingController();

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  void _submitPage(int max) {
    final v = int.tryParse(_pageCtl.text);
    if (v == null || v < 1) return;
    Navigator.pop(context, GotoResult(v.clamp(1, max)));
  }

  @override
  Widget build(BuildContext context) {
    final tk = widget.tk;
    final q = context.watch<QuranProvider>();
    final data = q.data!;
    final cur = data.byPage[widget.currentPage]?.first;

    const tabs = ['السور', 'الأجزاء', 'صفحة', 'بحث في الآيات', 'العلامات'];
    Widget body;
    switch (_tab) {
      case 0:
        body = _surahs(tk, data, cur?.surah ?? 1);
        break;
      case 1:
        body = _juzs(tk, data, cur?.juz ?? 1);
        break;
      case 2:
        body = _pageInput(tk, data.pageCount);
        break;
      case 3:
        body = _ayahSearch(tk, data);
        break;
      default:
        body = _marks(tk, q);
    }

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++) ...[
                    QPill(
                        tk: tk,
                        label: tabs[i],
                        selected: _tab == i,
                        onTap: () => setState(() => _tab = i)),
                    if (i < tabs.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _badge(HomeTokens tk, int n) => IslamicStar(
        size: 40,
        color: tk.mint,
        child: Text(toArabicDigits(n),
            style: cairoStyle(11.5, weight: 700, color: tk.mintInk)),
      );

  Widget _surahs(HomeTokens tk, QuranData data, int current) {
    final nq = normalizeArabic(_filter);
    final asNum = int.tryParse(_filter);
    final list = data.surahs.where((s) {
      if (_filter.isEmpty) return true;
      if (asNum != null) return s.number == asNum;
      return normalizeArabic(s.name).contains(nq) ||
          normalizeArabic(QuranAudioProvider.surahName(s.number)).contains(nq);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v.trim()),
            style: cairoStyle(14, color: tk.ink),
            decoration: InputDecoration(
              hintText: 'ابحث باسم السورة أو رقمها',
              hintStyle: cairoStyle(14, color: tk.muted),
              isDense: true,
              filled: true,
              fillColor: tk.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: tk.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: tk.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: tk.gold)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final s = list[i];
              final on = s.number == current;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context, GotoResult(s.firstPage)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: tk.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: on ? tk.gold : tk.line),
                  ),
                  child: Row(
                    children: [
                      _badge(tk, s.number),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(QuranAudioProvider.surahName(s.number),
                                style:
                                    amiriStyle(20, bold: true, color: tk.ink)),
                            Text(
                                '${s.meccan ? 'مكية' : 'مدنية'} · ${toArabicDigits(s.ayahCount)} آية',
                                style: cairoStyle(11.5, color: tk.muted)),
                          ],
                        ),
                      ),
                      Text('ص ${toArabicDigits(s.firstPage)}',
                          style: cairoStyle(12, weight: 600, color: tk.gold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _juzs(HomeTokens tk, QuranData data, int current) {
    return GridView.builder(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 68,
      ),
      itemCount: 30,
      itemBuilder: (ctx, i) {
        final on = i + 1 == current;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              Navigator.pop(context, GotoResult(data.juzStartPages[i])),
          child: Container(
            decoration: BoxDecoration(
              color: on ? tk.mint : tk.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? tk.gold : tk.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('الجزء ${toArabicDigits(i + 1)}',
                    style: cairoStyle(13.5,
                        weight: 700, color: on ? tk.mintInk : tk.ink)),
                Text('صفحة ${toArabicDigits(data.juzStartPages[i])}',
                    style: cairoStyle(11, color: tk.muted)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pageInput(HomeTokens tk, int max) {
    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Center(
          child: Text('اكتب رقم الصفحة (١ – ${toArabicDigits(max)})',
              style: cairoStyle(13, color: tk.muted)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pageCtl,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _submitPage(max),
          style: cairoStyle(30, weight: 700, color: tk.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: tk.card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: tk.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: tk.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: tk.gold)),
          ),
        ),
        const SizedBox(height: 14),
        QButton(tk: tk, label: 'اذهب', onTap: () => _submitPage(max)),
      ],
    );
  }

  Widget _ayahSearch(HomeTokens tk, QuranData data) {
    final hits = _ayahQuery.trim().isEmpty
        ? const <Ayah>[]
        : data.searchAyahs(_ayahQuery);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _ayahQuery = v),
            style: cairoStyle(14, color: tk.ink),
            decoration: InputDecoration(
              hintText: 'اكتب كلمة أو جزءًا من آية',
              hintStyle: cairoStyle(14, color: tk.muted),
              isDense: true,
              filled: true,
              fillColor: tk.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: tk.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: tk.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: tk.gold)),
            ),
          ),
        ),
        Expanded(
          child: hits.isEmpty
              ? Center(
                  child: Text(
                      _ayahQuery.trim().isEmpty
                          ? 'ابحث بكلمة من القرآن'
                          : 'لا توجد نتائج مطابقة',
                      style: cairoStyle(13.5, color: tk.muted)),
                )
              : ListView.builder(
                  controller: widget.controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: hits.length,
                  itemBuilder: (ctx, i) {
                    final a = hits[i];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          Navigator.pop(context, GotoResult(a.page, a.key)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tk.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: tk.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '${surahTitle(a.surah)} · ${toArabicDigits(a.number)}',
                                      style: cairoStyle(13,
                                          weight: 700, color: tk.ink)),
                                ),
                                Text('ص ${toArabicDigits(a.page)}',
                                    style: cairoStyle(12,
                                        weight: 600, color: tk.gold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(a.text,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: AppTheme.quranFont,
                                    fontSize: 19,
                                    height: 1.9,
                                    color: tk.ink)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _marks(HomeTokens tk, QuranProvider q) {
    final data = q.data!;
    final items = q.bookmarks.map(data.ayahByKey).whereType<Ayah>().toList()
      ..sort((a, b) => q.ayahIndex(a).compareTo(q.ayahIndex(b)));
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('لا توجد علامات بعد.\nاضغط على أي آية ثم «علامة».',
              textAlign: TextAlign.center,
              style: cairoStyle(13.5, color: tk.muted, height: 1.8)),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final a = items[i];
              final mark = q.markOf(a.key);
              final c = kMarkColors[(mark?.color ?? 0) % kMarkColors.length];
              final note = (mark?.note ?? '').trim();
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context, GotoResult(a.page, a.key)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tk.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tk.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: c, shape: BoxShape.circle)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '${surahTitle(a.surah)} · ${toArabicDigits(a.number)}',
                                      style: cairoStyle(13.5,
                                          weight: 700, color: tk.ink)),
                                ),
                                Text('ص ${toArabicDigits(a.page)}',
                                    style: cairoStyle(12,
                                        weight: 600, color: tk.gold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // الآية كاملة بلا اقتطاع.
                            Text(a.text,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: AppTheme.quranFont,
                                    fontSize: 20,
                                    height: 1.9,
                                    color: tk.ink)),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: tk.mint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.sticky_note_2_outlined,
                                        size: 16, color: tk.gold),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(note,
                                          style: cairoStyle(13,
                                              color: tk.mintInk, height: 1.6)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: QButton(
            tk: tk,
            primary: false,
            label: 'كل العلامات',
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()));
            },
          ),
        ),
      ],
    );
  }
}
