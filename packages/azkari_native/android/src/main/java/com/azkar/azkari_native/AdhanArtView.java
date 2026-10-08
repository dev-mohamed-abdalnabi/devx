package com.azkar.azkari_native;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.SweepGradient;
import android.view.View;

import java.util.Random;

/** خلفية شاشة الأذان المتحركة: خمسة أشكال تُرسم بالكامل بالكود (بدون صور أو فيديو). */
public class AdhanArtView extends View {
    static final int[][] BG = {
            {0xFF0F4A41, 0xFF1E7A5F}, {0xFF070B24, 0xFF1B2A5C}, {0xFF0B0B0B, 0xFF1A1710},
            {0xFF3B1F4F, 0xFFE5784B}, {0xFFF7F5EE, 0xFFF7F5EE}};
    static final int[] INK = {0xFFFFFFFF, 0xFFEFF2FF, 0xFFF6E7B4, 0xFFFFFFFF, 0xFF1F2A1F};
    static final int[] ACCENT = {0xFFE2BC63, 0xFFBFD0FF, 0xFFE2BC63, 0xFFFFE2A8, 0xFFB8923A};
    static final int[] BTN = {0xFFFFFFFF, 0xFFEFF2FF, 0xFFE2BC63, 0xFFFFFFFF, 0xFF2F6B3A};
    static final int[] BTN_INK = {0xFF0F4A41, 0xFF0B1433, 0xFF1A1710, 0xFF7A2E1E, 0xFFFFFFFF};

    private final int style;
    private final float dp;
    private final long t0 = System.nanoTime();
    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final Path star = new Path();
    private final RectF rect = new RectF();
    private final float[] sx = new float[80], sy = new float[80], sr = new float[80], sph = new float[80];
    private Shader bg, sweep;
    private final Matrix m = new Matrix();

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
    }

    /** مركز الشعار وحجمه (يتركها النص فارغة بنفس الحجم). */
    public static int emblemSizeDp() { return 132; }

    @Override
    protected void onSizeChanged(int w, int h, int ow, int oh) {
        bg = new LinearGradient(0, 0, 0, h, BG[style][0], BG[style][1], Shader.TileMode.CLAMP);
        sweep = new SweepGradient(w / 2f, h / 2f,
                new int[]{0x66E2BC63, 0xFFFFF1C4, 0x66E2BC63, 0x66E2BC63}, new float[]{0f, .12f, .3f, 1f});
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

        float s = emblemSizeDp() * dp;
        float cx = w / 2f, cy = h * 0.075f + s / 2f;
        int accent = ACCENT[style];

        switch (style) {
            case 0: pattern(c, t, w, h, 0);
                glow(c, cx, cy, s * (1.5f + .08f * (float) Math.sin(t * 1.6)), accent, .35f);
                ripples(c, cx, cy, s, accent, t);
                mosque(c, cx, cy + 4 * dp * (float) Math.sin(t * 1.3), s, accent);
                break;
            case 1: stars(c, t, w, h); shooting(c, t, w, h);
                glow(c, cx, cy, s * 1.5f, 0xFFBFD0FF, .25f + .08f * (float) Math.sin(t * 1.4));
                float fy = 5 * dp * (float) Math.sin(t * 1.1);
                crescent(c, cx, cy + fy, s * .36f, accent);
                p.setColor(alpha(0xFFFFFFFF, .6f + .4f * (float) Math.sin(t * 3)));
                c.drawCircle(cx + s * .30f, cy + fy - s * .22f, 3.2f * dp, p);
                break;
            case 2: pattern(c, t, w, h, 0x14E2BC63); frame(c, t, w, h);
                glow(c, cx, cy, s * 1.4f, accent, .22f);
                star8(c, cx, cy, s * .5f, t * 14, accent, false);
                star8(c, cx, cy, s * .34f, -t * 22, accent, true);
                crescent(c, cx, cy, s * .13f, accent);
                break;
            case 3: sun(c, t, w, h, cx, cy, s);
                break;
            default: pattern(c, t, w, h, 0x00000000);
                ripples(c, cx, cy, s * .92f, accent, t);
                float br = 1f + .03f * (float) Math.sin(t * 1.8);
                p.setColor(0xFFE3EFD8);
                c.drawCircle(cx, cy, s * .46f * br, p);
                p.setStyle(Paint.Style.STROKE);
                p.setStrokeWidth(1.6f * dp);
                p.setColor(accent);
                c.drawCircle(cx, cy, s * .46f * br, p);
                p.setStyle(Paint.Style.FILL);
                mosque(c, cx, cy + s * .02f, s * .62f, 0xFF2F5A2A);
        }
        postInvalidateOnAnimation();
    }

    // ───────── عناصر الرسم ─────────

    private void pattern(Canvas c, float t, float w, float h, int color) {
        if (style == 4) return;
        float cell = 46 * dp, r = cell * .36f;
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(dp);
        p.setColor(style == 2 ? 0x1FE2BC63 : 0x22FFFFFF);
        float ox = (t * 5 * dp) % cell, oy = (t * 3 * dp) % cell;
        for (float y = -cell + oy; y < h + cell; y += cell) {
            for (float x = -cell + ox; x < w + cell; x += cell) {
                c.save();
                c.translate(x, y);
                c.scale(r * 1.4f, r * 1.4f);
                p.setStrokeWidth(1f / (r * 1.4f) * dp);
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

    private void mosque(Canvas c, float cx, float cy, float s, int color) {
        p.setColor(color);
        path.reset();
        path.moveTo(cx - .26f * s, cy + .12f * s);
        rect.set(cx - .26f * s, cy - .16f * s, cx + .26f * s, cy + .40f * s);
        path.arcTo(rect, 180, 180);
        path.close();
        c.drawPath(path, p);
        c.drawRect(cx - .30f * s, cy + .12f * s, cx + .30f * s, cy + .40f * s, p);
        c.drawCircle(cx, cy - .24f * s, .028f * s, p);
        c.drawRect(cx - .004f * s, cy - .22f * s, cx + .004f * s, cy - .14f * s, p);
        for (int sd = -1; sd <= 1; sd += 2) {
            float mx = cx + sd * .43f * s;
            c.drawRect(mx - .045f * s, cy - .06f * s, mx + .045f * s, cy + .40f * s, p);
            path.reset();
            path.moveTo(mx - .065f * s, cy - .06f * s);
            path.lineTo(mx + .065f * s, cy - .06f * s);
            path.lineTo(mx, cy - .27f * s);
            path.close();
            c.drawPath(path, p);
            c.drawRect(mx - .065f * s, cy + .06f * s, mx + .065f * s, cy + .075f * s, p);
        }
        rect.set(cx - .5f * s, cy + .40f * s, cx + .5f * s, cy + .45f * s);
        c.drawRoundRect(rect, .02f * s, .02f * s, p);
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
        if (stroke) {
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(1.8f * dp);
        }
        p.setColor(stroke ? color : alpha(color, .92f));
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
            c.drawLine(x + k * 70 * dp * .6f, y - k * 30 * dp * .6f,
                    x + (k + .08f) * 70 * dp * .6f, y - (k + .08f) * 30 * dp * .6f, p);
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
        // أشعة تدور حول الشمس الصغيرة
        glow(c, cx, cy, s * 1.5f, accent, .30f);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(2.2f * dp);
        p.setStrokeCap(Paint.Cap.ROUND);
        for (int i = 0; i < 16; i++) {
            double a = Math.PI * 2 / 16 * i + t * .25;
            float len = s * (i % 2 == 0 ? .17f : .10f) * (1f + .25f * (float) Math.sin(t * 2 + i));
            float r0 = s * .33f;
            p.setColor(alpha(accent, .9f));
            c.drawLine(cx + (float) Math.cos(a) * r0, cy + (float) Math.sin(a) * r0,
                    cx + (float) Math.cos(a) * (r0 + len), cy + (float) Math.sin(a) * (r0 + len), p);
        }
        p.setStyle(Paint.Style.FILL);
        p.setColor(accent);
        c.drawCircle(cx, cy, s * .24f, p);
        // طيور/أطياف خفيفة: ثلاث جسيمات دافئة تطفو
        for (int i = 0; i < 6; i++) {
            float u = ((t * .05f) + i / 6f) % 1f;
            p.setColor(alpha(0xFFFFE2A8, .5f * (float) Math.sin(u * Math.PI)));
            c.drawCircle(w * (.15f + .7f * ((i * 37 % 10) / 10f)), h * (1f - u) , (2f + i % 3) * dp, p);
        }
    }
}
