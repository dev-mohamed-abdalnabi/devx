package com.azkar.azkari_native;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** يستقبل منبّه التحديث التالي + إقلاع الجهاز + تغيّر الوقت/المنطقة/تحديث التطبيق. */
public class WidgetTickReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        WidgetUpdater.updateAsync(context, goAsync());
    }
}
