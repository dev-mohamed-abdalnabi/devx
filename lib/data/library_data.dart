import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import '../core/text_utils.dart' show searchKey;

/// بيانات المكتبة (الحديث) والأحكام الفقهية. كل النصوص منقولة حرفيًا من
/// مصادرها (انظر tool/fetch_library.py) ولا يُولَّد أي نص ديني بالذكاء الاصطناعي.

class LibBook {
  final String id, title, author, desc, file, sourceUrl;
  final int count, chapters;
  const LibBook({
    required this.id,
    required this.title,
    required this.author,
    required this.desc,
    required this.file,
    required this.sourceUrl,
    required this.count,
    required this.chapters,
  });

  factory LibBook.fromJson(Map<String, dynamic> j) => LibBook(
        id: j['id'] as String,
        title: j['title'] as String,
        author: (j['author'] as String?) ?? '',
        desc: (j['desc'] as String?) ?? '',
        file: j['file'] as String,
        sourceUrl: (j['sourceUrl'] as String?) ?? '',
        count: (j['count'] as num).toInt(),
        chapters: (j['chapters'] as num).toInt(),
      );
}

class HadithItem {
  final int n;
  final String text;
  const HadithItem(this.n, this.text);
}

class HadithChapter {
  final String title;
  final List<HadithItem> items;
  const HadithChapter(this.title, this.items);
}

class HadithRef {
  final HadithChapter chapter;
  final HadithItem item;
  const HadithRef(this.chapter, this.item);
}

class HadithBook {
  final String id, title, author;
  final List<HadithChapter> chapters;
  HadithBook(this.id, this.title, this.author, this.chapters);

  int get count => chapters.fold(0, (a, c) => a + c.items.length);

  /// كل الأحاديث بترتيب الكتاب (للبحث).
  late final List<HadithRef> flat = [
    for (final c in chapters)
      for (final h in c.items) HadithRef(c, h),
  ];

  factory HadithBook.fromJson(Map<String, dynamic> j) {
    final chapters = <HadithChapter>[];
    for (final c in (j['chapters'] as List)) {
      final m = c as Map<String, dynamic>;
      final items = <HadithItem>[
        for (final h in (m['h'] as List))
          HadithItem(((h as List)[0] as num).toInt(), h[1] as String),
      ];
      chapters.add(HadithChapter(m['t'] as String, items));
    }
    return HadithBook(j['id'] as String, j['title'] as String,
        (j['author'] as String?) ?? '', chapters);
  }
}

class FiqhInfo {
  final String id, madhhab, title, author, desc, edition, file;
  final int sections;
  const FiqhInfo({
    required this.id,
    required this.madhhab,
    required this.title,
    required this.author,
    required this.desc,
    required this.edition,
    required this.file,
    required this.sections,
  });

  factory FiqhInfo.fromJson(Map<String, dynamic> j) => FiqhInfo(
        id: j['id'] as String,
        madhhab: j['madhhab'] as String,
        title: j['title'] as String,
        author: (j['author'] as String?) ?? '',
        desc: (j['desc'] as String?) ?? '',
        edition: (j['edition'] as String?) ?? '',
        file: j['file'] as String,
        sections: (j['sections'] as num).toInt(),
      );
}

class FiqhSection {
  final String title;
  final int level; // 1 كتاب · 2 باب · 3 فصل
  final List<String> paragraphs;
  const FiqhSection(this.title, this.level, this.paragraphs);
}

class FiqhRef {
  final int section;
  final String text;
  const FiqhRef(this.section, this.text);
}

class FiqhBook {
  final String id, title, author, madhhab;
  final List<FiqhSection> sections;
  FiqhBook(this.id, this.title, this.author, this.madhhab, this.sections);

  /// كل الفقرات مع رقم قسمها (للبحث).
  late final List<FiqhRef> flat = [
    for (var i = 0; i < sections.length; i++)
      for (final p in sections[i].paragraphs) FiqhRef(i, p),
  ];

  factory FiqhBook.fromJson(Map<String, dynamic> j) => FiqhBook(
        j['id'] as String,
        j['title'] as String,
        (j['author'] as String?) ?? '',
        (j['madhhab'] as String?) ?? '',
        [
          for (final s in (j['sections'] as List))
            FiqhSection(
              (s as Map<String, dynamic>)['t'] as String,
              (s['lvl'] as num).toInt(),
              [for (final p in (s['p'] as List)) p as String],
            ),
        ],
      );
}

/// مفاتيح البحث المطبّعة (تُحسب مرة واحدة في خيط خلفي).
List<String> buildKeys(List<String> texts) =>
    [for (final t in texts) searchKey(t)];

HadithBook parseHadithBook(String raw) =>
    HadithBook.fromJson(json.decode(raw) as Map<String, dynamic>);

FiqhBook parseFiqhBook(String raw) =>
    FiqhBook.fromJson(json.decode(raw) as Map<String, dynamic>);

List<LibBook> parseLibIndex(String raw) => [
      for (final b in (json.decode(raw) as List))
        LibBook.fromJson(b as Map<String, dynamic>)
    ];

List<FiqhInfo> parseFiqhIndex(String raw) => [
      for (final b in (json.decode(raw) as List))
        FiqhInfo.fromJson(b as Map<String, dynamic>)
    ];

/// تحميل كسول مع تخزين مؤقت. الكتب الكبيرة تُفكّ في خيط خلفي.
/// الفشل لا يُخزَّن: المحاولة التالية تعيد التحميل.
class LibraryRepo {
  LibraryRepo._();

  static final Map<String, Future<Object>> _cache = {};

  static Future<T> _cached<T extends Object>(
      String key, Future<T> Function() load) {
    final hit = _cache[key];
    if (hit != null) return hit as Future<T>;
    final f = load();
    _cache[key] = f;
    f.then<void>((_) {}, onError: (Object _) {
      _cache.remove(key);
    });
    return f;
  }

  static Future<List<LibBook>> libIndex() => _cached<List<LibBook>>(
        'lib-index',
        () async =>
            parseLibIndex(await rootBundle.loadString('assets/library/index.json')),
      );

  static Future<List<FiqhInfo>> fiqhIndex() => _cached<List<FiqhInfo>>(
        'fiqh-index',
        () async =>
            parseFiqhIndex(await rootBundle.loadString('assets/fiqh/index.json')),
      );

  static Future<HadithBook> hadith(LibBook b) => _cached<HadithBook>(
        'h-${b.id}',
        () async {
          final raw = await rootBundle.loadString('assets/library/${b.file}');
          return compute(parseHadithBook, raw);
        },
      );

  static Future<FiqhBook> fiqh(FiqhInfo b) => _cached<FiqhBook>(
        'f-${b.id}',
        () async {
          final raw = await rootBundle.loadString('assets/fiqh/${b.file}');
          return compute(parseFiqhBook, raw);
        },
      );

  static Future<List<String>> hadithKeys(HadithBook b) => _cached<List<String>>(
        'hk-${b.id}',
        () => compute(buildKeys, [for (final r in b.flat) r.item.text]),
      );

  static Future<List<String>> fiqhKeys(FiqhBook b) => _cached<List<String>>(
        'fk-${b.id}',
        () => compute(buildKeys, [for (final r in b.flat) r.text]),
      );

  /// كل كلمات الاستعلام يجب أن تظهر. يعيد فهارس المطابقات (حتى [limit]).
  static List<int> match(List<String> keys, String query, {int limit = 50}) {
    final words =
        searchKey(query).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty || words.every((w) => w.length < 2)) return const [];
    final out = <int>[];
    for (var i = 0; i < keys.length && out.length < limit; i++) {
      final k = keys[i];
      var ok = true;
      for (final w in words) {
        if (!k.contains(w)) {
          ok = false;
          break;
        }
      }
      if (ok) out.add(i);
    }
    return out;
  }
}
