#!/usr/bin/env python3
"""Build the offline Hadith library and the Fiqh library for the app.

NOTHING here is written or paraphrased by us (or by an AI). Every word comes
verbatim from published, attributed sources:

* Hadith  : https://github.com/AhmedBaset/hadith-json  (data scraped from
            sunnah.com; we keep the Arabic text only, in the original order).
* Fiqh    : four SHORT classical fiqh matns, one per madhhab, from
            al-Maktaba al-Shamila via the open OpenITI corpus
            (github.com/OpenITI and github.com/arabic-digital-humanities/fiqh).
            We only strip layout markers (page numbers, tags) and re-flow lines.

Both repositories are pinned to a commit so the build is reproducible.
Any validation failure aborts the build (exit code 1).

Outputs
  assets/library/index.json + one <id>.json per hadith book
  assets/fiqh/index.json    + one <id>.json per fiqh book
  assets/library/SOURCES.json (SHA-256 of every raw upstream file)

Usage
  python3 tool/fetch_library.py
  python3 tool/fetch_library.py --hadith-dir <clone>/db/by_book --fiqh-dir <clone>/txt
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIB_OUT = ROOT / "assets" / "library"
FIQH_OUT = ROOT / "assets" / "fiqh"

HADITH_SHA = "70b83d6d21995bb32f8d7271cd75501be5a922a7"
HADITH_RAW = ("https://raw.githubusercontent.com/AhmedBaset/hadith-json/"
              f"{HADITH_SHA}/db/by_book/")
FIQH_SHA = "accb72b4a075e7776378fde30062a6ca69191be6"
FIQH_RAW = ("https://raw.githubusercontent.com/arabic-digital-humanities/fiqh/"
            f"{FIQH_SHA}/txt/")


def _oi(repo: str, sha: str, author: str, book: str, fname: str) -> str:
    return (f"https://raw.githubusercontent.com/OpenITI/{repo}/{sha}/data/"
            f"{author}/{author}.{book}/{fname}")


# (id, path in upstream, sunnah.com slug, short description, expected count)
HADITH_BOOKS = [
    ("bukhari", "the_9_books/bukhari.json", "bukhari", "أصح كتاب بعد كتاب الله", 7277),
    ("muslim", "the_9_books/muslim.json", "muslim", "ثاني الصحيحين", 7459),
    ("nawawi40", "forties/nawawi40.json", "nawawi40", "جوامع كلم النبي ﷺ", 42),
    ("riyad", "other_books/riyad_assalihin.json", "riyadussalihin", "في الآداب والرقائق والأخلاق", 1896),
    ("qudsi40", "forties/qudsi40.json", "qudsi40", "أحاديث رواها النبي ﷺ عن ربه", 40),
    ("bulugh", "other_books/bulugh_almaram.json", "bulugh", "أحاديث الأحكام مرتبة على أبواب الفقه", 1767),
    ("abudawud", "the_9_books/abudawud.json", "abudawud", "من كتب السنن الأربعة", 5276),
    ("tirmidhi", "the_9_books/tirmidhi.json", "tirmidhi", "مع بيان درجة الحديث", 4053),
    ("nasai", "the_9_books/nasai.json", "nasai", "من كتب السنن الأربعة", 5768),
    ("ibnmajah", "the_9_books/ibnmajah.json", "ibnmajah", "من كتب السنن الأربعة", 4345),
]

# One short, well-known matn per madhhab (mode: "lines" = Quduri file format,
# "openiti" = OpenITI mARkdown). local = file name used with --fiqh-dir.
FIQH_BOOKS = [
    dict(id="hanafi", madhhab="المذهب الحنفي", mode="lines",
         title="مختصر القدوري", author="أبو الحسين أحمد القدوري (ت ٤٢٨هـ)",
         url=FIQH_RAW + "0428AlQuduri.Mukhtasar.txt",
         local="0428AlQuduri.Mukhtasar.txt", min_chars=150_000,
         desc="متن مشهور في الفقه الحنفي، من الطهارة إلى الفرائض",
         edition="دار الكتب العلمية، تحقيق كامل محمد عويضة"),
    dict(id="maliki", madhhab="المذهب المالكي", mode="openiti",
         title="الرسالة", author="ابن أبي زيد القيرواني (ت ٣٨٦هـ)",
         url=_oi("0400AH", "5bb6966d8df2ed22b1bff5cdbe29bb9c24f3ca29",
                 "0386IbnAbiZaydQayrawani", "Risala",
                 "0386IbnAbiZaydQayrawani.Risala.Shamela0011373-ara1"),
         local="0386IbnAbiZaydQayrawani.Risala.Shamela0011373-ara1",
         min_chars=120_000,
         desc="متن مختصر في العقيدة والفقه على مذهب الإمام مالك",
         edition="المكتبة الشاملة"),
    dict(id="shafii", madhhab="المذهب الشافعي", mode="openiti",
         title="الغاية والتقريب (متن أبي شجاع)",
         author="القاضي أبو شجاع الأصفهاني (ت ٥٩٣هـ)",
         url=_oi("0600AH", "ea4bdc6517a49d07106f223aa0869aa7c21b9589",
                 "0593IbnHusaynShihabDinIsbahani", "GhayaWaTaqrib",
                 "0593IbnHusaynShihabDinIsbahani.GhayaWaTaqrib.Shamela0011370-ara1"),
         local="0593IbnHusaynShihabDinIsbahani.GhayaWaTaqrib.Shamela0011370-ara1",
         min_chars=40_000,
         desc="أشهر المتون المختصرة في الفقه الشافعي",
         edition="المكتبة الشاملة"),
    dict(id="hanbali", madhhab="المذهب الحنبلي", mode="openiti",
         title="عمدة الفقه", author="ابن قدامة المقدسي (ت ٦٢٠هـ)",
         url=_oi("0625AH", "f1e38210b32fd0d043949ff6471e869d658c3b16",
                 "0620IbnQudamaMaqdisi", "CumdatFiqh",
                 "0620IbnQudamaMaqdisi.CumdatFiqh.Shamela0011315-ara1"),
         local="0620IbnQudamaMaqdisi.CumdatFiqh.Shamela0011315-ara1",
         min_chars=120_000,
         desc="متن مختصر في الفقه الحنبلي، على قول واحد وبأحاديث صحيحة",
         edition="المكتبة الشاملة"),
]

SOURCES: dict[str, str] = {}


def fetch(url: str, local: pathlib.Path | None) -> bytes:
    if local is not None:
        data = local.read_bytes()
    else:
        req = urllib.request.Request(url, headers={"User-Agent": "azkari-build/1.0"})
        data = b""
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    data = r.read()
                break
            except Exception as e:  # network hiccup: retry, then fail loudly
                if attempt == 3:
                    fail(f"download failed: {url}: {e}")
                time.sleep(3 * (attempt + 1))
    SOURCES[url] = hashlib.sha256(data).hexdigest()
    return data


def fail(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


# --------------------------------------------------------------------------- hadith

def clean_hadith(s: str) -> str:
    s = s.replace("‏", "").replace("‎", "")
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\s*\n\s*", "\n", s)
    return s.strip()


def build_hadith(hadith_dir: pathlib.Path | None) -> list[dict]:
    index = []
    for bid, rel, slug, desc, expected in HADITH_BOOKS:
        local = hadith_dir / rel if hadith_dir else None
        raw = fetch(HADITH_RAW + rel, local)
        data = json.loads(raw.decode("utf-8"))
        hadiths = data["hadiths"]
        if len(hadiths) != expected:
            fail(f"{bid}: expected {expected} hadiths, got {len(hadiths)}")
        titles = {c["id"]: (c.get("arabic") or "").strip() for c in data["chapters"]}
        order = [c["id"] for c in data["chapters"]]
        groups: dict[int, list] = {cid: [] for cid in order}
        for h in hadiths:
            text = clean_hadith(h.get("arabic", ""))
            if not text:
                # keep the upstream numbering honest: skip but count
                continue
            groups.setdefault(h["chapterId"], []).append([h["idInBook"], text])
        chapters = []
        kept = 0
        for cid in groups:
            items = groups[cid]
            if not items:
                continue
            kept += len(items)
            chapters.append({"t": titles.get(cid) or "الأحاديث", "h": items})
        if kept < expected * 0.98:
            fail(f"{bid}: too many empty hadiths ({kept}/{expected})")
        meta = data["metadata"]["arabic"]
        out = {"id": bid, "title": meta["title"], "author": meta["author"], "chapters": chapters}
        LIB_OUT.mkdir(parents=True, exist_ok=True)
        (LIB_OUT / f"{bid}.json").write_text(
            json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        index.append({
            "id": bid, "title": meta["title"], "author": meta["author"], "desc": desc,
            "count": kept, "chapters": len(chapters), "file": f"{bid}.json",
            "sourceUrl": f"https://sunnah.com/{slug}",
        })
        print(f"hadith {bid}: {kept} hadiths, {len(chapters)} chapters")
    return index


# --------------------------------------------------------------------------- fiqh

HEADER_RE = re.compile(r"^\s*\|?\s*(?:\d+\s*-\s*)?###\s*(\|+)\s*\|?\s*\d*\s*(.*)$")
PAGE_ONLY_RE = re.compile(r"^\s*\(\d+/\d+\)\s*$")
FRONT_RE = re.compile(r"^(الكتاب|المؤلف|المحقق|الناشر|الطبعة|عدد الأجزاء|أعده|\[ترقيم)")
HEADISH_RE = re.compile(r'^"?(فصل|باب|كتاب|مدخل)')


def scrub(s: str) -> str:
    s = re.sub(r"PageV\d+P\d+", " ", s)
    s = re.sub(r"Milestone\d+", " ", s)
    s = re.sub(r"\bms\d+\b", " ", s)
    s = s.replace("@QB@", "﴿").replace("@QE@", "﴾")
    s = re.sub(r"[ \t\u00a0]+", " ", s)
    return s.strip()


def split_long(p: str, limit: int = 2400) -> list[str]:
    out = []
    while len(p) > limit:
        cut = p.find(" ", int(limit * 0.75))
        if cut == -1 or cut > limit + 400:
            break
        out.append(p[:cut].strip())
        p = p[cut:].strip()
    if p:
        out.append(p)
    return out


class Builder:
    """Collects sections; empty كتاب headings are kept (as headings only)."""

    def __init__(self):
        self.sections: list[dict] = []
        self.cur = {"t": "مقدمة", "lvl": 1, "p": []}
        self.buf: list[str] = []

    def flush(self):
        para = " ".join(self.buf).strip()
        self.buf = []
        if para and para != self.cur["t"]:
            self.cur["p"].extend(split_long(para))

    def new_section(self, title: str, lvl: int):
        self.flush()
        if self.cur["p"] or self.cur["lvl"] == 1 and self.cur["t"] != "مقدمة":
            self.sections.append(self.cur)
        self.cur = {"t": title or "…", "lvl": lvl, "p": []}

    def finish(self) -> list[dict]:
        self.flush()
        if self.cur["p"]:
            self.sections.append(self.cur)
        # a heading with no text is kept only when it is a كتاب grouping
        return [s for s in self.sections
                if s["t"].startswith("كتاب")
                or sum(len(p) for p in s["p"]) >= 40]


def parse_quduri(text: str) -> list[dict]:
    """The Quduri file: one real paragraph per line; page markers '(n/m)'
    sit in the middle of paragraphs."""
    b = Builder()
    join_next = False
    started = False
    for raw in text.split("\n"):
        line = raw.strip()
        if not line or line.startswith("#META#") or line.startswith("######OpenITI#"):
            continue
        if PAGE_ONLY_RE.match(line):
            join_next = True
            continue
        m = HEADER_RE.match(raw)
        if m:
            b.new_section(scrub(m.group(2)), min(len(m.group(1)), 3))
            started = True
            join_next = False
            continue
        if not started and FRONT_RE.match(line):
            continue
        line = scrub(line)
        if not line:
            continue
        if join_next and b.buf:
            b.buf.append(line)
        else:
            b.flush()
            b.buf.append(line)
        join_next = False
    return b.finish()


def parse_openiti(text: str) -> list[dict]:
    """OpenITI mARkdown: '# ' starts a paragraph, '~~' continues it, '### |' is
    a heading, 'PageVxxPyyy' marks a page. A page break can split a paragraph,
    so a paragraph that starts right after a page marker is joined to the
    previous one unless it opens with a heading word (فصل/باب/كتاب)."""
    b = Builder()
    after_page = False
    for raw in text.split("\n"):
        line = raw.rstrip()
        if not line.strip() or line.startswith("#META#") or line.startswith("######OpenITI#"):
            continue
        m = HEADER_RE.match(line)
        if m:
            b.new_section(scrub(m.group(2)), min(len(m.group(1)), 3))
            after_page = False
            continue
        if re.match(r"^#\s*PageV\d+P\d+\s*$", line):
            after_page = True
            continue
        if line.startswith("~~"):
            body = scrub(line[2:])
            if body:
                b.buf.append(body)
        elif line.startswith("#"):
            body = scrub(line[1:])
            if not body or body == "..." or re.fullmatch(r"المجلد .+", body):
                continue
            if after_page and b.buf and not HEADISH_RE.match(body):
                b.buf.append(body)
            else:
                b.flush()
                b.buf.append(body)
            after_page = False
    sections = b.finish()
    # Levels: if the book groups its أبواب under كتب, make أبواب level 2.
    if any(s["t"].startswith("كتاب") for s in sections):
        for s in sections:
            if not s["t"].startswith("كتاب") and s["t"] != "مقدمة":
                s["lvl"] = 2
    else:
        for s in sections:
            s["lvl"] = 1
    return sections


def build_fiqh(fiqh_dir: pathlib.Path | None) -> list[dict]:
    index = []
    FIQH_OUT.mkdir(parents=True, exist_ok=True)
    for old in FIQH_OUT.glob("*.json"):
        old.unlink()  # drop files of books no longer in the list
    for b in FIQH_BOOKS:
        local = fiqh_dir / b["local"] if fiqh_dir else None
        raw = fetch(b["url"], local)
        text = raw.decode("utf-8")
        sections = parse_quduri(text) if b["mode"] == "lines" else parse_openiti(text)
        chars = sum(len(p) for s in sections for p in s["p"])
        if len(sections) < 8 or chars < b["min_chars"]:
            fail(f"{b['id']}: parsed too little ({len(sections)} sections, {chars} chars)")
        titles = " ".join(s["t"] for s in sections)
        for must in (("طهار", "وضوء"), ("صلاة",), ("زكاة",),
                     ("صيام", "صوم"), ("حج",), ("نكاح",)):
            if not any(m in titles for m in must):
                fail(f"{b['id']}: missing expected section containing «{must[0]}»")
        out = {"id": b["id"], "title": b["title"], "author": b["author"],
               "madhhab": b["madhhab"], "sections": sections}
        (FIQH_OUT / f"{b['id']}.json").write_text(
            json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        index.append({
            "id": b["id"], "madhhab": b["madhhab"], "title": b["title"],
            "author": b["author"], "desc": b["desc"], "edition": b["edition"],
            "sections": len(sections), "file": f"{b['id']}.json",
        })
        print(f"fiqh {b['id']}: {len(sections)} sections, {chars} chars")
    return index


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hadith-dir", type=pathlib.Path)
    ap.add_argument("--fiqh-dir", type=pathlib.Path,
                    help="folder holding the raw fiqh files (by their base file name)")
    a = ap.parse_args()
    hidx = build_hadith(a.hadith_dir)
    fidx = build_fiqh(a.fiqh_dir)
    (LIB_OUT / "index.json").write_text(
        json.dumps(hidx, ensure_ascii=False, indent=1), encoding="utf-8")
    (FIQH_OUT / "index.json").write_text(
        json.dumps(fidx, ensure_ascii=False, indent=1), encoding="utf-8")
    (LIB_OUT / "SOURCES.json").write_text(
        json.dumps({"hadithCommit": HADITH_SHA, "fiqhCommit": FIQH_SHA, "files": SOURCES},
                   indent=1), encoding="utf-8")
    print("OK")


if __name__ == "__main__":
    main()
