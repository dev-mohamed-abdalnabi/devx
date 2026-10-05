package com.azkar.azkari_native;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.DisplayMetrics;
import android.view.View;
import android.widget.RemoteViews;

import java.util.Calendar;

/** يبني RemoteViews للودجتس الثلاثة ويحدّثها. لا خدمات دائمة ولا محرّك Flutter. */
final class WidgetUpdater {
    static final String HERO = "hero", AYAH = "ayah", PRAYER = "prayer";

    private WidgetUpdater() {}

    static Class<?> providerFor(String kind) {
        if (HERO.equals(kind)) return AzwHeroProvider.class;
        if (AYAH.equals(kind)) return AzwAyahProvider.class;
        if (PRAYER.equals(kind)) return AzwPrayerProvider.class;
        return null;
    }

    static int count(Context ctx, String kind) {
        try {
            Class<?> cls = providerFor(kind);
            if (cls == null) return 0;
            return AppWidgetManager.getInstance(ctx).getAppWidgetIds(new ComponentName(ctx, cls)).length;
        } catch (Throwable t) {
            return 0;
        }
    }

    static boolean anyWidget(Context ctx) {
        return count(ctx, HERO) + count(ctx, AYAH) + count(ctx, PRAYER) > 0;
    }

    /** تحديث على خيط خلفي كي لا نحجز الخيط الرئيسي ولا نتجاوز مهلة المستقبِل. */
    static void updateAsync(final Context ctx, final BroadcastReceiver.PendingResult pr) {
        final Context app = ctx.getApplicationContext();
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    updateAll(app);
                } catch (Throwable ignored) {
                } finally {
                    if (pr != null) pr.finish();
                }
            }
        }, "azkari-widgets");
        t.start();
    }

    static synchronized void updateAll(Context ctx) {
        AppWidgetManager mgr = AppWidgetManager.getInstance(ctx);
        WidgetData d = WidgetData.load(ctx);
        long now = System.currentTimeMillis();
        boolean any = false;
        for (String kind : new String[]{HERO, AYAH, PRAYER}) {
            Class<?> cls = providerFor(kind);
            int[] ids = mgr.getAppWidgetIds(new ComponentName(ctx, cls));
            for (int id : ids) {
                any = true;
                RemoteViews rv;
                try {
                    rv = build(ctx, mgr, id, kind, d, now);
                } catch (Throwable e) {
                    rv = fallback(ctx);
                }
                try {
                    mgr.updateAppWidget(id, rv);
                } catch (Throwable ignored) {
                }
            }
        }
        if (any) WidgetScheduler.schedule(ctx, d, now);
        else WidgetScheduler.cancel(ctx);
    }

    private static RemoteViews fallback(Context ctx) {
        RemoteViews rv = new RemoteViews(ctx.getPackageName(), R.layout.azw_loading);
        rv.setOnClickPendingIntent(R.id.azw_root, launchPi(ctx, 77));
        return rv;
    }

    private static PendingIntent launchPi(Context ctx, int code) {
        Intent i = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        if (i == null) i = new Intent();
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        return PendingIntent.getActivity(ctx, code, i, flags);
    }

    /** مقاس الودجت الفعلي بالـdp حسب الاتجاه (نفس الأسلوب المعتمد في وثائق أندرويد). */
    private static float[] size(Context ctx, AppWidgetManager mgr, int id, float defW, float defH) {
        float w = defW, h = defH;
        try {
            Bundle o = mgr.getAppWidgetOptions(id);
            boolean land = ctx.getResources().getConfiguration().orientation
                    == android.content.res.Configuration.ORIENTATION_LANDSCAPE;
            int ow = o.getInt(land ? AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH : AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0);
            int oh = o.getInt(land ? AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT : AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0);
            if (ow > 0) w = ow;
            if (oh > 0) h = oh;
        } catch (Throwable ignored) {
        }
        return new float[]{Math.max(120, Math.min(800, w)), Math.max(70, Math.min(500, h))};
    }

    private static RemoteViews build(Context ctx, AppWidgetManager mgr, int id, String kind, WidgetData d, long now) {
        if (HERO.equals(kind)) return hero(ctx, mgr, id, d, now);
        if (AYAH.equals(kind)) return ayah(ctx, mgr, id, d, now);
        return prayer(ctx, mgr, id, d, now);
    }

    // ---------------------------------------------------------------- hero
    private static RemoteViews hero(Context ctx, AppWidgetManager mgr, int id, WidgetData d, long now) {
        float[] sz = size(ctx, mgr, id, 320, 160);
        float w = sz[0], h = sz[1];
        DisplayMetrics dm = ctx.getResources().getDisplayMetrics();
        float textScale = Math.min(dm.density, 2.5f);
        // حد ذاكرة الـRemoteViews تقريبًا ٦ بايت × بكسلات الشاشة؛ نستهلك أقل من نصفه.
        double budget = dm.widthPixels * (double) dm.heightPixels * 4 * 1.5 * 0.45;
        double textBytes = w * h * textScale * textScale * 4;
        float artScale = 0;
        int frames = 3;
        for (float s = Math.min(dm.density, 2f); s >= 1f; s -= .25f) {
            if (textBytes + 4 * w * h * s * s * 4 <= budget) { artScale = s; break; }
        }
        if (artScale == 0) {
            frames = 1; // ذاكرة قليلة: صورة ثابتة بدون تبديل إطارات
            artScale = 1f;
            if (textBytes + 2 * w * h * 4 > budget) textScale = 1f;
        }

        Calendar cal = Calendar.getInstance();
        cal.setTimeInMillis(now);
        int scene = HeroArt.sceneFor(cal.get(Calendar.HOUR_OF_DAY) + cal.get(Calendar.MINUTE) / 60.0);
        float t0 = (now % 24000L) / 24000f;

        RemoteViews rv = new RemoteViews(ctx.getPackageName(), R.layout.azw_hero);
        Bitmap a0 = WidgetRenderer.heroArt(w, h, artScale, scene, t0);
        rv.setImageViewBitmap(R.id.azw_base, a0);
        if (frames > 1) {
            rv.setViewVisibility(R.id.azw_flip, View.VISIBLE);
            rv.setImageViewBitmap(R.id.azw_f0, a0);
            rv.setImageViewBitmap(R.id.azw_f1, WidgetRenderer.heroArt(w, h, artScale, scene, (t0 + .12f) % 1f));
            rv.setImageViewBitmap(R.id.azw_f2, WidgetRenderer.heroArt(w, h, artScale, scene, (t0 + .24f) % 1f));
        } else {
            rv.setViewVisibility(R.id.azw_flip, View.GONE);
        }
        rv.setImageViewBitmap(R.id.azw_text, WidgetRenderer.heroText(ctx, d, w, h, textScale, now));
        rv.setContentDescription(R.id.azw_root, "أذكار الوقت");
        rv.setOnClickPendingIntent(R.id.azw_root, launchPi(ctx, 71));
        return rv;
    }

    // ---------------------------------------------------------------- ayah
    private static RemoteViews ayah(Context ctx, AppWidgetManager mgr, int id, WidgetData d, long now) {
        float[] sz = size(ctx, mgr, id, 320, 140);
        float scale = Math.min(ctx.getResources().getDisplayMetrics().density, 2.5f);
        RemoteViews rv = new RemoteViews(ctx.getPackageName(), R.layout.azw_single);
        rv.setImageViewBitmap(R.id.azw_img, WidgetRenderer.ayah(ctx, d, sz[0], sz[1], scale, now));
        WidgetData.Ayah a = d.ayahFor(WidgetData.dayKey(now));
        rv.setContentDescription(R.id.azw_root, "آية اليوم" + (a == null ? "" : ": " + a.text + " " + a.ref));
        rv.setOnClickPendingIntent(R.id.azw_root, launchPi(ctx, 72));
        return rv;
    }

    // -------------------------------------------------------------- prayer
    private static RemoteViews prayer(Context ctx, AppWidgetManager mgr, int id, WidgetData d, long now) {
        float[] sz = size(ctx, mgr, id, 320, 150);
        float scale = Math.min(ctx.getResources().getDisplayMetrics().density, 2.5f);
        WidgetRenderer.PrayerView pv = WidgetRenderer.prayer(ctx, d, sz[0], sz[1], scale, now);
        RemoteViews rv = new RemoteViews(ctx.getPackageName(), R.layout.azw_prayer);
        rv.setImageViewBitmap(R.id.azw_img, pv.bitmap);
        if (pv.next != null && Build.VERSION.SDK_INT >= 24) {
            // العدّاد التنازلي يعمل داخل اللانشر نفسه: صفر تنبيهات وصفر استيقاظ للتطبيق.
            long base = SystemClock.elapsedRealtime() + (pv.next.time - now);
            rv.setViewVisibility(R.id.azw_chrono, View.VISIBLE);
            rv.setChronometerCountDown(R.id.azw_chrono, true);
            rv.setChronometer(R.id.azw_chrono, base, "%s", true);
            rv.setTextColor(R.id.azw_chrono, WidgetRenderer.tokens(ctx, d).gold);
        } else {
            rv.setViewVisibility(R.id.azw_chrono, View.GONE);
        }
        rv.setContentDescription(R.id.azw_root, pv.next == null ? "الصلاة القادمة" : "الصلاة القادمة: " + pv.next.name());
        rv.setOnClickPendingIntent(R.id.azw_root, launchPi(ctx, 73));
        return rv;
    }
}
