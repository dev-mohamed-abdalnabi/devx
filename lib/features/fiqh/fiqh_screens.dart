import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/library_data.dart';
import '../../widgets/home_style.dart';
import '../../widgets/page_kit.dart' show KitCard;
import '../home/home_art.dart';
import '../library/library_widgets.dart';

/// الأحكام الفقهية: متون المذاهب الأربعة من كتبها الأصلية، كما هي بلا تعديل.
class FiqhScreen extends StatelessWidget {
  const FiqhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return LibPage(
      title: 'الأحكام الفقهية',
      body: LibFuture<List<FiqhInfo>>(
        future: LibraryRepo.fiqhIndex(),
        errorTitle: 'تعذّر تحميل الأحكام الفقهية',
        builder: (context, infos) => ListView(
          padding: const EdgeInsets.only(top: 6, bottom: 24),
          children: [
            HomeHeroCard(
              tk: tk,
              icon: HomeIcons.scale,
              eyebrow: 'من كتب الفقه الأصلية',
              title: 'الأحكام الفقهية',
              caption: 'المذاهب الأربعة · العبادات والمعاملات',
            ),
            const SizedBox(height: 10),
            LibRow(
              tk: tk,
              emphasized: true,
              title: 'ابحث في كل المذاهب',
              subtitle: 'في نص الكتب الأربعة كلها',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FiqhSearchScreen(infos: infos)),
              ),
            ),
            const SizedBox(height: 10),
            for (final b in infos) ...[
              LibRow(
                tk: tk,
                title: b.madhhab,
                subtitle: '${b.title}\n${b.author}',
                subtitleLines: 3,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FiqhBookScreen(info: b)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            KitCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                'النصوص منقولة كما هي من كتب أهل العلم المعتمدة في كل مذهب '
                'دون تعديل منا، وتُعرض كما وردت في الكتاب مع اسم المؤلف. '
                'وفي النوازل والمسائل الخاصة اسأل أهل العلم الثقات.',
                style: cairoStyle(12, color: tk.muted, height: 1.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// فهرس كتاب فقهي: كتب وأبواب.
class FiqhBookScreen extends StatelessWidget {
  final FiqhInfo info;
  const FiqhBookScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return LibPage(
      title: info.madhhab,
      actions: [
        HeaderButton(
          icon: ZikrIcons.search,
          label: 'البحث في الكتاب',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => FiqhSearchScreen(infos: [info])),
          ),
        ),
      ],
      body: LibFuture<FiqhBook>(
        future: LibraryRepo.fiqh(info),
        errorTitle: 'تعذّر تحميل الكتاب',
        builder: (context, book) => ListView.builder(
          padding: const EdgeInsets.only(top: 6, bottom: 24),
          itemCount: book.sections.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HomeHeroCard(
                  tk: tk,
                  icon: HomeIcons.scale,
                  eyebrow: book.author,
                  title: book.title,
                  caption: info.desc,
                ),
              );
            }
            final s = book.sections[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LibRow(
                tk: tk,
                title: s.title,
                emphasized: s.level == 1,
                indent: s.level <= 1 ? 0 : (s.level - 1) * 14.0,
                onTap: () {
                  // عنوان «كتاب» بلا نص يفتح أول باب تحته.
                  var t = i - 1;
                  while (t < book.sections.length &&
                      book.sections[t].paragraphs.isEmpty) {
                    t++;
                  }
                  if (t >= book.sections.length) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FiqhReaderScreen(book: book, index: t)),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// قراءة قسم من كتاب فقهي، مع السابق/التالي.
class FiqhReaderScreen extends StatefulWidget {
  final FiqhBook book;
  final int index;
  const FiqhReaderScreen({super.key, required this.book, required this.index});

  @override
  State<FiqhReaderScreen> createState() => _FiqhReaderScreenState();
}

class _FiqhReaderScreenState extends State<FiqhReaderScreen> {
  late int _i = widget.index;

  void _go(int to) => setState(() => _i = to);

  /// أقرب قسم فيه نص في الاتجاه [dir] (العناوين الفارغة تُتخطّى)، أو -1.
  int _step(int dir) {
    var j = _i + dir;
    final secs = widget.book.sections;
    while (j >= 0 && j < secs.length && secs[j].paragraphs.isEmpty) {
      j += dir;
    }
    return (j < 0 || j >= secs.length) ? -1 : j;
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final s = book.sections[_i];
    return LibPage(
      title: s.title,
      body: BookPageReader(
        key: ValueKey(_i),
        title: s.title,
        author: '${book.title} · ${book.author}',
        pages: s.paragraphs,
      ),
    );
  }
}

class _Hit {
  final FiqhBook book;
  final int section;
  final String snippet;
  const _Hit(this.book, this.section, this.snippet);
}

/// بحث في نص كتاب واحد أو الكتب الأربعة.
class FiqhSearchScreen extends StatefulWidget {
  final List<FiqhInfo> infos;
  const FiqhSearchScreen({super.key, required this.infos});

  @override
  State<FiqhSearchScreen> createState() => _FiqhSearchScreenState();
}

class _FiqhSearchScreenState extends State<FiqhSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _busy = false;
  bool _failed = false;
  int _only = -1; // -1 = كل الكتب
  List<_Hit> _hits = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _run);
  }

  Future<void> _run() async {
    final q = _query;
    if (searchKey(q).replaceAll(' ', '').length < 2) {
      setState(() {
        _hits = const [];
        _busy = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final infos = _only < 0 ? widget.infos : [widget.infos[_only]];
      final perBook = (60 / infos.length).ceil();
      final hits = <_Hit>[];
      for (final info in infos) {
        final book = await LibraryRepo.fiqh(info);
        final keys = await LibraryRepo.fiqhKeys(book);
        final idx = LibraryRepo.match(keys, q, limit: perBook);
        for (final i in idx) {
          final ref = book.flat[i];
          hits.add(_Hit(book, ref.section, snippetFor(ref.text, keys[i], q)));
        }
      }
      if (!mounted || q != _query) return;
      setState(() {
        _hits = hits;
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final short = searchKey(_query).replaceAll(' ', '').length < 2;
    Widget body;
    if (_failed) {
      body = HomeEmpty(
          tk: tk, icon: ZikrIcons.search, title: 'تعذّر البحث حاليًا');
    } else if (short) {
      body = HomeEmpty(
        tk: tk,
        icon: ZikrIcons.search,
        title: 'ابحث في الأحكام الفقهية',
        message: 'اكتب كلمة أو أكثر من نص المسألة',
      );
    } else if (_busy && _hits.isEmpty) {
      body = Center(child: CircularProgressIndicator(color: tk.leaf));
    } else if (_hits.isEmpty) {
      body = HomeEmpty(tk: tk, icon: ZikrIcons.search, title: 'لا توجد نتائج');
    } else {
      body = ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: _hits.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final h = _hits[i];
          return LibRow(
            tk: tk,
            title: '${h.book.madhhab} · ${h.book.sections[h.section].title}',
            subtitle: h.snippet,
            subtitleLines: 5,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      FiqhReaderScreen(book: h.book, index: h.section)),
            ),
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
            hint: 'ابحث في الأحكام الفقهية...',
            autofocus: true,
            onChanged: _onChanged,
            onClear: () {
              _controller.clear();
              _onChanged('');
            },
          ),
          if (widget.infos.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = -1; i < widget.infos.length; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: HomeChip(
                        tk: tk,
                        label: i < 0 ? 'الكل' : widget.infos[i].madhhab,
                        selected: _only == i,
                        onTap: () {
                          setState(() => _only = i);
                          _run();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(child: body),
        ],
      ),
    );
  }
}
