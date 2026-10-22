import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفضلة «حكايات الوحي» (معرّفات المدخلات فقط) محفوظة محليًا.
class StoriesProvider extends ChangeNotifier {
  static const _k = 'stories_favs_v1';
  final Set<String> favorites = <String>{};
  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  Future<void> init() => _initFuture ??= _load();

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      favorites.addAll(_prefs!.getStringList(_k) ?? const []);
      notifyListeners();
    } catch (_) {
      // عدم توفر التخزين لا يمنع قراءة القصص؛ المفضلة فقط تصبح مؤقتة.
    }
  }

  bool isFav(String id) => favorites.contains(id);

  Future<void> toggle(String id) async {
    if (!favorites.remove(id)) favorites.add(id);
    notifyListeners();
    await _prefs?.setStringList(_k, favorites.toList());
  }
}
