package com.azkar.azkari_native;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextClock;
import android.widget.TextView;

/**
 * شاشة الأذان الكاملة بخمسة أشكال متحركة (الشكل يأتي من إعدادات التطبيق).
 * إيقاف الأذان: زر «إيقاف الأذان»، أو أي زر صوت، أو زر الرجوع.
 */
public class AdhanActivity extends Activity {
    static final String EXTRA_NAME = "name";
    static final String EXTRA_STYLE = "style";

    private int style = 0;
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
        style = Math.max(0, Math.min(4, getIntent().getIntExtra(EXTRA_STYLE, 0)));
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
        int s = Math.max(0, Math.min(4, intent.getIntExtra(EXTRA_STYLE, style)));
        if (s != style) {
            style = s;
            setContentView(build());
        }
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

    private TextView text(String s, float sp, int color, boolean bold, boolean serif) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(color);
        t.setGravity(Gravity.CENTER);
        t.setTypeface(serif ? Typeface.create("serif", bold ? Typeface.BOLD : Typeface.NORMAL)
                : (bold ? Typeface.create("sans-serif-medium", Typeface.BOLD) : Typeface.DEFAULT));
        t.setLineSpacing(0, 1.3f);
        t.setIncludeFontPadding(false);
        return t;
    }

    private void enter(View v, long delay, float fromScale) {
        v.setAlpha(0f);
        v.setTranslationY(dp(22));
        v.setScaleX(fromScale);
        v.setScaleY(fromScale);
        v.animate().alpha(1f).translationY(0f).scaleX(1f).scaleY(1f)
                .setStartDelay(delay).setDuration(850)
                .setInterpolator(fromScale < 1f ? new OvershootInterpolator(1.1f) : new DecelerateInterpolator(2f))
                .start();
    }

    private View build() {
        final int ink = AdhanArtView.INK[style], accent = AdhanArtView.ACCENT[style];
        FrameLayout root = new FrameLayout(this);
        root.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        root.addView(new AdhanArtView(this, style), new FrameLayout.LayoutParams(-1, -1));

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER_HORIZONTAL);
        FrameLayout.LayoutParams cp = new FrameLayout.LayoutParams(-1, -2, Gravity.TOP);
        cp.topMargin = (int) (getResources().getDisplayMetrics().heightPixels * 0.075f);
        root.addView(col, cp);

        // مساحة الشعار المرسوم داخل AdhanArtView
        col.addView(new View(this), new LinearLayout.LayoutParams(1, dp(AdhanArtView.emblemSizeDp())));

        TextView lead = text("حان الآن وقت صلاة", 17, (ink & 0x00FFFFFF) | 0xCC000000, false, false);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, -2);
        lp.topMargin = dp(30);
        col.addView(lead, lp);
        enter(lead, 250, 1f);

        nameView = text("الصلاة", 56, accent, true, true);
        LinearLayout.LayoutParams np = new LinearLayout.LayoutParams(-2, -2);
        np.topMargin = dp(6);
        col.addView(nameView, np);
        enter(nameView, 450, .82f);

        View line = new View(this);
        GradientDrawable ld = new GradientDrawable();
        ld.setColor((accent & 0x00FFFFFF) | 0xCC000000);
        ld.setCornerRadius(dp(2));
        line.setBackground(ld);
        LinearLayout.LayoutParams lnp = new LinearLayout.LayoutParams(dp(64), dp(2));
        lnp.topMargin = dp(14);
        col.addView(line, lnp);
        line.setAlpha(0f);
        line.setScaleX(0f);
        line.animate().alpha(1f).scaleX(1f).setStartDelay(750).setDuration(700).start();

        TextClock clock = new TextClock(this);
        clock.setFormat12Hour("h:mm a");
        clock.setFormat24Hour("HH:mm");
        clock.setTextSize(18);
        clock.setTextColor(ink);
        clock.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams kp = new LinearLayout.LayoutParams(-2, -2);
        kp.topMargin = dp(14);
        col.addView(clock, kp);
        enter(clock, 850, 1f);

        TextView dua = text("حيَّ على الصلاة · حيَّ على الفلاح\nاللهم اجعل الصلاة قرة عين لنا", 18,
                (ink & 0x00FFFFFF) | 0xE0000000, false, true);
        LinearLayout.LayoutParams dp2 = new LinearLayout.LayoutParams(-2, -2);
        dp2.topMargin = dp(18);
        col.addView(dua, dp2);
        enter(dua, 1000, 1f);

        LinearLayout bottom = new LinearLayout(this);
        bottom.setOrientation(LinearLayout.VERTICAL);
        bottom.setGravity(Gravity.CENTER_HORIZONTAL);
        FrameLayout.LayoutParams bp = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        bp.bottomMargin = dp(44);
        root.addView(bottom, bp);

        TextView btn = text("إيقاف الأذان", 17, AdhanArtView.BTN_INK[style], true, false);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(AdhanArtView.BTN[style]);
        bg.setCornerRadius(dp(30));
        btn.setBackground(bg);
        btn.setPadding(dp(44), dp(16), dp(44), dp(16));
        btn.setOnClickListener(v -> stopAdhan());
        bottom.addView(btn, new LinearLayout.LayoutParams(-2, -2));
        enter(btn, 1200, 1f);
        // نبضة خفيفة تلفت النظر للزر
        btn.animate().setStartDelay(2200).scaleX(1.04f).scaleY(1.04f).setDuration(900)
                .withEndAction(new Runnable() {
                    boolean up = false;

                    @Override
                    public void run() {
                        up = !up;
                        float s = up ? 1f : 1.04f;
                        btn.animate().setStartDelay(0).scaleX(s).scaleY(s).setDuration(1100)
                                .setInterpolator(new android.view.animation.AccelerateDecelerateInterpolator())
                                .withEndAction(this).start();
                    }
                }).start();

        TextView hint = text("أو اضغط أي زر صوت لإيقاف الأذان", 12.5f, ink, false, false);
        hint.setAlpha(0.7f);
        LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(-2, -2);
        hp.topMargin = dp(12);
        bottom.addView(hint, hp);
        return root;
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
        super.onDestroy();
    }
}
