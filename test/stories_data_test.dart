import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/data/stories_data.dart';

void main() {
  test('تحليل فهرس حكايات الوحي وبحثه', () {
    final idx = parseStoriesIndex(
        '{"sections":[{"id":"quran","title":"قصص","subtitle":"",'
        '"entries":[{"id":"quran:yusuf","title":"قصة يوسف عليه السلام",'
        '"parts":[{"k":"quran","s":12,"from":1,"to":111},'
        '{"k":"hadith","b":"bukhari","n":3215,"anchor":"x"}]}]}]}');
    expect(idx.total, 1);
    final e = idx.byId('quran:yusuf')!;
    expect(e.parts[0].kind, StoryPartKind.quran);
    expect(e.parts[1].number, 3215);
    expect(searchStories(idx, 'يُوسُف').length, 1);
    expect(searchStories(idx, 'نوح'), isEmpty);
  });

  test('الفهرس المرفق سليم الشكل', () {
    final idx = parseStoriesIndex(File('assets/stories/stories.json').readAsStringSync());
    expect(idx.sections.map((s) => s.id), ['quran', 'prophets', 'seerah']);
    final ids = <String>{};
    for (final s in idx.sections) {
      for (final e in s.entries) {
        expect(ids.add(e.id), isTrue, reason: 'معرّف مكرر ${e.id}');
        expect(e.parts, isNotEmpty);
        for (final p in e.parts) {
          if (p.kind == StoryPartKind.quran) {
            expect(p.surah, inInclusiveRange(1, 114));
            expect(p.from, lessThanOrEqualTo(p.to));
          }
        }
      }
    }
  });
}
