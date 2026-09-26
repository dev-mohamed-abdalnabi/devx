# تطبيق أذكاري (Azkar App)

تطبيق أذكار كامل بدون إنترنت، مبني بـ Flutter.

## طريقة التشغيل

1. ثبّت Flutter SDK: https://docs.flutter.dev/get-started/install
2. افتح مجلد المشروع في VS Code أو Android Studio
3. نفّذ الأوامر التالية في الطرفية:

```bash
flutter pub get
flutter run
```

## بناء ملف APK للتوزيع (يدوياً)

```bash
flutter build apk --release
```
الملف الناتج هيكون في: `build/app/outputs/flutter-apk/app-release.apk`

## البناء التلقائي عند الرفع على GitHub ✅

المشروع فيه `.github/workflows/build-apk.yml` جاهز. كل ما تعمل:

```bash
git init
git add .
git commit -m "أول رفعة"
git branch -M main
git remote add origin <رابط-المستودع-بتاعك>
git push -u origin main
```

GitHub هيشغّل تلقائياً عملية بناء الـ APK، وهتلاقي الناتج في مكانين:
1. تبويب **Actions** → آخر تشغيل → قسم Artifacts → حمّل `azkar-app-apk`
2. تبويب **Releases** على يمين صفحة المستودع → هيتعمل Release جديد تلقائياً بكل push فيه ملف الـ APK جاهز للتنزيل مباشرة

ملاحظة: أول تشغيل ممكن ياخد 3-5 دقائق (تثبيت Flutter وبناء المشروع).

## هيكل المشروع

- `lib/main.dart` — نقطة الدخول والثيمات (فاتح/داكن)
- `lib/data/azkar.json` — كل بيانات الأذكار (محلية بالكامل)
- `lib/models/zikr.dart` — نموذج البيانات
- `lib/providers/azkar_provider.dart` — إدارة الحالة (عداد، مفضلة، تقدم يومي)
- `lib/providers/notification_service.dart` — الإشعارات المحلية
- `lib/screens/` — كل الشاشات
- `lib/widgets/zikr_card.dart` — بطاقة الذكر التفاعلية

## المميزات الحالية
- عداد تفاعلي لكل ذكر مع اهتزاز
- 6 تصنيفات (صباح، مساء، نوم، استيقاظ، بعد الصلاة، أدعية)
- مفضلة + بحث فوري
- تتبع تقدم كل قسم (progress bar)
- وضع ليلي + تكبير/تصغير الخط
- إشعارات محلية يومية (صباح/مساء)

## أفكار للتوسع لاحقاً
- إضافة صوت لكل ذكر (تسجيل أو TTS محلي)
- Widget على الشاشة الرئيسية
- عداد تسبيح مستقل (تسبيحة منفصلة)
- المزيد من فئات "حصن المسلم" الكاملة (السفر، المرض، الزواج، إلخ) — ممكن تنسخها من:
  https://github.com/rn0x/hisn_almuslim_json وتحطها في نفس صيغة azkar.json
