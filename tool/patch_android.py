#!/usr/bin/env python3
"""يضيف أذونات أندرويد ومستقبلات الإشعارات إلى AndroidManifest.xml الناتج عن flutter create.
آمن للتشغيل أكثر من مرة (idempotent). يفشل بخطأ واضح إن تغيّر شكل الملف."""
import pathlib
import re
import shutil
import sys

MANIFEST = pathlib.Path('android/app/src/main/AndroidManifest.xml')
PROGUARD = pathlib.Path('android/app/proguard-rules.pro')
ACTIVITY_ROOT = pathlib.Path('android/app/src/main')

PERMISSIONS = """    <!-- أُضيفت بواسطة tool/patch_android.py -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-feature android:name="android.hardware.sensor.compass" android:required="false"/>
    <uses-feature android:name="android.hardware.location.gps" android:required="false"/>
    <uses-feature android:name="android.hardware.location.network" android:required="false"/>
"""

RECEIVERS = """        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true"
            android:stopWithTask="false">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
"""

PROGUARD_RULES = """# flutter_local_notifications deserializes scheduled notifications with Gson.
# Keep generic type signatures so R8 full mode does not throw Missing type parameter.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
-dontwarn sun.misc.**
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keep class com.google.gson.internal.** { *; }
-keep class com.google.gson.** { *; }
# Required by Android notification dependencies when AGP 8/R8 full mode is enabled.
-keep class org.xmlpull.** { *; }
# google_mobile_ads pulls in WorkManager (Room database created via reflection at app start).
# Without these rules R8 breaks it: "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.startup.Initializer { *; }
-keep class androidx.startup.** { *; }
-dontwarn androidx.work.**
"""


ADMOB_APP_ID = 'ca-app-pub-6238197963590573~3817588900'
ADMOB_META = f"""        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="{ADMOB_APP_ID}"/>
"""


ADMOB_PROVIDER_REMOVE = """        <!-- يمنع تشغيل SDK الإعلانات تلقائيًا عند فتح التطبيق؛ يعمل فقط عند اختيار المستخدم -->
        <provider android:name="com.google.android.gms.ads.MobileAdsInitProvider"
            tools:node="remove"/>
"""


NOTIFICATION_ICON = pathlib.Path('android/app/src/main/res/drawable/ic_stat_quran.xml')
NOTIFICATION_ICON_XML = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M9,2c-1.05,0 -2.05,0.16 -3,0.46 4.06,1.27 7,5.06 7,9.54 0,4.48 -2.94,8.27 -7,9.54 0.95,0.3 1.95,0.46 3,0.46 5.52,0 10,-4.48 10,-10S14.52,2 9,2z"/>
</vector>
"""


def patch_notification_icon() -> None:
    """أيقونة صغيرة أحادية اللون لإشعار التلاوة (أيقونة التطبيق الملونة تظهر مربعًا أبيض أو تُفشل الإشعار)."""
    NOTIFICATION_ICON.parent.mkdir(parents=True, exist_ok=True)
    NOTIFICATION_ICON.write_text(NOTIFICATION_ICON_XML, encoding='utf-8')
    print(f'تمت كتابة {NOTIFICATION_ICON}')


def patch_adhan_sound() -> None:
    """ينسخ تسجيل الأذان المرخّص إلى موارد Android الخام كي يعمل مع الإشعار المجدول."""
    source = pathlib.Path('assets/audio/adhan.ogg')
    target = pathlib.Path('android/app/src/main/res/raw/adhan.ogg')
    if not source.exists():
        print(f'ERROR: ملف الأذان غير موجود: {source}', file=sys.stderr)
        raise FileNotFoundError(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    print(f'تم نسخ صوت الأذان إلى {target}')


def patch_gradle() -> None:
    """يضغط المكتبات الأصلية داخل الـ APK (أكبر توفير في الحجم). لا يُفشل البناء إن تعذّر."""
    kts = pathlib.Path('android/app/build.gradle.kts')
    groovy = pathlib.Path('android/app/build.gradle')
    path = kts if kts.exists() else groovy if groovy.exists() else None
    if path is None:
        print('WARNING: لم أجد build.gradle للتطبيق؛ تخطّيت ضغط المكتبات الأصلية')
        return
    c = path.read_text(encoding='utf-8')
    if 'useLegacyPackaging' not in c:
        block = ('    packaging {\n        jniLibs {\n            useLegacyPackaging = true\n        }\n    }\n')
        idx = c.find('android {')
        if idx < 0:
            print('WARNING: لم أجد كتلة android {} ؛ تخطّيت ضغط المكتبات الأصلية')
            return
        nl = c.find('\n', idx)
        c = c[:nl + 1] + block + c[nl + 1:]
    # الإشعارات أهم من تصغير APK؛ R8 full mode يسبب Missing type parameter
    # في بعض إصدارات flutter_local_notifications حتى مع قواعد ProGuard.
    c = c.replace('minifyEnabled true', 'minifyEnabled false')
    c = c.replace('shrinkResources true', 'shrinkResources false')
    c = c.replace('isMinifyEnabled = true', 'isMinifyEnabled = false')
    c = c.replace('isShrinkResources = true', 'isShrinkResources = false')
    path.write_text(c, encoding='utf-8')
    print(f'تم تفعيل ضغط المكتبات الأصلية في {path}')


def patch_proguard() -> None:
    """يحافظ على معلومات Gson العامة التي تحتاجها الإشعارات المجدولة."""
    PROGUARD.parent.mkdir(parents=True, exist_ok=True)
    current = PROGUARD.read_text(encoding='utf-8') if PROGUARD.exists() else ''
    missing = [line for line in PROGUARD_RULES.splitlines() if line and line not in current]
    if missing:
        separator = '' if not current or current.endswith('\n') else '\n'
        PROGUARD.write_text(current + separator + PROGUARD_RULES, encoding='utf-8')
        print(f'تمت إضافة قواعد R8 إلى {PROGUARD}')


def patch_main_activity() -> bool:
    """يجعل Activity الرئيسية AudioServiceActivity (شرط لإشعار التحكم وشاشة القفل). يرجع True عند النجاح."""
    candidates = list(ACTIVITY_ROOT.rglob('MainActivity.kt')) + list(ACTIVITY_ROOT.rglob('MainActivity.java'))
    if not candidates:
        print('ERROR: لم أجد MainActivity؛ إشعار التلاوة لن يعمل', file=sys.stderr)
        return False
    path = candidates[0]
    c = path.read_text(encoding='utf-8')
    if path.suffix == '.kt':
        c = re.sub(r':\s*FlutterActivity\s*\(\s*\)', ': AudioServiceActivity()', c)
        c = c.replace('import io.flutter.embedding.android.FlutterActivity',
                      'import com.ryanheise.audioservice.AudioServiceActivity')
        if 'import com.ryanheise.audioservice.AudioServiceActivity' not in c:
            c = re.sub(r'(package [^\n]+\n)', r'\1\nimport com.ryanheise.audioservice.AudioServiceActivity\n', c, count=1)
        ok = 'AudioServiceActivity()' in c
    else:
        c = c.replace('import io.flutter.embedding.android.FlutterActivity;',
                      'import com.ryanheise.audioservice.AudioServiceActivity;')
        c = c.replace('extends FlutterActivity', 'extends AudioServiceActivity')
        ok = 'extends AudioServiceActivity' in c
    path.write_text(c, encoding='utf-8')
    print(f'{"تم ربط" if ok else "فشل ربط"} {path} بـ AudioServiceActivity')
    return ok


def main() -> int:
    if not MANIFEST.exists():
        print(f'ERROR: {MANIFEST} غير موجود. شغّل flutter create --platforms=android . أولًا', file=sys.stderr)
        return 1
    s = MANIFEST.read_text(encoding='utf-8')

    if 'POST_NOTIFICATIONS' not in s:
        idx = s.find('<application')
        if idx < 0:
            print('ERROR: لم أجد <application> في المانيفست', file=sys.stderr)
            return 1
        s = s[:idx] + PERMISSIONS.lstrip('\n') + '\n    ' + s[idx:]

    if 'ScheduledNotificationReceiver' not in s:
        idx = s.rfind('</application>')
        if idx < 0:
            print('ERROR: لم أجد </application> في المانيفست', file=sys.stderr)
            return 1
        s = s[:idx] + RECEIVERS + '    ' + s[idx:]

    if 'com.google.android.gms.ads.APPLICATION_ID' not in s:
        idx = s.rfind('</application>')
        if idx < 0:
            print('ERROR: لم أجد </application> في المانيفست', file=sys.stderr)
            return 1
        s = s[:idx] + ADMOB_META + '    ' + s[idx:]

    if 'xmlns:tools=' not in s:
        s = s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
    if 'MobileAdsInitProvider' not in s:
        idx = s.rfind('</application>')
        if idx < 0:
            print('ERROR: لم أجد </application> في المانيفست', file=sys.stderr)
            return 1
        s = s[:idx] + ADMOB_PROVIDER_REMOVE + '    ' + s[idx:]

    s = s.replace('android:label="azkar_app"', 'android:label="ذكر"')
    s = s.replace('android:label="أذكاري"', 'android:label="ذكر"')
    MANIFEST.write_text(s, encoding='utf-8')
    patch_gradle()
    patch_proguard()
    patch_notification_icon()
    patch_adhan_sound()
    if not patch_main_activity():
        return 1

    # تحقق نهائي
    need = ['POST_NOTIFICATIONS', 'INTERNET', 'RECEIVE_BOOT_COMPLETED', 'SCHEDULE_EXACT_ALARM', 'USE_EXACT_ALARM',
            'USE_FULL_SCREEN_INTENT',
            'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION',
            'ScheduledNotificationReceiver', 'ScheduledNotificationBootReceiver',
            'com.ryanheise.audioservice.AudioService', 'MediaButtonReceiver',
            'com.google.android.gms.ads.APPLICATION_ID', ADMOB_APP_ID,
            'MobileAdsInitProvider', 'xmlns:tools=']
    missing = [n for n in need if n not in s]
    if missing:
        print('ERROR: ناقص في المانيفست:', missing, file=sys.stderr)
        return 1
    print('AndroidManifest.xml جاهز:')
    print(s)
    return 0


if __name__ == '__main__':
    sys.exit(main())
