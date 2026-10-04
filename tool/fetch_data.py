#!/usr/bin/env python3
"""يجلب بيانات القرآن والخطوط من مصادر خارجية ويتحقق منها قبل البناء.
أي فشل في التحقق يوقف البناء ولا يُكتب ملف ناقص أو مشوَّه.
الاستخدام: python3 tool/fetch_data.py
"""
import hashlib, json, os, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QURAN_URL = "https://api.alquran.cloud/v1/quran/quran-uthmani"
FONTS = {
    "AmiriQuran-Regular.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/amiriquran/AmiriQuran-Regular.ttf",
    "Tajawal-Regular.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal/Tajawal-Regular.ttf",
    "Tajawal-Medium.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal/Tajawal-Medium.ttf",
    "Amiri-Regular.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Regular.ttf",
    "Amiri-Bold.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Bold.ttf",
    "Cairo.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/cairo/Cairo%5Bslnt%2Cwght%5D.ttf",
    "Tajawal-Bold.ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal/Tajawal-Bold.ttf",
}

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "azkari-build"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()

def fail(msg):
    print("خطأ في التحقق:", msg, file=sys.stderr)
    sys.exit(1)

def fetch_fonts():
    d = os.path.join(ROOT, "assets", "fonts")
    os.makedirs(d, exist_ok=True)
    for name, url in FONTS.items():
        data = get(url)
        if len(data) < 30000 or data[:4] not in (b"\x00\x01\x00\x00", b"true", b"OTTO"):
            fail(f"الخط {name} غير صالح")
        open(os.path.join(d, name), "wb").write(data)
        print("font ok:", name, len(data))

def fetch_quran():
    raw = get(QURAN_URL)
    sha = hashlib.sha256(raw).hexdigest()
    j = json.loads(raw.decode("utf-8"))
    if j.get("code") != 200:
        fail("استجابة غير ناجحة من المصدر")
    surahs = j["data"]["surahs"]
    if len(surahs) != 114:
        fail(f"عدد السور {len(surahs)} بدل 114")

    # يعود المصدر أحيانًا بمحرف BOM في بداية أول آية فقط.
    basmala = surahs[0]["ayahs"][0]["text"].lstrip("\ufeff")
    # السورتان 95 و97 تستخدمان شدة مختلفة على الباء في المصدر.
    basmala_variants = (basmala, basmala.replace("بِسْمِ", "بِّسْمِ"))
    total = 0
    stripped = 0
    out_surahs, out_ayahs = [], []
    prev_juz, prev_page = 1, 1
    for i, s in enumerate(surahs, start=1):
        if s["number"] != i:
            fail(f"ترتيب السور مختل عند {i}")
        ayahs = s["ayahs"]
        # بعض استجابات alquran.cloud الحديثة لا تعيد numberOfAyahs؛
        # نستخدم عدد الآيات الفعلي عند غياب الحقل، مع إبقاء التحقق
        # عند وجوده.
        expected_ayahs = s.get("numberOfAyahs", len(ayahs))
        if len(ayahs) != expected_ayahs:
            fail(f"عدد آيات سورة {i} لا يطابق الوصف")
        # نحتفظ بالاسم كما يورده المصدر، بما فيه كلمة «سورة».
        name = s["name"].strip()
        out_surahs.append([i, name, 1 if s["revelationType"] == "Meccan" else 0, len(ayahs)])
        for k, a in enumerate(ayahs, start=1):
            if a["numberInSurah"] != k:
                fail(f"ترقيم آيات سورة {i} مختل عند {k}")
            text = a["text"].lstrip("\ufeff")
            if k == 1 and i not in (1, 9):
                for prefix in basmala_variants:
                    if text.startswith(prefix):
                        text = text[len(prefix):].lstrip()
                        stripped += 1
                        break
            if not text.strip():
                fail(f"آية فارغة {i}:{k}")
            if a["juz"] < prev_juz or a["page"] < prev_page:
                fail(f"الجزء أو الصفحة يتراجع عند {i}:{k}")
            prev_juz, prev_page = a["juz"], a["page"]
            out_ayahs.append([i, k, text, a["juz"], a["page"], a["hizbQuarter"], 1 if a.get("sajda") else 0])
            total += 1
    if total != 6236:
        fail(f"عدد الآيات {total} بدل 6236")
    if stripped != 112:
        fail(f"عدد البسملات المفصولة {stripped} بدل 112؛ افحص شكل البسملة في المصدر")
    if out_ayahs[-1][3] != 30 or out_ayahs[-1][4] != 604:
        fail("آخر آية ليست في الجزء 30 والصفحة 604")

    d = os.path.join(ROOT, "assets", "data")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "quran.json"), "w", encoding="utf-8") as f:
        json.dump({"basmala": basmala, "surahs": out_surahs, "ayahs": out_ayahs}, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(d, "SOURCES.json"), "w", encoding="utf-8") as f:
        json.dump({"quran": {"source": QURAN_URL, "edition": "quran-uthmani (نص عثماني)", "sha256_raw": sha,
                             "surahs": 114, "ayahs": total}}, f, ensure_ascii=False, indent=2)
    print("quran ok:", total, "ayahs, sha256", sha[:12])

if __name__ == "__main__":
    fetch_fonts()
    fetch_quran()
