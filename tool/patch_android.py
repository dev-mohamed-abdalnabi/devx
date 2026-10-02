#!/usr/bin/env python3
"""يضيف أذونات أندرويد ومستقبلات الإشعارات إلى AndroidManifest.xml الناتج عن flutter create.
آمن للتشغيل أكثر من مرة (idempotent). يفشل بخطأ واضح إن تغيّر شكل الملف."""
import pathlib
import re
import sys

MANIFEST = pathlib.Path('android/app/src/main/AndroidManifest.xml')
PROGUARD = pathlib.Path('android/app/proguard-rules.pro')
ACTIVITY_ROOT = pathlib.Path('android/app/src/main')
ADS_APP_ID = 'ca-app-pub-6238197963590573~3817588900'

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

NATIVE_AD_FACTORY = """{package_name}

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class ForumNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {{
    override fun createNativeAd(nativeAd: NativeAd, customOptions: Map<String, Any>?): NativeAdView {{
        val adView = NativeAdView(context)
        val container = LinearLayout(context).apply {{
            orientation = LinearLayout.VERTICAL
            setPadding(20, 8, 20, 8)
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.TRANSPARENT)
        }}
        val headline = TextView(context).apply {{
            textSize = 16f
            setTextColor(Color.DKGRAY)
            maxLines = 1
        }}
        val body = TextView(context).apply {{
            textSize = 13f
            setTextColor(Color.GRAY)
            maxLines = 2
        }}
        headline.text = nativeAd.headline ?: "إعلان لدعم التطبيق"
        body.text = nativeAd.body ?: "قد يساعدك هذا الإعلان في دعم استمرار التطبيق."
        container.addView(headline)
        container.addView(body)
        adView.addView(container)
        adView.headlineView = headline
        adView.bodyView = body
        adView.setNativeAd(nativeAd)
        return adView
    }}
}}
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


def patch_ads_manifest(s: str) -> str:
    """يضيف App ID الإنتاجي لـ AdMob إلى application مرة واحدة."""
    if 'com.google.android.gms.ads.APPLICATION_ID' in s:
        return s
    idx = s.rfind('</application>')
    if idx < 0:
        raise RuntimeError('لم أجد </application> لإضافة App ID الخاص بـ AdMob')
    meta = (
        f'        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" '
        f'android:value="{ADS_APP_ID}" />\n'
    )
    return s[:idx] + meta + s[idx:]


def patch_main_activity() -> None:
    """يربط AudioService ويسجل مصنع الإعلان الأصلي للمنتدى."""
    candidates = list(ACTIVITY_ROOT.rglob('MainActivity.kt')) + list(ACTIVITY_ROOT.rglob('MainActivity.java'))
    if not candidates:
        print('WARNING: لم أجد MainActivity؛ تخطّيت ربط AudioServiceActivity')
        return
    path = candidates[0]
    c = path.read_text(encoding='utf-8')
    package_match = re.search(r'^package\s+([^\s]+)', c, re.MULTILINE)
    if package_match is None:
        print('WARNING: لم أجد package في MainActivity؛ تخطّيت مصنع الإعلان')
        return
    package_name = package_match.group(1)
    # يجب أن يكون المصنع داخل نفس source root الخاص بـ MainActivity؛
    # Flutter يضع Kotlin عادةً تحت src/main/kotlin/<package>/.
    factory = path.parent / 'ForumNativeAdFactory.kt'
    factory.write_text(
        NATIVE_AD_FACTORY.format(package_name=f'package {package_name}'),
        encoding='utf-8',
    )
    if path.suffix == '.kt':
        if 'AudioServiceActivity' not in c:
            c = c.replace('import io.flutter.embedding.android.FlutterActivity',
                          'import com.ryanheise.audioservice.AudioServiceActivity')
            c = re.sub(r'class\s+MainActivity\s*:\s*FlutterActivity\s*\(\)',
                       'class MainActivity : AudioServiceActivity()', c)
        if 'GoogleMobileAdsPlugin' not in c:
            c = c.replace(
                'import com.ryanheise.audioservice.AudioServiceActivity',
                'import com.ryanheise.audioservice.AudioServiceActivity\n'
                'import io.flutter.embedding.engine.FlutterEngine\n'
                'import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin',
            )
            c = c.replace(
                'class MainActivity : AudioServiceActivity()',
                '''class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GoogleMobileAdsPlugin.registerNativeAdFactory(
        flutterEngine, "forum", ForumNativeAdFactory(this)
    )
}
}''',
            )
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

    s = patch_ads_manifest(s)

    if 'ScheduledNotificationReceiver' not in s:
        idx = s.rfind('</application>')
        if idx < 0:
            print('ERROR: لم أجد </application> في المانيفست', file=sys.stderr)
            return 1
        s = s[:idx] + RECEIVERS + '    ' + s[idx:]

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
            'com.google.android.gms.ads.APPLICATION_ID']
    missing = [n for n in need if n not in s]
    if missing:
        print('ERROR: ناقص في المانيفست:', missing, file=sys.stderr)
        return 1
    print('AndroidManifest.xml جاهز:')
    print(s)
    return 0


if __name__ == '__main__':
    sys.exit(main())
