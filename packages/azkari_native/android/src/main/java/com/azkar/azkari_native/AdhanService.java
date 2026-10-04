package com.azkar.azkari_native;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

/**
 * خدمة أمامية تشغّل الأذان كاملًا من res/raw/adhan ثم تتوقف.
 * (صوت قناة الإشعار قد يُقطع من النظام أو عند أول تفاعل؛ هذه الخدمة لا تُقطع حتى ينتهي الملف.)
 */
public class AdhanService extends Service {
    private static final String CHANNEL = "adhan_playback_v1";
    private static final int NOTIF_ID = 79000;
    static final String ACTION_STOP = "com.azkar.azkari_native.ADHAN_STOP";

    private MediaPlayer player;
    private PowerManager.WakeLock wake;
    private AudioManager audio;
    private AudioFocusRequest focusRequest;

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            stopSelf();
            return START_NOT_STICKY;
        }
        String name = intent == null ? null : intent.getStringExtra(AdhanScheduler.EXTRA_NAME);
        if (name == null || name.isEmpty()) name = "الصلاة";
        startForegroundCompat(name);
        if (player == null) play();
        return START_NOT_STICKY;
    }

    private void startForegroundCompat(String name) {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26 && nm != null) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, "الأذان", NotificationManager.IMPORTANCE_LOW);
            ch.setDescription("تشغيل الأذان عند دخول وقت الصلاة");
            ch.setSound(null, null);
            nm.createNotificationChannel(ch);
        }
        int flagsImm = Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0;
        Intent stop = new Intent(this, AdhanService.class).setAction(ACTION_STOP);
        PendingIntent stopPi = PendingIntent.getService(this, 2, stop, PendingIntent.FLAG_UPDATE_CURRENT | flagsImm);
        Intent open = getPackageManager().getLaunchIntentForPackage(getPackageName());
        PendingIntent openPi = PendingIntent.getActivity(this, 3, open, PendingIntent.FLAG_UPDATE_CURRENT | flagsImm);

        int icon = getResources().getIdentifier("ic_stat_blank", "drawable", getPackageName());
        if (icon == 0) icon = getApplicationInfo().icon;

        Notification.Builder b = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(this, CHANNEL)
                : new Notification.Builder(this);
        b.setSmallIcon(icon)
                .setContentTitle("أذان " + name)
                .setContentText("حان الآن وقت صلاة " + name)
                .setContentIntent(openPi)
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_ALARM)
                .addAction(new Notification.Action.Builder(icon, "إيقاف", stopPi).build());
        Notification n = b.build();
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(NOTIF_ID, n);
        }
    }

    private void play() {
        try {
            PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
            if (pm != null) {
                wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "azkari:adhan");
                wake.acquire(15 * 60 * 1000L);
            }
        } catch (Exception ignored) {
        }
        audio = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        AudioAttributes attrs = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build();
        try {
            if (audio != null) {
                if (Build.VERSION.SDK_INT >= 26) {
                    focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                            .setAudioAttributes(attrs).build();
                    audio.requestAudioFocus(focusRequest);
                } else {
                    audio.requestAudioFocus(null, AudioManager.STREAM_ALARM,
                            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE);
                }
            }
        } catch (Exception ignored) {
        }
        int id = getResources().getIdentifier("adhan", "raw", getPackageName());
        if (id == 0) {
            stopSelf();
            return;
        }
        int session = audio != null ? audio.generateAudioSessionId() : 0;
        player = MediaPlayer.create(this, id, attrs, session);
        if (player == null) {
            stopSelf();
            return;
        }
        player.setOnCompletionListener(mp -> stopSelf());
        player.setOnErrorListener((mp, what, extra) -> {
            stopSelf();
            return true;
        });
        player.start();
    }

    @Override
    public void onDestroy() {
        try {
            if (player != null) {
                player.release();
                player = null;
            }
        } catch (Exception ignored) {
        }
        try {
            if (audio != null) {
                if (Build.VERSION.SDK_INT >= 26 && focusRequest != null) audio.abandonAudioFocusRequest(focusRequest);
                else audio.abandonAudioFocus(null);
            }
        } catch (Exception ignored) {
        }
        try {
            if (wake != null && wake.isHeld()) wake.release();
        } catch (Exception ignored) {
        }
        stopForeground(true);
        super.onDestroy();
    }
}
