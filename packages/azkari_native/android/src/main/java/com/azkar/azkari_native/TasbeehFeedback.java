package com.azkar.azkari_native;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioTrack;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;

/**
 * اهتزاز وصوت المسبحة مباشرة من النظام (بدون الاعتماد على إعدادات «ردود اللمس»).
 * الصوت نقرة قصيرة تُولَّد برمجيًا (لا ملفات) وتُشغَّل بدون طلب تركيز صوتي،
 * فلا توقف تلاوة أو أي صوت آخر شغّال.
 */
final class TasbeehFeedback {
    private static final int RATE = 22050;
    private static AudioTrack tick;
    private static AudioTrack done;

    private TasbeehFeedback() {}

    private static Vibrator vib(Context c) {
        try {
            if (Build.VERSION.SDK_INT >= 31) {
                VibratorManager vm = (VibratorManager) c.getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
                return vm == null ? null : vm.getDefaultVibrator();
            }
            return (Vibrator) c.getSystemService(Context.VIBRATOR_SERVICE);
        } catch (Throwable t) {
            return null;
        }
    }

    /** اهتزاز: ms قصير للعدّة، وطويل بنمط مزدوج عند إتمام الهدف. */
    static void vibrate(Context c, boolean goal) {
        try {
            Vibrator v = vib(c);
            if (v == null || !v.hasVibrator()) return;
            if (Build.VERSION.SDK_INT >= 26) {
                VibrationEffect e = goal
                        ? VibrationEffect.createWaveform(new long[]{0, 70, 60, 70, 60, 160}, -1)
                        : VibrationEffect.createOneShot(28, 180);
                v.vibrate(e);
            } else {
                if (goal) v.vibrate(new long[]{0, 70, 60, 70, 60, 160}, -1);
                else v.vibrate(28);
            }
        } catch (Throwable ignored) {
        }
    }

    private static AudioTrack build(short[] pcm) {
        AudioTrack t;
        if (Build.VERSION.SDK_INT >= 23) {
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();
            AudioFormat fmt = new AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build();
            t = new AudioTrack(attrs, fmt, pcm.length * 2, AudioTrack.MODE_STATIC,
                    android.media.AudioManager.AUDIO_SESSION_ID_GENERATE);
        } else {
            t = new AudioTrack(android.media.AudioManager.STREAM_MUSIC, RATE,
                    AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    pcm.length * 2, AudioTrack.MODE_STATIC);
        }
        t.write(pcm, 0, pcm.length);
        return t;
    }

    /** نغمة جيبية متلاشية: freq بالهرتز، ms مدة، amp 0..1. */
    private static short[] tone(double f1, double f2, int ms, double amp) {
        int n = RATE * ms / 1000;
        short[] out = new short[n];
        for (int i = 0; i < n; i++) {
            double t = i / (double) RATE;
            double env = Math.exp(-6.0 * i / n);
            double s = Math.sin(2 * Math.PI * f1 * t) * 0.7 + Math.sin(2 * Math.PI * f2 * t) * 0.3;
            double fadeIn = Math.min(1.0, i / 60.0); // يمنع طقطقة البداية
            out[i] = (short) (s * env * fadeIn * amp * 32767);
        }
        return out;
    }

    private static void play(AudioTrack t) {
        try {
            t.stop();
            t.reloadStaticData();
            t.play();
        } catch (Throwable ignored) {
        }
    }

    static synchronized void tick(boolean goal) {
        try {
            if (tick == null) tick = build(tone(1500, 2250, 55, 0.55));
            if (done == null) {
                short[] a = tone(880, 1320, 140, 0.6);
                short[] b = tone(1175, 1760, 220, 0.6);
                short[] m = new short[a.length + b.length];
                System.arraycopy(a, 0, m, 0, a.length);
                System.arraycopy(b, 0, m, a.length, b.length);
                done = build(m);
            }
            play(goal ? done : tick);
        } catch (Throwable ignored) {
        }
    }
}
