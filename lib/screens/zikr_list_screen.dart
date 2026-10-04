import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/home_tokens.dart';
import '../core/text_utils.dart';
import '../providers/azkar_provider.dart';
import '../widgets/home_style.dart';
import '../widgets/zikr_card.dart';

class ZikrListScreen extends StatefulWidget {
  final String categoryId;
  const ZikrListScreen({super.key, required this.categoryId});

  @override
  State<ZikrListScreen> createState() => _ZikrListScreenState();
}

class _ZikrListScreenState extends State<ZikrListScreen> {
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  bool _restoredPosition = false;
  bool _celebrated = false;
  bool _hideDone = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // إبقاء الشاشة مفتوحة أثناء القراءة
  }

  GlobalKey _key(int i) => _keys.putIfAbsent(i, () => GlobalKey());

  @override
  void dispose() {
    WakelockPlus.disable();
    _scrollController.dispose();
    super.dispose();
  }

  /// يمرّر لأعلى البطاقة المطلوبة بدقة (بدل التقدير بارتفاع ثابت اللي كان يرجّع القائمة لفوق).
  void _reveal(int index, {required bool animate}) {
    final ctx = _key(index).currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.02,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  void _fontSheet() {
    final tk = HomeTokens.of(context);
    showHomeSheet<void>(
      context,
      builder: (ctx) => Consumer<AzkarProvider>(
        builder: (ctx, p, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('حجم الخط', style: cairoStyle(16, weight: 700, color: tk.ink)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              decoration: BoxDecoration(
                color: tk.bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tk.line),
              ),
              child: Text(
                'بسم الله الرحمن الرحيم',
                textAlign: TextAlign.center,
                style: amiriStyle(21 * p.fontScale, color: tk.ink, height: 1.8),
              ),
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(ctx).copyWith(
                activeTrackColor: tk.gold,
                inactiveTrackColor: tk.line,
                thumbColor: tk.gold,
                overlayColor: tk.gold.withValues(alpha: .15),
                trackHeight: 4,
              ),
              child: Row(
                children: [
                  Text('أ', style: cairoStyle(14, weight: 700, color: tk.muted)),
                  Expanded(
                    child: Slider(
                      value: p.fontScale.clamp(0.8, 1.6),
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      onChanged: (v) => p.setFontScale(v),
                    ),
                  ),
                  Text('أ', style: cairoStyle(26, weight: 700, color: tk.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(AzkarProvider provider) async {
    final tk = HomeTokens.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: tk.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tk.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إعادة تعيين العداد؟',
                  style: cairoStyle(16, weight: 700, color: tk.ink)),
              const SizedBox(height: 6),
              Text('سيتم تصفير تقدّمك في هذا القسم.',
                  style: cairoStyle(13, color: tk.muted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: HomeButton(
                        tk: tk,
                        label: 'إلغاء',
                        onTap: () => Navigator.pop(ctx, false)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HomeButton(
                        tk: tk,
                        primary: true,
                        label: 'إعادة التعيين',
                        onTap: () => Navigator.pop(ctx, true)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      provider.resetCategory(widget.categoryId);
      _celebrated = false;
    }
  }

  void _afterComplete(int index, int length) {
    final provider = context.read<AzkarProvider>();
    if (!_celebrated && provider.categoryProgress(widget.categoryId) >= 1) {
      _celebrated = true;
      _showDone();
      return;
    }
    _scrollToNext(index, length);
  }

  void _showDone() {
    final tk = HomeTokens.of(context);
    showHomeSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tk.mint,
              shape: BoxShape.circle,
              border: Border.all(color: tk.leaf.withValues(alpha: .5)),
            ),
            child: Center(
                child: StyledIcon(ZikrIcons.check, size: 30, color: tk.leaf)),
          ),
          const SizedBox(height: 12),
          Text('أتممت الأذكار، تقبّل الله منك',
              textAlign: TextAlign.center,
              style: amiriStyle(22, bold: true, color: tk.ink)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: HomeButton(
                    tk: tk,
                    label: 'البقاء هنا',
                    onTap: () => Navigator.pop(ctx)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HomeButton(
                  tk: tk,
                  primary: true,
                  label: 'الرئيسية',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrollToNext(int index, int length) {
    final cat = context.read<AzkarProvider>().categoryById(widget.categoryId);
    var next = -1;
    for (var j = index + 1; j < length; j++) {
      if (cat.azkar[j].remaining > 0) {
        next = j;
        break;
      }
    }
    if (next < 0) return;
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      _reveal(next, animate: true);
    });
  }

  PopupMenuItem<String> _menuItem(
      HomeTokens tk, String value, String icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      height: 46,
      child: Row(
        children: [
          StyledIcon(icon, size: 20, color: tk.gold),
          const SizedBox(width: 12),
          Text(label, style: cairoStyle(13.5, weight: 600, color: tk.ink)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final provider = context.watch<AzkarProvider>();
    final cat = provider.categoryById(widget.categoryId);
    final progress = provider.categoryProgress(widget.categoryId);
    final total = cat.azkar.length;
    final doneCount = cat.azkar.where((z) => z.remaining == 0).length;
    final pct = (progress * 100).round();

    if (!_restoredPosition) {
      _restoredPosition = true;
      final firstPending = cat.azkar.indexWhere((z) => z.remaining > 0);
      if (firstPending > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reveal(firstPending, animate: false);
        });
      }
    }

    final allDone = cat.azkar.every((z) => z.remaining == 0);

    return Scaffold(
      body: MediaQuery(
        data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                PageHeader(
                  title: 'الأذكار',
                  actions: [
                    HeaderButton(
                      icon: ZikrIcons.fontSize,
                      label: 'حجم الخط',
                      onTap: _fontSheet,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'المزيد',
                      padding: EdgeInsets.zero,
                      color: tk.card,
                      surfaceTintColor: Colors.transparent,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: tk.line),
                      ),
                      onSelected: (v) {
                        if (v == 'hide') setState(() => _hideDone = !_hideDone);
                        if (v == 'reset') _confirmReset(provider);
                      },
                      itemBuilder: (_) => [
                        _menuItem(
                            tk,
                            'hide',
                            _hideDone ? ZikrIcons.eye : ZikrIcons.eyeOff,
                            _hideDone ? 'إظهار المكتملة' : 'إخفاء المكتملة'),
                        _menuItem(tk, 'reset', ZikrIcons.refresh,
                            'إعادة تعيين العداد'),
                      ],
                      child: HeaderButton(icon: ZikrIcons.dots),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 6, bottom: 24),
                    child: Column(
                      children: [
                        HomeHeroCard(
                          tk: tk,
                          icon: ZikrIcons.forKey(cat.icon),
                          eyebrow: '${toArabicDigits(total)} من الأذكار',
                          title: cat.title,
                          progress: progress,
                          caption:
                              'أنجزت ${toArabicDigits(pct)}٪ · ${toArabicDigits(doneCount)} من ${toArabicDigits(total)}',
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < cat.azkar.length; i++)
                          if (!(_hideDone && cat.azkar[i].remaining == 0))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: KeyedSubtree(
                                key: _key(i),
                                child: ZikrCard(
                                  zikr: cat.azkar[i],
                                  onCompleted: () =>
                                      _afterComplete(i, cat.azkar.length),
                                ),
                              ),
                            ),
                        if (_hideDone && allDone)
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: Text('كل أذكار هذا القسم مكتملة ✓',
                                style: cairoStyle(14,
                                    weight: 600, color: tk.mintInk)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
