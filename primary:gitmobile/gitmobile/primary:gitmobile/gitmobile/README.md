# GitMobile

تطبيق React Native (Expo) لإدارة GitHub بالكامل من الموبايل: رفع فولدر كامل أو ملفات متعددة (بيحافظ على شكل الفولدر)، حذف، تعديل ملفات، تبديل وإنشاء فروع.

## ⚠️ أول حاجة قبل أي حاجة

لو سبق وحطيت GitHub Token في أي مكان مكشوف (شات، كومنت، إلخ) — **الغيه فورًا** من:
`GitHub → Settings → Developer settings → Personal access tokens → Revoke`

التوكن بيتخزن جوه التطبيق نفسه بس (SecureStore على الموبايل) — مش هارد كودد في السورس كود خالص، فتقدر ترفع الريبو على GitHub براحتك.

## الرفع على GitHub

```bash
cd gitmobile
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/dev-mohamed-abdalnabi/gitmobile.git
git push -u origin main
```

بمجرد ما تعمل push، الـ **GitHub Actions workflow** (`.github/workflows/build-apk.yml`) هيشتغل تلقائي:
1. يعمل `expo prebuild` (يبني مشروع Android native)
2. يعمل `gradlew assembleDebug`
3. يرفع الـ APK كـ **Release** جوه تبويب **Releases** في الريبو، وكمان كـ Artifact في تبويب Actions

روح على تبويب **Actions** في الريبو، استنى الـ build يخلص (بياخد حوالي 5-8 دقايق أول مرة)، بعدين روح **Releases** ونزّل الـ APK على موبايلك مباشرة.

## الاستخدام جوه التطبيق

1. افتح التطبيق → اكتب الـ GitHub Token بتاعك في شاشة الإعدادات (اعمله من [github.com/settings/tokens](https://github.com/settings/tokens) بصلاحية `repo`)
2. دوس "اختبار التوكن" للتأكد إنه شغال
3. روح "اذهب للريبوهات" → اختار الريبو → تصفح الملفات
4. من أي فولدر، دوس "رفع هنا" → اختار "فولدر كامل" (بيحافظ على شكله بالكامل) أو "ملفات متعددة"
5. حذف/تعديل أي ملف من جوه استعراض الملفات

## ملاحظة عن رفع الفولدر

اختيار فولدر كامل بيحافظ على شكله (Storage Access Framework) شغال على **Android بس** حاليًا — وده أصلًا اللي محتاجه. اختيار الملفات المتعددة شغال على أي منصة كـ fallback.

## لو عايز توقيع APK رسمي (مش debug)

ضيف secrets في الريبو (`Settings → Secrets and variables → Actions`):
- `SIGNING_KEY`, `KEY_ALIAS`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`

وعدّل الـ workflow يستخدم `assembleRelease` بدل `assembleDebug` مع signing config. قولّي لو عايز أضيفهملك.
