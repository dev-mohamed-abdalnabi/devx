#!/usr/bin/env python3
"""يتأكد (وقت البناء) أن ملف الأذان والأيقونة الشفافة وخدمة الميديا موجودة، ويفشل البناء لو ناقصة.

  python3 tool/verify_android.py                      # قبل البناء: المصدر + android/
  python3 tool/verify_android.py apk <ملف.apk|مجلد>   # بعد البناء: داخل الـ APK نفسه
"""
import glob
import pathlib
import sys
import zipfile

AUDIO_EXTS = ['ogg', 'mp3', 'wav', 'm4a', 'aac', 'opus']
MIN_BYTES = 10 * 1024
RAW = pathlib.Path('android/app/src/main/res/raw')
PLUGIN = pathlib.Path('packages/azkari_native/android/src/main')
PLUGIN_RAW = PLUGIN / 'res/raw'
PLUGIN_ICON = PLUGIN / 'res/drawable/ic_stat_blank.xml'
PLUGIN_MANIFEST = PLUGIN / 'AndroidManifest.xml'
ICON = pathlib.Path('android/app/src/main/res/drawable/ic_stat_blank.xml')
MANIFEST = pathlib.Path('android/app/src/main/AndroidManifest.xml')


def looks_like_audio(head: bytes) -> bool:
    return (head.startswith(b'OggS') or head.startswith(b'ID3') or head.startswith(b'RIFF')
            or (len(head) > 1 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0)
            or head[4:8] == b'ftyp')


def check_source() -> list:
    errors = []
    candidates = []
    for ext in AUDIO_EXTS:
        candidates.append(pathlib.Path(f'assets/audio/adhan.{ext}'))
        candidates.append(PLUGIN_RAW / f'adhan.{ext}')
    existing = [f for f in candidates if f.exists()]
    if not existing:
        errors.append('ملف الأذان غير موجود: ضع packages/azkari_native/android/src/main/res/raw/adhan.ogg '
                      '(أو mp3/wav)')
    for src in existing:
        size = src.stat().st_size
        head = src.read_bytes()[:16]
        if size < MIN_BYTES:
            errors.append(f'{src} صغير جدًا ({size} بايت) — غالبًا ملف تالف أو ملف LFS مؤشّر')
        elif not looks_like_audio(head):
            errors.append(f'{src} ليس ملف صوت صالح (ترويسة غير معروفة)')
        else:
            print(f'OK: {src} ({size // 1024} KB)')
    has_raw = (RAW.exists() and list(RAW.glob('adhan.*'))) or (PLUGIN_RAW.exists() and list(PLUGIN_RAW.glob('adhan.*')))
    if not has_raw:
        errors.append('لا يوجد res/raw/adhan.* لا في حزمة azkari_native ولا في android/app')
    if not (ICON.exists() or PLUGIN_ICON.exists()):
        errors.append('الأيقونة الشفافة ic_stat_blank.xml غير موجودة')
    manifests = [m.read_text(encoding='utf-8') for m in (MANIFEST, PLUGIN_MANIFEST) if m.exists()]
    if not manifests:
        errors.append('لا يوجد أي AndroidManifest')
    else:
        m = '\n'.join(manifests)
        for need in ['com.ryanheise.audioservice.AudioService', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
                     'POST_NOTIFICATIONS', 'foregroundServiceType="mediaPlayback"',
                     'ScheduledNotificationReceiver']:
            if need not in m:
                errors.append(f'المانيفست ينقصه: {need}')
    acts = list(pathlib.Path('android/app/src/main').rglob('MainActivity.*'))
    if acts and 'AudioServiceActivity' not in acts[0].read_text(encoding='utf-8'):
        print('تحذير: MainActivity ليست AudioServiceActivity (شغّل tool/patch_android.py)')
    return errors


def has_resource(apk: zipfile.ZipFile, name: str) -> bool:
    if any(n.startswith('res/') and f'/{name}.' in n for n in apk.namelist()):
        return True
    # لو أسماء الملفات مُصغّرة، اسم المورد يبقى في resources.arsc
    if 'resources.arsc' in apk.namelist():
        data = apk.read('resources.arsc')
        return name.encode() in data or name.encode('utf-16-le') in data
    return False


def check_apk(target: str) -> list:
    files = sorted(glob.glob(f'{target}/*.apk')) if pathlib.Path(target).is_dir() else [target]
    if not files:
        return [f'لا يوجد APK في {target}']
    errors = []
    for f in files:
        with zipfile.ZipFile(f) as apk:
            for res in ('adhan', 'ic_stat_blank'):
                if has_resource(apk, res):
                    print(f'OK: {pathlib.Path(f).name} يحتوي المورد {res}')
                else:
                    errors.append(f'{pathlib.Path(f).name}: المورد {res} غير موجود داخل الـ APK')
    return errors


def main() -> int:
    errors = check_apk(sys.argv[2]) if len(sys.argv) >= 3 and sys.argv[1] == 'apk' else check_source()
    if errors:
        print('\nفشل التحقق:', file=sys.stderr)
        for e in errors:
            print(f'  ✗ {e}', file=sys.stderr)
        return 1
    print('تم التحقق بنجاح')
    return 0


if __name__ == '__main__':
    sys.exit(main())
