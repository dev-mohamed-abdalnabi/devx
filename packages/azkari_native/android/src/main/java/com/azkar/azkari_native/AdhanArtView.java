package com.azkar.azkari_native;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.SweepGradient;
import android.view.View;

import java.util.Random;

/**
 * خلفية شاشة الأذان المتحركة: خمسة أشكال تُرسم بالكود، وشعار «ذِكر» (adhan_logo)
 * يظهر في الخمسة بتلوين وحركة خاصة بكل شكل.
 */
public class AdhanArtView extends View {
    static final int[][] BG = {
            {0xFF0B3B34, 0xFF1E7A5F}, {0xFF050818, 0xFF1B2A5C}, {0xFF070707, 0xFF1C1810},
            {0xFF2E1A48, 0xFFE5784B}, {0xFFF7F5EE, 0xFFEFEBDD}};
    static final int[] INK = {0xFFFFFFFF, 0xFFEFF2FF, 0xFFF6E7B4, 0xFFFFFFFF, 0xFF1F2A1F};
    static final int[] ACCENT = {0xFFE2BC63, 0xFFBFD0FF, 0xFFE2BC63, 0xFFFFE2A8, 0xFFB8923A};
    static final int[] BTN = {0xFFFFFFFF, 0xFFEFF2FF, 0xFFE2BC63, 0xFFFFFFFF, 0xFF2F6B3A};
    static final int[] BTN_INK = {0xFF0F4A41, 0xFF0B1433, 0xFF1A1710, 0xFF7A2E1E, 0xFFFFFFFF};
    /** تدرّج تلوين الشعار (أعلى ← أسفل) لكل شكل. */
    private static final int[][] LOGO = {
            {0xFFF7E3A1, 0xFFD9A93C}, {0xFFFFFFFF, 0xFFBFD0FF}, {0xFFFFF1C4, 0xFFC9962E},
            {0xFFFFFFFF, 0xFFFFE2A8}, {0xFF3F7A47, 0xFF1F4A2A}};

    private final int style;
    private final float dp;
    private final long t0 = System.nanoTime();
    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bmpPaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Paint fillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final Path star = new Path();
    private final RectF rect = new RectF();
    private final RectF logoRect = new RectF();
    private final float[] sx = new float[80], sy = new float[80], sr = new float[80], sph = new float[80];
    private Shader bg, sweep, logoFill, shine;
    private final Matrix m = new Matrix();
    private final PorterDuffXfermode srcIn = new PorterDuffXfermode(PorterDuff.Mode.SRC_IN);
    private final PorterDuffXfermode srcAtop = new PorterDuffXfermode(PorterDuff.Mode.SRC_ATOP);
    private Bitmap logo;

    public AdhanArtView(Context c, int style) {
        super(c);
        this.style = Math.max(0, Math.min(4, style));
        dp = c.getResources().getDisplayMetrics().density;
        Random r = new Random(7);
        for (int i = 0; i < sx.length; i++) {
            sx[i] = r.nextFloat();
            sy[i] = r.nextFloat();
            sr[i] = .6f + r.nextFloat() * 1.5f;
            sph[i] = r.nextFloat() * 6.28f;
        }
        // نجمة ثمانية للنقش (مربعان متداخلان) بنصف قطر 1
        for (int k = 0; k < 2; k++) {
            for (int i = 0; i < 4; i++) {
                double a = Math.PI / 4 * k + Math.PI / 2 * i;
                float x = (float) Math.cos(a), y = (float) Math.sin(a);
                if (i == 0) star.moveTo(x, y); else star.lineTo(x, y);
            }
            star.close();
        }
        try {
            int id = c.getResources().getIdentifier("adhan_logo", "drawable", c.getPackageName());
            if (id != 0) logo = BitmapFactory.decodeResource(c.getResources(), id);
        } catch (Throwable ignored) {
            logo = null;
        }
    }

    /** ارتفاع منطقة الشعار بالبكسل (تتكيّف مع الشاشات الصغيرة). */
    public static int emblemPx(Context c) {
        android.util.DisplayMetrics d = c.getResources().getDisplayMetrics();
        return Math.round(Math.min(150 * d.density, d.heightPixels * 0.21f));
    }

    /** بداية منطقة الشعار من أعلى الشاشة. */
    public static int topPx(Context c) {
        return Math.round(c.getResources().getDisplayMetrics().heightPixels * 0.06f);
    }

    @Override
    protected void onSizeChanged(int w, int h, int ow, int oh) {
        bg = new LinearGradient(0, 0, 0, h, BG[style][0], BG[style][1], Shader.TileMode.CLAMP);
        sweep = new SweepGradient(w / 2f, h / 2f,
                new int[]{0x66E2BC63, 0xFFFFF1C4, 0x66E2BC63, 0x66E2BC63}, new float[]{0f, .12f, .3f, 1f});
        float eh = emblemPx(getContext());
        float cy = topPx(getContext()) + eh / 2f;
        float lw = logo == null ? eh * .75f : eh * logo.getWidth() / logo.getHeight();
        logoRect.set(w / 2f - lw / 2f, cy - eh / 2f, w / 2f + lw / 2f, cy + eh / 2f);
        logoFill = new LinearGradient(0, logoRect.top, 0, logoRect.bottom, LOGO[style][0], LOGO[style][1],
                Shader.TileMode.CLAMP);
        // شريط لمعان أفقي يمرّ فوق الشعار (يُستخدم في الشكل الذهبي)
        shine = new LinearGradient(0, 0, lw * .6f, 0,
                new int[]{0x00FFFFFF, 0xCCFFFFFF, 0x00FFFFFF}, new float[]{0f, .5f, 1f}, Shader.TileMode.CLAMP);
    }

    private int alpha(int color, float a) {
        int al = Math.max(0, Math.min(255, Math.round(a * 255)));
        return (color & 0x00FFFFFF) | (al << 24);
    }

    @Override
    protected void onDraw(Canvas c) {
        float t = (System.nanoTime() - t0) / 1e9f;
        float w = getWidth(), h = getHeight();
        p.setShader(bg);
        p.setStyle(Paint.Style.FILL);
        c.drawRect(0, 0, w, h, p);
        p.setShader(null);

        float cx = logoRect.centerX(), cy = logoRect.centerY();
        float s = logoRect.height();
        int accent = ACCENT[style];
        float lf = 0f; // طفو الشعار

        switch (style) {
            case 0: // الزمردي
                pattern(c, t, w, h, 0x22FFFFFF);
                glow(c, cx, cy, s * (1.25f + .06f * (float) Math.sin(t * 1.6)), accent, .38f);
                ripples(c, cx, cy, s * .8f, accent, t);
                lf = 3 * dp * (float) Math.sin(t * 1.3);
                break;
            case 1: // ليل الفجر
                stars(c, t, w, h);
                shooting(c, t, w, h);
                glow(c, cx, cy, s * 1.2f, 0xFFBFD0FF, .22f + .08f * (float) Math.sin(t * 1.4));
                crescent(c, w * .84f, h * .05f + 10 * dp * (float) Math.sin(t * .7), 10 * dp, alpha(0xFFFFFFFF, .35f));
                lf = 6 * dp * (float) Math.sin(t * 1.1);
                break;
            case 2: // الذهبي
                pattern(c, t, w, h, 0x1FE2BC63);
                frame(c, t, w, h);
                glow(c, cx, cy, s * 1.15f, accent, .20f);
                star8(c, cx, cy, s * .78f, t * 10, accent, true);
                star8(c, cx, cy, s * .60f, -t * 16, accent, true);
                break;
            case 3: // غروب
                sun(c, t, w, h, cx, cy, s);
                break;
            default: // بسيط
                ripples(c, cx, cy, s * .72f, accent, t);
                float br = 1f + .03f * (float) Math.sin(t * 1.8);
                p.setColor(0xFFE3EFD8);
                c.drawCircle(cx, cy, s * .62f * br, p);
                p.setStyle(Paint.Style.STROKE);
                p.setStrokeWidth(1.6f * dp);
                p.setColor(accent);
                c.drawCircle(cx, cy, s * .62f * br, p);
                p.setStyle(Paint.Style.FILL);
        }
        drawLogo(c, lf, t);
        postInvalidateOnAnimation();
    }

    // ───────── الشعار ─────────

    private void drawLogo(Canvas c, float dy, float t) {
        if (logo == null) return;
        rect.set(logoRect);
        rect.offset(0, dy);
        int sc = c.saveLayer(rect, null);
        c.drawBitmap(logo, null, rect, bmpPaint);
        fillPaint.setXfermode(srcIn);
        fillPaint.setShader(logoFill);
        c.save();
        c.translate(0, dy);
        c.drawRect(logoRect, fillPaint);
        c.restore();
        if (style == 2) {
            // لمعة ذهبية تعبر الشعار كل ~5 ثوانٍ
            float u = (t % 5f) / 1.6f;
            if (u < 1f) {
                fillPaint.setXfermode(srcAtop);
                m.setTranslate(rect.left - rect.width() * .6f + u * rect.width() * 1.6f, 0);
                shine.setLocalMatrix(m);
                fillPaint.setShader(shine);
                c.drawRect(rect, fillPaint);
            }
        }
        fillPaint.setShader(null);
        fillPaint.setXfermode(null);
        c.restoreToCount(sc);
    }

    // ───────── عناصر الرسم ─────────

    private void pattern(Canvas c, float t, float w, float h, int color) {
        float cell = 46 * dp, r = cell * .36f * 1.4f;
        p.setStyle(Paint.Style.STROKE);
        p.setColor(color);
        float ox = (t * 5 * dp) % cell, oy = (t * 3 * dp) % cell;
        for (float y = -cell + oy; y < h + cell; y += cell) {
            for (float x = -cell + ox; x < w + cell; x += cell) {
                c.save();
                c.translate(x, y);
                c.scale(r, r);
                p.setStrokeWidth(dp / r);
                c.drawPath(star, p);
                c.restore();
            }
        }
        p.setStyle(Paint.Style.FILL);
    }

    private void glow(Canvas c, float cx, float cy, float r, int color, float a) {
        p.setShader(new RadialGradient(cx, cy, r, new int[]{alpha(color, a), alpha(color, 0f)}, null,
                Shader.TileMode.CLAMP));
        c.drawCircle(cx, cy, r, p);
        p.setShader(null);
    }

    private void ripples(Canvas c, float cx, float cy, float s, int color, float t) {
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1.6f * dp);
        for (int i = 0; i < 3; i++) {
            float u = ((t / 3.6f) + i / 3f) % 1f;
            p.setColor(alpha(color, (1f - u) * .55f));
            c.drawCircle(cx, cy, s * (.45f + u * .85f), p);
        }
        p.setStyle(Paint.Style.FILL);
    }

    private void crescent(Canvas c, float cx, float cy, float r, int color) {
        Path a = new Path(), b = new Path();
        a.addCircle(cx, cy, r, Path.Direction.CW);
        b.addCircle(cx + r * .42f, cy - r * .12f, r * .82f, Path.Direction.CW);
        a.op(b, Path.Op.DIFFERENCE);
        p.setColor(color);
        c.drawPath(a, p);
    }

    private void star8(Canvas c, float cx, float cy, float r, float deg, int color, boolean stroke) {
        path.reset();
        for (int i = 0; i < 16; i++) {
            double a = Math.PI / 8 * i;
            float rr = (i % 2 == 0) ? r : r * .62f;
            float x = cx + (float) Math.cos(a) * rr, y = cy + (float) Math.sin(a) * rr;
            if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        path.close();
        c.save();
        c.rotate(deg, cx, cy);
        p.setStyle(stroke ? Paint.Style.STROKE : Paint.Style.FILL);
        p.setStrokeWidth(1.2f * dp);
        p.setColor(stroke ? alpha(color, .55f) : alpha(color, .92f));
        c.drawPath(path, p);
        p.setStyle(Paint.Style.FILL);
        c.restore();
    }

    private void stars(Canvas c, float t, float w, float h) {
        for (int i = 0; i < sx.length; i++) {
            float a = .25f + .65f * (.5f + .5f * (float) Math.sin(t * (.8f + sr[i] * .5f) + sph[i]));
            p.setColor(alpha(0xFFFFFFFF, a));
            c.drawCircle(sx[i] * w, sy[i] * h, sr[i] * dp * .8f, p);
        }
    }

    private void shooting(Canvas c, float t, float w, float h) {
        float u = (t % 7f) / 1.3f;
        if (u > 1f) return;
        float x = w * (.95f - .6f * u), y = h * (.12f + .28f * u);
        p.setStrokeWidth(1.6f * dp);
        p.setStyle(Paint.Style.STROKE);
        for (int i = 0; i < 12; i++) {
            float k = i / 12f;
            p.setColor(alpha(0xFFFFFFFF, (1f - k) * (1f - u * .6f) * .8f));
            c.drawLine(x + k * 42 * dp, y - k * 18 * dp, x + (k + .08f) * 42 * dp, y - (k + .08f) * 18 * dp, p);
        }
        p.setStyle(Paint.Style.FILL);
    }

    private void frame(Canvas c, float t, float w, float h) {
        m.setRotate(t * 40f, w / 2f, h / 2f);
        sweep.setLocalMatrix(m);
        p.setStyle(Paint.Style.STROKE);
        p.setShader(sweep);
        p.setStrokeWidth(1.8f * dp);
        rect.set(18 * dp, 18 * dp, w - 18 * dp, h - 18 * dp);
        c.drawRoundRect(rect, 26 * dp, 26 * dp, p);
        p.setStrokeWidth(dp);
        rect.inset(6 * dp, 6 * dp);
        c.drawRoundRect(rect, 21 * dp, 21 * dp, p);
        p.setShader(null);
        p.setStyle(Paint.Style.FILL);
    }

    private void sun(Canvas c, float t, float w, float h, float cx, float cy, float s) {
        int accent = ACCENT[3];
        // شمس كبيرة تتنفس عند الأفق
        float pulse = 1f + .06f * (float) Math.sin(t * 1.2);
        float gy = h + 40 * dp - 10 * dp * (float) Math.sin(t * .6);
        glow(c, w / 2f, gy, 330 * dp * pulse, 0xFFFFD08A, .9f);
        glow(c, cx, cy, s * 1.3f, accent, .30f);
        // أشعة تدور خلف الشعار
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(2f * dp);
        p.setStrokeCap(Paint.Cap.ROUND);
        for (int i = 0; i < 24; i++) {
            double a = Math.PI * 2 / 24 * i + t * .18;
            float len = s * (i % 2 == 0 ? .30f : .18f) * (1f + .2f * (float) Math.sin(t * 2 + i));
            float r0 = s * .66f;
            p.setColor(alpha(accent, .55f));
            c.drawLine(cx + (float) Math.cos(a) * r0, cy + (float) Math.sin(a) * r0,
                    cx + (float) Math.cos(a) * (r0 + len), cy + (float) Math.sin(a) * (r0 + len), p);
        }
        p.setStyle(Paint.Style.FILL);
        // جسيمات دافئة تطفو للأعلى
        for (int i = 0; i < 6; i++) {
            float u = ((t * .05f) + i / 6f) % 1f;
            p.setColor(alpha(0xFFFFE2A8, .5f * (float) Math.sin(u * Math.PI)));
            c.drawCircle(w * (.15f + .7f * ((i * 37 % 10) / 10f)), h * (1f - u), (2f + i % 3) * dp, p);
        }
    }
}
