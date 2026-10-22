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

  test('كل قصص الأنبياء لها محتوى قرآني ظاهر', () {
    final idx = parseStoriesIndex(File('assets/stories/stories.json').readAsStringSync());
    final prophets = idx.section('prophets');
    for (final entry in prophets.entries) {
      expect(entry.parts.any((p) => p.kind == StoryPartKind.quran), isTrue,
          reason: 'لا توجد آيات لقصة ${entry.title}');
    }
  });

  test('قصص القرآن عشر قصص مكتوبة بكتل صالحة', () {
    final idx = parseStoriesIndex(File('assets/stories/stories.json').readAsStringSync());
    final quran = idx.section('quran');
    expect(quran.entries.length, 10);
    for (final e in quran.entries) {
      expect(e.blocks, isNotEmpty, reason: 'لا سرد لقصة ${e.title}');
      expect(e.blocks.any((b) => b.t == 'p'), isTrue);
      expect(e.blocks.any((b) => b.t == 'q'), isTrue);
      for (final b in e.blocks) {
        if (b.t == 'q') {
          expect(b.surah, inInclusiveRange(1, 114));
          expect(b.from, lessThanOrEqualTo(b.to));
        }
        if (b.t == 'hd') expect(b.text, isNotEmpty);
      }
    }
  });

  test('قصص الأنبياء السبع عشرة مكتوبة بكتل صالحة', () {
    final idx = parseStoriesIndex(File('assets/stories/stories.json').readAsStringSync());
    final prophets = idx.section('prophets');
    expect(prophets.entries.length, 17);
    for (final e in prophets.entries) {
      expect(e.blocks.any((b) => b.t == 'p'), isTrue, reason: 'لا سرد لقصة ${e.title}');
      expect(e.blocks.any((b) => b.t == 'q'), isTrue);
      expect(e.blocks.last.t, 'src');
    }
  });

  test('السيرة النبوية قيد الإعداد: قسم بلا مدخلات', () {
    final idx = parseStoriesIndex(File('assets/stories/stories.json').readAsStringSync());
    expect(idx.section('seerah').entries, isEmpty);
    expect(Directory('assets/stories/books').existsSync(), isFalse);
  });
}
