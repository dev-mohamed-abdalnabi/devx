#!/usr/bin/env python3
"""يوقّع نسخة release بمفتاح ثابت حتى تُثبَّت كل نسخة جديدة فوق القديمة.

يقرأ من متغيرات البيئة (أسرار GitHub):
  ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
يفشل بوضوح إن كان أي سر ناقصًا، حتى لا يُبنى APK بمفتاح debug بالخطأ.
"""
import base64
import os
import pathlib
import sys

APP = pathlib.Path('android/app')
KTS = APP / 'build.gradle.kts'
GROOVY = APP / 'build.gradle'


def need(name: str) -> str:
    value = os.environ.get(name, '').strip()
    if not value:
        print(f'ERROR: السر {name} غير موجود. أضفه في GitHub: Settings > Secrets and variables > Actions',
              file=sys.stderr)
        sys.exit(1)
    return value


def write_keystore() -> None:
    data = base64.b64decode(need('ANDROID_KEYSTORE_BASE64'))
    (APP / 'upload-keystore.jks').write_bytes(data)
    props = (
        f"storePassword={need('ANDROID_KEYSTORE_PASSWORD')}\n"
        f"keyPassword={need('ANDROID_KEY_PASSWORD')}\n"
        f"keyAlias={need('ANDROID_KEY_ALIAS')}\n"
        "storeFile=upload-keystore.jks\n"
    )
    pathlib.Path('android/key.properties').write_text(props, encoding='utf-8')


KTS_BLOCK = '''    signingConfigs {
        create("release") {
            val props = java.util.Properties()
            props.load(java.io.FileInputStream(rootProject.file("key.properties")))
            keyAlias = props.getProperty("keyAlias")
            keyPassword = props.getProperty("keyPassword")
            storeFile = file(props.getProperty("storeFile"))
            storePassword = props.getProperty("storePassword")
        }
    }

'''

GROOVY_BLOCK = '''    signingConfigs {
        release {
            def props = new Properties()
            props.load(new FileInputStream(rootProject.file("key.properties")))
            keyAlias props['keyAlias']
            keyPassword props['keyPassword']
            storeFile file(props['storeFile'])
            storePassword props['storePassword']
        }
    }

'''


def patch_gradle() -> None:
    path = KTS if KTS.exists() else GROOVY if GROOVY.exists() else None
    if path is None:
        print('ERROR: لم أجد build.gradle للتطبيق', file=sys.stderr)
        sys.exit(1)
    c = path.read_text(encoding='utf-8')
    kts = path == KTS
    if 'key.properties' not in c:
        idx = c.find('buildTypes {')
        if idx < 0:
            print('ERROR: لم أجد buildTypes في ملف gradle', file=sys.stderr)
            sys.exit(1)
        c = c[:idx] + (KTS_BLOCK if kts else GROOVY_BLOCK) + c[idx:]
    if kts:
        c = c.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
    else:
        c = c.replace('signingConfigs.debug', 'signingConfigs.release')
    if 'signingConfigs.getByName("release")' not in c and 'signingConfigs.release' not in c:
        print('ERROR: لم أجد سطر signingConfig داخل buildTypes.release', file=sys.stderr)
        sys.exit(1)
    path.write_text(c, encoding='utf-8')
    print(f'تم ربط توقيع release بالمفتاح الثابت في {path}')


if __name__ == '__main__':
    write_keystore()
    patch_gradle()
