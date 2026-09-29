#!/usr/bin/env python3
"""يضيف أذونات أندرويد ومستقبلات الإشعارات إلى AndroidManifest.xml الناتج عن flutter create.
آمن للتشغيل أكثر من مرة (idempotent). يفشل بخطأ واضح إن تغيّر شكل الملف."""
import pathlib
import sys

MANIFEST = pathlib.Path('android/app/src/main/AndroidManifest.xml')

PERMISSIONS = """    <!-- أُضيفت بواسطة tool/patch_android.py -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
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
    if 'useLegacyPackaging' in c:
        return
    block = ('    packaging {\n        jniLibs {\n            useLegacyPackaging = true\n        }\n    }\n')
    idx = c.find('android {')
    if idx < 0:
        print('WARNING: لم أجد كتلة android {} ؛ تخطّيت ضغط المكتبات الأصلية')
        return
    nl = c.find('\n', idx)
    c = c[:nl + 1] + block + c[nl + 1:]
    path.write_text(c, encoding='utf-8')
    print(f'تم تفعيل ضغط المكتبات الأصلية في {path}')


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

    s = s.replace('android:label="azkar_app"', 'android:label="أذكاري"')
    MANIFEST.write_text(s, encoding='utf-8')
    patch_gradle()

    # تحقق نهائي
    need = ['POST_NOTIFICATIONS', 'RECEIVE_BOOT_COMPLETED', 'SCHEDULE_EXACT_ALARM',
            'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION',
            'ScheduledNotificationReceiver', 'ScheduledNotificationBootReceiver']
    missing = [n for n in need if n not in s]
    if missing:
        print('ERROR: ناقص في المانيفست:', missing, file=sys.stderr)
        return 1
    print('AndroidManifest.xml جاهز:')
    print(s)
    return 0


if __name__ == '__main__':
    sys.exit(main())
