import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/data/library_data.dart';

void main() {
  test('تحليل كتاب حديث وترتيب الأحاديث المسطّحة', () {
    final hb = parseHadithBook(
        '{"id":"x","title":"كتاب","author":"مؤلف","chapters":['
        '{"t":"باب أ","h":[[1,"نص ١"],[2,"نص ٢"]]},'
        '{"t":"باب ب","h":[[3,"نص ٣"]]}]}');
    expect(hb.count, 3);
    expect(hb.flat.map((r) => r.item.n), [1, 2, 3]);
    expect(hb.flat.last.chapter.title, 'باب ب');
  });

  test('تحليل كتاب فقه', () {
    final b = parseFiqhBook(
        '{"id":"f","title":"ك","author":"م","madhhab":"مذهب","sections":['
        '{"t":"كتاب الطهارة","lvl":1,"p":["أ","ب"]},'
        '{"t":"باب","lvl":2,"p":["ج"]}]}');
    expect(b.sections.length, 2);
    expect(b.flat.map((r) => r.section), [0, 0, 1]);
  });

  test('البحث يتجاهل التشكيل ويشترط كل الكلمات', () {
    final keys = buildKeys(['إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ', 'الصلاة والزكاة']);
    expect(LibraryRepo.match(keys, 'الاعمال بالنيات'), [0]);
    expect(LibraryRepo.match(keys, 'الصلاة الزكاة'), [1]);
    expect(LibraryRepo.match(keys, 'الصلاة النيات'), isEmpty);
    expect(LibraryRepo.match(keys, 'ا'), isEmpty);
  });
}
