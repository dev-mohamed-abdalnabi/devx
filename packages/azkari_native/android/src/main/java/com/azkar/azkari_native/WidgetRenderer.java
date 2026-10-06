package com.azkar.azkari_native;

import android.content.Context;
import android.content.res.AssetManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.DashPathEffect;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.os.Build;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;

import java.util.Calendar;

/**
 * يرسم الودجتس ببكسلات متطابقة على كل الأجهزة واللانشرات (الخطوط والألوان من التطبيق نفسه).
 * كل الإحداثيات بوحدة dp والـCanvas مُكبَّر بمعامل الكثافة.
 */
final class WidgetRenderer {
    private WidgetRenderer() {}

    // ===== ألوان التطبيق (home_tokens.dart) =====
    static final class Tk {
        final int bg, card, line, ink, muted, gold, mint, mintInk, leaf;
        Tk(int bg, int card, int line, int ink, int muted, int gold, int mint, int mintInk, int leaf) {
            this.bg = bg; this.card = card; this.line = line; this.ink = ink; this.muted = muted;
            this.gold = gold; this.mint = mint; this.mintInk = mintInk; this.leaf = leaf;
        }
    }

    static final Tk LIGHT = new Tk(0xFFF7F5EE, 0xFFFFFFFF, 0xFFE7E1CE, 0xFF1F2A1F, 0xFF7B8270,
            0xFFB8923A, 0xFFE3EFD8, 0xFF2F5A2A, 0xFF6FAE5A);
    static final Tk DARK = new Tk(0xFF141913, 0xFF1C231B, 0xFF2D3629, 0xFFF1EEE2, 0xFF9AA38E,
            0xFFD4AE5A, 0xFF243320, 0xFFBFE0AE, 0xFF6FAE5A);
    static final int PATTERN_GOLD = 0xFFB8923A;

    static Tk tokens(Context ctx, WidgetData d) {
        if ("light".equals(d.theme)) return LIGHT;
        if ("dark".equals(d.theme)) return DARK;
        int night = ctx.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
        return night == Configuration.UI_MODE_NIGHT_YES ? DARK : LIGHT;
    }

    // ===== الخطوط: نفس خطوط التطبيق من assets/fonts (flutter_assets) مع بديل آمن =====
    private static Typeface amiri, amiriBold, cairo, cairoSemi, cairoBold;

    private static synchronized void fonts(Context ctx) {
        if (cairo != null) return;
        AssetManager am = ctx.getAssets();
        amiri = asset(am, "Amiri-Regular.ttf", 0, Typeface.SERIF);
        amiriBold = asset(am, "Amiri-Bold.ttf", 0, Typeface.create(Typeface.SERIF, Typeface.BOLD));
        cairo = asset(am, "Cairo.ttf", 400, Typeface.DEFAULT);
        cairoSemi = asset(am, "Cairo.ttf", 600, Typeface.DEFAULT_BOLD);
        cairoBold = asset(am, "Cairo.ttf", 700, Typeface.DEFAULT_BOLD);
    }

    private static Typeface asset(AssetManager am, String file, int wght, Typeface fb) {
        String path = "flutter_assets/assets/fonts/" + file;
        try {
            if (wght > 0 && Build.VERSION.SDK_INT >= 26) {
                Typeface t = new Typeface.Builder(am, path).setFontVariationSettings("'wght' " + wght).build();
                if (t != null) return t;
            }
            return Typeface.createFromAsset(am, path);
        } catch (Throwable e) {
            return fb;
        }
    }

    private static TextPaint tp(Typeface tf, float size, int color) {
        TextPaint p = new TextPaint(Paint.ANTI_ALIAS_FLAG | Paint.SUBPIXEL_TEXT_FLAG);
        p.setTypeface(tf);
        p.setTextSize(size);
        p.setColor(color);
        return p;
    }

    private static final String RLM = "\u200F";

    /** ارتفاع سطر كما في Flutter: lh = حجم الخط × المعامل. */
    private static float baseline(float top, float lh, Paint p) {
        Paint.FontMetrics fm = p.getFontMetrics();
        float fontH = fm.descent - fm.ascent;
        return top + (lh - fontH) / 2f - fm.ascent;
    }

    /** سطر واحد محاذى لليمين (RTL). يعيد العرض. */
    private static float right(Canvas c, String s, float xRight, float top, float lh, Paint p) {
        p.setTextAlign(Paint.Align.RIGHT);
        c.drawText(RLM + s, xRight, baseline(top, lh, p), p);
        return p.measureText(s);
    }

    private static void center(Canvas c, String s, float cx, float top, float lh, Paint p) {
        p.setTextAlign(Paint.Align.CENTER);
        c.drawText(RLM + s, cx, baseline(top, lh, p), p);
    }

    private static void left(Canvas c, String s, float xLeft, float top, float lh, Paint p) {
        p.setTextAlign(Paint.Align.LEFT);
        c.drawText(RLM + s, xLeft, baseline(top, lh, p), p);
    }

    private static StaticLayout layout(String s, TextPaint p, int w, Layout.Alignment a, float lineH, int maxLines) {
        Paint.FontMetrics fm = p.getFontMetrics();
        float mult = lineH / (fm.descent - fm.ascent);
        String cur = s;
        StaticLayout l = new StaticLayout(RLM + cur, p, Math.max(1, w), a, mult, 0f, false);
        while (maxLines > 0 && l.getLineCount() > maxLines && cur.length() > 2) {
            int end = Math.max(1, l.getLineEnd(maxLines - 1) - 1);
            if (end >= cur.length()) end = cur.length() - 1;
            cur = cur.substring(0, end).trim();
            String shown = cur + "…";
            l = new StaticLayout(RLM + shown, p, Math.max(1, w), a, mult, 0f, false);
            if (l.getLineCount() <= maxLines) break;
        }
        return l;
    }

    private static float widest(StaticLayout l) {
        float m = 0;
        for (int i = 0; i < l.getLineCount(); i++) m = Math.max(m, l.getLineWidth(i));
        return m;
    }

    private static void draw(Canvas c, StaticLayout l, float x, float y) {
        c.save();
        c.translate(x, y);
        l.draw(c);
        c.restore();
    }

    // ===== أيقونات الرئيسية (HomeIcons) =====
    static final int ICON_MOON = 0, ICON_SUN = 1, ICON_SUNSET = 2, ICON_CLOCK = 3, ICON_QURAN = 4, ICON_SPARKLE = 5;
    private static final String[] ICON_PATH = {
            "M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z",
            "M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4",
            "M7 18a5 5 0 0 1 10 0M12 9v2M5.6 12.6l1.4 1.4M18.4 12.6L17 14M3 18h2M19 18h2M3 21h18",
            "M12 7v5l3 2",
            "M3 5c3-1 6-1 9 1 3-2 6-2 9-1v13c-3-1-6-1-9 1-3-2-6-2-9-1zM12 6v13",
            "M9 4l1.8 4.2L15 10l-4.2 1.8L9 16l-1.8-4.2L3 10l4.2-1.8zM17 14l.9 2.1L20 17l-2.1.9L17 20l-.9-2.1L14 17l2.1-.9z",
    };

    private static void icon(Canvas c, int which, float x, float y, float size, int color) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1.7f);
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setStrokeJoin(Paint.Join.ROUND);
        p.setColor(color);
        c.save();
        c.translate(x, y);
        c.scale(size / 24f, size / 24f);
        if (which == ICON_SUN) c.drawCircle(12, 12, 4, p);
        if (which == ICON_CLOCK) c.drawCircle(12, 12, 9, p);
        c.drawPath(SvgPath.parse(ICON_PATH[which]), p);
        c.restore();
    }

    // ===== أدوات الحجم =====
    static Bitmap newBitmap(float wDp, float hDp, float scale) {
        int w = Math.max(1, Math.round(wDp * scale)), h = Math.max(1, Math.round(hDp * scale));
        return Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
    }

    private static void maskRounded(Canvas c, float w, float h, float r) {
        Paint m = new Paint(Paint.ANTI_ALIAS_FLAG);
        m.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.DST_IN));
        m.setColor(0xFFFFFFFF);
        c.drawRoundRect(new RectF(0, 0, w, h), r, r, m);
    }

    // =====================================================================
    //  ١) كارت الرئيسية (أذكار الوقت)
    // =====================================================================
    static final float HERO_RADIUS = 22f;

    /** طبقة من الكارت (ثابتة / نجوم / سحاب) بنفس زوايا الكارت المدوّرة. */
    static Bitmap heroLayer(float w, float h, float scale, int scene, float t, int layers) {
        Bitmap b = newBitmap(w, h, scale);
        Canvas c = new Canvas(b);
        c.scale(scale, scale);
        HeroArt.draw(c, scene, w, h, t, layers);
        maskRounded(c, w, h, HERO_RADIUS);
        return b;
    }

    private static int slotFor(int hour) {
        if (hour >= 3 && hour < 15) return 0; // صباح
        if (hour >= 15 && hour < 21) return 1; // مساء
        return 2; // نوم
    }

    /** النص فوق الخلفية: شفاف تمامًا خارج الحروف حتى لا يتأثر بتلاشي الإطارات. */
    static Bitmap heroText(Context ctx, WidgetData d, float w, float h, float scale, long now) {
        fonts(ctx);
        Bitmap b = newBitmap(w, h, scale);
        Canvas c = new Canvas(b);
        c.scale(scale, scale);

        Calendar cal = Calendar.getInstance();
        cal.setTimeInMillis(now);
        int hour = cal.get(Calendar.HOUR_OF_DAY);
        double hf = hour + cal.get(Calendar.MINUTE) / 60.0;
        int scene = HeroArt.sceneFor(hf);
        HeroArt.Pal pal = HeroArt.pal(scene);
        int slot = slotFor(hour);
        String[] titles = {"أذكار الصباح", "أذكار المساء", "أذكار النوم"};
        double progress = d.azkarProgress(slot, WidgetData.dayKey(now));
        int pct = (int) Math.round(progress * 100);
        String prefix = (slot == 0 && scene == HeroArt.DAWN) ? "بعد الفجر" : "حان وقت";

        Hint hint = hintFor(cal, d.nextPrayer(now), now);

        final float padH = 16, padV = 14;
        float inner = w - padH * 2;
        float rightEdge = w - padH;

        boolean compact = h < 150;
        // الصف العلوي: أيقونة (يمين) + كبسولة النص.
        float iconSize = 22;
        TextPaint hp = tp(cairoSemi, 11.5f, pal.ink);
        float maxPillW = inner * .58f;
        StaticLayout hl = layout(hint.text, hp, (int) (maxPillW - 20), Layout.Alignment.ALIGN_NORMAL, 11.5f * 1.35f, compact ? 1 : 2);
        float pillW = Math.min(maxPillW, widest(hl) + 20);
        float pillH = hl.getHeight() + 10;
        float rowH = Math.max(iconSize, pillH);
        float rowTop = padV;
        icon(c, hint.icon, rightEdge - iconSize, rowTop + (rowH - iconSize) / 2f, iconSize, pal.accent);
        float pillR = rightEdge - iconSize - 8;
        float pillL = pillR - pillW;
        Paint bg = new Paint(Paint.ANTI_ALIAS_FLAG);
        bg.setColor(pal.pill);
        float pillTop = rowTop + (rowH - pillH) / 2f;
        c.drawRoundRect(new RectF(pillL, pillTop, pillR, pillTop + pillH), 12, 12, bg);
        // الكبسولة RTL: النص ملاصق للحافة اليمنى للكبسولة مع حشوة ١٠.
        draw(c, hl, pillR - 10 - hl.getWidth(), pillTop + 5);

        // الكتلة السفلية: عرض ٦٢٪ ملاصقة لليمين ومثبّتة بالأسفل.
        float bw = inner * .62f;
        float bx = rightEdge - bw;
        TextPaint subP = tp(cairo, 11.5f, pal.sub);
        TextPaint titleP = tp(amiriBold, 26f, pal.ink);
        float subH = 11.5f * 1.6f, titleH = 26f * 1.4f;
        float y = h - padV;
        // سطر النسبة
        y -= subH;
        String pctLine = "أنجزت " + WidgetData.arDigits(pct) + "٪ · اضغط للمتابعة";
        StaticLayout pl = layout(pctLine, subP, (int) bw, Layout.Alignment.ALIGN_NORMAL, subH, 1);
        draw(c, pl, bx, y);
        // شريط التقدم (يبدأ من اليمين)
        y -= 3 + 6;
        Paint bar = new Paint(Paint.ANTI_ALIAS_FLAG);
        bar.setColor(pal.track);
        c.drawRoundRect(new RectF(bx, y, bx + bw, y + 6), 3, 3, bar);
        float fw = (float) (bw * Math.max(0, Math.min(1, progress)));
        if (fw > 0.5f) {
            bar.setColor(pal.fill);
            c.drawRoundRect(new RectF(bx + bw - fw, y, bx + bw, y + 6), 3, 3, bar);
        }
        // العنوان
        y -= 9 + titleH;
        StaticLayout tl = layout(titles[slot], titleP, (int) bw, Layout.Alignment.ALIGN_NORMAL, titleH, 1);
        draw(c, tl, bx, y);
        // «حان وقت» / «بعد الفجر»
        if (!compact) {
            y -= 3 + subH - 2;
            StaticLayout fl = layout(prefix, subP, (int) bw, Layout.Alignment.ALIGN_NORMAL, subH, 1);
            draw(c, fl, bx, y);
        }
        return b;
    }

    private static final class Hint {
        final int icon;
        final String text;
        Hint(int icon, String text) { this.icon = icon; this.text = text; }
    }

    /** نفس منطق _hintFor في home_screen.dart. */
    private static Hint hintFor(Calendar n, WidgetData.Next next, long now) {
        if (next != null) {
            long m = (next.time - now) / 60000L;
            if (m >= 0 && m <= 25) {
                return new Hint(ICON_CLOCK, m <= 1
                        ? "حان وقت صلاة " + next.name() + " تقريبًا"
                        : "صلاة " + next.name() + " بعد " + WidgetData.arDigits(m) + " دقيقة");
            }
        }
        int h = n.get(Calendar.HOUR_OF_DAY);
        int dow = n.get(Calendar.DAY_OF_WEEK);
        if (dow == Calendar.FRIDAY && h >= 6 && h < 15) {
            return new Hint(ICON_QURAN, "يوم الجمعة · سورة الكهف وكثرة الصلاة على النبي ﷺ");
        }
        if ((dow == Calendar.MONDAY || dow == Calendar.THURSDAY) && h >= 3 && h < 12) {
            return new Hint(ICON_SPARKLE, "اليوم " + (dow == Calendar.MONDAY ? "الإثنين" : "الخميس") + " · يُستحب صيامه");
        }
        if (h >= 3 && h < 6) return new Hint(ICON_SUN, "بعد الفجر · ابدأ يومك بالأذكار والقرآن");
        if (h >= 6 && h < 9) return new Hint(ICON_SUN, "بكّر بأذكار الصباح ثم اقرأ وردك");
        if (h >= 9 && h < 12) return new Hint(ICON_SUN, "وقت صلاة الضحى · ركعتان أو أكثر");
        if (h >= 12 && h < 15) return new Hint(ICON_QURAN, "خذ لك وردًا من القرآن بعد الظهر");
        if (h >= 15 && h < 19) return new Hint(ICON_SUNSET, "أذكار المساء بعد العصر");
        if (h >= 19 && h < 21) return new Hint(ICON_MOON, "أذكار المساء، وراجع وردك قبل النوم");
        if (h >= 21 || h < 1) return new Hint(ICON_MOON, "قبل النوم · آية الكرسي والمعوذات");
        return new Hint(ICON_MOON, "الثلث الأخير من الليل · وقت الدعاء والاستغفار");
    }

    // =====================================================================
    //  ٢) آية اليوم
    // =====================================================================
    static final float CARD_RADIUS = 18f;

    private static void pattern(Canvas c, float w, float h, float opacity) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1f);
        p.setColor(HeroArt.alpha(PATTERN_GOLD, opacity));
        Path star = HeroArt.starPath();
        for (float y = 0; y < h; y += 44) {
            for (float x = 0; x < w; x += 44) {
                c.save();
                c.translate(x, y);
                c.drawPath(star, p);
                c.restore();
            }
        }
    }

    private static void dashedBorder(Canvas c, float w, float h, float r, int color) {
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1f);
        p.setColor(color);
        p.setPathEffect(new DashPathEffect(new float[]{3, 3}, 0));
        c.drawRoundRect(new RectF(.5f, .5f, w - .5f, h - .5f), r, r, p);
    }

    static Bitmap ayah(Context ctx, WidgetData d, float w, float h, float scale, long now) {
        fonts(ctx);
        Tk tk = tokens(ctx, d);
        Bitmap b = newBitmap(w, h, scale);
        Canvas c = new Canvas(b);
        c.scale(scale, scale);
        Paint bg = new Paint(Paint.ANTI_ALIAS_FLAG);
        bg.setColor(tk.bg);
        c.drawRect(0, 0, w, h, bg);
        pattern(c, w, h, .18f);
        maskRounded(c, w, h, CARD_RADIUS);

        WidgetData.Ayah a = d.ayahFor(WidgetData.dayKey(now));
        String text = a != null ? a.text : "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ";
        String ref = a != null ? a.ref : "سورة الرعد · ٢٨";

        float padX = 16, padY = 12;
        int tw = (int) (w - padX * 2);
        float availH = h - padY * 2;
        float head = 11.5f * 1.5f, foot = 11.5f * 1.5f, gaps = 4;
        // FittedBox(scaleDown): نصغّر خط الآية حتى تتّسع.
        float size = 21f;
        StaticLayout al;
        while (true) {
            TextPaint ap = tp(amiri, size, tk.ink);
            al = layout("﴿ " + text + " ﴾", ap, tw, Layout.Alignment.ALIGN_CENTER, size * 1.7f, 0);
            if (al.getHeight() + head + foot + gaps <= availH || size <= 11) break;
            size -= 1;
        }
        float total = head + foot + gaps + al.getHeight();
        float y = padY + Math.max(0, (availH - total) / 2f);
        center(c, "آية اليوم", w / 2f, y, head, tp(cairoSemi, 11.5f, tk.gold));
        y += head + 2;
        draw(c, al, padX, y);
        y += al.getHeight() + 2;
        center(c, ref, w / 2f, y, foot, tp(cairoSemi, 11.5f, tk.gold));

        dashedBorder(c, w, h, CARD_RADIUS, tk.gold);
        return b;
    }

    // =====================================================================
    //  ٣) الصلاة القادمة
    // =====================================================================
    static final class PrayerView {
        Bitmap bitmap;
        WidgetData.Next next; // null لو لا مواقيت
    }

    static String clock12(long ms) {
        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(ms);
        int h = c.get(Calendar.HOUR_OF_DAY), m = c.get(Calendar.MINUTE);
        boolean pm = h >= 12;
        int h12 = h % 12 == 0 ? 12 : h % 12;
        return WidgetData.arDigits(h12) + ":" + WidgetData.arDigits(m / 10) + WidgetData.arDigits(m % 10)
                + (pm ? " م" : " ص");
    }

    /** نصيحة تُختار حسب قرب الصلاة وحالة «صليت» ولا تتغيّر عشوائيًا بين التحديثات. */
    static String tip(WidgetData d, WidgetData.Next next, long now) {
        if (next == null) return "افتح التطبيق واختر مدينتك لتظهر مواقيت الصلاة هنا.";
        Calendar cal = Calendar.getInstance();
        cal.setTimeInMillis(now);
        int seed = cal.get(Calendar.DAY_OF_YEAR) + next.index;
        long minsLeft = (next.time - now) / 60000L;
        WidgetData.Next prev = d.prevPrayer(now);
        if (prev != null) {
            long since = (now - prev.time) / 60000L;
            if (since >= 0 && since <= 40) {
                String pn = prev.name();
                if (prev.day.done[prev.index]) {
                    return "تقبّل الله صلاتك. " + pn + " تمّت، كمّل على كده.";
                }
                String[] nudge = {
                        "دخل وقت " + pn + " ولسه ما صلّيتش! قم صلّي وارجع، الموبايل مش هيهرب.",
                        pn + " بتنتظرك… خمس دقايق وتخلص وترتاح.",
                        "لا تؤجّل " + pn + "، اللي تؤجّله اليوم يتراكم بكرة.",
                        "يلا بينا على " + pn + "! بعدها كمّل اللي كنت فيه."};
                return nudge[seed % nudge.length];
            }
        }
        if (minsLeft <= 25) {
            String[] soon = {
                    "اقتربت صلاة " + next.name() + "، توضّأ وتهيّأ.",
                    "ثواني ويدخل وقت " + next.name() + "… جهّز نفسك.",
                    "خلّص اللي في إيدك، " + next.name() + " على الأبواب."};
            return soon[seed % soon.length];
        }
        if (minsLeft <= 90) {
            String[] near = {
                    "قرب الموعد، رتّب أمورك وخذ نفسًا قبل الصلاة.",
                    "هل توضّأت؟ جهّز نفسك وسجّادتك من دلوقتي.",
                    "اترك الشاشة شوية، ربّك ينتظرك."};
            return near[seed % near.length];
        }
        String[] far = {
                "الصلاة راحة بين مشاغل اليوم، حافظ على موعدك معها.",
                "خمس مواعيد في اليوم مع ربّك… لا تفوّت واحدًا.",
                "ابدأ بنية صغيرة: صلاة واحدة في وقتها اليوم.",
                "قلبك محتاج وقفة هادئة، والصلاة تجيبهالك."};
        return far[seed % far.length];
    }

    static PrayerView prayer(Context ctx, WidgetData d, float w, float h, float scale, long now) {
        fonts(ctx);
        Tk tk = tokens(ctx, d);
        PrayerView out = new PrayerView();
        Bitmap b = newBitmap(w, h, scale);
        Canvas c = new Canvas(b);
        c.scale(scale, scale);

        Paint bg = new Paint(Paint.ANTI_ALIAS_FLAG);
        bg.setColor(tk.card);
        c.drawRect(0, 0, w, h, bg);
        pattern(c, w, h, .10f);
        maskRounded(c, w, h, CARD_RADIUS);
        Paint border = new Paint(Paint.ANTI_ALIAS_FLAG);
        border.setStyle(Paint.Style.STROKE);
        border.setStrokeWidth(1f);
        border.setColor(tk.line);
        c.drawRoundRect(new RectF(.5f, .5f, w - .5f, h - .5f), CARD_RADIUS, CARD_RADIUS, border);

        WidgetData.Next next = d.nextPrayer(now);
        out.next = next;
        String today = WidgetData.dayKey(now);
        WidgetData.Day day = d.dayFor(today);
        float pad = 14, rightEdge = w - pad;

        // الصف الأول: أيقونة + «الصلاة القادمة» (يمين) / التاريخ الهجري (يسار)
        icon(c, ICON_CLOCK, rightEdge - 20, pad - 1, 20, tk.gold);
        right(c, "الصلاة القادمة", rightEdge - 26, pad, 18, tp(cairoSemi, 12f, tk.muted));
        if (day != null && !day.hijri.isEmpty()) {
            TextPaint hp = tp(cairoSemi, 11f, tk.muted);
            float tw = hp.measureText(day.hijri);
            float pw = Math.min(tw + 20, w * .48f), ph = 24;
            Paint dp = new Paint(Paint.ANTI_ALIAS_FLAG);
            dp.setStyle(Paint.Style.STROKE);
            dp.setStrokeWidth(1f);
            dp.setColor(tk.gold);
            dp.setPathEffect(new DashPathEffect(new float[]{3, 3}, 0));
            c.drawRoundRect(new RectF(pad, pad - 3, pad + pw, pad - 3 + ph), 12, 12, dp);
            center(c, day.hijri, pad + pw / 2f, pad - 3, ph, hp);
        }

        // الصف الثاني: اسم الصلاة + وقتها (يمين) ، العدّاد (يسار: Chronometer فوق الصورة)
        float y = 42;
        String name = next == null ? "حدّد موقعك" : next.name();
        TextPaint np = tp(amiriBold, 32f, tk.ink);
        right(c, name, rightEdge, y, 38, np);
        if (next != null) {
            right(c, clock12(next.time), rightEdge, y + 38, 20, tp(cairoBold, 15f, tk.gold));
            center(c, "المتبقي", pad + 43, y + 2, 16, tp(cairo, 10.5f, tk.muted));
        }
        y += 38 + 20 + 6;

        // النصيحة
        boolean showChips = h >= 190;
        float tipH = (h >= 150) ? 38 : 24;
        if (y + tipH + 8 <= h) {
            Paint mint = new Paint(Paint.ANTI_ALIAS_FLAG);
            mint.setColor(tk.mint);
            c.drawRoundRect(new RectF(pad, y, w - pad, y + tipH), 12, 12, mint);
            TextPaint tpnt = tp(cairoSemi, 11.5f, tk.mintInk);
            int maxLines = tipH > 30 ? 2 : 1;
            StaticLayout tl = layout(tip(d, next, now), tpnt, (int) (w - pad * 2 - 20), Layout.Alignment.ALIGN_NORMAL, 11.5f * 1.4f, maxLines);
            draw(c, tl, pad + 10, y + (tipH - tl.getHeight()) / 2f);
            y += tipH + 8;
        }

        // صف الصلوات الخمس
        if (showChips && day != null && y + 40 <= h - 6) {
            float gap = 6;
            float cw = (w - pad * 2 - gap * 4) / 5f;
            for (int i = 0; i < 5; i++) {
                // RTL: الفجر في أقصى اليمين.
                float x1 = w - pad - i * (cw + gap), x0 = x1 - cw;
                boolean isNext = next != null && next.day == day && next.index == i;
                boolean done = day.done[i];
                Paint chip = new Paint(Paint.ANTI_ALIAS_FLAG);
                chip.setColor(isNext ? tk.mint : tk.bg);
                RectF r = new RectF(x0, y, x1, y + 40);
                c.drawRoundRect(r, 10, 10, chip);
                chip.setStyle(Paint.Style.STROKE);
                chip.setStrokeWidth(1f);
                chip.setColor(isNext ? tk.gold : tk.line);
                c.drawRoundRect(new RectF(x0 + .5f, y + .5f, x1 - .5f, y + 39.5f), 10, 10, chip);
                center(c, WidgetData.PRAYER_NAMES[i], (x0 + x1) / 2f, y + 4, 17, tp(cairoSemi, 11.5f, done ? tk.muted : tk.ink));
                long tm = day.t[WidgetData.PRAYER_SLOT[i]];
                center(c, tm > 0 ? clock12(tm) : "—", (x0 + x1) / 2f, y + 21, 15, tp(cairo, 10.5f, isNext ? tk.gold : tk.muted));
                if (done) {
                    Paint ck = new Paint(Paint.ANTI_ALIAS_FLAG);
                    ck.setColor(tk.leaf);
                    c.drawCircle(x0 + 7, y + 7, 3, ck);
                }
            }
        }
        out.bitmap = b;
        return out;
    }
}
