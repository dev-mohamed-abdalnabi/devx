import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/library_data.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';
import 'library_screen.dart' show hadithCountLabel;
import 'library_widgets.dart';

String _source(String bookTitle, HadithItem h) =>
    '$bookTitle · حديث رقم ${toArabicDigits(h.n)}';

/// أحاديث باب واحد.
class _HadithList extends StatelessWidget {
  final String bookTitle;
  final HadithChapter chapter;
  final List<Widget> actions;
  const _HadithList(
      {required this.bookTitle, required this.chapter, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final items = chapter.items;
    return BookPageReader(
      title: chapter.title,
      author: bookTitle,
      pages: [for (final item in items) item.text],
      pageFooters: [for (final item in items) _source(bookTitle, item)],
      actions: actions,
    );
  }
}

/// كتاب حديث: قائمة الأبواب (وإن كان له باب واحد تُعرض أحاديثه مباشرة).
class HadithBookScreen extends StatelessWidget {
  final LibBook book;
  const HadithBookScreen({super.key, required this.book});

  Widget _searchAction(BuildContext context) => HeaderButton(
        icon: ZikrIcons.search,
        label: 'البحث في الكتاب',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HadithSearchScreen(book: book)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return LibFuture<HadithBook>(
      future: LibraryRepo.hadith(book),
      errorTitle: 'تعذّر تحميل الكتاب',
      builder: (context, hb) {
        if (hb.chapters.length == 1) {
          return _HadithList(
            bookTitle: hb.title,
            chapter: hb.chapters.first,
            actions: [_searchAction(context)],
          );
        }
        return LibPage(
          title: book.title,
          actions: [_searchAction(context)],
          body: ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            itemCount: hb.chapters.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HomeHeroCard(
                    tk: tk,
                    icon: HomeIcons.books,
                    eyebrow: hb.author,
                    title: hb.title,
                    caption:
                        '${hadithCountLabel(hb.count)} · ${toArabicDigits(hb.chapters.length)} قسمًا',
                  ),
                );
              }
              final ch = hb.chapters[i - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LibRow(
                  tk: tk,
                  leading: toArabicDigits(i),
                  title: ch.title,
                  subtitle: hadithCountLabel(ch.items.length),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            _HadithList(bookTitle: hb.title, chapter: ch)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// البحث في نص أحاديث كتاب واحد (بدون تشكيل، وكل الكلمات يجب أن تظهر).
class HadithSearchScreen extends StatefulWidget {
  final LibBook book;
  const HadithSearchScreen({super.key, required this.book});

  @override
  State<HadithSearchScreen> createState() => _HadithSearchScreenState();
}

class _HadithSearchScreenState extends State<HadithSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _busy = false;
  List<HadithRef> _results = const [];
  HadithBook? _hb;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v));
  }

  Future<void> _run(String q) async {
    if (searchKey(q).replaceAll(' ', '').length < 2) {
      setState(() {
        _results = const [];
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final hb = _hb ?? await LibraryRepo.hadith(widget.book);
      _hb = hb;
      final keys = await LibraryRepo.hadithKeys(hb);
      if (!mounted || q != _query) return;
      final idx = LibraryRepo.match(keys, q, limit: 60);
      setState(() {
        _results = [for (final i in idx) hb.flat[i]];
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final short = searchKey(_query).replaceAll(' ', '').length < 2;
    Widget body;
    if (short) {
      body = HomeEmpty(
        tk: tk,
        icon: ZikrIcons.search,
        title: 'ابحث في ${widget.book.title}',
        message: 'اكتب كلمة أو أكثر من نص الحديث',
      );
    } else if (_busy && _results.isEmpty) {
      body = Center(child: CircularProgressIndicator(color: tk.leaf));
    } else if (_results.isEmpty) {
      body = HomeEmpty(tk: tk, icon: ZikrIcons.search, title: 'لا توجد نتائج');
    } else {
      body = ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final r = _results[i];
          final src = _source(widget.book.title, r.item);
          return TextCard(
            text: r.item.text,
            source: '$src · ${r.chapter.title}',
            shareFooter: '$src\n(${r.chapter.title})',
          );
        },
      );
    }
    return LibPage(
      title: 'البحث',
      body: Column(
        children: [
          const SizedBox(height: 6),
          HomeSearchField(
            tk: tk,
            controller: _controller,
            hint: 'ابحث في ${widget.book.title}...',
            autofocus: true,
            onChanged: _onChanged,
            onClear: () {
              _controller.clear();
              _onChanged('');
            },
          ),
          const SizedBox(height: 10),
          Expanded(child: body),
        ],
      ),
    );
  }
}
