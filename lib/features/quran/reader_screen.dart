import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../core/star_shape.dart';
import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../data/quran_data.dart';
import '../../providers/activity_provider.dart';
import '../../providers/quran_audio_provider.dart';
import '../../providers/quran_provider.dart';
import '../home/home_art.dart';
import 'goto_sheet.dart';
import 'quran_ui.dart';

class ReaderScreen extends StatefulWidget {
  final int page;
  final String? highlight;
  const ReaderScreen({super.key, required this.page, this.highlight});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PageController _controller;
  final ScrollController _sc = ScrollController();
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};
  late String _mode;
  bool _jumping = false;
  late int _page;
  String? _flash;
  Timer? _readTimer;
  bool _chrome = true;
  final Set<String> _sel = <String>{};
  String? _anchor;

  bool get _selecting => _sel.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _page = widget.page.clamp(1, 604);
    _flash = widget.highlight;
    _controller = PageController(initialPage: _page - 1);
    _mode = context.read<QuranProvider>().pageMode;
    _sc.addListener(_onScroll);
    if (_mode == 'continuous') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _contJump(_page));
    }
    _onPage(_page);
  }

  GlobalKey _keyFor(int page) => _keys.putIfAbsent(page, () => GlobalKey());

  /// الصفحة التي يقع عندها خط القراءة (أعلى الشاشة تقريبًا) في وضع التمرير.
  int? _pageAtLine() {
    final line = MediaQuery.of(context).padding.top + 90;
    int? best;
    for (final e in _keys.entries) {
      final ctx = e.value.currentContext;
      if (ctx == null) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final top = ro.localToGlobal(Offset.zero).dy;
      if (top <= line && top + ro.size.height > line) {
        best = e.key;
        break;
      }
    }
    return best;
  }

  double _avgPageHeight() {
    var sum = 0.0, n = 0;
    for (final e in _keys.entries) {
      final ro = e.value.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached) {
        sum += ro.size.height;
        n++;
      }
    }
    return n == 0 ? 900 : sum / n;
  }

  void _onScroll() {
    if (_jumping || !mounted) return;
    final p = _pageAtLine();
    if (p != null && p != _page) {
      setState(() => _page = p);
      _onPage(p);
    }
  }

  Future<void> _contJump(int page) async {
    if (!mounted) return;
    _jumping = true;
    try {
      for (var i = 0; i < 12; i++) {
        if (!_sc.hasClients || !mounted) return;
        final ctx = _keys[page]?.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(ctx, alignment: 0, duration: Duration.zero);
          break;
        }
        final cur = _pageAtLine();
        final avg = _avgPageHeight();
        final pos = _sc.position;
        final target = cur == null
            ? (page - 1) * avg
            : pos.pixels + (page - cur) * avg;
        pos.jumpTo(target.clamp(0.0, pos.maxScrollExtent));
        await WidgetsBinding.instance.endOfFrame;
      }
    } finally {
      _jumping = false;
    }
    if (mounted) {
      setState(() => _page = page);
      _onPage(page);
    }
  }

  void _syncMode(String mode) {
    if (mode == _mode) return;
    _mode = mode;
    final old = _controller;
    _controller = PageController(initialPage: _page - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      if (mode == 'continuous') _contJump(_page);
    });
  }

  void _goPage(int p) {
    if (_mode == 'continuous') {
      setState(() => _page = p);
      _contJump(p);
    } else {
      _controller.jumpToPage(p - 1);
    }
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _controller.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _onPage(int page) {
    _readTimer?.cancel();
    final q = context.read<QuranProvider>();
    final act = context.read<ActivityProvider>();
    q.setLastPage(page);
    // تُحتسب الصفحة مقروءة بعد بقائها 6 ثوانٍ لتفادي احتساب التصفح السريع.
    _readTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        q.markRead(page);
        act.addPage(page);
      }
    });
  }

  HomeTokens get _tk =>
      readerTokens(context.read<QuranProvider>().readerTheme, Theme.of(context).brightness);

  void _clearSel() => setState(() {
        _sel.clear();
        _anchor = null;
      });

  void _onAyah(Ayah a) {
    // الضغطة العادية تُستخدم للتحديد المتعدد فقط؛ القائمة تُفتح بالضغطة المطوّلة.
    if (_selecting) {
      _toggleSelect(a);
      return;
    }
    _openAyahMenu(a);
  }

  void _openAyahMenu(Ayah a) {
    if (_selecting) {
      _toggleSelect(a);
      return;
    }
    setState(() => _flash = a.key);
    showAyahSheet(context, _tk, a, onMultiSelect: () {
      setState(() {
        _flash = null;
        _sel
          ..clear()
          ..add(a.key);
        _anchor = a.key;
      });
    });
  }

  void _toggleSelect(Ayah a) {
    final q = context.read<QuranProvider>();
    final data = q.data!;
    setState(() {
      if (_sel.contains(a.key)) {
        _sel.remove(a.key);
        if (_sel.isEmpty) _anchor = null;
        return;
      }
      final anchor = _anchor == null ? null : data.ayahByKey(_anchor!);
      if (anchor == null) {
        _sel.add(a.key);
        _anchor = a.key;
        return;
      }
      final i = q.ayahIndex(anchor), j = q.ayahIndex(a);
      final lo = math.min(i, j), hi = math.max(i, j);
      if (hi - lo <= 60) {
        _sel
          ..clear()
          ..addAll([for (var k = lo; k <= hi; k++) data.ayahs[k].key]);
      } else {
        _sel.add(a.key);
      }
    });
  }

  List<Ayah> _selectedAyahs() {
    final data = context.read<QuranProvider>().data!;
    return sortedAyahs(_sel.map(data.ayahByKey).whereType<Ayah>());
  }

  Future<void> _copySelected() async {
    final l = _selectedAyahs();
    if (l.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: copyText(l)));
    if (!mounted) return;
    _clearSel();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
  }

  Future<void> _shareSelected() async {
    final l = _selectedAyahs();
    if (l.isEmpty) return;
    await showShareDialog(context, l);
    if (mounted) _clearSel();
  }

  Future<void> _markSelected() async {
    final l = _selectedAyahs();
    if (l.isEmpty) return;
    await showMarkEditor(context, _tk, l);
    if (mounted) _clearSel();
  }

  Future<void> _openGoto() async {
    final r = await showGotoSheet(context, _tk, currentPage: _page);
    if (r == null || !mounted) return;
    setState(() => _flash = r.ayahKey);
    _goPage(r.page);
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer<QuranProvider>(builder: (ctx, q, _) {
        final tk = readerTokens(q.readerTheme, Theme.of(ctx).brightness);
        return Container(
          decoration: BoxDecoration(
            color: tk.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: tk.line, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 12),
                  Text('إعدادات القراءة', style: amiriStyle(24, bold: true, color: tk.ink)),
                  const SizedBox(height: 14),
                  Text('نمط القراءة', style: cairoStyle(12.5, weight: 700, color: tk.gold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    QPill(
                        tk: tk,
                        label: 'مصحف',
                        selected: q.pageMode != 'continuous',
                        onTap: () => q.setPageMode('page')),
                    const SizedBox(width: 8),
                    QPill(
                        tk: tk,
                        label: 'تمرير',
                        selected: q.pageMode == 'continuous',
                        onTap: () => q.setPageMode('continuous')),
                  ]),
                  const SizedBox(height: 14),
                  Text('حجم الخط', style: cairoStyle(12.5, weight: 700, color: tk.gold)),
                  SliderTheme(
                    data: SliderTheme.of(ctx).copyWith(
                        activeTrackColor: tk.gold,
                        inactiveTrackColor: tk.line,
                        thumbColor: tk.gold,
                        trackHeight: 3),
                    child: Slider(
                      value: q.fontSize,
                      min: 20,
                      max: 44,
                      divisions: 12,
                      label: toArabicDigits(q.fontSize.round()),
                      onChanged: q.setFontSize,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('لون الصفحة', style: cairoStyle(12.5, weight: 700, color: tk.gold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in const {
                      'auto': 'تلقائي',
                      'light': 'فاتح',
                      'dark': 'داكن',
                      'sepia': 'ورقي',
                    }.entries)
                      QPill(
                          tk: tk,
                          label: e.value,
                          selected: q.readerTheme == e.key,
                          onTap: () => q.setReaderTheme(e.key)),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  static String _countLabel(int n) {
    if (n == 1) return 'آية محددة';
    if (n == 2) return 'آيتان';
    if (n <= 10) return '${toArabicDigits(n)} آيات';
    return '${toArabicDigits(n)} آية';
  }

  void _toggleChrome() => setState(() {
        _flash = null;
        _chrome = !_chrome;
      });

  Widget _bar({required bool top, required bool show, required Widget child}) {
    return AnimatedSlide(
      offset: show ? Offset.zero : Offset(0, top ? -1 : 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(ignoring: !show, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.watch<QuranProvider>();
    final data = q.data;
    if (q.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (data == null || data.pageCount == 0) {
      return const Scaffold(
        body: Center(child: Text('تعذّر تحميل صفحات القرآن. أعد فتح التطبيق.')),
      );
    }
    if (_page > data.pageCount) _page = data.pageCount;
    final tk = readerTokens(q.readerTheme, Theme.of(context).brightness);
    final mq = MediaQuery.of(context);
    final pageAyahs = data.byPage[_page] ?? const <Ayah>[];
    final juz = pageAyahs.isNotEmpty ? pageAyahs.first.juz : 1;
    final showBars = _chrome || _selecting;
    _syncMode(q.pageMode);
    final continuous = _mode == 'continuous';

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSel();
      },
      child: Scaffold(
        backgroundColor: tk.bg,
        body: Stack(
          children: [
            const Positioned.fill(
                child: CustomPaint(painter: IslamicPatternPainter(opacity: .06))),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: mq.padding.top + 4, bottom: mq.padding.bottom + 4),
                child: continuous
                    ? ListView.builder(
                        key: const ValueKey('cont'),
                        controller: _sc,
                        cacheExtent: 1500,
                        itemCount: data.pageCount,
                        itemBuilder: (ctx, i) => KeyedSubtree(
                          key: _keyFor(i + 1),
                          child: _MushafPage(
                            q: q,
                            page: i + 1,
                            tk: tk,
                            flash: _flash,
                            selected: _sel,
                            onAyahTap: _onAyah,
                            onAyahLong: _openAyahMenu,
                            onBlankTap: _toggleChrome,
                          ),
                        ),
                      )
                    : PageView.builder(
                        key: const ValueKey('pages'),
                        controller: _controller,
                        itemCount: data.pageCount,
                        onPageChanged: (i) {
                          setState(() => _page = i + 1);
                          _onPage(i + 1);
                        },
                        itemBuilder: (ctx, i) => _MushafPage(
                          q: q,
                          page: i + 1,
                          tk: tk,
                          flash: _flash,
                          selected: _sel,
                          onAyahTap: _onAyah,
                          onAyahLong: _openAyahMenu,
                          onBlankTap: _toggleChrome,
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _bar(
                top: true,
                show: showBars,
                child: Container(
                  padding: EdgeInsets.fromLTRB(14, mq.padding.top + 6, 14, 8),
                  decoration: BoxDecoration(
                    color: tk.bg.withValues(alpha: .97),
                    border: Border(bottom: BorderSide(color: tk.line)),
                  ),
                  child: _selecting
                      ? Row(children: [
                          QCircleBtn(tk: tk, icon: kIcClose, onTap: _clearSel),
                          const SizedBox(width: 12),
                          Text(_countLabel(_sel.length),
                              style: cairoStyle(16, weight: 700, color: tk.ink)),
                          const Spacer(),
                          Text('اضغط آيات أخرى لتوسيع التحديد',
                              style: cairoStyle(11.5, color: tk.muted)),
                        ])
                      : Row(children: [
                          QCircleBtn(
                              tk: tk, icon: kIcBack, onTap: () => Navigator.of(context).maybePop()),
                          const Spacer(),
                          QCircleBtn(tk: tk, icon: kIcList, onTap: _openGoto),
                          const SizedBox(width: 10),
                          QCircleBtn(tk: tk, icon: kIcTune, onTap: _showSettings),
                        ]),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _bar(
                top: false,
                show: showBars,
                child: Container(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, mq.padding.bottom + 8),
                  decoration: BoxDecoration(
                    color: tk.bg.withValues(alpha: .97),
                    border: Border(top: BorderSide(color: tk.line)),
                  ),
                  child: _selecting
                      ? Row(children: [
                          Expanded(
                              child: QTile(
                                  tk: tk, icon: kIcCopy, label: 'نسخ', onTap: _copySelected)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: QTile(
                                  tk: tk, icon: kIcShare, label: 'مشاركة', onTap: _shareSelected)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: QTile(
                                  tk: tk, icon: kIcMark, label: 'علامة', onTap: _markSelected)),
                        ])
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Text('صفحة ${toArabicDigits(_page)}',
                                  style: cairoStyle(13, weight: 700, color: tk.ink)),
                              const Spacer(),
                              Text('الجزء ${toArabicDigits(juz)}',
                                  style: cairoStyle(12.5, color: tk.muted)),
                            ]),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: tk.gold,
                                inactiveTrackColor: tk.line,
                                thumbColor: tk.gold,
                                trackHeight: 3,
                                overlayShape: SliderComponentShape.noOverlay,
                              ),
                              child: Slider(
                                value: _page.toDouble(),
                                min: 1,
                                max: data.pageCount.toDouble(),
                                onChanged: (v) {
                                  final p = v.round();
                                  if (p != _page) _goPage(p);
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _K { banner, basmala, para }

class _Seg {
  final _K kind;
  final int surah;
  final List<Ayah> ayahs;
  const _Seg.banner(this.surah)
      : kind = _K.banner,
        ayahs = const [];
  const _Seg.basmala()
      : kind = _K.basmala,
        surah = 0,
        ayahs = const [];
  const _Seg.para(this.ayahs)
      : kind = _K.para,
        surah = 0;
}

/// صفحة من المصحف بنص حر الحجم (يتحكم فيه حجم الخط من الإعدادات).
class _MushafPage extends StatefulWidget {
  final QuranProvider q;
  final int page;
  final HomeTokens tk;
  final String? flash;
  final Set<String> selected;
  final void Function(Ayah) onAyahTap;
  final void Function(Ayah) onAyahLong;
  final VoidCallback onBlankTap;

  const _MushafPage({
    required this.q,
    required this.page,
    required this.tk,
    required this.flash,
    required this.selected,
    required this.onAyahTap,
    required this.onAyahLong,
    required this.onBlankTap,
  });

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  final List<GestureRecognizer> _recs = [];

  void _disposeRecs() {
    for (final r in _recs) {
      r.dispose();
    }
    _recs.clear();
  }

  @override
  void dispose() {
    _disposeRecs();
    super.dispose();
  }

  TextStyle _base(double fs) => TextStyle(
        fontFamily: AppTheme.quranFont,
        fontSize: fs,
        height: 1.85,
        color: widget.tk.ink,
      );

  List<_Seg> _segments(List<Ayah> ayahs) {
    final out = <_Seg>[];
    var cur = <Ayah>[];
    void flush() {
      if (cur.isNotEmpty) {
        out.add(_Seg.para(cur));
        cur = <Ayah>[];
      }
    }

    for (final a in ayahs) {
      if (a.number == 1) {
        flush();
        out.add(_Seg.banner(a.surah));
        if (a.surah != 1 && a.surah != 9) out.add(const _Seg.basmala());
      }
      cur.add(a);
    }
    flush();
    return out;
  }

  List<InlineSpan> _spans(List<Ayah> list, double fs) {
    final tk = widget.tk;
    final q = widget.q;
    final data = q.data!;
    final selecting = widget.selected.isNotEmpty;
    final out = <InlineSpan>[];
    for (final a in list) {
      final idx = q.ayahIndex(a);
      final prevHq = idx > 0 ? data.ayahs[idx - 1].hizbQuarter : 0;
      if (a.hizbQuarter != prevHq) {
        final isHizb = (a.hizbQuarter - 1) % 4 == 0;
        out.add(TextSpan(
            text: '\u06DE ',
            style: TextStyle(color: tk.gold, fontSize: fs * (isHizb ? 1.0 : .72))));
      }
      Color? bg;
      final mark = q.markOf(a.key);
      if (mark != null) bg = kMarkColors[mark.color % kMarkColors.length].withValues(alpha: .22);
      if (widget.flash == a.key) bg = tk.gold.withValues(alpha: .28);
      if (widget.selected.contains(a.key)) bg = tk.leaf.withValues(alpha: .34);
      // الضغطة العادية تمرّ إلى إظهار/إخفاء الأزرار؛ الضغطة المطوّلة تفتح قائمة الآية.
      // أثناء التحديد المتعدد تصبح الضغطة العادية لتبديل التحديد.
      final GestureRecognizer rec;
      if (selecting) {
        rec = TapGestureRecognizer()..onTap = () => widget.onAyahTap(a);
      } else {
        rec = LongPressGestureRecognizer()..onLongPress = () => widget.onAyahLong(a);
      }
      _recs.add(rec);
      out.add(TextSpan(
        text: a.text,
        recognizer: rec,
        style: bg == null ? null : TextStyle(backgroundColor: bg),
      ));
      out.add(TextSpan(
        text: ' \uFD3F${toArabicDigits(a.number)}\uFD3E${a.sajda ? ' \u06E9' : ''} ',
        style: TextStyle(color: tk.gold, fontSize: fs * .78),
      ));
    }
    return out;
  }

  List<Widget> _content(List<_Seg> segs, double fs) {
    final tk = widget.tk;
    final data = widget.q.data!;
    return [
      for (final s in segs)
        switch (s.kind) {
          _K.banner => _SurahBanner(surah: s.surah, tk: tk),
          _K.basmala => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(data.basmala,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: _base(fs * .95)),
            ),
          _K.para => Text.rich(
              TextSpan(children: _spans(s.ayahs, fs), style: _base(fs)),
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
            ),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecs();
    final tk = widget.tk;
    final data = widget.q.data!;
    final ayahs = data.byPage[widget.page] ?? const <Ayah>[];
    final segs = _segments(ayahs);
    final continuous = widget.q.pageMode == 'continuous';

    final footer = Center(
      child: IslamicStar(
        size: 30,
        color: tk.mint,
        child: Text(toArabicDigits(widget.page),
            style: cairoStyle(11, weight: 700, color: tk.mintInk)),
      ),
    );

    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._content(segs, widget.q.fontSize),
        const SizedBox(height: 12),
        footer,
      ],
    );
    const pad = EdgeInsets.fromLTRB(22, 8, 22, 28);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onBlankTap,
      child: continuous
          ? Padding(padding: pad, child: col)
          : SingleChildScrollView(padding: pad, child: col),
    );
  }
}

class _SurahBanner extends StatelessWidget {
  final int surah;
  final HomeTokens tk;
  const _SurahBanner({required this.surah, required this.tk});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: tk.mint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tk.gold.withValues(alpha: .6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IslamicStar(size: 14, color: tk.gold),
          const SizedBox(width: 10),
          Text(surahTitle(surah), style: amiriStyle(21, bold: true, color: tk.mintInk)),
          const SizedBox(width: 10),
          IslamicStar(size: 14, color: tk.gold),
        ],
      ),
    );
  }
}
