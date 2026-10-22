import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:azkari_native/azkari_native.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../providers/activity_provider.dart';
import '../home/home_art.dart';

const _chevronIcon = '<path d="M9 6l6 6-6 6"/>';
const _plusIcon = '<path d="M12 5v14M5 12h14"/>';
const _flagIcon = '<path d="M6 21V4M6 5h11l-2 4 2 4H6"/>';
const _resetIcon = '<path d="M4 12a8 8 0 1 0 3-6.200M4 4v4h4"/>';
const _trashIcon = '<path d="M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13"/>';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  String _selected = 'subhan';
  bool _pressed = false;

  void _tap(ActivityProvider a, TasbeehPreset p) {
    a.tapTasbeeh(p.id);
    if (!a.vibrate && !a.sound) return;
    final reachedGoal = a.tasbeehCount(p.id) == a.goalOf(p.id);
    // الاهتزاز والصوت من الجانب الأصلي مباشرة؛ لا يتأثران بإعدادات «ردود اللمس» في النظام.
    AzkariNative.tasbeehFeedback(
            vibrate: a.vibrate, sound: a.sound, goal: reachedGoal)
        .then((ok) {
      if (ok) return;
      // احتياطي لو القناة الأصلية غير متاحة.
      if (a.vibrate) {
        reachedGoal ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
      }
      if (a.sound) SystemSound.play(SystemSoundType.click);
    });
  }

  Future<void> _editGoal(ActivityProvider a, TasbeehPreset p) async {
    final c = TextEditingController(text: a.goalOf(p.id).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الهدف اليومي'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'مثال: ١٠٠'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    final v = int.tryParse(c.text);
    c.dispose();
    if (ok == true && v != null && v > 0) a.setGoal(p.id, v);
  }

  Future<void> _addCustom(ActivityProvider a) async {
    final text = TextEditingController();
    final goal = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسبيحة مخصصة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: text,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'النص'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goal,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'الهدف اليومي'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
        ],
      ),
    );
    final t = text.text.trim();
    final g = int.tryParse(goal.text) ?? 100;
    text.dispose();
    goal.dispose();
    if (ok == true && t.isNotEmpty) {
      final id = a.addCustom(t, g);
      setState(() => _selected = id);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final a = context.watch<ActivityProvider>();
    final presets = a.presets;
    final p = presets.firstWhere((e) => e.id == _selected, orElse: () => presets.first);
    final count = a.tasbeehCount(p.id);
    final goal = a.goalOf(p.id);
    final progress = goal <= 0 ? 0.0 : math.min(1.0, count / goal);
    final done = count >= goal;

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: Scaffold(
        // bottom مفعّل: لا تتداخل الأزرار مع أزرار/شريط تنقّل النظام.
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            // الشاشات القصيرة (أو الأفقي): نعطي المحتوى ارتفاعًا أدنى ويُمرَّر،
            // بدل overflow عند ضغط منطقة العدّ.
            child: LayoutBuilder(builder: (context, box) {
              final top = <Widget>[
                _Header(
                  tk: tk,
                  total: a.today.tasbeehTotal,
                  onBack: () => Navigator.of(context).maybePop(),
                ),

                // ── اختيار التسبيحة ──
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final e in presets) ...[
                        _PresetChip(
                          tk: tk,
                          label: e.text,
                          selected: e.id == p.id,
                          onTap: () => setState(() => _selected = e.id),
                        ),
                        const SizedBox(width: 8),
                      ],
                      GestureDetector(
                        onTap: () => _addCustom(a),
                        behavior: HitTestBehavior.opaque,
                        child: CustomPaint(
                          painter: DashedBorderPainter(color: tk.gold, radius: 18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                HomeIcon(_plusIcon, size: 16, color: tk.gold),
                                const SizedBox(width: 6),
                                Text('مخصصة',
                                    style: cairoStyle(13, weight: 600, color: tk.gold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── نص التسبيحة: إطار متقطع + نقش مثل آية اليوم ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CustomPaint(
                    foregroundPainter: DashedBorderPainter(color: tk.gold, radius: 18),
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: IslamicPatternPainter(opacity: .18)),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(p.text,
                                textAlign: TextAlign.center,
                                style: amiriStyle(28, bold: true, color: tk.ink, height: 1.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

];
              final cnt = <Widget>[
                // ── منطقة العدّ: الضغط في أي مكان فيها يسبّح ──
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    onTap: () => _tap(a, p),
                    child: Semantics(
                      button: true,
                      label:
                          '${p.text}، العدد ${toArabicDigits(count)} من ${toArabicDigits(goal)}. اضغط للتسبيح',
                      child: LayoutBuilder(builder: (context, box) {
                        final s = math.max(
                            150.0, math.min(math.min(box.maxWidth, 300.0), box.maxHeight - 44));
                        return Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _CounterRing(
                                  tk: tk,
                                  size: s,
                                  count: count,
                                  goal: goal,
                                  progress: progress,
                                  done: done,
                                  pressed: _pressed,
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 24,
                                  child: Text(
                                    done
                                        ? 'ما شاء الله، أتممت هدف اليوم'
                                        : 'المتبقي ${toArabicDigits(goal - count)}',
                                    style: done
                                        ? cairoStyle(14, weight: 700, color: tk.leaf)
                                        : cairoStyle(13, color: tk.muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

];
              final bottom = <Widget>[
                // ── أزرار الإجراءات ──
                Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        tk: tk,
                        icon: _flagIcon,
                        label: 'الهدف',
                        onTap: () => _editGoal(a, p),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PillButton(
                        tk: tk,
                        icon: _resetIcon,
                        label: 'إعادة العدّ',
                        onTap: count == 0
                            ? null
                            : () async {
                                if (await _confirm('إعادة العدّ',
                                    'سيُصفَّر عدّ «${p.text}» لهذا اليوم.', 'إعادة')) {
                                  a.resetTasbeeh(p.id);
                                }
                              },
                      ),
                    ),
                    if (p.custom) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PillButton(
                          tk: tk,
                          icon: _trashIcon,
                          label: 'حذف',
                          onTap: () async {
                            if (await _confirm(
                                'حذف التسبيحة', 'حذف «${p.text}» من القائمة؟', 'حذف')) {
                              a.removeCustom(p.id);
                              setState(() => _selected = 'subhan');
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // ── الاهتزاز والصوت ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: tk.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: tk.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ToggleItem(
                            tk: tk, label: 'الاهتزاز', value: a.vibrate, onChanged: a.setVibrate),
                      ),
                      Container(width: 1, height: 28, color: tk.line),
                      Expanded(
                        child: _ToggleItem(
                            tk: tk, label: 'الصوت', value: a.sound, onChanged: a.setSound),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
];
              // أفقي (هاتف مقلوب أو تابلت): لوحتان — التحكم يمين والعدّاد شمال.
              final landscape =
                  box.maxWidth > 560 && box.maxWidth > box.maxHeight * 1.25;
              if (landscape) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(children: [...top, ...bottom]),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(children: cnt)),
                  ],
                );
              }
              // عمودي: ارتفاع أدنى ويُمرَّر على الشاشات القصيرة.
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  height: math.max(box.maxHeight, 560.0),
                  child: Column(children: [...top, ...cnt, ...bottom]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final HomeTokens tk;
  final int total;
  final VoidCallback onBack;
  const _Header({required this.tk, required this.total, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tk.card,
                border: Border.all(color: tk.line),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: HomeIcon(_chevronIcon, size: 18, color: tk.ink),
            ),
          ),
          const SizedBox(width: 12),
          Text('التسبيح', style: amiriStyle(30, bold: true, color: tk.ink)),
          const Spacer(),
          CustomPaint(
            painter: DashedBorderPainter(color: tk.gold, radius: 14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text('اليوم · ${toArabicDigits(total)}',
                  style: cairoStyle(13, weight: 600, color: tk.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final HomeTokens tk;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip(
      {required this.tk, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? tk.mint : tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? tk.gold : tk.line),
        ),
        child: Text(label,
            style: cairoStyle(13, weight: 600, color: selected ? tk.mintInk : tk.ink)),
      ),
    );
  }
}

class _CounterRing extends StatelessWidget {
  final HomeTokens tk;
  final double size;
  final int count, goal;
  final double progress;
  final bool done, pressed;
  const _CounterRing({
    required this.tk,
    required this.size,
    required this.count,
    required this.goal,
    required this.progress,
    required this.done,
    required this.pressed,
  });

  @override
  Widget build(BuildContext context) {
    final inner = size - 38;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 220),
              builder: (context, v, _) => CustomPaint(
                painter: _RingPainter(
                  progress: v,
                  track: tk.line,
                  color: done ? tk.leaf : tk.gold,
                ),
              ),
            ),
          ),
          AnimatedScale(
            scale: pressed ? 0.95 : 1,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: inner,
              height: inner,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tk.mint,
                border: Border.all(color: pressed ? tk.gold : Colors.transparent, width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: IslamicPatternPainter(opacity: .22)),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(toArabicDigits(count),
                          style: cairoStyle(inner * .30,
                              weight: 700, color: tk.mintInk, height: 1.1)),
                      Text('من ${toArabicDigits(goal)}',
                          style: cairoStyle(14, color: tk.mintInk.withValues(alpha: .75))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track, color;
  const _RingPainter({required this.progress, required this.track, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const w = 10.0;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}

class _PillButton extends StatelessWidget {
  final HomeTokens tk;
  final String icon, label;
  final VoidCallback? onTap;
  const _PillButton(
      {required this.tk, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: PressableCard(
        onTap: onTap ?? () {},
        builder: (context, pressed) => Container(
          height: 44,
          decoration: BoxDecoration(
            color: tk.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pressed ? tk.gold : tk.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HomeIcon(icon, size: 18, color: tk.gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairoStyle(13, weight: 600, color: tk.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final HomeTokens tk;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem(
      {required this.tk, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        Expanded(child: Text(label, style: cairoStyle(14, weight: 600, color: tk.ink))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: tk.leaf,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
