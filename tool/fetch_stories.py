#!/usr/bin/env python3
"""يجلب كتبًا سردية معتمدة لقسم «حكايات الوحي» من مشروع OpenITI (أصلها المكتبة الشاملة).

لا يُكتب أي نص هنا ولا يُعاد تأليفه: النص منقول كما هو، ونحذف فقط علامات التنسيق
وأرقام الصفحات (نفس معالج الفقه في fetch_library.py).

المصادر (أكثر من مصدر لكل قسم، وكل مصدر يُعرض باسمه وتنبيهه):
  * السيرة:        نور اليقين — الخضري (ت ١٣٤٥هـ، أسلوب حديث مبسّط)  +  السيرة النبوية — ابن هشام
  * الأنبياء:      قصص الأنبياء — ابن كثير
  * قصص القرآن:    البداية والنهاية (الجزء الثاني) — ابن كثير: تُستخرج منه الأقسام التي تكمّل
                   القصص القرآنية (الكهف، ذو القرنين، الجنتين، أصحاب الجنة، لقمان، الأخدود…)
                   + قصص الأنبياء لابن كثير لما يوافقها.

تنبيه علمي: هذه كتب تاريخ وتفسير لا «صحاح»؛ فيها روايات لم تصح وأخبار إسرائيلية. تُعرض
بوسم يوضح ذلك، ولا يُنسب شيء منها إلى الحديث الصحيح. الصحيح في القصة هو الآيات والأحاديث.

آلية التثبيت (لأن الـcommit لم يكن معروفًا عند كتابة السكربت):
  * أول تشغيل: يكتشف الملف عبر GitHub API، يسجّل (commit + رابط raw + SHA-256) في
    tool/stories_sources.lock.json، ثم يبني. ارفع ملف القفل إلى المستودع.
  * ما بعده: يقرأ من الروابط المثبّتة ويتحقق من SHA-256، فاختلافها يوقف البناء.
أي فشل في كتاب «مطلوب» (required) يوقف السكربت برمز 1 ولا يُكتب أي ملف ناقص.
كتاب «اختياري» يفشل جلبه يُتخطّى مع تحذير واضح، ويظهر في تقرير التغطية.

بعد كل تشغيل يُطبع (ويُكتب في tool/stories_coverage.txt) تقرير: لكل قصة، أي أقسام من
كل كتاب طابقت عنوانها. أي قصة بلا مطابقة تظهر فيه صراحةً.

الاستخدام:  python3 tool/fetch_stories.py [--local-dir <مجلد به الملفات الخام>]
الإخراج:    assets/stories/books/index.json + <id>.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import sys
import time
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fetch_library as fl  # noqa: E402  (parse_openiti, norm helpers)
from build_stories import KW, QURAN_ONLY, SEERAH  # noqa: E402  (كلمات مطابقة العناوين)

ROOT = HERE.parent
OUT = ROOT / "assets" / "stories" / "books"
LOCK = HERE / "stories_sources.lock.json"
REPORT = HERE / "stories_coverage.txt"

# الترتيب هنا هو ترتيب ظهور المصادر داخل القصة: الأحدث أسلوبًا أولًا.
BOOKS = [
    dict(
        id="nur_yaqin",
        repo="1350AH", author="1345IbnCafifiKhudari", book_hint=("NurYaqin", "Yaqin"),
        title="نور اليقين في سيرة سيد المرسلين", author_name="محمد الخضري بك (ت ١٣٤٥هـ)",
        desc="سيرة مختصرة بأسلوب حديث مبسّط مرتبة بالأحداث",
        style="أسلوب حديث مبسّط",
        notice="كتاب سيرة مختصر حديث العهد، لا يلتزم بتخريج الأسانيد؛ يُقرأ لمعرفة الأحداث "
               "ومجراها، ويُرجع في الثابت إلى الآيات والأحاديث الصحيحة المعروضة في القصة.",
        serves=["seerah"], mode="whole", required=False, hidden=False,
        min_chars=100_000,
        must_have=["بدر", "احد", "الخندق", "حنين"],
    ),
    dict(
        id="sira_ibn_hisham",
        repo="0225AH", author="0213IbnHisham", book_hint=("SiraNabawiyya", "Sira"),
        title="السيرة النبوية", author_name="ابن هشام (ت ٢١٨هـ)",
        desc="تهذيب ابن هشام لسيرة محمد بن إسحاق",
        style="أسلوب تراثي",
        notice="من أقدم كتب السيرة، وفيه روايات منقطعة وضعيفة وأشعار وأنساب؛ "
               "يُقرأ بوصفه مصدرًا تاريخيًا لا حديثًا صحيحًا.",
        serves=["seerah"], mode="whole", required=True, hidden=False,
        min_chars=400_000,
        must_have=["الهجره", "بدر", "احد", "الخندق", "حنين"],
    ),
    dict(
        id="qisas_anbiya",
        repo="0775AH", author="0774IbnKathir", book_hint=("QisasAnbiya", "Qisas"),
        title="قصص الأنبياء", author_name="الحافظ ابن كثير (ت ٧٧٤هـ)",
        desc="قصص الأنبياء عليهم السلام من القرآن والسنة وما نقله أهل العلم",
        style="أسلوب تراثي",
        notice="كتاب تاريخ وتفسير؛ قد يذكر روايات لم تصح وأخبارًا إسرائيلية للاستئناس. "
               "ما لم يثبت بالقرآن أو الحديث الصحيح لا يُعدّ من الدين.",
        serves=["prophets", "quran"], mode="whole", required=True, hidden=False,
        min_chars=100_000,
        must_have=["ادم", "نوح", "ابراهيم", "موسي", "عيسي"],
    ),
    dict(
        id="bidaya",
        repo="0775AH", author="0774IbnKathir", book_hint=("BidayaWaNihaya", "Bidaya"),
        title="البداية والنهاية (مقتطفات القصص القرآنية)", author_name="الحافظ ابن كثير (ت ٧٧٤هـ)",
        desc="الأقسام التي تكمّل القصص القرآنية، منقولة كما هي من الجزء الثاني",
        style="أسلوب تراثي",
        notice="كتاب تاريخ جامع؛ يذكر أخبارًا عن أهل الكتاب وغيرهم مما لم يثبت، وكثيرًا ما "
               "ينبّه ابن كثير عليها. ما لم يثبت بالقرآن أو الحديث الصحيح لا يُعدّ من الدين.",
        serves=["quran"], mode="excerpt", required=False, hidden=True,
        min_chars=3_000_000,
        must_have=["الكهف", "لقمان", "الاخدود", "القرنين"],
    ),
]

MAX_ROOTS = 3          # أقصى عدد أقسام (جذور) تُستخرج لكل قصة من كتاب مقتطفات
MAX_BLOCK = 60         # أقصى عدد أقسام فرعية تُضمّ تحت جذر واحد
MIN_BLOCK_CHARS = 300  # جذر أقصر من هذا يُتجاهل (إشارة عابرة لا قصة)


def fail(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def http(url: str, api: bool = False) -> bytes:
    headers = {"User-Agent": "azkari-build/1.0"}
    tok = os.environ.get("GITHUB_TOKEN")
    if api and tok:
        headers["Authorization"] = f"Bearer {tok}"
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers),
                                        timeout=180) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001
            if attempt == 3:
                fail(f"download failed: {url}: {e}")
            time.sleep(3 * (attempt + 1))
    return b""


def api_json(path: str):
    return json.loads(http("https://api.github.com" + path, api=True).decode("utf-8"))


def discover(b: dict) -> dict:
    """يجد ملف النص العربي للكتاب في مستودع OpenITI، ويعيد (commit, url)."""
    base = f"/repos/OpenITI/{b['repo']}/contents/data/{b['author']}"
    try:
        dirs = [d["name"] for d in api_json(base) if d["type"] == "dir"]
    except SystemExit:
        fail(f"{b['id']}: لم أجد المؤلف {b['author']} في {b['repo']}")
    cands = [d for d in dirs if any(h in d for h in b["book_hint"])]
    if not cands:
        fail(f"{b['id']}: لا كتاب يطابق {b['book_hint']} عند {b['author']}. الموجود: {dirs}")
    # يُفضَّل الاسم الأطول تطابقًا مع التلميح الأول
    cands.sort(key=lambda d: (b["book_hint"][0] not in d, len(d)))
    book_dir = cands[0]
    files = api_json(f"{base}/{book_dir}")
    texts = [f for f in files if f["type"] == "file" and "-ara" in f["name"]
             and not f["name"].endswith((".yml", ".md", ".json"))]
    if not texts:
        fail(f"{b['id']}: لا ملف نص عربي في {book_dir}: {[f['name'] for f in files]}")
    # أحدث إصدار/أكبر ملف أولًا
    texts.sort(key=lambda f: -f.get("size", 0))
    f = texts[0]
    commits = api_json(f"/repos/OpenITI/{b['repo']}/commits?path={f['path']}&per_page=1")
    if not commits:
        fail(f"{b['id']}: تعذّر تحديد commit للملف {f['path']}")
    sha = commits[0]["sha"]
    url = f"https://raw.githubusercontent.com/OpenITI/{b['repo']}/{sha}/{f['path']}"
    return {"commit": sha, "url": url, "path": f["path"]}


def load_lock() -> dict:
    return json.loads(LOCK.read_text(encoding="utf-8")) if LOCK.exists() else {}


def fetch_book(b: dict, lock: dict, local: pathlib.Path | None) -> tuple[str, dict]:
    pin = lock.get(b["id"])
    if local is not None:
        cand = list(local.glob(f"*{b['book_hint'][0]}*")) or list(local.glob(f"*{b['book_hint'][1]}*"))
        if not cand:
            fail(f"{b['id']}: لا ملف محلي يطابق {b['book_hint']} في {local}")
        data = cand[0].read_bytes()
        pin = pin or {"commit": "local", "url": str(cand[0]), "path": cand[0].name}
    else:
        pin = pin or discover(b)
        data = http(pin["url"])
    digest = hashlib.sha256(data).hexdigest()
    if pin.get("sha256") and pin["sha256"] != digest:
        fail(f"{b['id']}: بصمة الملف تغيّرت عن المثبّتة ({pin['sha256'][:12]} ≠ {digest[:12]})")
    pin["sha256"] = digest
    return data.decode("utf-8"), pin


def fl_norm(s: str) -> str:
    s = re.sub("[\u064B-\u065F\u0670\u0640\u06D6-\u06ED]", "", s)
    for a in "أإآٱ":
        s = s.replace(a, "ا")
    return s.replace("ى", "ي").replace("ة", "ه")


def validate(b: dict, sections: list[dict]):
    chars = sum(len(p) for s in sections for p in s["p"])
    if len(sections) < 8 or chars < b["min_chars"]:
        fail(f"{b['id']}: parsed too little ({len(sections)} sections, {chars} chars)")
    blob = fl_norm(" ".join(s["t"] + " " + " ".join(s["p"]) for s in sections))
    for w in b["must_have"]:
        if w not in blob:
            fail(f"{b['id']}: الكلمة الدالة «{w}» غير موجودة، فالملف غير المتوقع")
    return chars


# ───────────── كتب المقتطفات: نحتفظ بعمق العنوان الأصلي لضمّ الأقسام الفرعية ─────────────
def parse_depth(text: str) -> list[dict]:
    """نفس fl.parse_openiti لكن دون حذف العناوين الفارغة ودون تسطيح المستويات:
    كل قسم {t, d, p} حيث d عمق العنوان (عدد الشرطات في ### |||)."""
    secs: list[dict] = [{"t": "مقدمة", "d": 0, "p": []}]
    buf: list[str] = []
    after_page = False

    def flush():
        nonlocal buf
        para = " ".join(buf).strip()
        buf = []
        if para and para != secs[-1]["t"]:
            secs[-1]["p"].extend(fl.split_long(para))

    for raw in text.split("\n"):
        line = raw.rstrip()
        if not line.strip() or line.startswith("#META#") or line.startswith("######OpenITI#"):
            continue
        m = fl.HEADER_RE.match(line)
        if m:
            flush()
            secs.append({"t": fl.scrub(m.group(2)) or "…", "d": len(m.group(1)), "p": []})
            after_page = False
            continue
        if re.match(r"^#\s*PageV\d+P\d+\s*$", line):
            after_page = True
            continue
        if line.startswith("~~"):
            body = fl.scrub(line[2:])
            if body:
                buf.append(body)
        elif line.startswith("#"):
            body = fl.scrub(line[1:])
            if not body or body == "..." or re.fullmatch(r"المجلد .+", body):
                continue
            if after_page and buf and not fl.HEADISH_RE.match(body):
                buf.append(body)
            else:
                flush()
                buf.append(body)
            after_page = False
    flush()
    return secs


def excerpt(secs: list[dict], kw_by_story: dict[str, list[str]]) -> tuple[list[dict], dict]:
    """لكل قصة: الأقسام التي يطابق عنوانها كلماتها، مع ضمّ ما تحتها من أقسام فرعية
    في قسم واحد بعنوان الجذر (فيظهر السرد كاملًا). النص منقول حرفيًا.
    يعيد (الأقسام المختارة بترتيب الكتاب، تقرير {قصة: [(عنوان, حروف)]})."""
    taken: dict[int, dict] = {}   # فهرس الجذر → القسم المدمج
    covered: set[int] = set()     # كل الفهارس المضمومة (لمنع التكرار)
    report: dict[str, list[tuple[str, int]]] = {}
    for sid, kws in kw_by_story.items():
        keys = [fl_norm(k) for k in kws]
        got = 0
        report[sid] = []
        for i, s in enumerate(secs):
            if got >= MAX_ROOTS:
                break
            if s["d"] == 0 or i in covered:
                continue
            # بعض إصدارات OpenITI تضع NOTMATCH داخل عناوين الفهارس
            # أو تلتقط عنوانًا طويلًا من موضع آخر؛ لا نعرضه كسرد للقصة.
            raw_title = s["t"]
            if "NOTMATCH" in raw_title.upper():
                continue
            if not any(k in fl_norm(s["t"]) for k in keys):
                continue
            title = fl_norm(s["t"])
            if sid == "fil" and "اصحاب الفيل" not in title:
                continue
            block = [i]
            j = i + 1
            while j < len(secs) and secs[j]["d"] > s["d"] and len(block) <= MAX_BLOCK:
                block.append(j)
                j += 1
            paras: list[str] = list(secs[i]["p"])
            for k in block[1:]:
                paras.append(secs[k]["t"])
                paras.extend(secs[k]["p"])
            chars = sum(len(p) for p in paras)
            if chars < MIN_BLOCK_CHARS:
                continue
            taken[i] = {"t": s["t"], "lvl": 1, "p": paras}
            covered.update(block)
            report[sid].append((s["t"], chars))
            got += 1
    return [taken[i] for i in sorted(taken)], report


def title_report(sections: list[dict], kw_by_story: dict[str, list[str]]) -> dict:
    """للكتب الكاملة: الأقسام التي طابق عنوانها كلمات كل قصة (للتشخيص فقط)."""
    out = {}
    for sid, kws in kw_by_story.items():
        keys = [fl_norm(k) for k in kws]
        out[sid] = [(s["t"], sum(len(p) for p in s["p"])) for s in sections
                    if s["p"] and any(k in fl_norm(s["t"]) for k in keys)][:8]
    return out


SEERAH_IDS = {e[0] for e in SEERAH}


def story_kind(sid: str) -> str:
    return "seerah" if sid in SEERAH_IDS else "quran" if sid in QURAN_ONLY else "prophets"


def write_report(blocks: list[tuple[str, list[str], dict]], skipped: list[str]):
    lines = ["تقرير تغطية القصص — «لا مطابقة» يعني لا يظهر سرد لتلك القصة من ذلك الكتاب", ""]
    for note in skipped:
        lines.append(f"⚠ تُخطّي: {note}")
    if skipped:
        lines.append("")
    for sid in KW:
        row = []
        for bid, serves, rep in blocks:
            if story_kind(sid) in serves and sid in rep:
                hits = rep[sid]
                row.append(f"  {bid}: " + (" | ".join(f"{t} ({n} حرفًا)" for t, n in hits)
                                           if hits else "— لا مطابقة —"))
        if row:
            lines.append(sid)
            lines.extend(row)
    text = "\n".join(lines)
    REPORT.write_text(text, encoding="utf-8")
    print(text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--local-dir", type=pathlib.Path)
    a = ap.parse_args()
    lock = load_lock()
    new_lock = dict(lock)
    results = []   # (book, sections, chars, report, pin)
    skipped: list[str] = []
    kw_quran = {sid: KW[sid] for sid in sorted(QURAN_ONLY) if sid in KW}
    for b in BOOKS:
        try:
            text, pin = fetch_book(b, lock, a.local_dir)
            if b["mode"] == "excerpt":
                full = parse_depth(text)
                validate(b, [{"t": s["t"], "p": s["p"]} for s in full])
                sections, rep = excerpt(full, kw_quran)
                chars = sum(len(p) for s in sections for p in s["p"])
                if not sections:
                    fail(f"{b['id']}: لم يُستخرج أي قسم؛ عناوين الكتاب لا تطابق الكلمات")
            else:
                sections = fl.parse_openiti(text)
                chars = validate(b, sections)
                rep = title_report(sections, dict(KW))
        except SystemExit:
            if b["required"]:
                raise
            skipped.append(f"{b['id']} (اختياري) — تعذّر جلبه أو التحقق منه؛ راجع رسالة الخطأ أعلاه")
            continue
        new_lock[b["id"]] = pin
        results.append((b, sections, chars, rep, pin))
        print(f"{b['id']}: {len(sections)} sections, {chars} chars, commit {pin['commit'][:10]}")
    # لا يُكتب شيء إلا بعد نجاح كل الكتب المطلوبة
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.json"):
        old.unlink()
    index = []
    for b, sections, _chars, _rep, pin in results:
        (OUT / f"{b['id']}.json").write_text(
            json.dumps({"id": b["id"], "title": b["title"], "author": b["author_name"],
                        "madhhab": "", "sections": sections},
                       ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        index.append({
            "id": b["id"], "title": b["title"], "author": b["author_name"],
            "desc": b["desc"], "notice": b["notice"], "sections": len(sections),
            "file": f"{b['id']}.json",
            "sourceUrl": f"https://github.com/OpenITI/{b['repo']}",
            "sourcePath": pin["path"], "commit": pin["commit"],
            "serves": b["serves"], "style": b["style"], "hidden": b["hidden"],
        })
    (OUT / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1),
                                    encoding="utf-8")
    if a.local_dir is None:
        LOCK.write_text(json.dumps(new_lock, indent=1, ensure_ascii=False), encoding="utf-8")
    write_report([(b["id"], b["serves"], rep) for b, _s, _c, rep, _p in results], skipped)
    print("OK")


if __name__ == "__main__":
    main()
