import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/library_data.dart';
import '../../data/quran_data.dart';
import '../../data/stories_data.dart';
import '../../providers/quran_audio_provider.dart';
import '../../providers/quran_provider.dart';
import '../../providers/stories_provider.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';
import '../home/home_screen.dart' show HomeTile;
import '../library/library_widgets.dart';
import '../quran/quran_home_screen.dart' show openReader;

/// «حكايات الوحي»: فهرس مراجع فقط. كل نص يُعرض حرفيًا من القرآن المحمّل في
/// التطبيق أو من كتب الحديث، مع اسم المصدر. لا يُولَّد أي محتوى ديني.
class StoriesHomeScreen extends StatelessWidget {
  const StoriesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return LibPage(
      title: 'حكايات الوحي',
      actions: [
        HeaderButton(
          icon: ZikrIcons.search,
          label: 'بحث',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const StoriesSearchScreen())),
        ),
      ],
      body: LibFuture<StoriesIndex>(
        future: StoriesRepo.index(),
        errorTitle: 'تعذّر تحميل حكايات الوحي',
        builder: (context, idx) {
          final favCount = context.watch<StoriesProvider>().favorites.length;
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              SliverToBoxAdapter(
                child: HomeHeroCard(
                  tk: tk,
                  icon: HomeIcons.quran,
                  eyebrow: 'قصص القرآن والأنبياء والسيرة',
                  title: 'حكايات الوحي',
                  caption: '${toArabicDigits(idx.total)} قصة',
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 112,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i == idx.sections.length) {
                      return HomeTile(
                        tk: tk,
                        compact: false,
                        icon: HomeIcons.heart,
                        title: 'المفضلة',
                        subtitle: favCount == 0
                            ? 'لا شيء محفوظ بعد'
                            : '${toArabicDigits(favCount)} محفوظة',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const StoriesFavoritesScreen())),
                      );
                    }
                    final s = idx.sections[i];
                    return HomeTile(
                      tk: tk,
                      compact: false,
                      icon: i == 0 ? HomeIcons.quran : HomeIcons.books,
                      title: s.title,
                      subtitle: '${s.subtitle} · ${toArabicDigits(s.entries.length)} موضوعًا',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => StorySectionScreen(section: s))),
                    );
                  },
                  childCount: idx.sections.length + 1,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 24),
                  child: Text(
                    'الآيات بنص المصحف المحمّل في التطبيق دون تعديل، والأحاديث كما وردت في الصحيحين '
                    'وغيرهما. وما يُعرض من كتب التاريخ والتفسير (ابن كثير، ابن هشام، الخضري) منقول '
                    'بنصه ومعه تنبيه باسم الكتاب؛ فقد يتضمن روايات لم تصح، ولا يُعدّ من الدين إلا '
                    'ما ثبت بالقرآن والحديث الصحيح. التفاصيل في «المصادر والتراخيص».',
                    style: cairoStyle(11.5, color: tk.muted, height: 1.7),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// قائمة مدخلات قسم (السيرة تُجمَّع حسب العهد).
class StorySectionScreen extends StatelessWidget {
  final StorySection section;
  const StorySectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final favs = context.watch<StoriesProvider>();
    return LibPage(
      title: section.title,
      body: GridView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 112,
        ),
        itemCount: section.entries.length,
        itemBuilder: (context, i) {
          final e = section.entries[i];
          return HomeTile(
            tk: tk,
            compact: false,
            icon: favs.isFav(e.id) ? HomeIcons.heart : HomeIcons.quran,
            title: e.title,
            subtitle: e.era.isEmpty ? 'اقرأ القصة' : e.era,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => StoryScreen(entry: e))),
          );
        },
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final HomeTokens tk;
  final StoryEntry entry;
  final bool fav;
  final int? index;
  final String? subtitle;
  const _EntryRow(
      {required this.tk, required this.entry, required this.fav, this.index, this.subtitle});

  @override
  Widget build(BuildContext context) => LibRow(
        tk: tk,
        leading: index == null ? null : toArabicDigits(index!),
        title: fav ? '★ ${entry.title}' : entry.title,
        subtitle: subtitle,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => StoryScreen(entry: entry))),
      );
}

class StoriesSearchScreen extends StatefulWidget {
  const StoriesSearchScreen({super.key});
  @override
  State<StoriesSearchScreen> createState() => _StoriesSearchScreenState();
}

class _StoriesSearchScreenState extends State<StoriesSearchScreen> {
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
    final favs = context.watch<StoriesProvider>();
    return LibPage(
      title: 'البحث',
      body: LibFuture<StoriesIndex>(
        future: StoriesRepo.index(),
        builder: (context, idx) {
          final res = searchStories(idx, _q);
          Widget body;
          if (searchKey(_q).replaceAll(' ', '').isEmpty) {
            body = HomeEmpty(
                tk: tk,
                icon: ZikrIcons.search,
                title: 'ابحث في حكايات الوحي',
                message: 'اكتب اسم نبي أو قصة أو غزوة');
          } else if (res.isEmpty) {
            body = HomeEmpty(tk: tk, icon: ZikrIcons.search, title: 'لا توجد نتائج');
          } else {
            body = ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final e in res)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EntryRow(
                      tk: tk,
                      entry: e,
                      fav: favs.isFav(e.id),
                      subtitle: idx.sections
                          .firstWhere((s) => s.entries.contains(e))
                          .title,
                    ),
                  ),
              ],
            );
          }
          return Column(children: [
            const SizedBox(height: 6),
            HomeSearchField(
              tk: tk,
              controller: _c,
              hint: 'ابحث عن نبي أو قصة أو غزوة...',
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              onClear: () {
                _c.clear();
                setState(() => _q = '');
              },
            ),
            const SizedBox(height: 10),
            Expanded(child: body),
          ]);
        },
      ),
    );
  }
}

class StoriesFavoritesScreen extends StatelessWidget {
  const StoriesFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final favs = context.watch<StoriesProvider>();
    return LibPage(
      title: 'المفضلة',
      body: LibFuture<StoriesIndex>(
        future: StoriesRepo.index(),
        builder: (context, idx) {
          final list = [
            for (final s in idx.sections)
              for (final e in s.entries)
                if (favs.isFav(e.id)) e,
          ];
          if (list.isEmpty) {
            return HomeEmpty(
                tk: tk,
                icon: HomeIcons.heart,
                title: 'لا توجد مفضلة بعد',
                message: 'اضغط على القلب داخل أي قصة لحفظه هنا');
          }
          return ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            children: [
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EntryRow(tk: tk, entry: e, fav: false),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// صفحة موضوع واحد: تُقرأ ككتاب، صفحة كاملة في كل انتقال، لا كبطاقات متتابعة.
class StoryScreen extends StatelessWidget {
  final StoryEntry entry;
  const StoryScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final favs = context.watch<StoriesProvider>();
    final isFav = favs.isFav(entry.id);
    return LibPage(
      title: entry.title,
      actions: [
        HeaderButton(
          icon: HomeIcons.heart,
          label: isFav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          color: isFav ? tk.gold : null,
          onTap: () => favs.toggle(entry.id),
        ),
      ],
      body: _StoryReader(entry: entry),
    );
  }
}

class _StoryPage {
  final String text;
  final String footer;
  const _StoryPage(this.text, this.footer);
}

/// يبني صفحات القصة من السرد المرفق ثم الآيات والأحاديث الموثقة.
/// النصوص تُقرأ من الأصول الموجودة في التطبيق ولا يُنشأ نص ديني جديد.
Future<List<_StoryPage>> _storyPages(StoryEntry entry, QuranData? quran) async {
  final pages = <_StoryPage>[];
  final sources = await _loadSources(entry);
  for (final source in sources) {
    for (final section in source.hits) {
      final text = section.paragraphs.join('\n\n').trim();
      if (text.isNotEmpty) {
        pages.add(_StoryPage(text,
            '${source.info.title}\n${source.info.author}\n${section.title}'));
      }
    }
  }
  for (final part in entry.parts) {
    if (part.kind == StoryPartKind.quran && quran != null) {
      final ayahs = [
        for (var n = part.from; n <= part.to; n++)
          if (quran.ayahByKey('${part.surah}:$n') != null)
            quran.ayahByKey('${part.surah}:$n')!,
      ];
      if (ayahs.isNotEmpty) {
        pages.add(_StoryPage(
          ayahs.map((a) => '${a.text} ﴿${toArabicDigits(a.number)}﴾').join(' '),
          '${_range(part)}\nالقرآن الكريم',
        ));
      }
    } else if (part.kind == StoryPartKind.hadith) {
      final result = await StoriesRepo.hadith(part.book, part.number);
      if (result != null) {
        pages.add(_StoryPage(
          result.item.text,
          '${result.title} · حديث رقم ${toArabicDigits(result.item.n)}\n${result.chapter.title}',
        ));
      }
    }
  }
  return pages;
}

class _StoryReader extends StatelessWidget {
  final StoryEntry entry;
  const _StoryReader({required this.entry});

  @override
  Widget build(BuildContext context) {
    final quran = context.watch<QuranProvider>().data;
    return FutureBuilder<List<_StoryPage>>(
      future: _storyPages(entry, quran),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final pages = snap.data ?? const <_StoryPage>[];
        if (pages.isEmpty) {
          return HomeEmpty(
            tk: HomeTokens.of(context),
            icon: HomeIcons.books,
            title: 'لا توجد صفحات متاحة',
            message: 'تحقق من ملفات القصة ثم أعد المحاولة',
          );
        }
        return BookPageReader(
          title: entry.title,
          pages: [for (final page in pages) page.text],
          pageFooters: [for (final page in pages) page.footer],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tk.line),
      ),
      child: Text(text, style: cairoStyle(11, weight: 700, color: tk.gold)),
    );
  }
}

String _range(StoryPart p) => p.from == p.to
    ? 'سورة ${QuranAudioProvider.surahName(p.surah)} · آية ${toArabicDigits(p.from)}'
    : 'سورة ${QuranAudioProvider.surahName(p.surah)} · الآيات ${toArabicDigits(p.from)}–${toArabicDigits(p.to)}';

/// آيات مدى واحد بنص المصحف حرفيًا، وبعد كل آية رقمها بين قوسين زخرفيين.
class _QuranPart extends StatefulWidget {
  final StoryPart part;
  const _QuranPart({required this.part});
  @override
  State<_QuranPart> createState() => _QuranPartState();
}

class _QuranPartState extends State<_QuranPart> {
  final bool _tafsir = false; // لا تفسير هنا
  Future<List<String?>>? _tf;

  List<Ayah> _ayahs(QuranData d) {
    final p = widget.part;
    return [
      for (var n = p.from; n <= p.to; n++)
        if (d.ayahByKey('${p.surah}:$n') != null) d.ayahByKey('${p.surah}:$n')!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final q = context.watch<QuranProvider>();
    final d = q.data;
    final p = widget.part;
    if (d == null) {
      return HomeEmpty(
          tk: tk,
          icon: HomeIcons.quran,
          title: 'نص القرآن غير متاح',
          message: 'أعد تثبيت التطبيق أو حدّثه');
    }
    final ayahs = _ayahs(d);
    final expected = p.to - p.from + 1;
    if (ayahs.length != expected) {
      return HomeEmpty(
          tk: tk,
          icon: HomeIcons.quran,
          title: 'تعذّر تحميل الآيات',
          message: _range(p));
    }
    if (_tafsir) _tf ??= Future.wait([for (final a in ayahs) q.tafsirOf(a)]);
    final text = ayahs.map((a) => '${a.text} ﴿${toArabicDigits(a.number)}﴾').join(' ');
    final src = _range(p);
    final footer = '$src\n(القرآن الكريم)';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: AlignmentDirectional.centerStart, child: const _Badge('قرآن كريم')),
          const SizedBox(height: 8),
          SelectableText(text,
              textAlign: TextAlign.justify,
              style: amiriStyle(22, color: tk.ink, height: 2.0)),
          const SizedBox(height: 6),
          Text(src, style: cairoStyle(11.5, weight: 600, color: tk.gold)),
          if (_tafsir)
            FutureBuilder<List<String?>>(
              future: _tf,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(color: tk.leaf)),
                  );
                }
                final t = snap.data!;
                if (t.every((x) => x == null)) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('التفسير غير متاح في هذه النسخة',
                        style: cairoStyle(12, color: tk.muted)),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('التفسير الميسر · مجمع الملك فهد',
                          style: cairoStyle(11.5, weight: 700, color: tk.gold)),
                      for (var i = 0; i < ayahs.length; i++)
                        if (t[i] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('﴿${toArabicDigits(ayahs[i].number)}﴾ ${t[i]}',
                                style: cairoStyle(13, color: tk.ink, height: 1.8)),
                          ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 6),
          Container(height: 1, color: tk.line),
          Row(children: [
            _PartAct(
                icon: ZikrIcons.copy,
                label: 'نسخ',
                onTap: () => copyToClipboard(context, '$text\n\n$footer')),
            _PartAct(
                icon: ZikrIcons.share,
                label: 'مشاركة',
                onTap: () => Share.share('$text\n\n$footer')),
            _PartAct(
                icon: HomeIcons.quran,
                label: 'في المصحف',
                onTap: () => openReader(context, ayahs.first.page, highlight: ayahs.first.key)),
          ]),
        ],
      ),
    );
  }
}

class _PartAct extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _PartAct({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label,
              textAlign: TextAlign.center,
              style: cairoStyle(11.5, weight: 600, color: tk.muted)),
        ),
      ),
    );
  }
}

/// حديث بنصه الحرفي من كتاب المكتبة، مع اسم الكتاب والرقم والباب.
class _HadithPart extends StatelessWidget {
  final StoryPart part;
  const _HadithPart({required this.part});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return FutureBuilder(
      future: StoriesRepo.hadith(part.book, part.number),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: tk.leaf)),
          );
        }
        final r = snap.data;
        if (r == null) {
          return HomeEmpty(
              tk: tk,
              icon: HomeIcons.books,
              title: 'تعذّر تحميل الحديث',
              message: '${StoriesRepo.bookTitles[part.book]} · ${toArabicDigits(part.number)}');
        }
        final src = '${r.title} · حديث رقم ${toArabicDigits(r.item.n)}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: const _Badge('حديث شريف · من الصحيحين')),
            const SizedBox(height: 6),
            TextCard(
              text: r.item.text,
              source: '$src · ${r.chapter.title}',
              shareFooter: '$src\n(${r.chapter.title})',
            ),
          ],
        );
      },
    );
  }
}

/// كتاب أصلي: أقسامه، مع تنبيه علمي ظاهر عن درجة رواياته، والمصدر والـcommit.
class StoryBookScreen extends StatelessWidget {
  final StoryBookInfo info;
  const StoryBookScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return LibPage(
      title: info.title,
      actions: [
        HeaderButton(
          icon: ZikrIcons.search,
          label: 'البحث في الكتاب',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => StoryBookSearchScreen(info: info))),
        ),
      ],
      body: LibFuture<FiqhBook>(
        future: StoriesRepo.book(info),
        errorTitle: 'تعذّر تحميل الكتاب',
        builder: (context, book) => ListView.builder(
          padding: const EdgeInsets.only(top: 6, bottom: 24),
          itemCount: book.sections.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHeroCard(
                      tk: tk,
                      icon: HomeIcons.books,
                      eyebrow: info.author,
                      title: info.title,
                      caption: '${toArabicDigits(book.sections.length)} قسمًا',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tk.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tk.gold),
                      ),
                      child: Text(
                        'تنبيه: ${info.notice}\nالمصدر: ${info.author}، والنص منقول من الكتاب كما هو.',
                        style: cairoStyle(12, color: tk.ink, height: 1.7),
                      ),
                    ),
                  ],
                ),
              );
            }
            final s = book.sections[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LibRow(
                tk: tk,
                emphasized: s.level == 1,
                indent: s.level > 1 ? 12.0 : 0.0,
                title: s.title,
                onTap: () => openBookSection(context, info, s),
              ),
            );
          },
        ),
      ),
    );
  }
}

class StoryBookSearchScreen extends StatefulWidget {
  final StoryBookInfo info;
  const StoryBookSearchScreen({super.key, required this.info});
  @override
  State<StoryBookSearchScreen> createState() => _StoryBookSearchState();
}

class _StoryBookSearchState extends State<StoryBookSearchScreen> {
  final _c = TextEditingController();
  List<FiqhRef> _res = const [];
  FiqhBook? _book;
  bool _busy = false;
  String _q = '';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    setState(() => _q = q);
    if (searchKey(q).replaceAll(' ', '').length < 2) {
      setState(() => _res = const []);
      return;
    }
    setState(() => _busy = true);
    final b = _book ??= await StoriesRepo.book(widget.info);
    final keys = await LibraryRepo.fiqhKeys(b);
    if (!mounted || q != _q) return;
    final idx = LibraryRepo.match(keys, q, limit: 60);
    setState(() {
      _res = [for (final i in idx) b.flat[i]];
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final short = searchKey(_q).replaceAll(' ', '').length < 2;
    Widget body;
    if (short) {
      body = HomeEmpty(
          tk: tk,
          icon: ZikrIcons.search,
          title: 'ابحث في ${widget.info.title}',
          message: 'اكتب كلمة أو أكثر من النص');
    } else if (_busy && _res.isEmpty) {
      body = Center(child: CircularProgressIndicator(color: tk.leaf));
    } else if (_res.isEmpty) {
      body = HomeEmpty(tk: tk, icon: ZikrIcons.search, title: 'لا توجد نتائج');
    } else {
      final b = _book!;
      body = ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: _res.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final r = _res[i];
          final sec = b.sections[r.section].title;
          return TextCard(
            text: r.text,
            source: '${widget.info.title} · $sec',
            shareFooter: '${widget.info.title} — ${widget.info.author}\n($sec)',
            baseSize: 19,
          );
        },
      );
    }
    return LibPage(
      title: 'البحث',
      body: Column(children: [
        const SizedBox(height: 6),
        HomeSearchField(
          tk: tk,
          controller: _c,
          hint: 'ابحث في ${widget.info.title}...',
          autofocus: true,
          onChanged: _run,
          onClear: () {
            _c.clear();
            _run('');
          },
        ),
        const SizedBox(height: 10),
        Expanded(child: body),
      ]),
    );
  }
}

void openBookSection(BuildContext context, StoryBookInfo info, FiqhSection s) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LibPage(
        title: s.title,
        body: BookPageReader(
          title: s.title,
          author: '${info.title} · ${info.author}',
          pages: s.paragraphs,
        ),
      ),
    ),
  );
}

/// كتب سردية جاهزة تُعرض داخل القصة، كلٌّ باسمه وتنبيهه: «قصص الأنبياء» و«البداية
/// والنهاية» لابن كثير، و«السيرة النبوية» لابن هشام، و«نور اليقين» للخضري.
/// النص منقول كما هو من OpenITI دون أي تعديل. الأقسام تُختار بمطابقة عنوانها
/// لكلمات القصة (kw)، ولا يُعرض من الكتاب إلا ما طابق.
class _SourceHits {
  final StoryBookInfo info;
  final List<FiqhSection> hits;
  const _SourceHits(this.info, this.hits);
}

Future<List<_SourceHits>> _loadSources(StoryEntry entry) async {
  final kind = entry.id.split(':').first;
  final all = await StoriesRepo.books();
  final keys = [for (final k in entry.kw) searchKey(k)];
  final out = <_SourceHits>[];
  for (final info in all) {
    if (!info.serves.contains(kind)) continue;
    try {
      final book = await StoriesRepo.book(info);
      // بعض النسخ الخام تحفظ عنوان الفصل بصيغة Markdown مثل ### قصة يوسف.
      // تتم المطابقة بعد تنظيف العنوان حتى لا تختفي القصة بسبب الوسم فقط.
      final hits = [
        for (final s in book.sections)
          if (s.paragraphs.isNotEmpty &&
              keys.any((k) => searchKey(cleanImportedText(s.title)).contains(k))) s,
      ].take(8).toList();
      out.add(_SourceHits(info, hits));
    } catch (_) {
      // كتاب تعذّر تحميله: نتجاوزه ونكمل ببقية المصادر.
    }
  }
  return out;
}

class _BookNarrative extends StatefulWidget {
  final StoryEntry entry;
  const _BookNarrative({required this.entry});

  @override
  State<_BookNarrative> createState() => _BookNarrativeState();
}

class _BookNarrativeState extends State<_BookNarrative> {
  late final Future<List<_SourceHits>> _future = _loadSources(widget.entry);

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return FutureBuilder<List<_SourceHits>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: tk.leaf)),
          );
        }
        final sources = snap.data ?? const <_SourceHits>[];
        if (sources.isEmpty) {
          // لا نعرض رسالة نقص أو نصًا خارج الموضوع؛ تبقى الآيات والأحاديث
          // الموثقة أسفل هذا الجزء هي محتوى القصة المتاح.
          return const SizedBox.shrink();
        }
        final withHits = [for (final s in sources) if (s.hits.isNotEmpty) s];
        final searchable = sources.firstWhere((s) => !s.info.hidden, orElse: () => sources.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final src in withHits) ..._sourceBlock(context, tk, src),
            if (withHits.isEmpty)
              LibRow(
                tk: tk,
                title: 'ابحث عنها في ${searchable.info.title}',
                subtitle: 'لم يُعثر على قسم بعنوانها',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => StoryBookSearchScreen(info: searchable.info))),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _sourceBlock(BuildContext context, HomeTokens tk, _SourceHits src) {
    final info = src.info;
    final style = info.style.isEmpty ? '' : ' · ${info.style}';
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text('القصة · ${info.title} · ${info.author}$style',
            style: cairoStyle(13, weight: 700, color: tk.gold)),
      ),
      for (final s in src.hits)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LibRow(
            tk: tk,
            emphasized: true,
            title: s.title,
            subtitle: 'اقرأ القصة',
            onTap: () => openBookSection(context, info, s),
          ),
        ),
      Container(
        margin: const EdgeInsets.only(top: 2, bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tk.line),
        ),
        child: Text('تنبيه: ${info.notice}',
            style: cairoStyle(11.5, color: tk.muted, height: 1.7)),
      ),
    ];
  }
}
