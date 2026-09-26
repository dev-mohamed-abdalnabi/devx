import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/zikr.dart';

class AzkarProvider extends ChangeNotifier {
  List<AzkarCategory> categories = [];
  final Set<String> favorites = {};
  bool isDarkMode = false;
  double fontScale = 1.0;
  DateTime? lastMorningDone;
  DateTime? lastEveningDone;

  static const _favKey = 'azkar_favorites';
  static const _darkKey = 'azkar_dark_mode';
  static const _fontKey = 'azkar_font_scale';
  static const _morningKey = 'azkar_morning_done';
  static const _eveningKey = 'azkar_evening_done';

  Future<void> init() async {
    final raw = await rootBundle.loadString('lib/data/azkar.json');
    final data = json.decode(raw);
    categories = (data['categories'] as List)
        .map((c) => AzkarCategory.fromJson(c))
        .toList();

    final prefs = await SharedPreferences.getInstance();
    favorites.addAll(prefs.getStringList(_favKey) ?? []);
    isDarkMode = prefs.getBool(_darkKey) ?? false;
    fontScale = prefs.getDouble(_fontKey) ?? 1.0;
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
      final cat = categoryById(z.categoryId);
      final allDone = cat.azkar.every((a) => a.remaining == 0);
      if (allDone) {
        _markCategoryDone(cat.id);
      }
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
    return all.where((z) => z.text.contains(query)).toList();
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
}
