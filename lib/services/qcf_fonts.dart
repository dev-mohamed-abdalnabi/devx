import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// تحميل خط صفحة QCF عند الطلب من أصل منفصل، دون فك 604 خطًا في الذاكرة.
class QcfFonts {
  QcfFonts._();
  static final Map<int, Future<bool>> _loading = {};
  static final Set<int> _ready = {};
  static final Set<int> _warming = {};

  static String family(int page) => 'QCF_P${page.toString().padLeft(3, '0')}';
  static String _asset(int page) =>
      'assets/qcf/p${page.toString().padLeft(3, '0')}.ttf';
  static bool isReady(int page) => _ready.contains(page);

  static Future<bool> load(int page) {
    if (page < 1 || page > 604) return Future.value(false);
    if (_ready.contains(page)) return Future.value(true);
    return _loading[page] ??= _do(page);
  }

  static Future<bool> _do(int page) async {
    try {
      final bytes = await rootBundle.load(_asset(page));
      final loader = FontLoader(family(page))
        // استخدم الـ ByteData الذي يعيده Flutter مباشرة بدون نسخة Uint8List إضافية.
        ..addFont(Future.value(bytes));
      await loader.load();
      _ready.add(page);
      return true;
    } catch (_) {
      _loading.remove(page);
      return false;
    }
  }

  /// يجهز الصفحة السابقة والقادمة بعد هدوء أول إطار، حتى لا يتوقف السحب في أي اتجاه.
  static void warm(int page, {int radius = 1}) {
    final targets = <int>[];
    for (var d = 1; d <= radius; d++) {
      targets..add(page - d)..add(page + d);
    }
    Future<void>.delayed(const Duration(milliseconds: 180), () async {
      for (final target in targets) {
        if (target < 1 || target > 604 ||
            _ready.contains(target) || !_warming.add(target)) continue;
        try {
          await load(target);
        } finally {
          _warming.remove(target);
        }
      }
    });
  }
}
