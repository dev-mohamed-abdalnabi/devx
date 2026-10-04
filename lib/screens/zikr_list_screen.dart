import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/azkar_provider.dart';
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer<AzkarProvider>(
        builder: (ctx, p, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('حجم الخط',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('بسم الله الرحمن الرحيم',
                    style: TextStyle(fontSize: 19 * p.fontScale, height: 1.8)),
                Row(
                  children: [
                    const Text('أ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Slider(
                        value: p.fontScale.clamp(0.8, 1.6),
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        onChanged: (v) => p.setFontScale(v),
                      ),
                    ),
                    const Text('أ', style: TextStyle(fontSize: 26)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(AzkarProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة تعيين العداد؟'),
        content: const Text('سيتم تصفير تقدّمك في هذا القسم.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إعادة التعيين')),
        ],
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 56, color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(height: 12),
              Text('أتممت الأذكار، تقبّل الله منك',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('البقاء هنا')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      child: const Text('الرئيسية'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final cat = provider.categoryById(widget.categoryId);
    final progress = provider.categoryProgress(widget.categoryId);

    if (!_restoredPosition) {
      _restoredPosition = true;
      final firstPending = cat.azkar.indexWhere((z) => z.remaining > 0);
      if (firstPending > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reveal(firstPending, animate: false);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(cat.title),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'المزيد',
            onSelected: (v) {
              if (v == 'font') _fontSheet();
              if (v == 'hide') setState(() => _hideDone = !_hideDone);
              if (v == 'reset') _confirmReset(provider);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'font',
                  child: ListTile(
                      dense: true,
                      leading: Icon(Icons.text_fields_rounded),
                      title: Text('حجم الخط'))),
              PopupMenuItem(
                  value: 'hide',
                  child: ListTile(
                      dense: true,
                      leading: Icon(_hideDone
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      title:
                          Text(_hideDone ? 'إظهار المكتملة' : 'إخفاء المكتملة'))),
              const PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                      dense: true,
                      leading: Icon(Icons.refresh),
                      title: Text('إعادة تعيين العداد'))),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < cat.azkar.length; i++)
              if (!(_hideDone && cat.azkar[i].remaining == 0))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: KeyedSubtree(
                    key: _key(i),
                    child: ZikrCard(
                      zikr: cat.azkar[i],
                      onCompleted: () => _afterComplete(i, cat.azkar.length),
                    ),
                  ),
                ),
            if (_hideDone && cat.azkar.every((z) => z.remaining == 0))
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('كل أذكار هذا القسم مكتملة ✓'),
              ),
          ],
        ),
      ),
    );
  }
}
