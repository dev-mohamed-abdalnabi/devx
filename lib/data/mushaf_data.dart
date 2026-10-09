import 'dart:convert';

enum QcfKind { text, banner, basmala, empty }

class QcfWord {
  final String key; // "سورة:آية"
  final String code; // رمز الكلمة في خط الصفحة
  const QcfWord(this.key, this.code);
}

class QcfRow {
  final QcfKind kind;
  final int surah; // للعنوان
  final List<QcfWord> words;
  const QcfRow(this.kind, {this.surah = 0, this.words = const []});
}

/// تخطيط مصحف المدينة: لكل صفحة صفوفها (١٥ سطرًا، أو ٨ لأول صفحتين).
class MushafData {
  final List<List<QcfRow>> pages;
  MushafData(this.pages);

  Map<String, int>? _pageOfKey;

  /// رقم الصفحة التي تبدأ فيها الآية في المصحف الفعلي.
  int? pageOfKey(String key) {
    if (_pageOfKey == null) {
      final m = <String, int>{};
      for (var i = 0; i < pages.length; i++) {
        for (final r in pages[i]) {
          for (final w in r.words) {
            m.putIfAbsent(w.key, () => i + 1);
          }
        }
      }
      _pageOfKey = m;
    }
    return _pageOfKey![key];
  }
}

/// يُستدعى عبر compute. يرجع null لو الملف فارغ (فشل الجلب وقت البناء).
MushafData? parseMushaf(String raw) {
  final j = json.decode(raw) as Map<String, dynamic>;
  if (j['v'] != 1) return null;
  final pages = <List<QcfRow>>[];
  for (final p in (j['pages'] as List)) {
    final rows = <QcfRow>[];
    for (final r in (p as List)) {
      final l = r as List;
      switch (l[0] as String) {
        case 't':
          rows.add(QcfRow(QcfKind.text, words: [
            for (final w in (l[1] as List)) QcfWord((w as List)[0] as String, w[1] as String)
          ]));
        case 'b':
          rows.add(QcfRow(QcfKind.banner, surah: (l[1] as num).toInt()));
        case 'm':
          rows.add(const QcfRow(QcfKind.basmala));
        default:
          rows.add(const QcfRow(QcfKind.empty));
      }
    }
    pages.add(rows);
  }
  return pages.length == 604 ? MushafData(pages) : null;
}
