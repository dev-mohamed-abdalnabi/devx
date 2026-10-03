#!/usr/bin/env python3
"""يضيف خطوات patch + verify إلى workflow البناء تلقائيًا (آمن للتكرار)."""
import glob
import re
import sys

PATCH = ('Patch Android', 'python3 tool/patch_android.py')
VERIFY_SRC = ('Verify adhan and notification resources', 'python3 tool/verify_android.py')
VERIFY_APK = ('Verify APK contains adhan', 'python3 tool/verify_android.py apk build/app/outputs/flutter-apk')


def step(indent, name, cmd):
    pad = ' ' * indent
    return [f'{pad}- name: {name}\n', f'{pad}  run: {cmd}\n']


def process(path):
    lines = open(path, encoding='utf-8').read().splitlines(True)
    text = ''.join(lines)
    idx = next((i for i, l in enumerate(lines) if 'flutter build' in l), None)
    if idx is None:
        return False
    # بداية الخطوة: أقرب سطر يبدأ بـ "- " قبل سطر البناء
    start = idx
    while start >= 0 and not re.match(r'^\s*-\s', lines[start]):
        start -= 1
    if start < 0:
        return False
    indent = len(lines[start]) - len(lines[start].lstrip())
    end = idx + 1
    while end < len(lines) and not (lines[end].strip() and
            (len(lines[end]) - len(lines[end].lstrip())) <= indent and lines[end].lstrip().startswith('- ')) \
            and not (lines[end].strip() and (len(lines[end]) - len(lines[end].lstrip())) < indent):
        end += 1
    before, after = [], []
    if 'patch_android.py' not in text:
        before += step(indent, *PATCH)
    if 'verify_android.py"' not in text and 'verify_android.py\n' not in text:
        before += step(indent, *VERIFY_SRC)
    if 'verify_android.py apk' not in text:
        after += step(indent, *VERIFY_APK)
    if not before and not after:
        print(f'{path}: الخطوات موجودة بالفعل')
        return True
    new = lines[:start] + before + lines[start:end] + after + lines[end:]
    open(path, 'w', encoding='utf-8').write(''.join(new))
    print(f'{path}: أُضيفت {len(before) // 2} خطوة قبل البناء و{len(after) // 2} بعده')
    return True


def main():
    files = glob.glob('.github/workflows/*.yml') + glob.glob('.github/workflows/*.yaml')
    done = [f for f in files if process(f)]
    if not done:
        print('لم أجد خطوة "flutter build" في أي workflow', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
