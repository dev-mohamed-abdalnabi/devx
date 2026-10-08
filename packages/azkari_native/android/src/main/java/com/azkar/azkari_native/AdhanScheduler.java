package com.azkar.azkari_native;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import org.json.JSONArray;
import org.json.JSONObject;

/** يجدول الأذان بمنبّه دقيق (AlarmClock) ويحفظ القائمة ليعيد جدولتها بعد إعادة تشغيل الجهاز. */
final class AdhanScheduler {
    private static final String PREFS = "azkari_adhan";
    private static final String KEY = "entries";
    static final String EXTRA_NAME = "name";
    static final String EXTRA_STYLE = "style";
    static final String EXTRA_DISPLAY = "display";
    static final String EXTRA_SOUND = "soundPath";

    private AdhanScheduler() {}

    private static PendingIntent pending(Context ctx, int id, String name) {
        return pending(ctx, id, name, 0, 1, "");
    }

    private static PendingIntent pending(Context ctx, int id, String name, int style, int display, String sound) {
        Intent i = new Intent(ctx, AdhanReceiver.class);
        i.setAction("com.azkar.azkari_native.ADHAN." + id);
        i.putExtra(EXTRA_NAME, name);
        i.putExtra(EXTRA_STYLE, style);
        i.putExtra(EXTRA_DISPLAY, display);
        i.putExtra(EXTRA_SOUND, sound == null ? "" : sound);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        return PendingIntent.getBroadcast(ctx, id, i, flags);
    }

    static void cancelAll(Context ctx) {
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        SharedPreferences sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        try {
            JSONArray arr = new JSONArray(sp.getString(KEY, "[]"));
            for (int k = 0; k < arr.length(); k++) {
                JSONObject o = arr.getJSONObject(k);
                if (am != null) am.cancel(pending(ctx, o.getInt("id"), o.optString("name")));
            }
        } catch (Exception ignored) {
        }
        sp.edit().remove(KEY).apply();
    }

    /** يستبدل كل الجداول السابقة. entries: [{id, time(ms), name}] */
    static void scheduleAll(Context ctx, JSONArray entries) {
        cancelAll(ctx);
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, entries.toString()).apply();
        arm(ctx, entries);
    }

    static void rescheduleFromStorage(Context ctx) {
        try {
            JSONArray arr = new JSONArray(
                    ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"));
            arm(ctx, arr);
        } catch (Exception ignored) {
        }
    }

    private static void arm(Context ctx, JSONArray arr) {
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        long now = System.currentTimeMillis();
        for (int k = 0; k < arr.length(); k++) {
            try {
                JSONObject o = arr.getJSONObject(k);
                long t = o.getLong("time");
                if (t <= now) continue;
                int id = o.getInt("id");
                String name = o.optString("name");
                PendingIntent pi = pending(ctx, id, name, o.optInt("style", 0), o.optInt("display", 1),
                        o.optString("soundPath", ""));
                try {
                    Intent show = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
                    int flags = PendingIntent.FLAG_UPDATE_CURRENT;
                    if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
                    PendingIntent showPi = PendingIntent.getActivity(ctx, 1, show, flags);
                    am.setAlarmClock(new AlarmManager.AlarmClockInfo(t, showPi), pi);
                } catch (Exception e) {
                    // لا إذن للمنبّه الدقيق: أقرب بديل يعمل أثناء Doze.
                    if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi);
                    else am.set(AlarmManager.RTC_WAKEUP, t, pi);
                }
            } catch (Exception ignored) {
            }
        }
    }
}
