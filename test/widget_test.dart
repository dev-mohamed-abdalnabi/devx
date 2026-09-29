import 'package:flutter_test/flutter_test.dart';
import 'package:azkar_app/main.dart';

void main() {
  test('التطبيق يعرّف الجذر الصحيح', () {
    expect(const AzkarApp(), isA<AzkarApp>());
  });
}
