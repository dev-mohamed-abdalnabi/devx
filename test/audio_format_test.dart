import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/providers/quran_audio_provider.dart';

void main() {
  test('تنسيق وقت المشغل', () {
    expect(formatAudioTime(Duration.zero), '0:00');
    expect(formatAudioTime(const Duration(seconds: 9)), '0:09');
    expect(formatAudioTime(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(formatAudioTime(const Duration(hours: 1, minutes: 2, seconds: 9)), '1:02:09');
    expect(formatAudioTime(const Duration(seconds: -5)), '0:00');
  });

  test('أسماء السور ١١٤ وتبدأ بالفاتحة', () {
    expect(QuranAudioProvider.surahNames.length, QuranAudioProvider.surahCount);
    expect(QuranAudioProvider.surahName(1), 'الفاتحة');
    expect(QuranAudioProvider.surahName(114), 'الناس');
  });
}
