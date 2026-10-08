import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'ayah_marker.dart';
import 'goto_sheet.dart';
import 'mushaf_layout.dart';
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
  ScrollController _sc = ScrollController();
  // الصفحات المبنية حاليًا فقط (تسجّل نفسها وتحذف نفسها)، بدل GlobalKey لكل الـ604 صفحة.
  final Map<int, BuildContext> _reg = <int, BuildContext>{};
  late final QuranProvider _q;
  late String _mode;
  // في وضع التمرير: الصفحة التي تُبنى القائمة منها (مرساة)؛ القفز لأي صفحة = إعادة ترسيخ فورية
  // بدل قفزات متكررة تبني عشرات الصفحات الثقيلة (كانت سبب البطء والكراش).
  late int _contAnchor;
  late int _page;
  String? _flash;
  Timer? _readTimer;
  Timer? _lastTimer;
  int? _pendingLast;
  bool _chrome = true;
  final Set<String> _sel = <String>{};
  String? _anchor;

  bool get _selecting => _sel.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _q = context.read<QuranProvider>();
    _page = widget.page.clamp(1, 604);
    _contAnchor = _page;
    _flash = widget.highlight;
    _controller = PageController(initialPage: _page - 1);
    _mode = _q.pageMode;
    _sc.addListener(_onScroll);
    _onPage(_page);
  }

  /// الصفحة التي يقع عندها خط القراءة (أعلى الشاشة تقريبًا) في وضع التمرير.
  /// تفحص فقط الصفحات المبنية حاليًا (عادةً ٣–٥).
  int? _pageAtLine() {
    final line = MediaQuery.of(context).padding.top + 90;
    for (final e in _reg.entries) {
      final ctx = e.value;
      if (!ctx.mounted) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final top = ro.localToGlobal(Offset.zero).dy;
      if (top <= line && top + ro.size.height > line) return e.key;
    }
    return null;
  }

  void _onScroll() {
    if (!mounted) return;
    final p = _pageAtLine();
    if (p != null && p != _page) {
      setState(() => _page = p);
      _onPage(p);
    }
  }

  /// يعيد بناء قائمة التمرير بحيث تبدأ من [page] مباشرة (بدون أي قفز/تمرير).
  void _reanchor(int page) {
    final old = _sc;
    _sc = ScrollController()..addListener(_onScroll);
    _contAnchor = page;
    _page = page;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _syncMode(String mode) {
    if (mode == _mode) return;
    _mode = mode;
    final old = _controller;
    _controller = PageController(initialPage: _page - 1);
    if (mode == 'continuous') _reanchor(_page);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _goPage(int p) {
    if (_mode == 'continuous') {
      setState(() => _reanchor(p));
      _onPage(p);
    } else {
      _controller.jumpToPage(p - 1);
    }
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _lastTimer?.cancel();
    // لو خرج المستخدم قبل انتهاء مهلة الحفظ نحفظ آخر صفحة بعد انتهاء الفريم.
    final pending = _pendingLast;
    if (pending != null) {
      final q = _q;
      Future.microtask(() => q.setLastPage(pending));
    }
    _controller.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _onPage(int page) {
    _readTimer?.cancel();
    _lastTimer?.cancel();
    final q = _q;
    final act = context.read<ActivityProvider>();
    // حفظ آخر صفحة يُعمل notifyListeners ويعيد بناء الشاشات؛ نؤجله لحين توقف التمرير.
    _pendingLast = page;
    _lastTimer = Timer(const Duration(milliseconds: 500), () {
      _pendingLast = null;
      if (mounted) q.setLastPage(page);
    });
    // تُحتسب الصفحة مقروءة بعد بقائها 6 ثوانٍ لتفادي احتساب التصفح السريع.
    _readTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        q.markRead(page);
        act.addPage(page);
      }
    });
  }

  double get _refHeight {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.top - mq.padding.bottom - 8;
  }

  HomeTokens get _tk => readerTokens(
      context.read<QuranProvider>().readerTheme, Theme.of(context).brightness);

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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم النسخ')));
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
                            color: tk.line,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 12),
                  Text('إعدادات القراءة',
                      style: amiriStyle(24, bold: true, color: tk.ink)),
                  const SizedBox(height: 14),
                  Text('نمط القراءة',
                      style: cairoStyle(12.5, weight: 700, color: tk.gold)),
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
                  Row(children: [
                    Text('حجم الخط',
                        style: cairoStyle(12.5, weight: 700, color: tk.gold)),
                    const SizedBox(width: 8),
                    Text(
                        q.isFitToPage
                            ? 'ملء الصفحة'
                            : '${toArabicDigits((q.fontScale * 100).round())}٪',
                        style: cairoStyle(12, color: tk.muted)),
                  ]),
                  Row(children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(ctx).copyWith(
                            activeTrackColor: tk.gold,
                            inactiveTrackColor: tk.line,
                            thumbColor: tk.gold,
                            trackHeight: 3),
                        child: Slider(
                          value: q.fontScale.clamp(0.8, 2.0).toDouble(),
                          min: 0.8,
                          max: 2.0,
                          divisions: 12,
                          onChanged: q.setFontScale,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: q.isFitToPage ? .4 : 1,
                      child: GestureDetector(
                        onTap: q.isFitToPage ? null : q.resetFontScale,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: tk.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: tk.line),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.restart_alt_rounded,
                                size: 18, color: tk.mintInk),
                            const SizedBox(width: 4),
                            Text('إعادة',
                                style: cairoStyle(12.5,
                                    weight: 600, color: tk.ink)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text('لون الصفحة',
                      style: cairoStyle(12.5, weight: 700, color: tk.gold)),
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

  Widget _contList(QuranData data, QuranProvider q, HomeTokens tk) {
    final anchor = _contAnchor.clamp(1, data.pageCount);
    Widget item(int page) => RepaintBoundary(
          child: _Tracked(
            page: page,
            reg: _reg,
            child: _MushafPage(
              q: q,
              page: page,
              tk: tk,
              flash: _flash,
              selected: _sel,
              refHeight: _refHeight,
              onAyahTap: _onAyah,
              onAyahLong: _openAyahMenu,
              onBlankTap: _toggleChrome,
            ),
          ),
        );
    final fwdKey = ValueKey('fwd$anchor');
    return CustomScrollView(
      key: ValueKey('cont$anchor'),
      controller: _sc,
      center: fwdKey,
      scrollCacheExtent: const ScrollCacheExtent.pixels(800),
      slivers: [
        // الصفحات السابقة للمرساة (تتجه للأعلى).
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => item(anchor - 1 - i),
            childCount: anchor - 1,
          ),
        ),
        // المرساة وما بعدها.
        SliverList(
          key: fwdKey,
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => item(anchor + i),
            childCount: data.pageCount - anchor + 1,
          ),
        ),
      ],
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
                child: RepaintBoundary(
                    child: CustomPaint(
                        painter: IslamicPatternPainter(opacity: .06)))),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                    top: mq.padding.top + 4, bottom: mq.padding.bottom + 4),
                child: continuous
                    ? _contList(data, q, tk)
                    : PageView.builder(
                        key: const ValueKey('pages'),
                        controller: _controller,
                        itemCount: data.pageCount,
                        onPageChanged: (i) {
                          setState(() => _page = i + 1);
                          _onPage(i + 1);
                        },
                        itemBuilder: (ctx, i) => RepaintBoundary(
                            child: _MushafPage(
                          q: q,
                          page: i + 1,
                          tk: tk,
                          flash: _flash,
                          selected: _sel,
                          refHeight: _refHeight,
                          onAyahTap: _onAyah,
                          onAyahLong: _openAyahMenu,
                          onBlankTap: _toggleChrome,
                        )),
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
                              style:
                                  cairoStyle(16, weight: 700, color: tk.ink)),
                          const Spacer(),
                          Text('اضغط آيات أخرى لتوسيع التحديد',
                              style: cairoStyle(11.5, color: tk.muted)),
                        ])
                      : Row(children: [
                          QCircleBtn(
                              tk: tk,
                              icon: kIcBack,
                              onTap: () => Navigator.of(context).maybePop()),
                          const Spacer(),
                          QCircleBtn(tk: tk, icon: kIcList, onTap: _openGoto),
                          const SizedBox(width: 10),
                          QCircleBtn(
                              tk: tk, icon: kIcTune, onTap: _showSettings),
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
                  padding:
                      EdgeInsets.fromLTRB(14, 8, 14, mq.padding.bottom + 8),
                  decoration: BoxDecoration(
                    color: tk.bg.withValues(alpha: .97),
                    border: Border(top: BorderSide(color: tk.line)),
                  ),
                  child: _selecting
                      ? Row(children: [
                          Expanded(
                              child: QTile(
                                  tk: tk,
                                  icon: kIcCopy,
                                  label: 'نسخ',
                                  onTap: _copySelected)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: QTile(
                                  tk: tk,
                                  icon: kIcShare,
                                  label: 'مشاركة',
                                  onTap: _shareSelected)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: QTile(
                                  tk: tk,
                                  icon: kIcMark,
                                  label: 'علامة',
                                  onTap: _markSelected)),
                        ])
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Text('صفحة ${toArabicDigits(_page)}',
                                  style: cairoStyle(13,
                                      weight: 700, color: tk.ink)),
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

/// يسجّل سياق الصفحة أثناء بنائها فقط، لحساب «الصفحة الحالية» بدون GlobalKeys.
class _Tracked extends StatefulWidget {
  final int page;
  final Map<int, BuildContext> reg;
  final Widget child;
  const _Tracked({required this.page, required this.reg, required this.child});

  @override
  State<_Tracked> createState() => _TrackedState();
}

class _TrackedState extends State<_Tracked> {
  @override
  void initState() {
    super.initState();
    widget.reg[widget.page] = context;
  }

  @override
  void dispose() {
    if (identical(widget.reg[widget.page], context))
      widget.reg.remove(widget.page);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// صفحة من المصحف: ١٥ سطرًا مضبوطة على عرض الصفحة وتظهر كاملة بدون سكرول،
/// وعند تغيير حجم الخط من الإعدادات تصبح الصفحة قابلة للتمرير.
class _MushafPage extends StatelessWidget {
  final QuranProvider q;
  final int page;
  final HomeTokens tk;
  final String? flash;
  final Set<String> selected;
  final double refHeight; // الارتفاع المرجعي في وضع التمرير المستمر
  final void Function(Ayah) onAyahTap;
  final void Function(Ayah) onAyahLong;
  final VoidCallback onBlankTap;

  const _MushafPage({
    required this.q,
    required this.page,
    required this.tk,
    required this.flash,
    required this.selected,
    required this.refHeight,
    required this.onAyahTap,
    required this.onAyahLong,
    required this.onBlankTap,
  });

  static const double _hPad = 8, _headerH = 24, _footerH = 38;

  Color? _bgOf(Ayah a) {
    Color? bg;
    final mark = q.markOf(a.key);
    if (mark != null) {
      bg = kMarkColors[mark.color % kMarkColors.length].withValues(alpha: .22);
    }
    if (flash == a.key) bg = tk.gold.withValues(alpha: .28);
    if (selected.contains(a.key)) bg = tk.leaf.withValues(alpha: .34);
    return bg;
  }

  TextStyle _base(double f) => TextStyle(
        fontFamily: AppTheme.quranFont,
        fontSize: f,
        height: 1.0,
        color: tk.ink,
      );

  Widget _item(MItem it, double f) {
    final bg = _bgOf(it.ayah);
    final selecting = selected.isNotEmpty;
    final word = Text.rich(
      TextSpan(children: [
        if (it.lead > 0)
          TextSpan(
              text: '\u06DE ',
              style: TextStyle(
                  color: tk.gold, fontSize: f * (it.lead == 2 ? 1.0 : .72))),
        TextSpan(text: it.text),
      ]),
      style: _base(f),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      softWrap: false,
    );
    final child = Container(
      height: f * kLineH,
      alignment: Alignment.center,
      color: bg,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        word,
        if (it.end) ...[
          SizedBox(width: f * kMarkerGap),
          if (it.sajda)
            Padding(
              padding: EdgeInsetsDirectional.only(end: f * .1),
              child: Text('\u06E9',
                  textScaler: TextScaler.noScaling,
                  style: _base(f * .8).copyWith(color: tk.gold)),
            ),
          AyahMarker(number: it.ayah.number, size: f * kMarkerSize, tk: tk),
        ],
      ]),
    );
    // الضغطة العادية تُظهر/تخفي الأزرار (تمرّ للصفحة)؛ المطوّلة تفتح قائمة الآية؛
    // أثناء التحديد المتعدد تصبح الضغطة العادية لتبديل التحديد.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: selecting ? () => onAyahTap(it.ayah) : null,
      onLongPress: selecting ? null : () => onAyahLong(it.ayah),
      child: child,
    );
  }

  Widget _line(MLine l, double f, double slotH, double w) {
    final kids = <Widget>[];
    for (var i = 0; i < l.items.length; i++) {
      final it = l.items[i];
      kids.add(_item(it, f));
      if (i < l.items.length - 1) {
        // المسافة بين كلمتين من نفس الآية تُلوَّن مع التظليل ليبقى متصلًا.
        final bg = it.end ? null : _bgOf(it.ayah);
        final gap = Container(height: f * kLineH, color: bg);
        kids.add(l.justify
            ? Expanded(child: gap)
            : SizedBox(width: f * kCenterGap, child: gap));
      }
    }
    return SizedBox(
      height: slotH,
      child: Center(
        child: SizedBox(
          width: w,
          child: Row(
            mainAxisAlignment:
                l.justify ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: kids,
          ),
        ),
      ),
    );
  }

  Widget _row(MRow r, MPageLayout lay, double w) {
    final f = lay.font, slotH = lay.slotH;
    switch (r.kind) {
      case MRowKind.banner:
        return SizedBox(
          height: slotH,
          child: Center(
              child: _SurahBanner(
                  surah: r.surah, tk: tk, height: math.min(44, slotH * .84))),
        );
      case MRowKind.basmala:
        return SizedBox(
          height: slotH,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(q.data!.basmala,
                  textDirection: TextDirection.rtl,
                  textScaler: TextScaler.noScaling,
                  style: _base(f * 1.05)),
            ),
          ),
        );
      case MRowKind.line:
        return _line(r.line!, f, slotH, w);
    }
  }

  Widget _header(List<Ayah> ayahs) {
    if (ayahs.isEmpty) return const SizedBox(height: _headerH);
    final names = <int>[];
    for (final a in ayahs) {
      if (!names.contains(a.surah)) names.add(a.surah);
    }
    final st = cairoStyle(12, weight: 600, color: tk.muted);
    return SizedBox(
      height: _headerH,
      child: Row(children: [
        Text(names.map(QuranAudioProvider.surahName).join('  '),
            textScaler: TextScaler.noScaling, style: st),
        const Spacer(),
        Text('الجزء ${toArabicDigits(ayahs.first.juz)}',
            textScaler: TextScaler.noScaling, style: st),
      ]),
    );
  }

  Widget _footer() => SizedBox(
        height: _footerH,
        child: Center(
          child: IslamicStar(
            size: 30,
            color: tk.mint,
            child: Text(toArabicDigits(page),
                textScaler: TextScaler.noScaling,
                style: cairoStyle(11, weight: 700, color: tk.mintInk)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final data = q.data!;
    final ayahs = data.byPage[page] ?? const <Ayah>[];
    final continuous = q.pageMode == 'continuous';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBlankTap,
      child: LayoutBuilder(builder: (ctx, c) {
        final w = c.maxWidth - _hPad * 2;
        final fullH = c.hasBoundedHeight ? c.maxHeight : refHeight;
        final avail = math.max(120.0, fullH - _headerH - _footerH - 4);
        final lay = layoutPage(
          data: data,
          page: page,
          indexOf: q.ayahIndex,
          width: w,
          height: avail,
          scale: q.fontScale,
        );
        warmNeighbors(
          data: data,
          page: page,
          indexOf: q.ayahIndex,
          width: w,
          height: avail,
          scale: q.fontScale,
        );
        final body = Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _hPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(ayahs),
                for (final r in lay.rows) _row(r, lay, w),
                if (!lay.fits) const SizedBox(height: 12),
                _footer(),
              ],
            ),
          ),
        );
        if (lay.fits) {
          // صفحة كاملة بدون سكرول.
          return SizedBox(
              height: continuous ? fullH : null,
              child: Align(alignment: Alignment.topCenter, child: body));
        }
        return continuous
            ? body
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16), child: body);
      }),
    );
  }
}

class _SurahBanner extends StatelessWidget {
  final int surah;
  final HomeTokens tk;
  final double height;
  const _SurahBanner(
      {required this.surah, required this.tk, this.height = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
          Text(surahTitle(surah),
              style: amiriStyle(math.min(21, height * .5),
                  bold: true, color: tk.mintInk)),
          const SizedBox(width: 10),
          IslamicStar(size: 14, color: tk.gold),
        ],
      ),
    );
  }
}
