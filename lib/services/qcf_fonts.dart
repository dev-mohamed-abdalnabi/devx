import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// تحميل خط صفحة QCF عند الطلب من أصل منفصل، دون فك 604 خطًا في الذاكرة.
///
/// تحميل أي خط جديد يُبطل كاش الخطوط في المحرك ويعيد قياس كل النصوص الظاهرة،
/// فلو حصل أثناء السحب تهبط الإطارات لـ 3 فقط. لذلك:
///  - التحميل يتم واحدًا واحدًا (طابور) وبين كل تحميل إطار فاضي.
///  - أثناء السحب بين الصفحات يتأجل التحميل لحد ما يقف السحب.
///  - الأقرب للصفحة الحالية يتحمّل الأول.
class QcfFonts {
  QcfFonts._();
  static final Map<int, Future<bool>> _loading = {};
  static final Map<int, Completer<bool>> _waiters = {};
  static final Set<int> _ready = {};
  static final Set<int> _pending = {};
  static final Set<int> _warming = {};
  static bool _pumping = false;
  static bool _scrolling = false;
  static Completer<void>? _idle;
  static int _focus = 1;

  /// الصفحة الحالية (لترتيب أولوية التحميل).
  static set focus(int page) => _focus = page;

  /// يُستدعى من القارئ عند بداية/نهاية سحب الصفحات.
  static void setScrolling(bool v) {
    _scrolling = v;
    if (!v) {
      final c = _idle;
      _idle = null;
      if (c != null && !c.isCompleted) c.complete();
    }
  }

  static String family(int page) => 'QCF_P${page.toString().padLeft(3, '0')}';
  static String _asset(int page) =>
      'assets/qcf/p${page.toString().padLeft(3, '0')}.ttf';
  static bool isReady(int page) => _ready.contains(page);

  static Future<bool> load(int page) {
    if (page < 1 || page > 604) return Future.value(false);
    if (_ready.contains(page)) return Future.value(true);
    return _loading[page] ??= _enqueue(page);
  }

  static Future<bool> _enqueue(int page) {
    final c = Completer<bool>();
    _waiters[page] = c;
    _pending.add(page);
    _pump();
    return c.future;
  }

  static Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_pending.isNotEmpty) {
        while (_scrolling) {
          _idle ??= Completer<void>();
          await _idle!.future;
        }
        if (_pending.isEmpty) break;
        // الأقرب للصفحة الحالية أولًا.
        var best = _pending.first;
        for (final p in _pending) {
          if ((p - _focus).abs() < (best - _focus).abs()) best = p;
        }
        _pending.remove(best);
        final ok = await _do(best);
        if (!ok) _loading.remove(best);
        _waiters.remove(best)?.complete(ok);
        // إطار فاضي بين كل تحميل وآخر.
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    } finally {
      _pumping = false;
    }
  }

  static Future<bool> _do(int page) async {
    try {
      final bytes = await rootBundle.load(_asset(page));
      final loader = FontLoader(family(page))..addFont(Future.value(bytes));
      await loader.load();
      _ready.add(page);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// يجهز الصفحات المجاورة بعد هدوء أول إطار (التحميل نفسه يتأجل لحد ما يقف السحب).
  static void warm(int page, {int radius = 2}) {
    final targets = <int>[];
    for (var d = 1; d <= radius; d++) {
      targets..add(page + d)..add(page - d);
    }
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      for (final target in targets) {
        if (target < 1 || target > 604 ||
            _ready.contains(target) || !_warming.add(target)) continue;
        load(target).whenComplete(() => _warming.remove(target));
      }
    });
  }
}
