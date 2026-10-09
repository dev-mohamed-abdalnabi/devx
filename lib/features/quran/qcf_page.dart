import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../data/mushaf_data.dart';
import '../../services/qcf_fonts.dart';

class _Metrics {
  final List<double> nat100; // عرض كل صف نصي بخط 100 (0 لغير النص)
  final double h100; // ارتفاع سطر الخط عند 100 وheight=1.0
  const _Metrics(this.nat100, this.h100);
}

final Map<int, _Metrics> _metricsCache = {};

String _lineText(List<QcfWord> ws) => ws.map((w) => w.code).join(' ');

_Metrics _metricsOf(int page, List<QcfRow> rows) {
  final hit = _metricsCache[page];
  if (hit != null) return hit;
  final fam = QcfFonts.family(page);
  final nat = <double>[];
  var h = 100.0;
  for (final r in rows) {
    if (r.kind != QcfKind.text) {
      nat.add(0);
      continue;
    }
    final tp = TextPainter(
      text: TextSpan(
          text: _lineText(r.words),
          style: TextStyle(fontFamily: fam, fontSize: 100, height: 1.0)),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
    )..layout();
    nat.add(tp.width);
    h = tp.height;
    tp.dispose();
  }
  if (_metricsCache.length > 40) _metricsCache.clear();
  return _metricsCache[page] = _Metrics(nat, h);
}

/// صفحة مصحف المدينة: كل سطر `RichText` واحد بخط الصفحة، والتحليّة بـ wordSpacing.
class QcfPageBody extends StatefulWidget {
  final int page;
  final List<QcfRow> rows;
  final double width;
  final double slotH;
  final Color ink;
  final Color? Function(String key) bgOf;
  final bool selecting;
  final void Function(String key) onTapKey;
  final void Function(String key) onLongKey;
  final Widget Function(int surah, double height) banner;
  final Widget Function(double fontSize) basmala;

  const QcfPageBody({
    super.key,
    required this.page,
    required this.rows,
    required this.width,
    required this.slotH,
    required this.ink,
    required this.bgOf,
    required this.selecting,
    required this.onTapKey,
    required this.onLongKey,
    required this.banner,
    required this.basmala,
  });

  @override
  State<QcfPageBody> createState() => _QcfPageBodyState();
}

class _QcfPageBodyState extends State<QcfPageBody> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(QcfPageBody old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) _ensure();
  }

  void _ensure() {
    final p = widget.page;
    if (QcfFonts.isReady(p)) {
      _ready = true;
      QcfFonts.warm(p);
      return;
    }
    _ready = false;
    QcfFonts.load(p).then((ok) {
      if (!mounted || widget.page != p) return;
      if (ok) {
        setState(() => _ready = true);
        QcfFonts.warm(p);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, slotH = widget.slotH;
    if (!_ready) {
      return SizedBox(
        height: slotH * widget.rows.length,
        child: const Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final m = _metricsOf(widget.page, widget.rows);
    final maxNat = m.nat100.fold<double>(0, math.max);
    var f = maxNat > 0 ? w * 100 / maxNat * .998 : slotH * .7;
    f = math.min(f, slotH * .96 / (m.h100 / 100));
    final fam = QcfFonts.family(widget.page);

    final children = <Widget>[];
    for (var i = 0; i < widget.rows.length; i++) {
      final r = widget.rows[i];
      switch (r.kind) {
        case QcfKind.empty:
          children.add(SizedBox(height: slotH));
        case QcfKind.banner:
          children.add(SizedBox(
              height: slotH,
              child: Center(
                  child: widget.banner(r.surah, math.min(44.0, slotH * .84)))));
        case QcfKind.basmala:
          children.add(SizedBox(
              height: slotH,
              child: Center(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: widget.basmala(math.min(f * .9, slotH * .62))))));
        case QcfKind.text:
          final nat = m.nat100[i] * f / 100;
          final spaces = r.words.length - 1;
          var ws = 0.0;
          if (spaces > 0 && nat / w >= .8) {
            ws = math.max(-f * .1, (w * .998 - nat) / spaces);
          }
          children.add(_QcfLine(
            words: r.words,
            family: fam,
            fontSize: f,
            wordSpacing: ws,
            width: w,
            height: slotH,
            ink: widget.ink,
            bgOf: widget.bgOf,
            selecting: widget.selecting,
            onTapKey: widget.onTapKey,
            onLongKey: widget.onLongKey,
          ));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _QcfLine extends StatefulWidget {
  final List<QcfWord> words;
  final String family;
  final double fontSize, wordSpacing, width, height;
  final Color ink;
  final Color? Function(String key) bgOf;
  final bool selecting;
  final void Function(String key) onTapKey;
  final void Function(String key) onLongKey;

  const _QcfLine({
    required this.words,
    required this.family,
    required this.fontSize,
    required this.wordSpacing,
    required this.width,
    required this.height,
    required this.ink,
    required this.bgOf,
    required this.selecting,
    required this.onTapKey,
    required this.onLongKey,
  });

  @override
  State<_QcfLine> createState() => _QcfLineState();
}

class _QcfLineState extends State<_QcfLine> {
  final GlobalKey _rt = GlobalKey();

  String? _keyAt(Offset local) {
    final ro = _rt.currentContext?.findRenderObject();
    if (ro is! RenderParagraph) return null;
    final off = ro.getPositionForOffset(local).offset;
    var pos = 0;
    for (var i = 0; i < widget.words.length; i++) {
      final end = pos + widget.words[i].code.length;
      if (off < end + 1) return widget.words[i].key;
      pos = end + 1; // + المسافة
    }
    return widget.words.last.key;
  }

  @override
  Widget build(BuildContext context) {
    final ws = widget.words;
    final spans = <InlineSpan>[];
    for (var i = 0; i < ws.length; i++) {
      final bg = widget.bgOf(ws[i].key);
      if (i > 0) {
        final same = ws[i - 1].key == ws[i].key;
        spans.add(TextSpan(
            text: ' ',
            style: same && bg != null ? TextStyle(backgroundColor: bg) : null));
      }
      spans.add(TextSpan(
          text: ws[i].code,
          style: bg != null ? TextStyle(backgroundColor: bg) : null));
    }
    final text = RichText(
      key: _rt,
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      softWrap: false,
      text: TextSpan(
        style: TextStyle(
          fontFamily: widget.family,
          fontSize: widget.fontSize,
          height: 1.0,
          color: widget.ink,
          wordSpacing: widget.wordSpacing,
        ),
        children: spans,
      ),
    );
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.selecting
              ? (d) {
                  final k = _keyAt(d.localPosition);
                  if (k != null) widget.onTapKey(k);
                }
              : null,
          onLongPressStart: widget.selecting
              ? null
              : (d) {
                  final k = _keyAt(d.localPosition);
                  if (k != null) widget.onLongKey(k);
                },
          child: text,
        ),
      ),
    );
  }
}
