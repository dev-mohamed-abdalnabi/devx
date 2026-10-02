#!/usr/bin/env python3
"""يقلّص الخطوط إلى الحروف العربية واللاتينية المستخدمة فقط لتصغير الـ APK.
لا يُفشل البناء أبدًا: أي خطأ أو نقص في تغطية الحروف يُبقي الخط الأصلي."""
import json, os, sys

FONT_DIR = 'assets/fonts'
UNICODES = ('U+0020-007E,U+00A0,U+00AB,U+00BB,U+0600-06FF,U+0750-077F,U+0870-089F,U+08A0-08FF,'
            'U+200B-200F,U+2010-2015,U+2018-201D,U+2026,U+202A-202E,U+2066-2069,U+25CC,'
            'U+FB50-FDFF,U+FE70-FEFF,U+00D7,U+2022,U+00B0')


def main() -> int:
    try:
        from fontTools import subset
        from fontTools.ttLib import TTFont
    except Exception as e:
        print('WARNING: fonttools غير متاح، تُركت الخطوط كما هي:', e)
        return 0

    quran_chars = set()
    try:
        with open('assets/data/quran.json', encoding='utf-8') as f:
            quran_chars = {c for c in f.read() if ord(c) > 127}
    except Exception:
        pass

    total_before = total_after = 0
    for name in sorted(os.listdir(FONT_DIR)):
        if not name.endswith('.ttf'):
            continue
        src = os.path.join(FONT_DIR, name)
        tmp = src + '.subset'
        try:
            opts = subset.Options()
            opts.layout_features = ['*']
            opts.glyph_names = False
            opts.notdef_outline = True
            opts.name_IDs = ['*']
            opts.hinting = False
            opts.desubroutinize = True
            font = subset.load_font(src, opts)
            sub = subset.Subsetter(opts)
            sub.populate(unicodes=subset.parse_unicodes(UNICODES))
            sub.subset(font)
            subset.save_font(font, tmp, opts)
            font.close()
            if name.startswith('AmiriQuran') and quran_chars:
                cmap = TTFont(tmp).getBestCmap()
                missing = {c for c in quran_chars if ord(c) not in cmap}
                # نتجاهل ما كان مفقودًا أصلًا في الخط الكامل
                full = TTFont(src).getBestCmap()
                lost = {c for c in missing if ord(c) in full}
                if lost:
                    raise RuntimeError(f'التقليص أضاع حروفًا من القرآن: {sorted(hex(ord(c)) for c in lost)[:10]}')
            before, after = os.path.getsize(src), os.path.getsize(tmp)
            if after == 0 or after >= before:
                raise RuntimeError('لا توفير في الحجم')
            os.replace(tmp, src)
            total_before += before
            total_after += after
            print(f'{name}: {before} -> {after} bytes')
        except Exception as e:
            print(f'WARNING: تُرك {name} كما هو ({e})')
            if os.path.exists(tmp):
                os.remove(tmp)
    print(f'الخطوط: {total_before} -> {total_after} bytes')
    return 0


if __name__ == '__main__':
    sys.exit(main())
