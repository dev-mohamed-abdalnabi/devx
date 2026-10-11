import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mushaf_data.dart';
import '../data/quran_data.dart';

/// لون (فهرس 0–4) وملاحظة اختيارية على آية محفوظة.
class AyahMark {
  final int color;
  final String note;
  const AyahMark(this.color, this.note);
}

List<String> _parseStrings(String raw) =>
    (json.decode(raw) as List).map((e) => e as String).toList();

class QuranProvider extends ChangeNotifier {
  QuranData? data;
  /// تخطيط مصحف المدينة؛ null = المحرك القديم.
  MushafData? mushaf;
  bool loading = true;
  Object? error;

  int lastPage = 1;
  String? lastAyahKey;
  String readerTheme = 'auto'; // auto | light | dark | sepia
  String pageMode = 'page'; // page (مصحف: صفحة بصفحة) | continuous (تمرير مستمر)
  /// 1.0 = الصفحة كاملة على الشاشة بدون سكرول (الافتراضي). غير ذلك = تكبير/تصغير يدوي.
  double fontScale = 1.0;
  final Set<String> bookmarks = <String>{};
  final Map<String, AyahMark> marks = <String, AyahMark>{};
  final Set<int> readPages = <int>{};

  static const _kLastPage = 'quran_last_page';
  static const _kLastAyah = 'quran_last_ayah';
  static const _kTheme = 'quran_reader_theme';
  static const _kFont = 'quran_font_scale';
  static const _kBookmarks = 'quran_bookmarks';
  static const _kMarks = 'quran_marks_meta';
  static const _kMode = 'quran_page_mode';
  static const _kRead = 'quran_read_pages';

  SharedPreferences? _prefs;
  List<int>? _off;
  Future<List<String>?>? _tafsirFuture;

  Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/data/quran.json');
      data = await compute(parseQuran, raw);
    } catch (e) {
      error = e;
    }
    try {
      final rawM = await rootBundle.loadString('assets/data/mushaf.json');
      mushaf = await compute(parseMushaf, rawM);
    } catch (_) {
      mushaf = null;
    }
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    final savedPage = p.getInt(_kLastPage) ?? 1;
    lastAyahKey = p.getString(_kLastAyah);
    readerTheme = p.getString(_kTheme) ?? 'auto';
    pageMode = p.getString(_kMode) == 'continuous' ? 'continuous' : 'page';
    fontScale = (p.getDouble(_kFont) ?? 1.0).clamp(1.0, 2.0).toDouble();
    bookmarks.addAll(p.getStringList(_kBookmarks) ?? const []);
    final rawMarks = p.getString(_kMarks);
    if (rawMarks != null) {
      try {
        final m = json.decode(rawMarks) as Map<String, dynamic>;
        m.forEach((k, v) {
          if (v is Map) {
            marks[k] = AyahMark((v['c'] as num?)?.toInt() ?? 0, (v['n'] as String?) ?? '');
          }
        });
      } catch (_) {}
    }
    final savedRead = p.getStringList(_kRead) ?? const <String>[];
    readPages.addAll(savedRead.map(int.tryParse).whereType<int>().where((v) => v > 0));
    final maxPage = data?.pageCount ?? 604;
    lastPage = savedPage.clamp(1, maxPage == 0 ? 1 : maxPage).toInt();
    loading = false;
    notifyListeners();
  }

  bool get hasStartedReading => _prefs?.containsKey(_kLastPage) ?? false;

  double get khatmaProgress {
    final d = data;
    if (d == null || d.pageCount == 0) return 0;
    return readPages.length / d.pageCount;
  }

  /// الترتيب المطلق للآية (0–6235) داخل [QuranData.ayahs].
  int ayahIndex(Ayah a) {
    final d = data!;
    if (_off == null) {
      final off = <int>[];
      var o = 0;
      for (final s in d.surahs) {
        off.add(o);
        o += s.ayahCount;
      }
      _off = off;
    }
    return _off![a.surah - 1] + a.number - 1;
  }

  Future<void> setLastPage(int page, {String? ayahKey}) async {
    final maxPage = data?.pageCount ?? 604;
    lastPage = page.clamp(1, maxPage == 0 ? 1 : maxPage).toInt();
    if (ayahKey != null) lastAyahKey = ayahKey;
    await _prefs?.setInt(_kLastPage, lastPage);
    if (ayahKey != null) await _prefs?.setString(_kLastAyah, ayahKey);
    notifyListeners();
  }

  Future<void> markRead(int page) async {
    final maxPage = data?.pageCount ?? 604;
    if (page < 1 || page > maxPage) return;
    if (readPages.add(page)) {
      await _prefs?.setStringList(_kRead, readPages.map((e) => e.toString()).toList());
      notifyListeners();
    }
  }

  // ───────── العلامات ─────────

  bool isBookmarked(String key) => bookmarks.contains(key);

  AyahMark? markOf(String key) =>
      bookmarks.contains(key) ? (marks[key] ?? const AyahMark(0, '')) : null;

  Future<void> _saveMarks() async {
    await _prefs?.setStringList(_kBookmarks, bookmarks.toList());
    await _prefs?.setString(
      _kMarks,
      json.encode({
        for (final e in marks.entries)
          if (bookmarks.contains(e.key)) e.key: {'c': e.value.color, 'n': e.value.note},
      }),
    );
  }

  Future<void> toggleBookmark(String key) async {
    if (!bookmarks.remove(key)) {
      bookmarks.add(key);
    } else {
      marks.remove(key);
    }
    await _saveMarks();
    notifyListeners();
  }

  Future<void> saveMark(String key, {required int color, String note = ''}) async {
    bookmarks.add(key);
    marks[key] = AyahMark(color, note.trim());
    await _saveMarks();
    notifyListeners();
  }

  /// يطبّق لونًا على عدة آيات مع الإبقاء على ملاحظات الموجود منها.
  Future<void> saveMarksColor(Iterable<String> keys, int color) async {
    for (final k in keys) {
      bookmarks.add(k);
      marks[k] = AyahMark(color, marks[k]?.note ?? '');
    }
    await _saveMarks();
    notifyListeners();
  }

  Future<void> removeMarks(Iterable<String> keys) async {
    for (final k in keys) {
      bookmarks.remove(k);
      marks.remove(k);
    }
    await _saveMarks();
    notifyListeners();
  }

  // ───────── الإعدادات ─────────

  Future<void> setReaderTheme(String v) async {
    readerTheme = v;
    await _prefs?.setString(_kTheme, v);
    notifyListeners();
  }

  Future<void> setPageMode(String v) async {
    pageMode = v;
    await _prefs?.setString(_kMode, v);
    notifyListeners();
  }

  bool get isFitToPage => (fontScale - 1).abs() < .005;

  Future<void> setFontScale(double v) async {
    v = (v.clamp(1.0, 2.0) * 100).round() / 100;
    if ((v - 1).abs() < .01) v = 1.0;
    fontScale = v;
    await _prefs?.setDouble(_kFont, v);
    notifyListeners();
  }

  Future<void> resetFontScale() => setFontScale(1.0);

  // ───────── التفسير (الميسّر) ─────────

  /// يحمّل ملف التفسير عند أول طلب فقط. يعيد null إن لم يوجد الملف.
  Future<String?> tafsirOf(Ayah a) async {
    _tafsirFuture ??= _loadTafsir();
    final list = await _tafsirFuture;
    if (list == null || data == null) return null;
    final i = ayahIndex(a);
    return (i >= 0 && i < list.length) ? list[i] : null;
  }

  Future<List<String>?> _loadTafsir() async {
    try {
      final raw = await rootBundle.loadString('assets/data/tafsir.json');
      final l = await compute(_parseStrings, raw);
      return l.length == 6236 ? l : null;
    } catch (_) {
      return null;
    }
  }
}
