package com.azkar.azkari_native;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextClock;
import android.widget.TextView;

/**
 * شاشة الأذان الكاملة بخمسة أشكال متحركة (الشكل من إعدادات التطبيق) وفي كلٍّ منها شعار «ذِكر».
 * تعرض كلمات الأذان مكتوبةً ومتزامنة مع الصوت، وتنتهي بالدعاء المأثور بعد الأذان.
 * إيقاف الأذان: زر «إيقاف الأذان»، أو أي زر صوت، أو زر الرجوع.
 */
public class AdhanActivity extends Activity {
    static final String EXTRA_NAME = "name";
    static final String EXTRA_STYLE = "style";

    private static final int TICK_MS = 100;

    private int style = 0;
    private TextView nameView, label, prevView, curView, nextView;
    private FrameLayout trackFill;
    private View[] dots;
    private int shownIndex = -2;
    private boolean shownDone = false, shownStarted = false;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            syncLyrics();
            handler.postDelayed(this, TICK_MS);
        }
    };
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
    protected void onResume() {
        super.onResume();
        handler.post(tick);
    }

    @Override
    protected void onPause() {
        handler.removeCallbacks(tick);
        super.onPause();
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

    private static int withAlpha(int color, float a) {
        return (color & 0x00FFFFFF) | (Math.round(a * 255) << 24);
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
        shownIndex = -2;
        shownDone = false;
        shownStarted = false;

        FrameLayout root = new FrameLayout(this);
        root.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        root.addView(new AdhanArtView(this, style), new FrameLayout.LayoutParams(-1, -1));

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER_HORIZONTAL);
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));

        // مساحة الشعار (يرسمه AdhanArtView في نفس الموضع)
        col.addView(new View(this), new LinearLayout.LayoutParams(1,
                AdhanArtView.topPx(this) + AdhanArtView.emblemPx(this)));

        TextView lead = text("حان الآن وقت صلاة", 15, withAlpha(ink, .8f), false, false);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, -2);
        lp.topMargin = dp(16);
        col.addView(lead, lp);
        enter(lead, 250, 1f);

        nameView = text("الصلاة", 46, accent, true, true);
        LinearLayout.LayoutParams np = new LinearLayout.LayoutParams(-2, -2);
        np.topMargin = dp(4);
        col.addView(nameView, np);
        enter(nameView, 450, .82f);

        LinearLayout meta = new LinearLayout(this);
        meta.setOrientation(LinearLayout.HORIZONTAL);
        meta.setGravity(Gravity.CENTER_VERTICAL);
        View line = new View(this);
        GradientDrawable ld = new GradientDrawable();
        ld.setColor(withAlpha(accent, .8f));
        ld.setCornerRadius(dp(2));
        line.setBackground(ld);
        meta.addView(line, new LinearLayout.LayoutParams(dp(28), dp(2)));
        TextClock clock = new TextClock(this);
        clock.setFormat12Hour("h:mm a");
        clock.setFormat24Hour("HH:mm");
        clock.setTextSize(16);
        clock.setTextColor(ink);
        LinearLayout.LayoutParams ckp = new LinearLayout.LayoutParams(-2, -2);
        ckp.leftMargin = dp(12);
        ckp.rightMargin = dp(12);
        meta.addView(clock, ckp);
        View line2 = new View(this);
        line2.setBackground(ld.getConstantState().newDrawable());
        meta.addView(line2, new LinearLayout.LayoutParams(dp(28), dp(2)));
        LinearLayout.LayoutParams mp = new LinearLayout.LayoutParams(-2, -2);
        mp.topMargin = dp(10);
        col.addView(meta, mp);
        enter(meta, 750, 1f);

        // ───── بطاقة كلمات الأذان ─────
        FrameLayout slot = new FrameLayout(this);
        col.addView(slot, new LinearLayout.LayoutParams(-1, 0, 1f));

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER_HORIZONTAL);
        card.setPadding(dp(18), dp(16), dp(18), dp(16));
        GradientDrawable cbg = new GradientDrawable();
        cbg.setColor(withAlpha(ink, style == 4 ? .06f : .09f));
        cbg.setCornerRadius(dp(26));
        cbg.setStroke(dp(1), withAlpha(accent, .45f));
        card.setBackground(cbg);
        FrameLayout.LayoutParams cardP = new FrameLayout.LayoutParams(-1, -2, Gravity.CENTER);
        cardP.leftMargin = dp(22);
        cardP.rightMargin = dp(22);
        slot.addView(card, cardP);
        enter(card, 950, 1f);

        label = text("ردِّد مع المؤذن", 12.5f, accent, true, false);
        card.addView(label, new LinearLayout.LayoutParams(-2, -2));

        prevView = text("", 14, withAlpha(ink, .38f), false, true);
        prevView.setMinHeight(dp(20));
        LinearLayout.LayoutParams pvp = new LinearLayout.LayoutParams(-1, -2);
        pvp.topMargin = dp(10);
        card.addView(prevView, pvp);

        curView = text("", 27, ink, true, true);
        curView.setMinHeight(dp(74));
        curView.setLineSpacing(0, 1.35f);
        LinearLayout.LayoutParams cvp = new LinearLayout.LayoutParams(-1, -2);
        cvp.topMargin = dp(4);
        card.addView(curView, cvp);

        nextView = text("", 14, withAlpha(ink, .38f), false, true);
        nextView.setMinHeight(dp(20));
        LinearLayout.LayoutParams nvp = new LinearLayout.LayoutParams(-1, -2);
        nvp.topMargin = dp(4);
        card.addView(nextView, nvp);

        // شريط تقدّم العبارة الحالية
        FrameLayout track = new FrameLayout(this);
        GradientDrawable tb = new GradientDrawable();
        tb.setColor(withAlpha(ink, .15f));
        tb.setCornerRadius(dp(3));
        track.setBackground(tb);
        trackFill = new FrameLayout(this);
        GradientDrawable fb = new GradientDrawable();
        fb.setColor(accent);
        fb.setCornerRadius(dp(3));
        trackFill.setBackground(fb);
        trackFill.setScaleX(0f);
        track.addView(trackFill, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout.LayoutParams trp = new LinearLayout.LayoutParams(-1, dp(3));
        trp.topMargin = dp(14);
        card.addView(track, trp);
        track.addOnLayoutChangeListener((v, l, t, r, bt, ol, ot, or, ob) -> trackFill.setPivotX(r - l));

        // نقاط الترتيب (12 عبارة)
        LinearLayout dotRow = new LinearLayout(this);
        dotRow.setOrientation(LinearLayout.HORIZONTAL);
        dotRow.setGravity(Gravity.CENTER);
        dots = new View[AdhanLyrics.LINES.length];
        for (int i = 0; i < dots.length; i++) {
            View d = new View(this);
            LinearLayout.LayoutParams dpm = new LinearLayout.LayoutParams(dp(6), dp(6));
            dpm.leftMargin = dp(3);
            dpm.rightMargin = dp(3);
            dotRow.addView(d, dpm);
            dots[i] = d;
        }
        LinearLayout.LayoutParams drp = new LinearLayout.LayoutParams(-2, -2);
        drp.topMargin = dp(12);
        card.addView(dotRow, drp);
        paintDots(-1, false);
        showLine(0, true, false);

        // ───── الزر ─────
        LinearLayout bottom = new LinearLayout(this);
        bottom.setOrientation(LinearLayout.VERTICAL);
        bottom.setGravity(Gravity.CENTER_HORIZONTAL);
        LinearLayout.LayoutParams bp = new LinearLayout.LayoutParams(-1, -2);
        bp.bottomMargin = dp(36);
        bp.topMargin = dp(8);
        col.addView(bottom, bp);

        TextView btn = text("إيقاف الأذان", 16, AdhanArtView.BTN_INK[style], true, false);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(AdhanArtView.BTN[style]);
        bg.setCornerRadius(dp(30));
        btn.setBackground(bg);
        btn.setPadding(dp(44), dp(14), dp(44), dp(14));
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
                                .setInterpolator(new AccelerateDecelerateInterpolator())
                                .withEndAction(this).start();
                    }
                }).start();

        TextView hint = text("أو اضغط أي زر صوت لإيقاف الأذان", 12, ink, false, false);
        hint.setAlpha(0.65f);
        LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(-2, -2);
        hp.topMargin = dp(10);
        bottom.addView(hint, hp);
        return root;
    }

    // ───────── مزامنة الكلمات مع الصوت ─────────

    private void syncLyrics() {
        if (curView == null) return;
        MediaPlayer mp = AdhanService.current;
        if (mp == null) return; // لم يبدأ التشغيل بعد، أو انتهى (وسيُغلق الـActivity)
        int pos, dur;
        try {
            pos = mp.getCurrentPosition();
            dur = mp.getDuration();
        } catch (Exception e) {
            return;
        }
        AdhanLyrics.State st = AdhanLyrics.at(pos, dur, AdhanService.currentBundled);
        if (st.done) {
            if (!shownDone) {
                shownDone = true;
                shownStarted = true;
                shownIndex = AdhanLyrics.LINES.length;
                paintDots(AdhanLyrics.LINES.length, true);
                showAfter();
            }
            return;
        }
        if (!st.started) {
            if (shownStarted) return;
            label.setText("يبدأ الأذان بعد لحظات");
            return;
        }
        if (!shownStarted || st.index != shownIndex) {
            shownStarted = true;
            shownIndex = st.index;
            showLine(st.index, false, true);
            paintDots(st.index, false);
        }
        trackFill.setScaleX(st.progress);
    }

    private void showLine(int i, boolean first, boolean animate) {
        final String cur = AdhanLyrics.LINES[i];
        final String prev = i > 0 ? AdhanLyrics.LINES[i - 1] : "";
        final String next = i + 1 < AdhanLyrics.LINES.length ? AdhanLyrics.LINES[i + 1] : "";
        final Runnable apply = () -> {
            curView.setTextSize(27);
            curView.setText(cur);
            prevView.setText(prev);
            nextView.setText(next);
            label.setText(first ? "ردِّد مع المؤذن" : "ردِّد مع المؤذن · " + (i + 1) + " / " + AdhanLyrics.LINES.length);
            trackFill.setScaleX(0f);
        };
        if (!animate) {
            apply.run();
            curView.setAlpha(first ? .6f : 1f);
            return;
        }
        curView.animate().alpha(0f).translationY(dp(-6)).setDuration(140).withEndAction(() -> {
            apply.run();
            curView.setTranslationY(dp(8));
            curView.animate().alpha(1f).translationY(0f).setDuration(260)
                    .setInterpolator(new DecelerateInterpolator(2f)).start();
        }).start();
    }

    private void showAfter() {
        curView.animate().alpha(0f).setDuration(160).withEndAction(() -> {
            curView.setTextSize(19);
            curView.setText(AdhanLyrics.AFTER);
            curView.setLineSpacing(0, 1.5f);
            prevView.setText("");
            nextView.setText("");
            label.setText("الدعاء بعد الأذان");
            trackFill.setScaleX(1f);
            curView.animate().alpha(1f).setDuration(400).start();
        }).start();
    }

    private void paintDots(int active, boolean all) {
        final int accent = AdhanArtView.ACCENT[style], ink = AdhanArtView.INK[style];
        for (int i = 0; i < dots.length; i++) {
            GradientDrawable g = new GradientDrawable();
            g.setShape(GradientDrawable.OVAL);
            boolean on = i == active;
            g.setColor(all || i < active ? withAlpha(accent, .85f) : (on ? accent : withAlpha(ink, .22f)));
            dots[i].setBackground(g);
            float sc = on ? 1.5f : 1f;
            dots[i].animate().scaleX(sc).scaleY(sc).setDuration(180).start();
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
        handler.removeCallbacksAndMessages(null);
        try {
            unregisterReceiver(ended);
        } catch (Exception ignored) {
        }
        super.onDestroy();
    }
}
