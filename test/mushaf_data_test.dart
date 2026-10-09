import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/data/mushaf_data.dart';

void main() {
  test('ملف فارغ (فشل الجلب) يرجع null فيعود المحرك القديم', () {
    expect(parseMushaf(json.encode({'v': 0, 'pages': []})), isNull);
  });

  test('تحليل صفوف الصفحة: نص وعنوان وبسملة', () {
    final page = [
      ['t', [['71:1', 'a'], ['71:1', 'b']]],
      ['b', 71],
      ['m'],
      ['e'],
    ];
    final raw = json.encode({'v': 1, 'pages': List.generate(604, (_) => page)});
    final m = parseMushaf(raw)!;
    final rows = m.pages[569];
    expect(rows[0].kind, QcfKind.text);
    expect(rows[0].words.length, 2);
    expect(rows[1].kind, QcfKind.banner);
    expect(rows[1].surah, 71);
    expect(rows[2].kind, QcfKind.basmala);
    expect(rows[3].kind, QcfKind.empty);
    expect(m.pageOfKey('71:1'), 1);
  });
}
