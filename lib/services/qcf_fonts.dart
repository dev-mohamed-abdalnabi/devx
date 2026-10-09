import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// تحميل خط صفحة QCF عند الطلب من حزمة واحدة مضغوطة.
class QcfFonts {
  QcfFonts._();
  static final Map<int, Future<bool>> _loading = {};
  static final Set<int> _ready = {};
  static Future<Archive>? _bundle;

  static String family(int page) => 'QCF_P${page.toString().padLeft(3, '0')}';
  static String _asset(int page) => 'p${page.toString().padLeft(3, '0')}.ttf';
  static bool isReady(int page) => _ready.contains(page);

  static Future<bool> load(int page) {
    if (page < 1 || page > 604) return Future.value(false);
    if (_ready.contains(page)) return Future.value(true);
    return _loading[page] ??= _do(page);
  }

  static Future<Archive> _loadBundle() async {
    final bytes = await rootBundle.load('assets/qcf_fonts.zip');
    return ZipDecoder().decodeBytes(bytes.buffer.asUint8List(
        bytes.offsetInBytes, bytes.lengthInBytes));
  }

  static Future<bool> _do(int page) async {
    try {
      final archive = await (_bundle ??= _loadBundle());
      final file = archive.findFile(_asset(page));
      if (file == null) throw StateError('Missing QCF font for page $page');
      final data = Uint8List.fromList(file.content as List<int>);
      final loader = FontLoader(family(page))
        ..addFont(Future.value(ByteData.sublistView(data)));
      await loader.load();
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
