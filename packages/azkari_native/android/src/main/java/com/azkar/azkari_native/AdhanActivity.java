package com.azkar.azkari_native;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.AssetFileDescriptor;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.SurfaceTexture;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextClock;
import android.widget.TextView;

/**
 * شاشة الأذان الكاملة: تظهر فوق شاشة القفل وتُشغّل الشاشة، وفيها فيديو هادئ يعمل مع صوت الأذان.
 * إيقاف الأذان: زر «إيقاف الأذان»، أو أي زر صوت، أو زر الرجوع.
 */
public class AdhanActivity extends Activity {
    static final String EXTRA_NAME = "name";

    private static final int CREAM = 0xFFF1EEE2;
    private static final int MUTED = 0xFFB9BFAE;
    private static final int GOLD = 0xFFD4AE5A;
    private static final int INK = 0xFF141913;

    private TextureView texture;
    private MediaPlayer video;
    private TextView nameView;
    private final BroadcastReceiver ended = new BroadcastReceiver() {
        @Override
        public void onReceive(Context c, Intent i) {
            finish();
        }
    };

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD);
        }
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(build());
        applyName(getIntent());
        IntentFilter f = new IntentFilter(AdhanService.ACTION_ENDED);
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(ended, f, Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(ended, f);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        applyName(intent);
    }

    private void applyName(Intent i) {
        String n = i == null ? null : i.getStringExtra(EXTRA_NAME);
        if (n == null || n.isEmpty()) n = "الصلاة";
        if (nameView != null) nameView.setText(n);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        }
    }

    private int dp(float v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }

    private TextView text(String s, float sp, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(color);
        t.setGravity(Gravity.CENTER);
        t.setTypeface(bold ? Typeface.create("sans-serif-medium", Typeface.BOLD) : Typeface.DEFAULT);
        t.setLineSpacing(0, 1.25f);
        t.setIncludeFontPadding(false);
        return t;
    }

    private View build() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(INK);
        root.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        texture = new TextureView(this);
        texture.setSurfaceTextureListener(new TextureView.SurfaceTextureListener() {
            @Override
            public void onSurfaceTextureAvailable(SurfaceTexture st, int w, int h) {
                startVideo(st);
            }

            @Override
            public void onSurfaceTextureSizeChanged(SurfaceTexture st, int w, int h) {
                if (video != null) fit(video.getVideoWidth(), video.getVideoHeight());
            }

            @Override
            public boolean onSurfaceTextureDestroyed(SurfaceTexture st) {
                releaseVideo();
                return true;
            }

            @Override
            public void onSurfaceTextureUpdated(SurfaceTexture st) {
            }
        });
        root.addView(texture, new FrameLayout.LayoutParams(-1, -1));

        // تعتيم خفيف أعلى الشاشة لثبات قراءة النص فوق الفيديو
        View scrim = new View(this);
        GradientDrawable g = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0x66141913, 0x33141913, 0x00141913});
        scrim.setBackground(g);
        root.addView(scrim, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER_HORIZONTAL);
        FrameLayout.LayoutParams cp = new FrameLayout.LayoutParams(-1, -2, Gravity.TOP);
        cp.topMargin = (int) (getResources().getDisplayMetrics().heightPixels * 0.075f);
        root.addView(col, cp);

        ImageView logo = new ImageView(this);
        logo.setImageResource(getResources().getIdentifier("adhan_logo", "drawable", getPackageName()));
        logo.setAdjustViewBounds(true);
        logo.setAlpha(0.92f);
        col.addView(logo, new LinearLayout.LayoutParams(dp(92), ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView lead = text("حان الآن وقت صلاة", 17, MUTED, false);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, -2);
        lp.topMargin = dp(34);
        col.addView(lead, lp);

        nameView = text("الصلاة", 52, GOLD, true);
        LinearLayout.LayoutParams np = new LinearLayout.LayoutParams(-2, -2);
        np.topMargin = dp(8);
        col.addView(nameView, np);

        TextClock clock = new TextClock(this);
        clock.setFormat12Hour("h:mm a");
        clock.setFormat24Hour("HH:mm");
        clock.setTextSize(16);
        clock.setTextColor(CREAM);
        clock.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams kp = new LinearLayout.LayoutParams(-2, -2);
        kp.topMargin = dp(10);
        col.addView(clock, kp);

        TextView dua = text("حيَّ على الصلاة · حيَّ على الفلاح", 16, CREAM, false);
        LinearLayout.LayoutParams dp2 = new LinearLayout.LayoutParams(-2, -2);
        dp2.topMargin = dp(22);
        col.addView(dua, dp2);

        LinearLayout bottom = new LinearLayout(this);
        bottom.setOrientation(LinearLayout.VERTICAL);
        bottom.setGravity(Gravity.CENTER_HORIZONTAL);
        FrameLayout.LayoutParams bp = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        bp.bottomMargin = dp(40);
        root.addView(bottom, bp);

        TextView btn = text("إيقاف الأذان", 17, INK, true);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(GOLD);
        bg.setCornerRadius(dp(28));
        btn.setBackground(bg);
        btn.setPadding(dp(40), dp(15), dp(40), dp(15));
        btn.setOnClickListener(v -> stopAdhan());
        bottom.addView(btn, new LinearLayout.LayoutParams(-2, -2));

        TextView hint = text("أو اضغط أي زر صوت لإيقاف الأذان", 12.5f, CREAM, false);
        hint.setAlpha(0.8f);
        LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(-2, -2);
        hp.topMargin = dp(12);
        bottom.addView(hint, hp);
        return root;
    }

    private void startVideo(SurfaceTexture st) {
        try {
            int id = getResources().getIdentifier("adhan_bg", "raw", getPackageName());
            if (id == 0) return;
            releaseVideo();
            video = new MediaPlayer();
            AssetFileDescriptor fd = getResources().openRawResourceFd(id);
            video.setDataSource(fd.getFileDescriptor(), fd.getStartOffset(), fd.getLength());
            fd.close();
            video.setSurface(new Surface(st));
            video.setLooping(true);
            video.setVolume(0f, 0f);
            video.setOnVideoSizeChangedListener((mp, w, h) -> fit(w, h));
            video.setOnPreparedListener(mp -> {
                fit(mp.getVideoWidth(), mp.getVideoHeight());
                mp.start();
            });
            video.prepareAsync();
        } catch (Exception ignored) {
        }
    }

    /** يملأ الشاشة بالفيديو (center-crop) بدل التمطيط. */
    private void fit(int vw, int vh) {
        if (texture == null || vw <= 0 || vh <= 0) return;
        float w = texture.getWidth(), h = texture.getHeight();
        if (w == 0 || h == 0) return;
        float s = Math.max(w / vw, h / vh);
        Matrix m = new Matrix();
        m.setScale(vw * s / w, vh * s / h, w / 2f, h / 2f);
        texture.setTransform(m);
    }

    private void releaseVideo() {
        try {
            if (video != null) {
                video.release();
                video = null;
            }
        } catch (Exception ignored) {
        }
    }

    private void stopAdhan() {
        try {
            startService(new Intent(this, AdhanService.class).setAction(AdhanService.ACTION_STOP));
        } catch (Exception ignored) {
        }
        finish();
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
                || keyCode == KeyEvent.KEYCODE_VOLUME_MUTE || keyCode == KeyEvent.KEYCODE_BACK) {
            stopAdhan();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onDestroy() {
        try {
            unregisterReceiver(ended);
        } catch (Exception ignored) {
        }
        releaseVideo();
        super.onDestroy();
    }
}
