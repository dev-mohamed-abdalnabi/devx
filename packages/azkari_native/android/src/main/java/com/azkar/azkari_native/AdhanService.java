package com.azkar.azkari_native;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.IntentFilter;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.os.SystemClock;

/**
 * خدمة أمامية تشغّل الأذان كاملًا من res/raw/adhan ثم تتوقف.
 * (صوت قناة الإشعار قد يُقطع من النظام أو عند أول تفاعل؛ هذه الخدمة لا تُقطع حتى ينتهي الملف.)
 */
public class AdhanService extends Service {
    private static final String CHANNEL = "adhan_playback_v2";
    private static final int NOTIF_ID = 79000;
    static final String ACTION_STOP = "com.azkar.azkari_native.ADHAN_STOP";
    /** يُبثّ عند انتهاء الأذان/إيقافه ليُغلق شاشة الأذان. */
    static final String ACTION_ENDED = "com.azkar.azkari_native.ADHAN_ENDED";
    static final String EXTRA_DIRECT = "direct";

    private MediaPlayer player;
    private PowerManager.WakeLock wake;
    private AudioManager audio;
    private AudioFocusRequest focusRequest;
    private BroadcastReceiver volumeReceiver;
    private long startedAt;
    private int style = 0;
    private int display = 1;
    private String soundPath = "";

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
        boolean direct = intent != null && intent.getBooleanExtra(EXTRA_DIRECT, false);
        if (intent != null) {
            style = intent.getIntExtra(AdhanScheduler.EXTRA_STYLE, style);
            display = intent.getIntExtra(AdhanScheduler.EXTRA_DISPLAY, display);
            String sp = intent.getStringExtra(AdhanScheduler.EXTRA_SOUND);
            if (sp != null) soundPath = sp;
        }
        startForegroundCompat(name);
        // «فوق كل التطبيقات» (display == 0) أو تجربة من داخل التطبيق: افتح الشاشة الكاملة مباشرة.
        // (يحتاج إذن «العرض فوق التطبيقات»؛ بدونه يبقى إشعار ملء الشاشة فقط.)
        if (direct || display == 0) {
            try {
                startActivity(activityIntent(name).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            } catch (Exception ignored) {
            }
        }
        if (player == null) play();
        return START_NOT_STICKY;
    }

    private Intent activityIntent(String name) {
        Intent i = new Intent(this, AdhanActivity.class);
        i.putExtra(AdhanActivity.EXTRA_NAME, name);
        i.putExtra(AdhanActivity.EXTRA_STYLE, style);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP
                | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return i;
    }

    private void startForegroundCompat(String name) {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26 && nm != null) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, "الأذان", NotificationManager.IMPORTANCE_HIGH);
            ch.setDescription("شاشة وإشعار الأذان عند دخول وقت الصلاة (الصوت من الخدمة نفسها)");
            ch.setSound(null, null);
            ch.enableVibration(false);
            ch.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            nm.createNotificationChannel(ch);
        }
        int flagsImm = Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0;
        Intent stop = new Intent(this, AdhanService.class).setAction(ACTION_STOP);
        PendingIntent stopPi = PendingIntent.getService(this, 2, stop, PendingIntent.FLAG_UPDATE_CURRENT | flagsImm);
        PendingIntent screenPi = PendingIntent.getActivity(this, 3, activityIntent(name),
                PendingIntent.FLAG_UPDATE_CURRENT | flagsImm);

        int icon = getResources().getIdentifier("ic_stat_adhan", "drawable", getPackageName());
        if (icon == 0) icon = getApplicationInfo().icon;

        Notification.Builder b = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(this, CHANNEL)
                : new Notification.Builder(this);
        b.setSmallIcon(icon)
                .setColor(0xFF2F6B3A)
                .setContentTitle("حان وقت صلاة " + name)
                .setContentText("حيَّ على الصلاة، حيَّ على الفلاح")
                .setSubText("ذِكر")
                .setStyle(new Notification.BigTextStyle().bigText("حيَّ على الصلاة، حيَّ على الفلاح"))
                .setContentIntent(screenPi)
                .setFullScreenIntent(screenPi, true)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setWhen(System.currentTimeMillis())
                .setCategory(Notification.CATEGORY_ALARM)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .addAction(new Notification.Action.Builder(icon, "إيقاف الأذان", stopPi).build());
        if (Build.VERSION.SDK_INT < 26) b.setPriority(Notification.PRIORITY_MAX);
        Notification n = b.build();
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(NOTIF_ID, n);
        }
    }

    /** أي ضغطة على زر الصوت (رفع/خفض) أثناء الأذان توقفه فورًا. */
    private void listenForVolumeKeys() {
        volumeReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context c, Intent i) {
                // تجاهل أي تغيير يحدث في أول لحظات التشغيل (من النظام نفسه)
                if (SystemClock.elapsedRealtime() - startedAt < 1200) return;
                stopSelf();
            }
        };
        IntentFilter f = new IntentFilter("android.media.VOLUME_CHANGED_ACTION");
        try {
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(volumeReceiver, f, Context.RECEIVER_EXPORTED);
            else registerReceiver(volumeReceiver, f);
        } catch (Exception ignored) {
            volumeReceiver = null;
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
        // الصوت المحمَّل من التطبيق إن وُجد، وإلا الأذان المدمج.
        if (soundPath != null && !soundPath.isEmpty() && new java.io.File(soundPath).exists()) {
            try {
                MediaPlayer mp = new MediaPlayer();
                mp.setAudioAttributes(attrs);
                mp.setDataSource(soundPath);
                mp.prepare();
                player = mp;
            } catch (Exception e) {
                player = null;
            }
        }
        if (player == null) {
            int id = getResources().getIdentifier("adhan", "raw", getPackageName());
            if (id == 0) {
                stopSelf();
                return;
            }
            int session = audio != null ? audio.generateAudioSessionId() : 0;
            player = MediaPlayer.create(this, id, attrs, session);
        }
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
        startedAt = SystemClock.elapsedRealtime();
        listenForVolumeKeys();
    }

    @Override
    public void onDestroy() {
        try {
            if (volumeReceiver != null) unregisterReceiver(volumeReceiver);
        } catch (Exception ignored) {
        }
        try {
            sendBroadcast(new Intent(ACTION_ENDED).setPackage(getPackageName()));
        } catch (Exception ignored) {
        }
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
