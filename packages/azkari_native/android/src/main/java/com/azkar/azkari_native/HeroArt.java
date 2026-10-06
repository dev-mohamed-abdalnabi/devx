package com.azkar.azkari_native;

import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;

/**
 * نسخة أصلية (Canvas) من مشاهد كارت الرئيسية في التطبيق (hero_scene.dart): نفس الألوان والرسم.
 * كل الإحداثيات بوحدة dp بنفس نسب الكارت، فيبدو الودجت مثل التطبيق على كل الشاشات.
 */
final class HeroArt {
    static final int DEEP_NIGHT = 0, SAHAR = 1, DAWN = 2, MORNING = 3, NOON = 4,
            AFTERNOON = 5, ASR = 6, MAGHRIB = 7, DUSK = 8, NIGHT = 9;

    /** حدود المشاهد بالساعات (نفس heroSceneFor في Dart). */
    static int sceneFor(double h) {
        if (h < 3) return DEEP_NIGHT;
        if (h < 5) return SAHAR;
        if (h < 6.5) return DAWN;
        if (h < 9.5) return MORNING;
        if (h < 13) return NOON;
        if (h < 15) return AFTERNOON;
        if (h < 17.5) return ASR;
        if (h < 19) return MAGHRIB;
        if (h < 21) return DUSK;
        return NIGHT;
    }

    static final class Pal {
        final int[] sky;
        final int ink, sub, accent, silhouette, hill, pill, track, fill;
        Pal(int s0, int s1, int s2, int ink, int sub, int accent, int sil, int hill, int pill, int track, int fill) {
            this.sky = new int[]{s0, s1, s2};
            this.ink = ink;
            this.sub = sub;
            this.accent = accent;
            this.silhouette = sil;
            this.hill = hill;
            this.pill = pill;
            this.track = track;
            this.fill = fill;
        }
    }

    private static final Pal[] PALS = {
            // deepNight
            new Pal(0xFF050816, 0xFF0B1B3A, 0xFF16305A, 0xFFF1EEE2, 0xFFC3D3E4, 0xFFF0D58A, 0xFF050A18, 0xFF0A1830, 0x26FFFFFF, 0x33FFFFFF, 0xFFF0D58A),
            // sahar
            new Pal(0xFF0A1530, 0xFF1B2F5E, 0xFF4B4A7C, 0xFFFFF4E0, 0xFFE6D8EC, 0xFFF6D58F, 0xFF0A1226, 0xFF121F42, 0x2EFFFFFF, 0x38FFFFFF, 0xFFF6D58F),
            // dawn
            new Pal(0xFF0C2B3D, 0xFF2F6A78, 0xFFE9B98A, 0xFFFFF6E3, 0xFFFFE9C7, 0xFFF2CB78, 0xFF0B2530, 0xFF123846, 0x33FFFFFF, 0x40FFFFFF, 0xFFF2CB78),
            // morning
            new Pal(0xFF1F5F73, 0xFF59A3A0, 0xFFF3D28B, 0xFFFFF8E6, 0xFFFFEBC8, 0xFFFFE08A, 0xFF0F3B3F, 0xFF1C5C57, 0x33FFFFFF, 0x40FFFFFF, 0xFFFFE08A),
            // noon
            new Pal(0xFF0F4C75, 0xFF2D86A8, 0xFF9AD3CF, 0xFFFFF9EA, 0xFFE3F4EE, 0xFFFFE9A0, 0xFF0C3B4A, 0xFF17566A, 0x33FFFFFF, 0x40FFFFFF, 0xFFFFE9A0),
            // afternoon
            new Pal(0xFF2B4F5E, 0xFFD39A4A, 0xFFF6D88F, 0xFFFFF6E0, 0xFFFFE9C2, 0xFFFFE3A0, 0xFF26352C, 0xFF3A4A3A, 0x33FFFFFF, 0x40FFFFFF, 0xFFFFE3A0),
            // asr
            new Pal(0xFF3A2B5C, 0xFFD9683A, 0xFFF8C970, 0xFFFFF4E0, 0xFFFFE2B8, 0xFFFFD98A, 0xFF2A1E3F, 0xFF4A2B45, 0x33FFFFFF, 0x40FFFFFF, 0xFFFFD98A),
            // maghrib
            new Pal(0xFF2B1B4A, 0xFFB5384A, 0xFFF08A4B, 0xFFFFF1DC, 0xFFFFD9B8, 0xFFFFC27A, 0xFF241233, 0xFF3A1B3F, 0x33FFFFFF, 0x40FFFFFF, 0xFFFFC27A),
            // dusk
            new Pal(0xFF120F33, 0xFF3B2A63, 0xFF9B4F6E, 0xFFF6EBDD, 0xFFE3CFE0, 0xFFF2C27A, 0xFF0E0A22, 0xFF1C1238, 0x2EFFFFFF, 0x38FFFFFF, 0xFFF2C27A),
            // night
            new Pal(0xFF050F16, 0xFF0C2B31, 0xFF16473F, 0xFFF1EEE2, 0xFFB9D3C6, 0xFFE2BC63, 0xFF040C10, 0xFF0A2127, 0x26FFFFFF, 0x33FFFFFF, 0xFFE2BC63),
    };

    static Pal pal(int scene) {
        return PALS[Math.max(0, Math.min(PALS.length - 1, scene))];
    }

    /** نجمة النقش الإسلامي (بلاطة ٤٤×٤٤) من star_shape.dart. */
    static final float[] STAR = {
            22, 3, 26.5f, 13.5f, 37, 9, 32.5f, 19.5f, 41, 22, 32.5f, 24.5f, 37, 35, 26.5f, 30.5f,
            22, 41, 17.5f, 30.5f, 7, 35, 11.5f, 24.5f, 3, 22, 11.5f, 19.5f, 7, 9, 17.5f, 13.5f};

    static Path starPath() {
        Path p = new Path();
        p.moveTo(STAR[0], STAR[1]);
        for (int i = 2; i < STAR.length; i += 2) p.lineTo(STAR[i], STAR[i + 1]);
        p.close();
        return p;
    }

    static int alpha(int color, float a) {
        int al = Math.max(0, Math.min(255, Math.round(a * 255)));
        return (color & 0x00FFFFFF) | (al << 24);
    }

    private static double frac(double x) {
        return x - Math.floor(x);
    }

    /** الطبقات: الثابت (سماء + مشهد + مسجد) ، النجوم المتلألئة ، السحاب/الطيور المتحركة. */
    static final int BASE = 1, STARS = 2, MOTION = 4;

    /** قوة النجوم في المشهد (0 = لا نجوم). */
    static float starStrength(int scene) {
        switch (scene) {
            case DEEP_NIGHT: return 1f;
            case SAHAR: return .6f;
            case DAWN: return .55f;
            case DUSK: return .45f;
            case NIGHT: return 1f;
            default: return 0f;
        }
    }

    static boolean hasMotion(int scene) {
        return scene == MORNING || scene == NOON || scene == AFTERNOON || scene == ASR || scene == MAGHRIB;
    }

    /** يرسم الطبقات المطلوبة داخل (0,0,w,h). t = طور الحركة (يغيّر لمعان النجوم). */
    static void draw(Canvas c, int scene, float w, float h, float t, int layers) {
        Pal pal = pal(scene);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);

        if ((layers & BASE) != 0) {
            p.setShader(new LinearGradient(0, 0, 0, h, pal.sky, null, Shader.TileMode.CLAMP));
            c.drawRect(0, 0, w, h, p);
            p.setShader(null);
            pattern(c, w, h, alpha(pal.accent, .1f));

            switch (scene) {
                case DEEP_NIGHT:
                    glow(c, w * .19f, h * .32f, h * .5f, 0xFFFFF0B8, .2f);
                    crescent(c, w * .19f, h * .32f, h * .12f, 0xFFFFF0B8, 1f);
                    break;
                case SAHAR:
                    glow(c, w * .24f, h * .98f, h * .85f, 0xFF9B7BC0, .4f);
                    crescent(c, w * .12f, h * .22f, h * .08f, 0xFFFFF2CF, .85f);
                    break;
                case DAWN:
                    glow(c, w * .24f, h * .86f, h * .75f, 0xFFFFC98A, .55f);
                    crescent(c, w * .1f, h * .2f, h * .08f, 0xFFFFF2CF, .85f);
                    break;
                case MORNING:
                    glow(c, w * .24f, h * .66f, h * .9f, 0xFFFFD98A, .6f);
                    disc(c, w * .24f, h * .62f, h * .14f, 0xFFFFE7A3);
                    break;
                case NOON:
                    glow(c, w * .2f, h * .36f, h * .7f, 0xFFFFF1B8, .45f);
                    disc(c, w * .2f, h * .34f, h * .12f, 0xFFFFF1B8);
                    break;
                case AFTERNOON:
                    glow(c, w * .24f, h * .55f, h * .8f, 0xFFFFD27A, .55f);
                    disc(c, w * .24f, h * .52f, h * .14f, 0xFFFFE6A8);
                    break;
                case ASR:
                    glow(c, w * .24f, h * .78f, h * .9f, 0xFFFFB347, .7f);
                    disc(c, w * .24f, h * .74f, h * .2f, 0xFFFFE1A0);
                    break;
                case MAGHRIB:
                    glow(c, w * .24f, h * .88f, h * 1.0f, 0xFFFF8A4A, .75f);
                    disc(c, w * .24f, h * .9f, h * .2f, 0xFFFFB36B);
                    break;
                case DUSK:
                    glow(c, w * .24f, h * .98f, h * .9f, 0xFFFF9A5A, .35f);
                    crescent(c, w * .19f, h * .32f, h * .1f, 0xFFFFEBC4, .9f);
                    break;
                default: // NIGHT
                    glow(c, w * .19f, h * .32f, h * .5f, 0xFFFFF0B8, .22f);
                    crescent(c, w * .19f, h * .32f, h * .12f, 0xFFFFF0B8, 1f);
                    break;
            }

            Path hill = new Path();
            hill.moveTo(0, h * .84f);
            hill.cubicTo(w * .2f, h * .74f, w * .38f, h * .9f, w * .58f, h * .82f);
            hill.cubicTo(w * .76f, h * .75f, w * .88f, h * .86f, w, h * .8f);
            hill.lineTo(w, h);
            hill.lineTo(0, h);
            hill.close();
            p.setStyle(Paint.Style.FILL);
            p.setColor(pal.hill);
            c.drawPath(hill, p);

            float mw = Math.min(w * .5f, h * 1.25f);
            boolean day = scene == MORNING || scene == NOON || scene == AFTERNOON;
            mosque(c, w * .02f, h + 1, mw, pal.silhouette, day ? 0 : pal.accent);
        }

        if ((layers & STARS) != 0) {
            float st = starStrength(scene);
            if (st > 0) stars(c, w, h, t, st);
        }

        if ((layers & MOTION) != 0) {
            switch (scene) {
                case MORNING:
                    cloud(c, w, h, .2f, h * .31f, .5f, .24f);
                    cloud(c, w, h, .68f, h * .31f, .45f, .18f);
                    break;
                case NOON:
                    cloud(c, w, h, .22f, h * .31f, .5f, .24f);
                    cloud(c, w, h, .68f, h * .31f, .45f, .18f);
                    break;
                case AFTERNOON:
                    cloud(c, w, h, .5f, h * .31f, .5f, .2f);
                    break;
                case ASR:
                case MAGHRIB:
                    birds(c, w, h);
                    break;
                default:
                    break;
            }
        }
    }

    private static void pattern(Canvas c, float w, float h, int color) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(.8f);
        p.setColor(color);
        Path star = starPath();
        for (float y = 0; y < h; y += 44) {
            for (float x = 0; x < w; x += 44) {
                c.save();
                c.translate(x, y);
                c.drawPath(star, p);
                c.restore();
            }
        }
    }

    private static void disc(Canvas c, float x, float y, float r, int color) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(color);
        c.drawCircle(x, y, r, p);
    }

    private static void glow(Canvas c, float x, float y, float r, int color, float a) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setShader(new RadialGradient(x, y, r, new int[]{alpha(color, a), alpha(color, 0)}, null, Shader.TileMode.CLAMP));
        c.drawCircle(x, y, r, p);
    }

    /** سحابة بموضع ثابت داخل اللوح؛ الحركة تأتي من تحريك الطبقة كلها (سلسة بلا إعادة رسم). */
    private static void cloud(Canvas c, float w, float h, float phase, float y, float s, float a) {
        float x = Math.max(48f, Math.min(w - 48f, phase * w));
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(alpha(0xFFFFFFFF, a));
        float u = h * .09f * s;
        c.drawOval(new RectF(x - u * 2.2f, y - u * .75f, x + u * 2.2f, y + u * .75f), p);
        c.drawCircle(x - u * .7f, y - u * .5f, u * .9f, p);
        c.drawCircle(x + u * .5f, y - u * .7f, u * 1.1f, p);
    }

    /** نفس شرط hero_scene.dart: لا نجوم خلف الكبسولة ولا كتلة العنوان ولا فوق المسجد. */
    private static void stars(Canvas c, float w, float h, float t, float strength) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        int drawn = 0;
        for (int i = 0; i < 160 && drawn < 26; i++) {
            double fx = frac(Math.sin(i * 12.9898) * 43758.5453);
            double fy = frac(Math.sin(i * 78.233) * 12345.6789) * .62;
            boolean ok = (fx < .30 && fy < .27) || (fx >= .30 && fy > .34 && fy < .40);
            if (!ok) continue;
            drawn++;
            float x = (float) (fx * w), y = (float) (fy * h);
            double tw = .35 + .65 * (.5 + .5 * Math.sin(2 * Math.PI * (t * 3 + i * .137)));
            float r = (float) (.8 + frac(i * .37) * 1.3);
            p.setColor(alpha(0xFFFFF6D8, (float) (tw * strength)));
            c.drawCircle(x, y, r, p);
        }
    }

    private static void crescent(Canvas c, float x, float y, float r, int color, float a) {
        Path outer = new Path();
        outer.addCircle(x, y, r, Path.Direction.CW);
        Path cut = new Path();
        cut.addCircle(x + r * .45f, y - r * .12f, r * .88f, Path.Direction.CW);
        Path res = new Path();
        res.op(outer, cut, Path.Op.DIFFERENCE);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(alpha(color, a));
        c.drawPath(res, p);
    }

    private static void birds(Canvas c, float w, float h) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1.6f);
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setColor(alpha(0xFF2A1E3F, .7f));
        float span = w + 60;
        for (int i = 0; i < 3; i++) {
            float x = w * .45f + i * .09f * span;
            float y = h * (.28f + i * .07f);
            Path b = new Path();
            b.moveTo(x - 7, y);
            b.quadTo(x - 3.5f, y - 5, x, y);
            b.quadTo(x + 3.5f, y - 5, x + 7, y);
            c.drawPath(b, p);
        }
    }

    /** المسجد (منقول من _mosque). lit = لون النوافذ المضيئة أو 0 نهارًا. */
    private static void mosque(Canvas c, float ox, float oy, float w, int col, int lit) {
        float k = w / 150f;
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(col);
        c.save();
        c.translate(ox, oy - 110 * k);
        c.scale(k, k);
        rect(c, 0, 100, 150, 10, p);
        rect(c, 38, 72, 64, 28, p);
        Path dome = new Path();
        dome.moveTo(40, 72);
        dome.arcTo(new RectF(40, 42, 100, 102), 180, 180);
        dome.close();
        c.drawPath(dome, p);
        rect(c, 69.5f, 27, 1, 16, p);
        c.drawCircle(70, 24, 3.2f, p);
        rect(c, 24, 88, 14, 12, p);
        rect(c, 102, 88, 14, 12, p);
        for (float x : new float[]{8f, 130f}) {
            rect(c, x, 54, 12, 46, p);
            rect(c, x - 3, 52, 18, 3, p);
            Path cap = new Path();
            cap.moveTo(x + 1, 52);
            cap.lineTo(x + 6, 34);
            cap.lineTo(x + 11, 52);
            cap.close();
            c.drawPath(cap, p);
            rect(c, x + 5.5f, 22, 1, 12, p);
        }
        if (lit != 0) {
            Paint l = new Paint(Paint.ANTI_ALIAS_FLAG);
            l.setColor(alpha(lit, .9f));
            for (float x : new float[]{13f, 135f}) {
                c.drawRoundRect(new RectF(x, 64, x + 2, 72), 1, 1, l);
                c.drawRoundRect(new RectF(x, 80, x + 2, 88), 1, 1, l);
            }
            for (float x : new float[]{46f, 86f}) {
                arch(c, x, 94, 8, 8, l);
            }
            arch(c, 64, 100, 12, 14, l);
        }
        c.restore();
    }

    /** نافذة/باب مقوّس: يبدأ من (x, base) بعرض aw وارتفاع الجسم bodyH ثم قوس نصف دائري. */
    private static void arch(Canvas c, float x, float base, float aw, float bodyH, Paint p) {
        float r = aw / 2f;
        float top = base - bodyH;
        Path a = new Path();
        a.moveTo(x, base);
        a.lineTo(x, top);
        a.arcTo(new RectF(x, top - r, x + aw, top + r), 180, 180);
        a.lineTo(x + aw, base);
        a.close();
        c.drawPath(a, p);
    }

    private static void rect(Canvas c, float x, float y, float w, float h, Paint p) {
        c.drawRect(x, y, x + w, y + h, p);
    }
}
