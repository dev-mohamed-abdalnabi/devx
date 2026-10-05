package com.azkar.azkari_native;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.os.Bundle;

/** أساس مزوّدي الودجتس الثلاثة. التحديث كله في WidgetUpdater. */
abstract class AzwProvider extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager mgr, int[] ids) {
        WidgetUpdater.updateAsync(context, goAsync());
    }

    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager mgr, int id, Bundle newOptions) {
        WidgetUpdater.updateAsync(context, goAsync());
    }

    @Override
    public void onEnabled(Context context) {
        WidgetUpdater.updateAsync(context, goAsync());
    }

    @Override
    public void onDeleted(Context context, int[] ids) {
        WidgetScheduler.cancelIfNone(context);
    }

    @Override
    public void onDisabled(Context context) {
        WidgetScheduler.cancelIfNone(context);
    }
}
