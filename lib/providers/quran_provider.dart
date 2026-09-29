import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/quran_data.dart';

class QuranProvider extends ChangeNotifier {
  QuranData? data;
  bool loading = true;
  Object? error;

  int lastPage = 1;
  String? lastAyahKey;
  String readerTheme = 'auto'; // auto | light | dark | sepia
  double fontSize = 28;
  final Set<String> bookmarks = <String>{};
  final Set<int> readPages = <int>{};

  static const _kLastPage = 'quran_last_page';
  static const _kLastAyah = 'quran_last_ayah';
  static const _kTheme = 'quran_reader_theme';
  static const _kFont = 'quran_font_size';
  static const _kBookmarks = 'quran_bookmarks';
  static const _kRead = 'quran_read_pages';

  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/data/quran.json');
      data = await compute(parseQuran, raw);
    } catch (e) {
      error = e;
    }
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    lastPage = p.getInt(_kLastPage) ?? 1;
    lastAyahKey = p.getString(_kLastAyah);
    readerTheme = p.getString(_kTheme) ?? 'auto';
    fontSize = p.getDouble(_kFont) ?? 28;
    bookmarks.addAll(p.getStringList(_kBookmarks) ?? const []);
    readPages.addAll((p.getStringList(_kRead) ?? const []).map(int.parse));
    loading = false;
    notifyListeners();
  }

  bool get hasStartedReading => _prefs?.containsKey(_kLastPage) ?? false;

  double get khatmaProgress {
    final d = data;
    if (d == null || d.pageCount == 0) return 0;
    return readPages.length / d.pageCount;
  }

  Future<void> setLastPage(int page, {String? ayahKey}) async {
    lastPage = page;
    if (ayahKey != null) lastAyahKey = ayahKey;
    await _prefs?.setInt(_kLastPage, page);
    if (ayahKey != null) await _prefs?.setString(_kLastAyah, ayahKey);
    notifyListeners();
  }

  Future<void> markRead(int page) async {
    if (readPages.add(page)) {
      await _prefs?.setStringList(_kRead, readPages.map((e) => e.toString()).toList());
      notifyListeners();
    }
  }

  bool isBookmarked(String key) => bookmarks.contains(key);

  Future<void> toggleBookmark(String key) async {
    if (!bookmarks.remove(key)) bookmarks.add(key);
    await _prefs?.setStringList(_kBookmarks, bookmarks.toList());
    notifyListeners();
  }

  Future<void> setReaderTheme(String v) async {
    readerTheme = v;
    await _prefs?.setString(_kTheme, v);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    fontSize = v;
    await _prefs?.setDouble(_kFont, v);
    notifyListeners();
  }
}
