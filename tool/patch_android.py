#!/usr/bin/env python3
"""يضيف أذونات أندرويد ومستقبلات الإشعارات إلى AndroidManifest.xml الناتج عن flutter create.
آمن للتشغيل أكثر من مرة (idempotent). يفشل بخطأ واضح إن تغيّر شكل الملف."""
import pathlib
import re
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
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
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


def patch_main_activity() -> None:
    """يجعل Activity الرئيسية متوافقة مع audio_service للإشعارات وشاشة القفل."""
    candidates = list(ACTIVITY_ROOT.rglob('MainActivity.kt')) + list(ACTIVITY_ROOT.rglob('MainActivity.java'))
    if not candidates:
        print('WARNING: لم أجد MainActivity؛ تخطّيت ربط AudioServiceActivity')
        return
    path = candidates[0]
    c = path.read_text(encoding='utf-8')
    if path.suffix == '.kt':
        if 'AudioServiceActivity' not in c:
            c = c.replace('import io.flutter.embedding.android.FlutterActivity',
                          'import com.ryanheise.audioservice.AudioServiceActivity')
            c = re.sub(r'class\s+MainActivity\s*:\s*FlutterActivity\s*\(\)',
                       'class MainActivity : AudioServiceActivity()', c)
    else:
        if 'AudioServiceActivity' not in c:
            c = c.replace('import io.flutter.embedding.android.FlutterActivity;',
                          'import com.ryanheise.audioservice.AudioServiceActivity;')
            c = c.replace('extends FlutterActivity', 'extends AudioServiceActivity')
    path.write_text(c, encoding='utf-8')
    print(f'تم ربط {path} بـ AudioServiceActivity')


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
    patch_main_activity()

    # تحقق نهائي
    need = ['POST_NOTIFICATIONS', 'INTERNET', 'RECEIVE_BOOT_COMPLETED', 'SCHEDULE_EXACT_ALARM',
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
