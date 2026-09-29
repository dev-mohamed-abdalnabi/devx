import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/text_utils.dart';
import '../models/zikr.dart';

class AzkarProvider extends ChangeNotifier {
  List<AzkarCategory> categories = [];
  final Set<String> favorites = {};
  bool isDarkMode = false;
  double fontScale = 1.0;
  bool showSources = true;
  DateTime? lastMorningDone;
  DateTime? lastEveningDone;

  static const _favKey = 'azkar_favorites';
  static const _darkKey = 'azkar_dark_mode';
  static const _fontKey = 'azkar_font_scale';
  static const _morningKey = 'azkar_morning_done';
  static const _eveningKey = 'azkar_evening_done';
  static const _progressKey = 'azkar_progress_v2';
  static const _progressDateKey = 'azkar_progress_date_v1';
  static const _sourcesKey = 'azkar_show_sources';

  Future<void> init() async {
    final raw = await rootBundle.loadString('lib/data/azkar.json');
    final data = json.decode(raw);
    categories = (data['categories'] as List)
        .map((c) => AzkarCategory.fromJson(c))
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    final savedDate = prefs.getString(_progressDateKey);
    final savedProgress = savedDate == today ? prefs.getStringList(_progressKey) ?? [] : <String>[];
    if (savedDate != today) {
      await prefs.setString(_progressDateKey, today);
      await prefs.setStringList(_progressKey, []);
    }
    final progress = <String, int>{};
    for (final entry in savedProgress) {
      final parts = entry.split('=');
      if (parts.length == 2) {
        final remaining = int.tryParse(parts[1]);
        if (remaining != null) progress[parts[0]] = remaining;
      }
    }
    for (final category in categories) {
      for (final zikr in category.azkar) {
        final remaining = progress[zikr.uniqueKey];
        if (remaining != null) {
          zikr.remaining = remaining.clamp(0, zikr.count).toInt();
        }
      }
    }
    favorites.addAll(prefs.getStringList(_favKey) ?? []);
    isDarkMode = prefs.getBool(_darkKey) ?? false;
    fontScale = prefs.getDouble(_fontKey) ?? 1.0;
    showSources = prefs.getBool(_sourcesKey) ?? true;
    final m = prefs.getString(_morningKey);
    final e = prefs.getString(_eveningKey);
    if (m != null) lastMorningDone = DateTime.tryParse(m);
    if (e != null) lastEveningDone = DateTime.tryParse(e);

    notifyListeners();
  }

  AzkarCategory categoryById(String id) =>
      categories.firstWhere((c) => c.id == id);

  void tapZikr(Zikr z) {
    if (z.remaining > 0) {
      z.remaining--;
      _saveProgress();
      final cat = categoryById(z.categoryId);
      final allDone = cat.azkar.every((a) => a.remaining == 0);
      if (allDone) {
        _markCategoryDone(cat.id);
      }
      notifyListeners();
    }
  }

  /// يتراجع عن ضغطة واحدة لهذا الذكر فقط، دون التأثير على بقية الباب.
  void undoZikr(Zikr z) {
    if (z.remaining < z.count) {
      z.remaining++;
      _saveProgress();
      notifyListeners();
    }
  }

  Future<void> _markCategoryDone(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    if (categoryId == 'morning') {
      lastMorningDone = now;
      await prefs.setString(_morningKey, now.toIso8601String());
    } else if (categoryId == 'evening') {
      lastEveningDone = now;
      await prefs.setString(_eveningKey, now.toIso8601String());
    }
  }

  bool isDoneToday(DateTime? last) {
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year && last.month == now.month && last.day == now.day;
  }

  void resetCategory(String categoryId) {
    final cat = categoryById(categoryId);
    for (final z in cat.azkar) {
      z.reset();
    }
    _saveProgress();
    notifyListeners();
  }

  double categoryProgress(String categoryId) {
    final cat = categoryById(categoryId);
    final total = cat.azkar.fold<int>(0, (s, z) => s + z.count);
    final done = cat.azkar.fold<int>(0, (s, z) => s + (z.count - z.remaining));
    return total == 0 ? 0 : done / total;
  }

  Future<void> toggleFavorite(Zikr z) async {
    final key = z.uniqueKey;
    if (favorites.contains(key)) {
      favorites.remove(key);
    } else {
      favorites.add(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, favorites.toList());
    notifyListeners();
  }

  bool isFavorite(Zikr z) => favorites.contains(z.uniqueKey);

  List<Zikr> get favoriteAzkar {
    final all = categories.expand((c) => c.azkar).toList();
    return all.where((z) => favorites.contains(z.uniqueKey)).toList();
  }

  List<Zikr> search(String query) {
    if (query.trim().isEmpty) return [];
    final all = categories.expand((c) => c.azkar).toList();
    final normalized = normalizeArabic(query);
    return all.where((z) => normalizeArabic(z.text).contains(normalized)).toList();
  }

  Future<void> toggleDarkMode() async {
    isDarkMode = !isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkKey, isDarkMode);
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    fontScale = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontKey, scale);
    notifyListeners();
  }

  Future<void> toggleSources() async {
    showSources = !showSources;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sourcesKey, showSources);
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final values = [
      for (final category in categories)
        for (final zikr in category.azkar) '${zikr.uniqueKey}=${zikr.remaining}',
    ];
    await prefs.setString(_progressDateKey, _dayKey(DateTime.now()));
    await prefs.setStringList(_progressKey, values);
  }

  String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
