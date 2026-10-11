import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/quran_data.dart';

/// محرك ترتيب صفحة المصحف: كل صفحة = ١٥ سطرًا متساويين (٨ في أول صفحتين)،
/// كل سطر مضبوط على عرض الصفحة (توزيع المسافات بين الكلمات) مثل مصحف المدينة.
/// اللافتة والبسملة تأخذ كل واحدة سطرًا كاملًا.

const double kMarkerSize = 1.15; // قطر علامة الآية × حجم الخط
const double kMarkerGap = .18; // المسافة بين الكلمة والعلامة
const double kSajdaW = .85; // عرض علامة السجدة
const double kMinGap = .14; // أقل مسافة بين كلمتين
const double kCenterGap = .24; // المسافة في الأسطر القصيرة (تتوسّط)
const double kSafety = .985; // هامش أمان ضد فروق القياس
const double kLineH = 1.4; // ارتفاع السطر × حجم الخط

enum MRowKind { banner, basmala, line }

class MItem {
  final Ayah ayah;
  final String text;
  final int lead; // 0 بدون، 1 ربع حزب، 2 بداية حزب
  final bool end; // آخر كلمة في الآية => تتبعها علامة الآية
  final bool sajda;
  final double w100; // عرض الكلمة (مع العلامة الأولية) عند خط ١٠٠
  const MItem(this.ayah, this.text, this.lead, this.end, this.sajda, this.w100);

  double width(double f) =>
      w100 * f / 100 +
      (end ? f * (kMarkerGap + kMarkerSize + (sajda ? kSajdaW : 0)) : 0);
}

class MLine {
  final List<MItem> items;
  final bool justify; // false => تتوسّط بمسافات طبيعية
  const MLine(this.items, this.justify);
}

class MRow {
  final MRowKind kind;
  final int surah;
  final MLine? line;
  const MRow.banner(this.surah)
      : kind = MRowKind.banner,
        line = null;
  const MRow.basmala()
      : kind = MRowKind.basmala,
        surah = 0,
        line = null;
  const MRow.line(MLine this.line)
      : kind = MRowKind.line,
        surah = 0;
}

class MPageLayout {
  final List<MRow> rows;
  final double font;
  final double slotH;
  final bool fits; // الصفحة كلها داخل الارتفاع المتاح (بدون سكرول)
  const MPageLayout(this.rows, this.font, this.slotH, this.fits);
}

class _Seg {
  final bool banner, basmala;
  final int surah;
  final List<MItem> items;
  final bool lastFree; // الفقرة تنتهي بآخر آية في السورة
  const _Seg(this.banner, this.basmala, this.surah, this.items, this.lastFree);
}

// ───────── قياس الكلمات (مع تخزين مؤقت) ─────────
final Map<String, double> _w100 = <String, double>{};

TextStyle _style100() => const TextStyle(
      fontFamily: AppTheme.quranFont,
      fontSize: 100,
    );

double _measure(String text, int lead) {
  final key = '$lead|$text';
  final hit = _w100[key];
  if (hit != null) return hit;
  final tp = TextPainter(
    textDirection: TextDirection.rtl,
    textScaler: TextScaler.noScaling,
    text: TextSpan(style: _style100(), children: [
      if (lead > 0)
        TextSpan(
            text: '\u06DE ',
            style: TextStyle(fontSize: lead == 2 ? 100 : 72)),
      TextSpan(text: text),
    ]),
  )..layout();
  final w = tp.width;
  tp.dispose();
  if (_w100.length > 30000) _w100.clear();
  return _w100[key] = w;
}

final RegExp _letter = RegExp(r'[\u0621-\u064A\u0671-\u06D3]');

List<_Seg> _segments(QuranData data, List<Ayah> ayahs, int Function(Ayah) indexOf) {
  final out = <_Seg>[];
  var cur = <MItem>[];
  var curSurah = 0;
  var curLastFree = false;
  void flush() {
    if (cur.isNotEmpty) {
      out.add(_Seg(false, false, curSurah, cur, curLastFree));
      cur = <MItem>[];
    }
  }

  for (final a in ayahs) {
    if (a.number == 1) {
      flush();
      out.add(_Seg(true, false, a.surah, const [], false));
      if (a.surah != 1 && a.surah != 9) {
        out.add(_Seg(false, true, a.surah, const [], false));
      }
    }
    final idx = indexOf(a);
    final prevHq = idx > 0 ? data.ayahs[idx - 1].hizbQuarter : 0;
    var lead = 0;
    if (a.hizbQuarter != prevHq) lead = (a.hizbQuarter - 1) % 4 == 0 ? 2 : 1;

    // علامات الوقف المنفصلة تُضم للكلمة السابقة حتى لا تصير «كلمة» مستقلة.
    final words = <String>[];
    for (final t in a.text.split(RegExp(r'\s+'))) {
      if (t.isEmpty) continue;
      if (words.isNotEmpty && !_letter.hasMatch(t)) {
        words[words.length - 1] = '${words.last} $t';
      } else {
        words.add(t);
      }
    }
    for (var i = 0; i < words.length; i++) {
      final first = i == 0;
      final last = i == words.length - 1;
      final l = first ? lead : 0;
      cur.add(MItem(a, words[i], l, last, last && a.sajda, _measure(words[i], l)));
    }
    curSurah = a.surah;
    curLastFree = a.number == data.surahs[a.surah - 1].ayahCount;
  }
  flush();
  return out;
}

// ───────── التقطيع ─────────
double _lineW(List<MItem> items, int i, int j, double f) {
  var w = 0.0;
  for (var k = i; k < j; k++) {
    w += items[k].width(f);
  }
  return w + (j - i - 1) * kMinGap * f;
}

/// تقطيع جشع: يعيد نقاط نهاية الأسطر.
List<int> _greedy(List<MItem> items, double f, double availW) {
  final ends = <int>[];
  var i = 0;
  while (i < items.length) {
    var j = i + 1;
    var w = items[i].width(f);
    while (j < items.length) {
      final nw = w + kMinGap * f + items[j].width(f);
      if (nw > availW) break;
      w = nw;
      j++;
    }
    ends.add(j);
    i = j;
  }
  return ends;
}

/// تقطيع إلى [n] سطرًا بالضبط يقلّل فروق الامتلاء بين الأسطر.
List<int>? _dp(List<MItem> items, int n, double f, double availW, bool lastFree) {
  final m = items.length;
  if (n > m || n < 1) return null;
  final pre = List<double>.filled(m + 1, 0);
  for (var i = 0; i < m; i++) {
    pre[i + 1] = pre[i] + items[i].width(f);
  }
  double width(int i, int j) => pre[j] - pre[i] + (j - i - 1) * kMinGap * f;
  const inf = 1e18;
  final dp = List.generate(n + 1, (_) => List<double>.filled(m + 1, inf));
  final par = List.generate(n + 1, (_) => List<int>.filled(m + 1, -1));
  dp[0][0] = 0;
  for (var k = 1; k <= n; k++) {
    for (var j = k; j <= m; j++) {
      for (var i = j - 1; i >= k - 1; i--) {
        final w = width(i, j);
        if (w > availW) break;
        final prev = dp[k - 1][i];
        if (prev >= inf) continue;
        final slack = (availW - w) / availW;
        final cost = (k == n && lastFree) ? 0.0 : slack * slack;
        if (prev + cost < dp[k][j]) {
          dp[k][j] = prev + cost;
          par[k][j] = i;
        }
      }
    }
  }
  if (dp[n][m] >= inf) return null;
  final ends = <int>[];
  var j = m;
  for (var k = n; k >= 1; k--) {
    ends.add(j);
    j = par[k][j];
  }
  return ends.reversed.toList();
}

List<MLine> _toLines(List<MItem> items, List<int> ends, double f, double width) {
  final out = <MLine>[];
  var s = 0;
  for (final e in ends) {
    final slice = items.sublist(s, e);
    var w = 0.0;
    for (final it in slice) {
      w += it.width(f);
    }
    final natural = w + (slice.length - 1) * kCenterGap * f;
    out.add(MLine(slice, natural / width >= .8 && slice.length > 1));
    s = e;
  }
  return out;
}


// ───────── أول صفحتين: أسطر مصحف المدينة كما هي ─────────
/// نهاية سطر ثابتة: بعد الكلمة رقم [word] من الآية [ayah] (٠ = آخر كلمة في الآية).
/// [justify] = السطر يُضبط على عرض الصفحة كاملًا، وإلا يتوسّط بمسافات طبيعية.
class _FixedLine {
  final int ayah, word;
  final bool justify;
  const _FixedLine(this.ayah, this.word, this.justify);
}

const Map<int, List<_FixedLine>> _fixedLines = {
  // الفاتحة: ٧ أسطر تحت اللافتة، الأسطر القصيرة في المنتصف (شكل المصحف).
  1: [
    _FixedLine(1, 0, false), // بسم الله الرحمن الرحيم
    _FixedLine(2, 0, false), // الحمد لله رب العالمين
    _FixedLine(4, 0, true), // الرحمن الرحيم مالك يوم الدين
    _FixedLine(5, 0, false), // إياك نعبد وإياك نستعين
    _FixedLine(6, 0, false), // اهدنا الصراط المستقيم
    _FixedLine(7, 6, true), // صراط الذين أنعمت عليهم غير المغضوب
    _FixedLine(7, 0, false), // عليهم ولا الضالين
  ],
  // أول البقرة: لافتة + بسملة + ٦ أسطر.
  2: [
    _FixedLine(2, 6, true), // الم ذلك الكتاب لا ريب فيه هدى
    _FixedLine(3, 5, true), // للمتقين الذين يؤمنون بالغيب ويقيمون الصلاة
    _FixedLine(4, 4, true), // ومما رزقناهم ينفقون والذين يؤمنون بما أنزل
    _FixedLine(4, 0, true), // إليك وما أنزل من قبلك وبالآخرة هم يوقنون
    _FixedLine(5, 6, true), // أولئك على هدى من ربهم وأولئك
    _FixedLine(5, 0, false), // هم المفلحون
  ],
};

/// يقطّع [items] حسب [spec]؛ يرجع null لو لم تطابق البيانات المتوقعة (فيعود المحرك العام).
List<MLine>? _fixedPageLines(List<MItem> items, List<_FixedLine> spec, double f) {
  final out = <MLine>[];
  var start = 0;
  for (final sp in spec) {
    var seen = 0;
    var end = -1;
    for (var i = start; i < items.length; i++) {
      if (items[i].ayah.number != sp.ayah) {
        if (seen > 0) break;
        continue;
      }
      seen++;
      final lastOfAyah = items[i].end;
      if (sp.word == 0 ? lastOfAyah : seen == sp.word) {
        end = i + 1;
        break;
      }
    }
    if (end <= start) return null;
    out.add(MLine(items.sublist(start, end), sp.justify));
    start = end;
  }
  return start == items.length ? out : null;
}

/// أكبر خط يجعل أعرض سطر ثابت داخل العرض المتاح.
double _fixedFit(List<MLine> lines, double availW, double maxF) {
  var f = maxF;
  for (final l in lines) {
    final w100 = _lineW(l.items, 0, l.items.length, 100);
    if (w100 > 0) f = math.min(f, availW * 100 / w100);
  }
  return math.max(8.0, f);
}

final Map<String, MPageLayout> _cache = <String, MPageLayout>{};
final Set<String> _warming = <String>{};

String _keyOf(int page, double width, double height, double scale) =>
    '$page|${width.round()}|${height.round()}|${(scale * 100).round()}';

/// يحسب ترتيب الصفحات المجاورة مسبقًا (صفحة كل ~50ms) حتى لا يحدث تقطيع وقت السحب.
void warmNeighbors({
  required QuranData data,
  required int page,
  required int Function(Ayah) indexOf,
  required double width,
  required double height,
  required double scale,
}) {
  var delay = 0;
  for (final p in [page + 1, page - 1, page + 2, page - 2]) {
    if (p < 1 || p > data.pageCount) continue;
    final key = _keyOf(p, width, height, scale);
    if (_cache.containsKey(key) || !_warming.add(key)) continue;
    delay += 50;
    Future.delayed(Duration(milliseconds: delay), () {
      _warming.remove(key);
      if (_cache.containsKey(key)) return;
      layoutPage(
          data: data,
          page: p,
          indexOf: indexOf,
          width: width,
          height: height,
          scale: scale);
    });
  }
}

/// يرتّب صفحة داخل [width]×[height]. [scale]==1 => صفحة كاملة بدون سكرول،
/// غير ذلك => حجم الخط = حجم الملاءمة × [scale] والصفحة قابلة للتمرير.
MPageLayout layoutPage({
  required QuranData data,
  required int page,
  required int Function(Ayah) indexOf,
  required double width,
  required double height,
  required double scale,
}) {
  final key = _keyOf(page, width, height, scale);
  final hit = _cache[key];
  if (hit != null) return hit;

  final ayahs = data.byPage[page] ?? const <Ayah>[];
  final segs = _segments(data, ayahs, indexOf);
  final slots = page <= 2 ? 8 : 15;
  final fixed = segs.where((s) => s.banner || s.basmala).length;
  final r = math.max(1, slots - fixed);
  final text = segs.where((s) => !s.banner && !s.basmala).toList();
  final availW = width * kSafety;
  final baseSlot = height / slots;

  // أول صفحتين: أسطر المصحف الثابتة (عند الحجم الأساسي فقط).
  final spec = _fixedLines[page];
  if (spec != null && (scale - 1).abs() < .005) {
    final textItems = [for (final s in text) ...s.items];
    final lines = _fixedPageLines(textItems, spec, 0);
    if (lines != null && fixed + lines.length == slots) {
      final f = _fixedFit(lines, availW, math.min(baseSlot / kLineH, width / 7.5));
      final rows = <MRow>[
        for (final s in segs)
          if (s.banner) MRow.banner(s.surah) else if (s.basmala) const MRow.basmala(),
        for (final l in lines) MRow.line(l),
      ];
      final res = MPageLayout(rows, f, baseSlot, true);
      if (_cache.length >= 40) _cache.remove(_cache.keys.first);
      return _cache[key] = res;
    }
  }

  int total(double f) =>
      text.fold(0, (a, s) => a + _greedy(s.items, f, availW).length);

  // أكبر خط يجعل كل النص في عدد الأسطر المتاح.
  var lo = 8.0;
  var hi = math.max(lo, math.min(baseSlot / kLineH, width / 7.5));
  var overflow = false;
  double fit;
  if (total(hi) <= r) {
    fit = hi;
  } else if (total(lo) > r) {
    fit = lo;
    overflow = true;
  } else {
    for (var i = 0; i < 16; i++) {
      final mid = (lo + hi) / 2;
      if (total(mid) <= r) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    fit = lo;
  }

  final exact = (scale - 1).abs() < .005;
  final f = exact ? fit : fit * scale;
  final slotH = overflow ? f * kLineH : (exact ? baseSlot : baseSlot * scale);

  // عدد أسطر كل فقرة.
  final counts = [for (final s in text) _greedy(s.items, f, availW).length];
  if (exact && !overflow) {
    var extra = r - counts.fold(0, (a, b) => a + b);
    while (extra > 0) {
      // السطر الإضافي يذهب للفقرة الأكثر امتلاءً.
      var best = -1;
      var bestFill = -1.0;
      for (var i = 0; i < text.length; i++) {
        if (counts[i] >= text[i].items.length) continue;
        final w = _lineW(text[i].items, 0, text[i].items.length, f);
        final fill = w / (counts[i] * availW);
        if (fill > bestFill) {
          bestFill = fill;
          best = i;
        }
      }
      if (best < 0) break;
      counts[best]++;
      extra--;
    }
  }

  final rows = <MRow>[];
  var ti = 0;
  for (final s in segs) {
    if (s.banner) {
      rows.add(MRow.banner(s.surah));
    } else if (s.basmala) {
      rows.add(const MRow.basmala());
    } else {
      final n = counts[ti++];
      List<int>? ends;
      if (exact && !overflow) ends = _dp(s.items, n, f, availW, s.lastFree);
      ends ??= _greedy(s.items, f, availW);
      for (final l in _toLines(s.items, ends, f, width)) {
        rows.add(MRow.line(l));
      }
    }
  }

  final res = MPageLayout(rows, f, slotH, exact && !overflow);
  if (_cache.length >= 40) _cache.remove(_cache.keys.first);
  return _cache[key] = res;
}
