import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// تحميل خطوط صفحات QCF عند الطلب (٦٠٤ خطًا، خط لكل صفحة).
class QcfFonts {
  QcfFonts._();
  static final Map<int, Future<bool>> _loading = {};
  static final Set<int> _ready = {};

  static String family(int page) => 'QCF_P${page.toString().padLeft(3, '0')}';
  static bool isReady(int page) => _ready.contains(page);

  static Future<bool> load(int page) {
    if (page < 1 || page > 604) return Future.value(false);
    if (_ready.contains(page)) return Future.value(true);
    return _loading[page] ??= _do(page);
  }

  static Future<bool> _do(int page) async {
    try {
      final f = FontLoader(family(page))
        ..addFont(rootBundle.load('assets/qcf/p${page.toString().padLeft(3, '0')}.ttf'));
      await f.load();
      _ready.add(page);
      return true;
    } catch (_) {
      _loading.remove(page);
      return false;
    }
  }

  /// يحمّل الصفحات المجاورة بالتتابع بدون ازدحام.
  static Future<void> warm(int page, {int radius = 2}) async {
    for (var d = 1; d <= radius; d++) {
      await load(page + d);
      await load(page - d);
    }
  }
}
