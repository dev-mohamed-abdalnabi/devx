#!/usr/bin/env bash
# يثبّت الـ APK على المحاكي ويفتحه ويراقبه 60 ثانية.
# لو كراش: يطبع سبب الكراش الكامل ويفشل البناء (فلا يُبنى APK نهائي).
APK="$1"
[ -f "$APK" ] || { echo "::error::الـ APK غير موجود: $APK"; exit 1; }

adb wait-for-device
adb install -r "$APK" || { echo "::error::فشل تثبيت الـ APK على المحاكي"; exit 1; }

PKG="$(adb shell pm list packages | tr -d '\r' | grep -i azkarapp | head -1 | cut -d: -f2)"
PKG="${PKG:-com.azkarapp.azkar_app}"
echo "Package: $PKG"

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

crashed=0
reason=""
for i in $(seq 1 12); do
  sleep 5
  if adb logcat -d -b crash | grep -qF "$PKG"; then crashed=1; reason="crash buffer"; break; fi
  if [ -z "$(adb shell "pidof $PKG" | tr -d '\r')" ]; then crashed=1; reason="process died"; break; fi
done

if [ "$crashed" = "1" ]; then
  echo "::error::التطبيق كراش عند الفتح ($reason). السبب في اللوج تحت."
  echo "================= CRASH BUFFER ================="
  adb logcat -d -b crash | tail -120
  echo "================= FILTERED LOGCAT ================="
  adb logcat -d -v time | grep -E "$PKG|AndroidRuntime|FATAL|MobileAds|gms\.ads|Caused by|UnsatisfiedLink|ClassNotFound|SecurityException|flutter" | tail -200
  exit 1
fi

echo "✅ التطبيق اشتغل 60 ثانية بدون كراش"
adb shell dumpsys activity activities | grep -i "ResumedActivity" | head -3
exit 0
