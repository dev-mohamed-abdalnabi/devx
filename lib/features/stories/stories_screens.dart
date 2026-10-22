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
import '../more/support_screen.dart';
import '../quran/quran_home_screen.dart' show openReader;

/// «حكايات الوحي»: الآيات تُعرض حرفيًا من القرآن المحمّل في التطبيق، والأحاديث
/// حرفيًا من كتب الحديث، مع اسم المصدر. وسرد قصص القرآن والأنبياء مكتوب ومصنَّف
/// بصناديقه (من أقوال المفسرين / مما لم يرد فيه نص) في tool/authored. قسم السيرة
/// قيد الإعداد: يعرض رسالة وزر تواصل.
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
                      subtitle: s.entries.isEmpty
                          ? '${s.subtitle} · قريبًا'
                          : '${s.subtitle} · ${toArabicDigits(s.entries.length)} موضوعًا',
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
                    'الآيات بنص المصحف المحمّل في التطبيق دون تعديل، والأحاديث كما وردت في الصحيحين، '
                    'ومقاطعها منقولة بنصها. وسرد القصص مكتوب بأسلوب مبسّط، وما نُقل فيه عن المفسرين '
                    'مُنبَّه عليه في موضعه، وقد يتضمن اجتهادات لا تُعدّ من الدين إلا ما ثبت بالقرآن '
                    'والحديث الصحيح. التفاصيل في «المصادر والتراخيص».',
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
    if (section.entries.isEmpty) return _SectionSoon(section: section);
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

/// قسم لا قصص فيه بعد (السيرة النبوية): رسالة صريحة وزر تواصل لمن يهمه الأمر.
class _SectionSoon extends StatelessWidget {
  final StorySection section;
  const _SectionSoon({required this.section});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return LibPage(
      title: section.title,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, size: 56, color: tk.gold),
              const SizedBox(height: 14),
              Text('نعمل حاليًا على هذا القسم',
                  textAlign: TextAlign.center,
                  style: cairoStyle(18, weight: 800, color: tk.ink)),
              const SizedBox(height: 10),
              Text(
                'قصص ${section.title} قيد الكتابة والمراجعة، ولن نعرض فيها إلا ما نطمئن إليه. '
                'إن كانت الفكرة تهمّك، أو عندك تفاصيل أو إضافات تفيدنا، تواصل معنا.',
                textAlign: TextAlign.center,
                style: cairoStyle(13.5, color: tk.muted, height: 1.8),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SupportScreen())),
                icon: const Icon(Icons.mail_outline_rounded),
                label: Text('تواصل معنا', style: cairoStyle(14, weight: 700, color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: tk.leaf,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              ),
            ],
          ),
        ),
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
    return _StoryReader(
      entry: entry,
      actions: [
        HeaderButton(
          icon: HomeIcons.heart,
          label: isFav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          color: isFav ? tk.gold : null,
          onTap: () => favs.toggle(entry.id),
        ),
      ],
    );
  }
}

class _StoryPage {
  final String text;
  final String footer;
  const _StoryPage(this.text, this.footer);
}

/// صفحات القصة: سرد مكتوب، والآيات من مصحف التطبيق، والأحاديث مقاطع حرفية موثَّقة.
Future<List<_StoryPage>> _storyPages(StoryEntry entry, QuranData? quran) async =>
    _authoredPages(entry, quran);

/// قصة مكتوبة: السرد صفحات بعنوان كل قسم، والآيات من مصحف التطبيق حرفيًا،
/// ومقاطع الأحاديث حرفية (موثَّقة وقت البناء)، وكل صفحة مصدرها في ذيلها.
List<_StoryPage> _authoredPages(StoryEntry entry, QuranData? quran) {
  const maxWords = 150;
  final pages = <_StoryPage>[];
  final buf = <String>[];
  var heading = '';
  var showHeading = true;
  var words = 0;

  void flush() {
    if (buf.isEmpty) return;
    final body = buf.join('\n\n');
    final text = (showHeading && heading.isNotEmpty) ? '$heading\n\n$body' : body;
    pages.add(_StoryPage(text, '${heading.isEmpty ? entry.title : heading}\nحكايات الوحي'));
    buf.clear();
    words = 0;
    showHeading = false;
  }

  for (final b in entry.blocks) {
    switch (b.t) {
      case 'h':
        flush();
        heading = b.text;
        showHeading = true;
        break;
      case 'p':
        final w = b.text.split(' ').length;
        if (buf.isNotEmpty && words + w > maxWords) flush();
        buf.add(b.text);
        words += w;
        break;
      case 'q':
        flush();
        if (quran == null) break;
        final ayahs = [
          for (var n = b.from; n <= b.to; n++)
            if (quran.ayahByKey('${b.surah}:$n') != null) quran.ayahByKey('${b.surah}:$n')!,
        ];
        if (ayahs.length != b.to - b.from + 1) break;
        pages.add(_StoryPage(
          ayahs.map((a) => '${a.text} ﴿${toArabicDigits(a.number)}﴾').join(' '),
          '${_range(StoryPart.quran(b.surah, b.from, b.to))}\nالقرآن الكريم',
        ));
        break;
      case 'hd':
        flush();
        pages.add(_StoryPage(b.text, '${b.ref}\nحديث رقم ${toArabicDigits(b.number)}'));
        break;
      case 'tf':
        flush();
        pages.add(_StoryPage(b.text, 'من أقوال المفسرين\nتُراجَع على أصول كتب التفسير'));
        break;
      case 'nx':
        flush();
        pages.add(_StoryPage(
            b.text, 'مما لم يرد فيه نصّ\nلا في القرآن ولا في السنة الصحيحة'));
        break;
      case 'l':
        flush();
        pages.add(_StoryPage(
          [for (var i = 0; i < b.items.length; i++) '${toArabicDigits(i + 1)}. ${b.items[i]}']
              .join('\n\n'),
          'ما تدل عليه القصة\nحكايات الوحي',
        ));
        break;
      case 'src':
        flush();
        pages.add(_StoryPage(b.items.join('\n\n'), 'المصادر\nحكايات الوحي'));
        break;
    }
  }
  flush();
  return pages;
}

class _StoryReader extends StatelessWidget {
  final StoryEntry entry;
  final List<Widget> actions;
  const _StoryReader({required this.entry, this.actions = const []});

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
          actions: actions,
        );
      },
    );
  }
}

String _range(StoryPart p) => p.from == p.to
    ? 'سورة ${QuranAudioProvider.surahName(p.surah)} · آية ${toArabicDigits(p.from)}'
    : 'سورة ${QuranAudioProvider.surahName(p.surah)} · الآيات ${toArabicDigits(p.from)}–${toArabicDigits(p.to)}';
