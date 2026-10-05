package com.azkar.azkari_native;

import android.graphics.Path;
import android.graphics.RectF;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** محلل بسيط لـ SVG path (M L H V C Q A Z بحروفها الكبيرة والصغيرة) ليرسم نفس أيقونات التطبيق. */
final class SvgPath {
    private static final Pattern TOKEN =
            Pattern.compile("[MmLlHhVvCcQqAaZz]|-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE]-?\\d+)?");

    private SvgPath() {}

    static Path parse(String d) {
        Path p = new Path();
        List<String> t = new ArrayList<>();
        Matcher m = TOKEN.matcher(d);
        while (m.find()) t.add(m.group());
        int i = 0;
        char cmd = 0;
        double x = 0, y = 0, sx = 0, sy = 0;
        while (i < t.size()) {
            String s = t.get(i);
            if (Character.isLetter(s.charAt(0))) {
                cmd = s.charAt(0);
                i++;
                if (cmd == 'Z' || cmd == 'z') {
                    p.close();
                    x = sx;
                    y = sy;
                    continue;
                }
            }
            boolean rel = Character.isLowerCase(cmd);
            try {
                switch (Character.toUpperCase(cmd)) {
                    case 'M': {
                        double nx = num(t, i++), ny = num(t, i++);
                        if (rel) { nx += x; ny += y; }
                        p.moveTo((float) nx, (float) ny);
                        x = sx = nx;
                        y = sy = ny;
                        cmd = rel ? 'l' : 'L'; // الأزواج التالية خطوط
                        break;
                    }
                    case 'L': {
                        double nx = num(t, i++), ny = num(t, i++);
                        if (rel) { nx += x; ny += y; }
                        p.lineTo((float) nx, (float) ny);
                        x = nx;
                        y = ny;
                        break;
                    }
                    case 'H': {
                        double nx = num(t, i++);
                        if (rel) nx += x;
                        p.lineTo((float) nx, (float) y);
                        x = nx;
                        break;
                    }
                    case 'V': {
                        double ny = num(t, i++);
                        if (rel) ny += y;
                        p.lineTo((float) x, (float) ny);
                        y = ny;
                        break;
                    }
                    case 'C': {
                        double[] v = new double[6];
                        for (int k = 0; k < 6; k++) v[k] = num(t, i++);
                        if (rel) for (int k = 0; k < 6; k += 2) { v[k] += x; v[k + 1] += y; }
                        p.cubicTo((float) v[0], (float) v[1], (float) v[2], (float) v[3], (float) v[4], (float) v[5]);
                        x = v[4];
                        y = v[5];
                        break;
                    }
                    case 'Q': {
                        double[] v = new double[4];
                        for (int k = 0; k < 4; k++) v[k] = num(t, i++);
                        if (rel) for (int k = 0; k < 4; k += 2) { v[k] += x; v[k + 1] += y; }
                        p.quadTo((float) v[0], (float) v[1], (float) v[2], (float) v[3]);
                        x = v[2];
                        y = v[3];
                        break;
                    }
                    case 'A': {
                        double rx = num(t, i++), ry = num(t, i++);
                        i++; // x-axis-rotation (دائمًا صفر في أيقونات التطبيق)
                        boolean large = num(t, i++) != 0, sweep = num(t, i++) != 0;
                        double nx = num(t, i++), ny = num(t, i++);
                        if (rel) { nx += x; ny += y; }
                        arc(p, x, y, rx, ry, large, sweep, nx, ny);
                        x = nx;
                        y = ny;
                        break;
                    }
                    default:
                        return p; // أمر غير مدعوم: نوقف بدل أن نعلّق
                }
            } catch (RuntimeException e) {
                return p;
            }
        }
        return p;
    }

    private static double num(List<String> t, int i) {
        return Double.parseDouble(t.get(i));
    }

    private static void arc(Path p, double x0, double y0, double rx, double ry,
                            boolean large, boolean sweep, double x, double y) {
        if (rx == 0 || ry == 0 || (x0 == x && y0 == y)) {
            p.lineTo((float) x, (float) y);
            return;
        }
        rx = Math.abs(rx);
        ry = Math.abs(ry);
        double x1p = (x0 - x) / 2, y1p = (y0 - y) / 2;
        double lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
        if (lam > 1) {
            double s = Math.sqrt(lam);
            rx *= s;
            ry *= s;
        }
        double num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
        double den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
        double coef = Math.sqrt(Math.max(0, num / den));
        if (large == sweep) coef = -coef;
        double cxp = coef * (rx * y1p / ry);
        double cyp = coef * -(ry * x1p / rx);
        double cx = cxp + (x0 + x) / 2, cy = cyp + (y0 + y) / 2;
        double th1 = Math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx);
        double th2 = Math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx);
        double dth = th2 - th1;
        if (!sweep && dth > 0) dth -= 2 * Math.PI;
        if (sweep && dth < 0) dth += 2 * Math.PI;
        p.arcTo(new RectF((float) (cx - rx), (float) (cy - ry), (float) (cx + rx), (float) (cy + ry)),
                (float) Math.toDegrees(th1), (float) Math.toDegrees(dth));
    }
}
