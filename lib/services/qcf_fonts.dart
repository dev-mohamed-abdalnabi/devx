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
  static const int radiusKeep = 12;
  // سقف التحميل المسبق: بعده الخطوط تتحمّل عند الحاجة بس (الخط المحمّل ما بيتفرّغش).
  static const int maxPrefetched = 60;

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

  static Future<void> _waitIdle() async {
    while (_scrolling) {
      _idle ??= Completer<void>();
      await _idle!.future;
    }
  }

  static Future<ByteData?> _bytes(int page) async {
    try {
      return await rootBundle.load(_asset(page));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_pending.isNotEmpty) {
        await _waitIdle();
        if (_pending.isEmpty) break;
        // لو المستخدم قفز بعيد (فهرس/بحث) نتجاهل الطلبات القديمة البعيدة.
        for (final p in _pending.toList()) {
          if ((p - _focus).abs() > radiusKeep) {
            _pending.remove(p);
            _loading.remove(p);
            _waiters.remove(p)?.complete(false);
          }
        }
        if (_pending.isEmpty) break;
        final urgent = _pending.contains(_focus);
        if (!urgent) {
          // الصفحات المجاورة تستنى فترة هدوء؛ لو المستخدم رجع يقلّب نستنى تاني.
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (_scrolling || _pending.isEmpty) continue;
        }
        final order = _pending.toList()
          ..sort((x, y) => (x - _focus).abs().compareTo((y - _focus).abs()));
        final batch = urgent ? <int>[_focus] : order.take(4).toList();
        _pending.removeAll(batch);
        // قراءة الملفات (I/O) بتتم بالتوازي بدون ما تعطّل الرسم.
        final datas = await Future.wait(batch.map(_bytes));
        // التسجيل هو اللي بيعيد قياس كل النصوص: لازم يتم والشاشة ساكنة،
        // وللكل مرة واحدة بدل مرة لكل خط.
        await _waitIdle();
        for (var i = 0; i < batch.length; i++) {
          final p = batch[i];
          var ok = false;
          final d = datas[i];
          if (d != null) {
            try {
              final loader = FontLoader(family(p))..addFont(Future.value(d));
              await loader.load();
              _ready.add(p);
              ok = true;
            } catch (_) {}
          }
          if (!ok) _loading.remove(p);
          _waiters.remove(p)?.complete(ok);
        }
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    } finally {
      _pumping = false;
    }
  }

  /// يجهز الصفحات المجاورة بعد هدوء أول إطار (التحميل نفسه يتأجل لحد ما يقف السحب).
  static void warm(int page, {int radius = 6}) {
    final targets = <int>[];
    for (var d = 1; d <= radius; d++) {
      targets..add(page + d)..add(page - d); // الأقرب أولًا، الأمام قبل الخلف
    }
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      for (final target in targets) {
        if (_ready.length >= maxPrefetched) return;
        if (target < 1 || target > 604 ||
            _ready.contains(target) || !_warming.add(target)) continue;
        load(target).whenComplete(() => _warming.remove(target));
      }
    });
  }
}
