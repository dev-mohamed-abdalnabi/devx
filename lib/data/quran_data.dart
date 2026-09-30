import 'dart:convert';
import '../core/text_utils.dart';

String displaySurahName(String name) {
  final clean = name.trim();
  return clean.startsWith('سورة') ? clean : 'سورة $clean';
}

class Surah {
  final int number;
  final String name;
  final bool meccan;
  final int ayahCount;
  int firstPage = 1;
  Surah(this.number, this.name, this.meccan, this.ayahCount);
}

class Ayah {
  final int surah;
  final int number;
  final String text;
  final int juz;
  final int page;
  final int hizbQuarter;
  final bool sajda;
  const Ayah(this.surah, this.number, this.text, this.juz, this.page, this.hizbQuarter, this.sajda);
  String get key => '$surah:$number';
}

class QuranData {
  final String basmala;
  final List<Surah> surahs;
  final List<Ayah> ayahs;
  late final Map<int, List<Ayah>> byPage;
  late final List<int> juzStartPages; // فهرس 0 => الجزء 1
  late final int pageCount;
  List<String>? _normalized;

  QuranData(this.basmala, this.surahs, this.ayahs) {
    final pages = <int, List<Ayah>>{};
    final juzStart = List<int>.filled(30, 0);
    for (final a in ayahs) {
      (pages[a.page] ??= <Ayah>[]).add(a);
      if (juzStart[a.juz - 1] == 0) juzStart[a.juz - 1] = a.page;
      if (a.number == 1) surahs[a.surah - 1].firstPage = a.page;
    }
    byPage = pages;
    juzStartPages = juzStart;
    pageCount = pages.keys.reduce((a, b) => a > b ? a : b);
  }

  Surah surahOf(int number) => surahs[number - 1];

  Ayah? ayahByKey(String key) {
    final p = key.split(':');
    if (p.length != 2) return null;
    final s = int.tryParse(p[0]);
    final n = int.tryParse(p[1]);
    if (s == null || n == null || s < 1 || s > surahs.length) return null;
    final sur = surahs[s - 1];
    if (n < 1 || n > sur.ayahCount) return null;
    // الآيات مرتبة بالتسلسل، نحسب الإزاحة.
    var offset = 0;
    for (var i = 0; i < s - 1; i++) {
      offset += surahs[i].ayahCount;
    }
    return ayahs[offset + n - 1];
  }

  List<Ayah> searchAyahs(String query, {int limit = 50}) {
    final q = normalizeArabic(query);
    if (q.length < 2) return const [];
    _normalized ??= ayahs.map((a) => normalizeArabic(a.text)).toList(growable: false);
    final out = <Ayah>[];
    final norm = _normalized!;
    for (var i = 0; i < norm.length && out.length < limit; i++) {
      if (norm[i].contains(q)) out.add(ayahs[i]);
    }
    return out;
  }
}

/// تُنفَّذ في Isolate منفصل حتى لا تسبب تقطيعًا عند فتح التطبيق.
QuranData parseQuran(String raw) {
  final j = json.decode(raw) as Map<String, dynamic>;
  final surahs = (j['surahs'] as List)
      .map((s) => Surah(s[0] as int, s[1] as String, (s[2] as int) == 1, s[3] as int))
      .toList();
  final ayahs = (j['ayahs'] as List)
      .map((a) => Ayah(a[0] as int, a[1] as int, a[2] as String, a[3] as int, a[4] as int,
          a[5] as int, (a[6] as int) == 1))
      .toList();
  return QuranData(j['basmala'] as String, surahs, ayahs);
}
