import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import '../core/text_utils.dart' show searchKey;
import 'library_data.dart';

/// فهرس «حكايات الوحي»: مراجع فقط (آيات بالسورة والرقم، وأحاديث بالكتاب والرقم).
/// لا يحتوي أي نص ديني؛ النصوص تُقرأ وقت العرض حرفيًا من القرآن المحمّل في
/// التطبيق ومن كتب الحديث في assets/library. انظر tool/build_stories.py.

enum StoryPartKind { quran, hadith }

class StoryPart {
  final StoryPartKind kind;
  final int surah, from, to; // آيات
  final String book; // أحاديث: bukhari | muslim
  final int number;
  const StoryPart.quran(this.surah, this.from, this.to)
      : kind = StoryPartKind.quran,
        book = '',
        number = 0;
  const StoryPart.hadith(this.book, this.number)
      : kind = StoryPartKind.hadith,
        surah = 0,
        from = 0,
        to = 0;

  factory StoryPart.fromJson(Map<String, dynamic> j) => j['k'] == 'quran'
      ? StoryPart.quran(
          (j['s'] as num).toInt(), (j['from'] as num).toInt(), (j['to'] as num).toInt())
      : StoryPart.hadith(j['b'] as String, (j['n'] as num).toInt());
}

class StoryEntry {
  final String id, title, era;
  final List<StoryPart> parts;
  final List<String> kw;
  StoryEntry(this.id, this.title, this.era, this.parts, [this.kw = const []]);

  late final String key = searchKey(title);

  factory StoryEntry.fromJson(Map<String, dynamic> j) => StoryEntry(
        j['id'] as String,
        j['title'] as String,
        (j['era'] as String?) ?? '',
        [for (final p in (j['parts'] as List)) StoryPart.fromJson(p as Map<String, dynamic>)],
        [for (final k in ((j['kw'] as List?) ?? const [])) k as String],
      );
}

class StorySection {
  final String id, title, subtitle;
  final List<StoryEntry> entries;
  const StorySection(this.id, this.title, this.subtitle, this.entries);
}

class StoriesIndex {
  final List<StorySection> sections;
  const StoriesIndex(this.sections);

  StorySection section(String id) => sections.firstWhere((s) => s.id == id);

  StoryEntry? byId(String id) {
    for (final s in sections) {
      for (final e in s.entries) {
        if (e.id == id) return e;
      }
    }
    return null;
  }

  int get total => sections.fold(0, (a, s) => a + s.entries.length);
}

StoriesIndex parseStoriesIndex(String raw) {
  final j = json.decode(raw) as Map<String, dynamic>;
  return StoriesIndex([
    for (final s in (j['sections'] as List))
      StorySection(
        (s as Map<String, dynamic>)['id'] as String,
        s['title'] as String,
        (s['subtitle'] as String?) ?? '',
        [for (final e in (s['entries'] as List)) StoryEntry.fromJson(e as Map<String, dynamic>)],
      ),
  ]);
}

/// بحث في عناوين المدخلات (يتجاهل التشكيل؛ كل الكلمات يجب أن تظهر).
List<StoryEntry> searchStories(StoriesIndex idx, String query) {
  final words = searchKey(query).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  return [
    for (final s in idx.sections)
      for (final e in s.entries)
        if (words.every(e.key.contains)) e,
  ];
}

/// كتاب أصلي (يُجلب وقت البناء بـ tool/fetch_stories.py). يغيب إن لم يُجلب.
/// `serves`: أقسام القصص التي يُعرض فيها (quran | prophets | seerah)، وترتيب الكتب
/// في الفهرس هو ترتيب ظهورها. `hidden`: كتاب مقتطفات يظهر داخل القصص فقط، لا في
/// قائمة «الكتب الأصلية كاملة».
class StoryBookInfo {
  final String id, title, author, desc, notice, file, sourceUrl, sourcePath, commit, style;
  final int sections;
  final bool hidden;
  final List<String> serves;
  const StoryBookInfo(this.id, this.title, this.author, this.desc, this.notice,
      this.file, this.sourceUrl, this.sourcePath, this.commit, this.sections,
      {this.style = '', this.hidden = false, this.serves = const <String>[]});

  factory StoryBookInfo.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final serves = j['serves'] as List?;
    return StoryBookInfo(
      id,
      j['title'] as String,
      (j['author'] as String?) ?? '',
      (j['desc'] as String?) ?? '',
      (j['notice'] as String?) ?? '',
      j['file'] as String,
      (j['sourceUrl'] as String?) ?? '',
      (j['sourcePath'] as String?) ?? '',
      (j['commit'] as String?) ?? '',
      (j['sections'] as num).toInt(),
      style: (j['style'] as String?) ?? '',
      hidden: j['hidden'] == true,
      // فهرس قديم بلا serves: السيرة لابن هشام، وما سواها للأنبياء وقصص القرآن.
      serves: serves != null
          ? [for (final x in serves) x as String]
          : (id == 'sira_ibn_hisham' ? const ['seerah'] : const ['prophets', 'quran']),
    );
  }
}

List<StoryBookInfo> parseStoryBooks(String raw) => [
      for (final b in (json.decode(raw) as List))
        StoryBookInfo.fromJson(b as Map<String, dynamic>)
    ];

class StoriesRepo {
  StoriesRepo._();
  static Future<StoriesIndex>? _index;

  static Future<StoriesIndex> index() {
    final f = _index ??= rootBundle
        .loadString('assets/stories/stories.json')
        .then(parseStoriesIndex);
    f.then<void>((_) {}, onError: (Object _) => _index = null);
    return f;
  }

  static Future<List<StoryBookInfo>>? _books;
  static final Map<String, Future<FiqhBook>> _bookCache = {};

  /// الكتب التي جُلبت فعلًا في هذا البناء؛ قائمة فارغة إن لم تُجلب (لا نعرض ما لا نملك).
  static Future<List<StoryBookInfo>> books() => _books ??= rootBundle
      .loadString('assets/stories/books/index.json')
      .then(parseStoryBooks)
      .catchError((Object _) => <StoryBookInfo>[]);

  /// النص الكامل بنفس بنية كتب الفقه (أقسام وفقرات).
  static Future<FiqhBook> book(StoryBookInfo b) => _bookCache.putIfAbsent(b.id, () async {
        final raw = await rootBundle.loadString('assets/stories/books/${b.file}');
        return compute(parseFiqhBook, raw);
      });

  static const bookTitles = {'bukhari': 'صحيح البخاري', 'muslim': 'صحيح مسلم'};

  /// الحديث بنصه الحرفي من كتاب المكتبة، أو null إن لم يوجد.
  static Future<({HadithItem item, HadithChapter chapter, String title})?> hadith(
      String book, int n) async {
    final books = await LibraryRepo.libIndex();
    final info = books.where((b) => b.id == book);
    if (info.isEmpty) return null;
    final hb = await LibraryRepo.hadith(info.first);
    for (final c in hb.chapters) {
      for (final h in c.items) {
        if (h.n == n) return (item: h, chapter: c, title: hb.title);
      }
    }
    return null;
  }
}
