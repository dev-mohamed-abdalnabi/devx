#!/usr/bin/env python3
"""يجلب تخطيط مصحف المدينة (١٥ سطرًا) وخطوط صفحات QCF أثناء البناء.

المخرجات:
  assets/data/mushaf.json   تخطيط كل صفحة: صفوف (نص / عنوان سورة / بسملة / فارغ)
  assets/qcf/pNNN.ttf       خط كل صفحة (٦٠٤ خطًا)

أي فشل لا يكسر البناء: يُكتب ملف mushaf.json فارغ (v=0) فيعود التطبيق
تلقائيًا إلى المحرك القديم. السكربت idempotent: إن وُجدت بيانات سليمة يتخطى.

متغيرات بيئة اختيارية لتغيير المصادر:
  QCF_API_BASE   مثل https://api.quran.com/api/v4
  QCF_FONT_URL   قالب فيه {p} لرقم الصفحة (مثل .../p{p}.ttf)
"""
import concurrent.futures as cf
import html
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_FILE = os.path.join(ROOT, "assets", "data", "mushaf.json")
FONT_DIR = os.path.join(ROOT, "assets", "qcf")
PAGES = 604

API_BASES = [b for b in [
    os.environ.get("QCF_API_BASE"),
    "https://api.quran.com/api/v4",
    "https://api.qurancdn.com/api/qdc",
] if b]

FONT_URLS = [u for u in [
    os.environ.get("QCF_FONT_URL"),
    "https://verses.quran.foundation/fonts/quran/hafs/v1/ttf/p{p}.ttf",
    "https://static.qurancdn.com/fonts/quran/hafs/v1/ttf/p{p}.ttf",
    "https://verses.quran.com/fonts/quran/hafs/v1/ttf/p{p}.ttf",
    "https://quran.com/fonts/quran/hafs/v1/ttf/p{p}.ttf",
    "https://verses.quran.foundation/fonts/quran/hafs/v1/woff2/p{p}.woff2",
    "https://static.qurancdn.com/fonts/quran/hafs/v1/woff2/p{p}.woff2",
    "https://verses.quran.com/fonts/quran/hafs/v1/woff2/p{p}.woff2",
    "https://quran.com/fonts/quran/hafs/v1/woff2/p{p}.woff2",
] if u]

UA = {"User-Agent": "Mozilla/5.0 (azkar-app build)"}


def get(url, tries=4):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (404, 403, 401):
                break
            time.sleep(2 * (i + 1) if e.code != 429 else 8 * (i + 1))
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"{url}: {last}")


def pad(p):
    return f"{p:03d}"


# ───────────────────────── تصنيف الأسطر (دالة نقية قابلة للاختبار)

def build_rows(lines, slots):
    """lines: {رقم_السطر: [[verse_key, code], ...]} → قائمة صفوف بطول slots."""
    rows = []
    n = 1
    while n <= slots:
        if n in lines:
            rows.append(["t", lines[n]])
            n += 1
            continue
        a = n
        while n <= slots and n not in lines:
            n += 1
        run = n - a  # عدد الأسطر الفارغة المتتالية
        kinds = ["e"] * run
        if n <= slots:  # يتبعها سطر نص
            first_key = lines[n][0][0]
            s, ay = first_key.split(":")
            prev_has_same = (a - 1) in lines and any(w[0] == first_key for w in lines[a - 1])
            if ay == "1" and not prev_has_same:
                surah = int(s)
                if surah in (1, 9) or run == 1:
                    kinds[-1] = ["b", surah]
                else:
                    kinds[-2] = ["b", surah]
                    kinds[-1] = ["m"]
        for k in kinds:
            rows.append(k if isinstance(k, list) else [k])
    return rows


# ───────────────────────── البيانات

def pick_api():
    errs = []
    for base in API_BASES:
        try:
            page = fetch_page(base, 1)
            if page:
                return base
        except Exception as e:  # noqa: BLE001
            errs.append(str(e))
    raise RuntimeError("لا مصدر بيانات يعمل: " + " | ".join(errs))


def fetch_page(base, p):
    """يرجع {سطر: [[key, code], ...]} لكلمات هذه الصفحة فقط."""
    lines = {}
    page_no = 1
    while True:
        url = (f"{base}/verses/by_page/{p}?words=true&per_page=50&page={page_no}"
               "&word_fields=code_v1,line_number,page_number,v1_page,char_type_name")
        j = json.loads(get(url).decode("utf-8"))
        for v in j.get("verses", []):
            key = v["verse_key"]
            for w in v.get("words", []):
                code = html.unescape(w.get("code_v1") or "")
                if not code:
                    continue
                wp = w.get("v1_page") or w.get("page_number")
                if wp is not None and int(wp) != p:
                    continue
                ln = w.get("line_number")
                if not ln:
                    continue
                lines.setdefault(int(ln), []).append([key, code])
        nxt = (j.get("pagination") or {}).get("next_page")
        if not nxt:
            break
        page_no = nxt
    return lines


def fetch_layout():
    base = pick_api()
    print("API:", base)
    out = [None] * PAGES

    def work(p):
        time.sleep(0.05)
        return p, fetch_page(base, p)

    with cf.ThreadPoolExecutor(max_workers=4) as ex:
        for p, lines in ex.map(work, range(1, PAGES + 1)):
            if not lines:
                raise RuntimeError(f"صفحة {p} بلا كلمات")
            mx = max(lines)
            slots = 8 if p in (1, 2) else 15
            if mx > 15 or mx < 1:
                raise RuntimeError(f"رقم سطر غير متوقع في صفحة {p}: {mx}")
            if p not in (1, 2) and mx < 15 - 4 and p not in (604,):
                print(f"تنبيه: صفحة {p} آخر سطر فيها {mx}")
            out[p - 1] = build_rows(lines, max(slots, mx))
    # تحقق: كل الآيات حاضرة
    keys = set()
    for rows in out:
        for r in rows:
            if r[0] == "t":
                for w in r[1]:
                    keys.add(w[0])
    if len(keys) != 6236:
        raise RuntimeError(f"عدد الآيات في التخطيط {len(keys)} بدل 6236")
    return out


# ───────────────────────── الخطوط

def to_ttf(raw):
    head = raw[:4]
    if head in (b"\x00\x01\x00\x00", b"true", b"OTTO"):
        return raw
    if head in (b"wOF2", b"wOFF"):
        from fontTools.ttLib import TTFont  # يحتاج fonttools (+ brotli لـ woff2)
        f = TTFont(io.BytesIO(raw))
        f.flavor = None
        buf = io.BytesIO()
        f.save(buf)
        return buf.getvalue()
    raise RuntimeError("صيغة خط غير معروفة")


def pick_font_url():
    errs = []
    for t in FONT_URLS:
        try:
            ttf = to_ttf(get(t.format(p=1), tries=2))
            if len(ttf) > 1000:
                return t
        except Exception as e:  # noqa: BLE001
            errs.append(str(e)[:120])
    raise RuntimeError("لا رابط خطوط يعمل: " + " | ".join(errs))


def fetch_fonts(pages_rows):
    os.makedirs(FONT_DIR, exist_ok=True)
    tpl = pick_font_url()
    print("fonts:", tpl)
    try:
        from fontTools.ttLib import TTFont
    except Exception:  # noqa: BLE001
        TTFont = None

    def work(p):
        dst = os.path.join(FONT_DIR, f"p{pad(p)}.ttf")
        if os.path.exists(dst) and os.path.getsize(dst) > 1000:
            ttf = open(dst, "rb").read()
        else:
            ttf = to_ttf(get(tpl.format(p=p)))
            with open(dst, "wb") as f:
                f.write(ttf)
        if TTFont is not None:  # تأكد أن الخط يغطي رموز الصفحة
            cmap = TTFont(io.BytesIO(ttf)).getBestCmap()
            need = {ord(c) for r in pages_rows[p - 1] if r[0] == "t" for w in r[1] for c in w[1]}
            miss = [c for c in need if c not in cmap]
            if miss:
                raise RuntimeError(f"خط صفحة {p} ينقصه {len(miss)} رمزًا")
        return p

    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        list(ex.map(work, range(1, PAGES + 1)))
    # .keep حتى يبقى المجلد أصلًا صالحًا في pubspec
    open(os.path.join(FONT_DIR, ".keep"), "w").close()


# ───────────────────────── الرئيسي

def valid_existing():
    try:
        j = json.load(open(DATA_FILE, encoding="utf-8"))
        if j.get("v") != 1 or len(j.get("pages", [])) != PAGES:
            return False
        return all(os.path.exists(os.path.join(FONT_DIR, f"p{pad(p)}.ttf")) for p in range(1, PAGES + 1))
    except Exception:  # noqa: BLE001
        return False


def write_stub():
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    os.makedirs(FONT_DIR, exist_ok=True)
    open(os.path.join(FONT_DIR, ".keep"), "w").close()
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump({"v": 0, "pages": []}, f)


def main():
    if valid_existing():
        print("mushaf: بيانات سليمة موجودة، تخطي")
        return 0
    try:
        pages = fetch_layout()
        fetch_fonts(pages)
        os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump({"v": 1, "pages": pages}, f, ensure_ascii=False, separators=(",", ":"))
        total = sum(os.path.getsize(os.path.join(FONT_DIR, x)) for x in os.listdir(FONT_DIR))
        print(f"mushaf ok: {PAGES} pages, fonts {total // 1024} KB")
    except Exception as e:  # noqa: BLE001
        print(f"::error::تعذر جلب مصحف المدينة وخطوط QCF: {e}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
