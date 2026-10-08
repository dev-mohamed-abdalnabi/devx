package com.azkar.azkari_native;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** يستقبل المنبّه عند دخول الوقت ويبدأ خدمة الأذان (تشغيل كامل). */
public class AdhanReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        Intent svc = new Intent(context, AdhanService.class);
        svc.putExtra(AdhanScheduler.EXTRA_NAME, intent.getStringExtra(AdhanScheduler.EXTRA_NAME));
        svc.putExtra(AdhanScheduler.EXTRA_STYLE, intent.getIntExtra(AdhanScheduler.EXTRA_STYLE, 0));
        svc.putExtra(AdhanScheduler.EXTRA_DISPLAY, intent.getIntExtra(AdhanScheduler.EXTRA_DISPLAY, 1));
        svc.putExtra(AdhanScheduler.EXTRA_SOUND, intent.getStringExtra(AdhanScheduler.EXTRA_SOUND));
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(svc);
            else context.startService(svc);
        } catch (Exception ignored) {
        }
    }
}
