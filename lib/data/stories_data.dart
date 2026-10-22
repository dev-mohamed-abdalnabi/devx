import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import '../core/text_utils.dart' show searchKey;
import 'library_data.dart';

/// فهرس «حكايات الوحي». الآيات مراجع فقط (السورة والرقم) وتُقرأ وقت العرض من
/// القرآن المحمّل في التطبيق. وقسم «قصص القرآن» له سرد مكتوب (blocks) فيه مقاطع
/// أحاديث حرفية يتحقق منها tool/build_stories.py من assets/library عند كل بناء.

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

/// كتلة من سرد قصة مكتوبة. t: h عنوان | p فقرة | q آيات | hd مقطع حديث |
/// tf من أقوال المفسرين | nx مما لم يرد فيه نص | l خلاصة | src مصادر.
class StoryBlock {
  final String t, text, book, ref;
  final List<String> items;
  final int surah, from, to, number;
  const StoryBlock(this.t,
      {this.text = '',
      this.items = const [],
      this.surah = 0,
      this.from = 0,
      this.to = 0,
      this.book = '',
      this.number = 0,
      this.ref = ''});

  factory StoryBlock.fromJson(Map<String, dynamic> j) => StoryBlock(
        j['t'] as String,
        text: (j['x'] as String?) ?? '',
        items: [for (final x in ((j['i'] as List?) ?? const [])) x as String],
        surah: (j['s'] as num?)?.toInt() ?? 0,
        from: (j['from'] as num?)?.toInt() ?? 0,
        to: (j['to'] as num?)?.toInt() ?? 0,
        book: (j['b'] as String?) ?? '',
        number: (j['n'] as num?)?.toInt() ?? 0,
        ref: (j['r'] as String?) ?? '',
      );
}

class StoryEntry {
  final String id, title, era;
  final List<StoryPart> parts;
  final List<StoryBlock> blocks; // سرد القصة المكتوب
  StoryEntry(this.id, this.title, this.era, this.parts, [this.blocks = const []]);

  late final String key = searchKey(title);

  factory StoryEntry.fromJson(Map<String, dynamic> j) => StoryEntry(
        j['id'] as String,
        j['title'] as String,
        (j['era'] as String?) ?? '',
        [for (final p in (j['parts'] as List)) StoryPart.fromJson(p as Map<String, dynamic>)],
        [
          for (final b in ((j['blocks'] as List?) ?? const []))
            StoryBlock.fromJson(b as Map<String, dynamic>)
        ],
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
