# ملاحظات للجزء الأصلي (Kotlin) — لم يكن داخل الملف المرفوع

التطبيق (Dart) يكتب هذه المفاتيح في SharedPreferences (على أندرويد: ملف FlutterSharedPreferences وبادئة `flutter.`):
- `flutter.adhan_style`      : 0..4 شكل شاشة الأذان
- `flutter.adhan_display`    : 0 = فوق كل التطبيقات، 1 = شاشة القفل فقط
- `flutter.adhan_sound_path` : مسار ملف الأذان المحمَّل، وفارغ = استخدم res/raw/adhan المدمج

وكل عنصر في `AzkariNative.scheduleAdhan` صار يحمل أيضًا: style / display / soundPath.
المطلوب في الخدمة الأصلية: تشغيل الملف من soundPath لو غير فارغ، وإظهار الـActivity فوق التطبيقات فقط لو display == 0.
