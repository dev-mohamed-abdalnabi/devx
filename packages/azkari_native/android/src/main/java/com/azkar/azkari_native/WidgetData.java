package com.azkar.azkari_native;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

/**
 * لقطة البيانات التي يرسلها Flutter (مواقيت ٤٠ يومًا + آية كل يوم + تقدم الأذكار + الثيم).
 * الودجت تقرأها محليًا فقط، فتعمل والتطبيق مغلق بدون أي محرّك Flutter.
 */
final class WidgetData {
    static final String PREFS = "azkari_widgets";
    static final String KEY = "snapshot";

    static final String[] PRAYER_NAMES = {"الفجر", "الظهر", "العصر", "المغرب", "العشاء"};
    /** موضع كل صلاة من الخمس داخل مصفوفة t (فجر، شروق، ظهر، عصر، مغرب، عشاء). */
    static final int[] PRAYER_SLOT = {0, 2, 3, 4, 5};

    static final class Day {
        String key = "";
        String hijri = "";
        final long[] t = new long[6];
        final boolean[] done = new boolean[5];
    }

    static final class Ayah {
        String day = "", text = "", ref = "";
    }

    static final class Next {
        final int index; // 0..4
        final long time;
        final Day day;
        Next(int index, long time, Day day) {
            this.index = index;
            this.time = time;
            this.day = day;
        }
        String name() { return PRAYER_NAMES[index]; }
    }

    String theme = "system";
    String azkarDay = "";
    final double[] azkar = new double[3]; // صباح، مساء، نوم
    boolean hasLocation = false;
    String place = "";
    final List<Day> days = new ArrayList<>();
    final List<Ayah> ayahs = new ArrayList<>();

    static WidgetData load(Context ctx) {
        WidgetData d = new WidgetData();
        try {
            SharedPreferences sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            String raw = sp.getString(KEY, null);
            if (raw == null) return d;
            JSONObject j = new JSONObject(raw);
            d.theme = j.optString("theme", "system");
            d.azkarDay = j.optString("azkarDay", "");
            JSONArray az = j.optJSONArray("azkar");
            if (az != null) for (int i = 0; i < 3 && i < az.length(); i++) d.azkar[i] = az.optDouble(i, 0);
            d.hasLocation = j.optBoolean("loc", false);
            d.place = j.optString("place", "");
            JSONArray ds = j.optJSONArray("days");
            if (ds != null) {
                for (int i = 0; i < ds.length(); i++) {
                    JSONObject o = ds.getJSONObject(i);
                    Day day = new Day();
                    day.key = o.optString("d");
                    day.hijri = o.optString("h");
                    JSONArray t = o.optJSONArray("t");
                    if (t != null) for (int k = 0; k < 6 && k < t.length(); k++) day.t[k] = t.optLong(k, 0);
                    JSONArray dn = o.optJSONArray("done");
                    if (dn != null) for (int k = 0; k < 5 && k < dn.length(); k++) day.done[k] = dn.optInt(k, 0) == 1;
                    d.days.add(day);
                }
            }
            JSONArray as = j.optJSONArray("ayahs");
            if (as != null) {
                for (int i = 0; i < as.length(); i++) {
                    JSONObject o = as.getJSONObject(i);
                    Ayah a = new Ayah();
                    a.day = o.optString("d");
                    a.text = o.optString("t");
                    a.ref = o.optString("r");
                    d.ayahs.add(a);
                }
            }
        } catch (Exception ignored) {
            // لقطة تالفة: نعرض الحالة الافتراضية حتى يفتح المستخدم التطبيق.
        }
        return d;
    }

    static String dayKey(long ms) {
        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(ms);
        return String.format(Locale.US, "%04d-%02d-%02d",
                c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH));
    }

    Day dayFor(String key) {
        for (Day d : days) if (d.key.equals(key)) return d;
        return null;
    }

    Ayah ayahFor(String key) {
        for (Ayah a : ayahs) if (a.day.equals(key)) return a;
        return null;
    }

    /** أول صلاة (من الخمس) بعد [now]، عبر الأيام المتتالية. */
    Next nextPrayer(long now) {
        for (Day d : days) {
            for (int i = 0; i < 5; i++) {
                long t = d.t[PRAYER_SLOT[i]];
                if (t > now) return new Next(i, t, d);
            }
        }
        return null;
    }

    /** آخر صلاة بدأ وقتها قبل [now]. */
    Next prevPrayer(long now) {
        Next best = null;
        for (Day d : days) {
            for (int i = 0; i < 5; i++) {
                long t = d.t[PRAYER_SLOT[i]];
                if (t > 0 && t <= now && (best == null || t > best.time)) best = new Next(i, t, d);
            }
        }
        return best;
    }

    double azkarProgress(int slot, String today) {
        return azkarDay.equals(today) ? Math.max(0, Math.min(1, azkar[slot])) : 0;
    }

    static String arDigits(long n) {
        String s = Long.toString(n);
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            b.append(c >= '0' && c <= '9' ? (char) ('\u0660' + (c - '0')) : c);
        }
        return b.toString();
    }
}
