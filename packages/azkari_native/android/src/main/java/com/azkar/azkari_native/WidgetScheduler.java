package com.azkar.azkari_native;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import java.util.Calendar;

/**
 * جدولة التحديث التالي فقط، وعند لحظة تغيّر فعلية (مشهد الكارت، نصيحة، دخول وقت صلاة، منتصف الليل).
 * المنبّه غير مُوقِظ للجهاز (RTC) وغير دقيق: لا يستهلك بطارية، وإن كان الجهاز نائمًا يُنفَّذ عند أول استيقاظ.
 */
final class WidgetScheduler {
    static final String ACTION = "com.azkar.azkari_native.WIDGET_TICK";
    private static final int REQ = 7100;
    /** حدود الساعات التي يتغيّر عندها المشهد أو النص أو الشريحة (بالساعة العشرية). */
    private static final double[] HOURS = {0, 1, 3, 5, 6, 6.5, 9, 9.5, 12, 13, 15, 17.5, 19, 21};

    private WidgetScheduler() {}

    private static PendingIntent pi(Context ctx) {
        Intent i = new Intent(ctx, WidgetTickReceiver.class);
        i.setAction(ACTION);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        return PendingIntent.getBroadcast(ctx, REQ, i, flags);
    }

    static void cancel(Context ctx) {
        try {
            AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
            if (am != null) am.cancel(pi(ctx));
        } catch (Throwable ignored) {
        }
    }

    static void cancelIfNone(Context ctx) {
        if (!WidgetUpdater.anyWidget(ctx)) cancel(ctx);
    }

    static void schedule(Context ctx, WidgetData d, long now) {
        try {
            AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            long next = nextTrigger(d, now);
            am.set(AlarmManager.RTC, next, pi(ctx));
        } catch (Throwable ignored) {
        }
    }

    static long nextTrigger(WidgetData d, long now) {
        long min = now + 6L * 3600_000L; // سقف أمان: نحدّث كل ٦ ساعات على الأكثر
        long floor = now + 20_000L;

        Calendar c = Calendar.getInstance();
        for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
            for (double hh : HOURS) {
                c.setTimeInMillis(now);
                c.add(Calendar.DAY_OF_YEAR, dayOffset);
                c.set(Calendar.HOUR_OF_DAY, (int) hh);
                c.set(Calendar.MINUTE, (int) Math.round((hh - (int) hh) * 60));
                c.set(Calendar.SECOND, 5);
                c.set(Calendar.MILLISECOND, 0);
                long t = c.getTimeInMillis();
                if (t > floor && t < min) min = t;
            }
        }
        // لحظات تغيّر نصيحة الصلاة: قبلها بـ٩٠ و٢٥ دقيقة، ودخولها، وبعدها بـ٤٠ دقيقة.
        long[] offs = {-90 * 60_000L, -25 * 60_000L, 5_000L, 40 * 60_000L + 5_000L};
        for (WidgetData.Day day : d.days) {
            for (int i = 0; i < 5; i++) {
                long p = day.t[WidgetData.PRAYER_SLOT[i]];
                if (p <= 0) continue;
                for (long o : offs) {
                    long t = p + o;
                    if (t > floor && t < min) min = t;
                }
            }
            if (day.t[0] > now + 3 * 24 * 3600_000L) break;
        }
        return min;
    }
}
