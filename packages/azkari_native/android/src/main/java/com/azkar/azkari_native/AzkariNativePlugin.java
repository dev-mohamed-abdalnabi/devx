package com.azkar.azkari_native;

import android.app.Activity;
import android.app.NotificationManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.PowerManager;
import android.service.notification.StatusBarNotification;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * حزمة موارد (أذان + أيقونة + مانيفست) مع أداة تشخيص واحدة: diagnose.
 * لا تغيّر أي سلوك وقت التشغيل؛ تقرأ الحالة فقط.
 */
public class AzkariNativePlugin implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private static final String CHANNEL = "azkari_native";
    private static final String AUDIO_SERVICE = "com.ryanheise.audioservice.AudioService";
    private static final String MEDIA_BUTTON_RECEIVER = "com.ryanheise.audioservice.MediaButtonReceiver";

    private MethodChannel channel;
    private Context context;
    private Activity activity;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (channel != null) channel.setMethodCallHandler(null);
        channel = null;
        context = null;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if ("diagnose".equals(call.method)) {
            try {
                result.success(diagnose());
            } catch (Exception e) {
                result.error("diagnose_failed", String.valueOf(e), null);
            }
        } else if ("scheduleAdhan".equals(call.method)) {
            try {
                java.util.List<java.util.Map<String, Object>> list = call.argument("entries");
                org.json.JSONArray arr = new org.json.JSONArray();
                if (list != null) {
                    for (java.util.Map<String, Object> m : list) {
                        org.json.JSONObject o = new org.json.JSONObject();
                        o.put("id", ((Number) m.get("id")).intValue());
                        o.put("time", ((Number) m.get("time")).longValue());
                        o.put("name", String.valueOf(m.get("name")));
                        arr.put(o);
                    }
                }
                AdhanScheduler.scheduleAll(context, arr);
                result.success(true);
            } catch (Exception e) {
                result.error("schedule_failed", String.valueOf(e), null);
            }
        } else if ("cancelAdhan".equals(call.method)) {
            AdhanScheduler.cancelAll(context);
            result.success(true);
        } else if ("stopAdhan".equals(call.method)) {
            context.stopService(new android.content.Intent(context, AdhanService.class));
            result.success(true);
        } else if ("setKeepAwake".equals(call.method)) {
            Boolean on = call.argument("on");
            setKeepAwake(on != null && on);
            result.success(true);
        } else if ("requestIgnoreBatteryOptimizations".equals(call.method)) {
            result.success(requestIgnoreBattery());
        } else {
            result.notImplemented();
        }
    }

    private PowerManager.WakeLock keepAwake;

    /** قفل CPU جزئي أثناء تشغيل التلاوة فقط، حتى لا ينام الجهاز ويقطع الصوت. */
    private void setKeepAwake(boolean on) {
        try {
            if (on) {
                if (keepAwake == null) {
                    PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
                    if (pm == null) return;
                    keepAwake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "azkari:quran");
                    keepAwake.setReferenceCounted(false);
                }
                keepAwake.acquire(6 * 60 * 60 * 1000L);
            } else if (keepAwake != null && keepAwake.isHeld()) {
                keepAwake.release();
            }
        } catch (Exception ignored) {
        }
    }

    /** يعيد true لو التطبيق مستثنى بالفعل؛ وإلا يفتح نافذة النظام لطلب الاستثناء ويعيد false. */
    private boolean requestIgnoreBattery() {
        try {
            if (Build.VERSION.SDK_INT < 23) return true;
            String pkg = context.getPackageName();
            PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (pm != null && pm.isIgnoringBatteryOptimizations(pkg)) return true;
            android.content.Intent i;
            try {
                i = new android.content.Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        android.net.Uri.parse("package:" + pkg));
                i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(i);
            } catch (Exception e) {
                i = new android.content.Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(i);
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    private Map<String, Object> diagnose() {
        Map<String, Object> out = new HashMap<>();
        Context ctx = context;
        if (ctx == null) {
            out.put("error", "no context");
            return out;
        }
        String pkg = ctx.getPackageName();
        PackageManager pm = ctx.getPackageManager();

        out.put("package", pkg);
        out.put("sdkInt", Build.VERSION.SDK_INT);
        out.put("targetSdk", ctx.getApplicationInfo().targetSdkVersion);

        // 1) هل MainActivity هي AudioServiceActivity؟
        if (activity != null) {
            out.put("activityClass", activity.getClass().getName());
            boolean ok = false;
            for (Class<?> c = activity.getClass(); c != null; c = c.getSuperclass()) {
                String n = c.getName();
                if (n.equals("com.ryanheise.audioservice.AudioServiceActivity")
                        || n.equals("com.ryanheise.audioservice.AudioServiceFragmentActivity")) {
                    ok = true;
                    break;
                }
            }
            out.put("activityIsAudioService", ok);
        } else {
            out.put("activityClass", "");
            out.put("activityIsAudioService", null);
        }

        // 2) خدمة الميديا ومستقبل أزرار الميديا في المانيفست النهائي
        try {
            ServiceInfo si = pm.getServiceInfo(new ComponentName(pkg, AUDIO_SERVICE), 0);
            out.put("audioServiceDeclared", true);
            if (Build.VERSION.SDK_INT >= 29) {
                out.put("audioServiceMediaType",
                        (si.getForegroundServiceType() & ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK) != 0);
            }
        } catch (PackageManager.NameNotFoundException e) {
            out.put("audioServiceDeclared", false);
        }
        try {
            pm.getReceiverInfo(new ComponentName(pkg, MEDIA_BUTTON_RECEIVER), 0);
            out.put("mediaButtonReceiverDeclared", true);
        } catch (PackageManager.NameNotFoundException e) {
            out.put("mediaButtonReceiverDeclared", false);
        }

        // 3) الموارد داخل الـ APK
        out.put("statIconId", ctx.getResources().getIdentifier("ic_stat_blank", "drawable", pkg));
        out.put("launcherIconId", ctx.getResources().getIdentifier("ic_launcher", "mipmap", pkg));
        out.put("adhanRawId", ctx.getResources().getIdentifier("adhan", "raw", pkg));
        String[] mediaIcons = {"ic_media_play", "ic_media_pause", "ic_media_next", "ic_media_previous",
                "audio_service_play", "audio_service_pause", "audio_service_skip_next"};
        for (String n : mediaIcons) {
            out.put("icon." + n, ctx.getResources().getIdentifier(n, "drawable", pkg));
        }

        // 4) إذن خدمة تشغيل الميديا (أندرويد 14+)
        if (Build.VERSION.SDK_INT >= 34) {
            out.put("fgsMediaPermission",
                    pm.checkPermission("android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK", pkg)
                            == PackageManager.PERMISSION_GRANTED);
        } else {
            out.put("fgsMediaPermission", true);
        }

        // 5) الإشعارات الظاهرة الآن (صيغة: المعرّف|القناة)
        try {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null) {
                if (Build.VERSION.SDK_INT >= 24) {
                    out.put("notificationsEnabled", nm.areNotificationsEnabled());
                }
                List<String> active = new ArrayList<>();
                if (Build.VERSION.SDK_INT >= 23) {
                    StatusBarNotification[] list = nm.getActiveNotifications();
                    for (StatusBarNotification sbn : list) {
                        String channelId = "";
                        if (Build.VERSION.SDK_INT >= 26 && sbn.getNotification() != null) {
                            String id = sbn.getNotification().getChannelId();
                            if (id != null) channelId = id;
                        }
                        active.add(sbn.getId() + "|" + channelId);
                    }
                }
                out.put("activeNotifications", active);
            }
        } catch (Exception e) {
            out.put("activeNotificationsError", String.valueOf(e));
        }

        // 6) قيود البطارية (بعض الأجهزة تقتل خدمة الميديا في الخلفية)
        try {
            if (Build.VERSION.SDK_INT >= 23) {
                PowerManager power = (PowerManager) ctx.getSystemService(Context.POWER_SERVICE);
                if (power != null) {
                    out.put("ignoringBatteryOptimizations", power.isIgnoringBatteryOptimizations(pkg));
                }
            }
        } catch (Exception ignored) {
        }

        return out;
    }
}
