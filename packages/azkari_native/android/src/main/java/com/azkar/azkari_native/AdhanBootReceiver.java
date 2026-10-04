package com.azkar.azkari_native;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** بعد إعادة التشغيل أو تحديث التطبيق: يعيد جدولة الأذان المحفوظ. */
public class AdhanBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        AdhanScheduler.rescheduleFromStorage(context);
    }
}
