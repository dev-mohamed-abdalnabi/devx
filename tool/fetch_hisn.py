#!/usr/bin/env python3
"""Fetch and validate the Arabic Hisn al-Muslim corpus for the offline app.

The upstream index exposes 132 chapters and each chapter points to a JSON file
containing the numbered supplications. We keep the upstream item number and URL
with every record so the app can show transparent attribution.
"""
from __future__ import annotations

import json
import pathlib
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT = pathlib.Path(__file__).resolve().parents[1]
INDEX_URL = "https://hisnmuslim.com/api/ar/husn_ar.json"
OUT = ROOT / "lib" / "data" / "azkar.json"

ICONS = (
    ("صباح", "wb_sunny"), ("مساء", "nightlight_round"),
    ("نوم", "bedtime"), ("استيقاظ", "alarm"), ("صلاة", "mosque"),
    ("مسجد", "mosque"), ("وضوء", "water_drop"), ("طعام", "restaurant"),
    ("سفر", "flight"), ("سوق", "storefront"), ("مريض", "healing"),
    ("مرض", "sick"), ("موت", "healing"), ("مطر", "thunderstorm"),
    ("ريح", "thunderstorm"), ("زواج", "favorite"), ("حج", "route"),
    ("عمرة", "route"), ("بيت", "home"), ("ثوب", "checkroom"),
    ("وضوء", "water_drop"), ("غضب", "mood_bad"), ("خوف", "sentiment_stressed"),
)


def get_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": "azkari-build/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8-sig"))


def icon_for(title: str) -> str:
    for needle, icon in ICONS:
        if needle in title:
            return icon
    return "auto_awesome"


def fetch_chapter(chapter: dict) -> tuple[dict, list[dict]]:
    title = chapter["TITLE"]
    detail = get_json(chapter["TEXT"])
    records = detail.get(title)
    if not isinstance(records, list):
        # Be tolerant of harmless title normalization by the upstream API.
        all_lists = [value for value in detail.values() if isinstance(value, list)]
        records = all_lists[0] if len(all_lists) == 1 else None
    if not records:
        raise ValueError(f"no records for chapter {chapter['ID']}: {title}")

    category_id = f"hisn-{chapter['ID']}"
    items = []
    for item in records:
        item_id = int(item["ID"])
        text = str(item.get("ARABIC_TEXT", "")).strip()
        if not text:
            raise ValueError(f"empty text in Hisn item {item_id}")
        repeat = int(item.get("REPEAT") or 1)
        if repeat < 1:
            raise ValueError(f"invalid repeat in Hisn item {item_id}")
        items.append({
            "id": item_id,
            "text": text,
            "count": repeat,
            "source": f"حصن المسلم · {title} · رقم {item_id}",
            "sourceUrl": f"https://sunnah.com/hisn:{item_id}",
        })
    if len({item["id"] for item in items}) != len(items):
        raise ValueError(f"duplicate item number inside chapter {chapter['ID']}: {title}")
    return ({
        "id": category_id,
        "title": title,
        "icon": icon_for(title),
        "sourceUrl": chapter["TEXT"].replace("http://", "https://"),
        "azkar": items,
    }, items)


def main() -> None:
    index = get_json(INDEX_URL)
    chapters = index.get("العربية")
    if not isinstance(chapters, list) or len(chapters) != 132:
        raise SystemExit(f"Hisn index validation failed: expected 132 chapters, got {len(chapters or [])}")

    results: list[tuple[dict, list[dict]] | None] = [None] * len(chapters)
    with ThreadPoolExecutor(max_workers=12) as pool:
        futures = {pool.submit(fetch_chapter, chapter): i for i, chapter in enumerate(chapters)}
        for future in as_completed(futures):
            results[futures[future]] = future.result()

    categories = [result[0] for result in results if result is not None]
    items = [item for result in results if result is not None for item in result[1]]
    ids = [item["id"] for item in items]
    if len(categories) != 132 or len(items) != 267:
        raise SystemExit(
            f"Hisn corpus validation failed: chapters={len(categories)}, items={len(items)}"
        )

    # أذكار المساء قسم مستقل بجانب أذكار الصباح (المصدر يدمجهما في باب 27).
    evening = json.loads((ROOT / "tool" / "hisn_evening.json").read_text(encoding="utf-8"))
    pos = next(i for i, c in enumerate(categories) if c["id"] == "hisn-27")
    categories.insert(pos + 1, evening)
    if not any(c["id"] == "hisn-27e" for c in categories):
        raise SystemExit("evening azkar category missing")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "source": "حصن المسلم من أذكار الكتاب والسنة",
        "sourceUrl": "https://hisnmuslim.com/",
        "sourceApi": INDEX_URL,
        "chapters": len(categories) - 1,
        "items": len(items),
        "categories": categories,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Hisn al-Muslim ok: {len(categories)} chapters, {len(items)} items -> {OUT}")


if __name__ == "__main__":
    main()
