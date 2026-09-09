#!/usr/bin/env bash
# restore.sh
# الريبو متخزن فيه الملفات كلها "فلات" (من غير فولدرات) في الروت،
# وأسماء الملفات بتشفر مكانها الحقيقي باستخدام "__" بدل "/".
# السكريبت ده بياخد كل ملف زي:
#   app__src__main__java__com__example__MainActivity.kt
# ويحطه في مكانه الصح:
#   app/src/main/java/com/example/MainActivity.kt
#
# بيتشغل تلقائيًا في الـ CI قبل البناء، وتقدر كمان تشغله لوكالي:
#   bash restore.sh

set -e

for f in *; do
  # اتخطى الفولدرات والسكريبت نفسه وأي ملف اسمه من غير "__" (ده معناه هو أصلاً في مكانه الصح)
  [ -f "$f" ] || continue
  [ "$f" = "restore.sh" ] && continue
  case "$f" in
    *__*) ;;
    *) continue ;;
  esac

  target=$(echo "$f" | sed 's/__/\//g')
  mkdir -p "$(dirname "$target")"
  cp "$f" "$target"
  echo "restored: $f -> $target"
done
