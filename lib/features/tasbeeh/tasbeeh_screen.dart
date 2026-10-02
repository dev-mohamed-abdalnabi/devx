import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../providers/activity_provider.dart';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  String _selected = 'subhan';

  void _tap(ActivityProvider a, TasbeehPreset p) {
    a.tapTasbeeh(p.id);
    if (a.vibrate) {
      if (a.tasbeehCount(p.id) == a.goalOf(p.id)) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    if (a.sound) SystemSound.play(SystemSoundType.click);
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
    final a = context.watch<ActivityProvider>();
    final scheme = Theme.of(context).colorScheme;
    final presets = a.presets;
    final p = presets.firstWhere((e) => e.id == _selected, orElse: () => presets.first);
    final count = a.tasbeehCount(p.id);
    final goal = a.goalOf(p.id);
    final progress = math.min(1.0, count / goal);

    return Scaffold(
      appBar: AppBar(title: const Text('التسبيح')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in presets)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(e.text),
                        selected: e.id == p.id,
                        onSelected: (_) => setState(() => _selected = e.id),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('مخصصة'),
                      onPressed: () => _addCustom(a),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(p.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Center(
                child: Semantics(
                  button: true,
                  label:
                      '${p.text}، العدد ${toArabicDigits(count)} من ${toArabicDigits(goal)}. اضغط للتسبيح',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _tap(a, p),
                    child: SizedBox(
                      width: 270,
                      height: 270,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 10,
                              backgroundColor: scheme.primaryContainer,
                            ),
                          ),
                          Container(
                            width: 225,
                            height: 225,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primaryContainer.withValues(alpha: 0.55),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(toArabicDigits(count),
                                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
                                Text('من ${toArabicDigits(goal)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _editGoal(a, p),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('تعديل الهدف'),
                  ),
                  TextButton.icon(
                    onPressed: count == 0
                        ? null
                        : () async {
                            if (await _confirm('إعادة العدّ',
                                'سيُصفَّر عدّ «${p.text}» لهذا اليوم.', 'إعادة')) {
                              a.resetTasbeeh(p.id);
                            }
                          },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('إعادة العدّ'),
                  ),
                  if (p.custom)
                    TextButton.icon(
                      onPressed: () async {
                        if (await _confirm('حذف التسبيحة', 'حذف «${p.text}» من القائمة؟', 'حذف')) {
                          a.removeCustom(p.id);
                          setState(() => _selected = 'subhan');
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف'),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('الاهتزاز'),
              value: a.vibrate,
              onChanged: a.setVibrate,
            ),
            SwitchListTile(
              dense: true,
              title: const Text('صوت النقر'),
              value: a.sound,
              onChanged: a.setSound,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('إجمالي تسبيحات اليوم: ${toArabicDigits(a.today.tasbeehTotal)}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
