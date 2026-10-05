import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../models/reminder.dart';
import '../../providers/notification_service.dart';
import '../../providers/reminders_provider.dart';
import '../../widgets/page_kit.dart';

IconData _iconFor(String kind) {
  switch (kind) {
    case 'morning':
      return Icons.wb_sunny_rounded;
    case 'evening':
      return Icons.wb_twilight_rounded;
    case 'sleep':
      return Icons.nights_stay_rounded;
    case 'quran':
      return Icons.menu_book_rounded;
    case 'challenges':
      return Icons.verified_rounded;
    default:
      return Icons.alarm_rounded;
  }
}

/// حرف مختصر لكل يوم (بترقيم Dart: الاثنين = 1 … الأحد = 7).
const _dayInitial = <int, String>{
  6: 'س',
  7: 'ح',
  1: 'ن',
  2: 'ث',
  3: 'ر',
  4: 'خ',
  5: 'ج',
};

/// اقتراحات سريعة عند إضافة تذكير مخصص.
const _suggestions = <String>[
  'صلاة الضحى',
  'الاستغفار',
  'قيام الليل',
  'صيام الاثنين والخميس',
  'الصلاة على النبي ﷺ',
];

class _NextUp {
  final Reminder reminder;
  final DateTime at;
  const _NextUp(this.reminder, this.at);
}

/// أقرب موعد قادم بين التذكيرات المفعّلة.
_NextUp? _findNext(List<Reminder> items) {
  final now = DateTime.now();
  _NextUp? best;
  for (final r in items) {
    if (!r.enabled) continue;
    for (var add = 0; add < 8; add++) {
      final d = now.add(Duration(days: add));
      if (!r.days.contains(d.weekday)) continue;
      final at = DateTime(d.year, d.month, d.day, r.hour, r.minute);
      if (!at.isAfter(now)) continue;
      if (best == null || at.isBefore(best.at)) best = _NextUp(r, at);
      break;
    }
  }
  return best;
}

String _whenLabel(DateTime at) {
  final now = DateTime.now();
  final days = DateTime(at.year, at.month, at.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  final day = days == 0
      ? 'اليوم'
      : days == 1
          ? 'غدًا'
          : (weekdayNames[at.weekday] ?? '');
  return '$day · ${formatClock(at)}';
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendTest(BuildContext context) async {
    final ok = await NotificationService.requestPermission();
    if (!context.mounted) return;
    if (!ok) {
      _snack(context, 'الإشعارات غير مسموحة. فعّلها من إعدادات النظام.');
      return;
    }
    await NotificationService.showTest();
    if (!context.mounted) return;
    _snack(context, 'أرسلنا إشعارًا تجريبيًا الآن.');
  }

  Future<void> _addCustom(BuildContext context) async {
    final result = await showModalBottomSheet<_NewReminder>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CustomReminderSheet(),
    );
    if (result == null || !context.mounted) return;
    await context
        .read<RemindersProvider>()
        .addCustom(result.title, result.hour, result.minute);
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final p = context.watch<RemindersProvider>();
    final builtIn = p.items.where((r) => !r.isCustom).toList();
    final custom = p.items.where((r) => r.isCustom).toList();
    final next = _findNext(p.items);
    final activeCount = p.items.where((r) => r.enabled).length;

    return Scaffold(
      appBar: AppBar(title: const Text('التذكيرات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCustom(context),
        backgroundColor: const Color(0xFF2F6B3A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('تذكير جديد',
            style: cairoStyle(14, weight: 700, color: Colors.white)),
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                _SummaryHero(
                  next: next,
                  activeCount: activeCount,
                  onTest: () => _sendTest(context),
                ),
                const SizedBox(height: 14),
                if (!p.exactAllowed) ...[
                  _Notice(
                    icon: Icons.timer_outlined,
                    text:
                        'الجهاز لا يسمح بالتنبيهات الدقيقة، فقد تتأخر التذكيرات بضع دقائق.',
                    action: 'السماح',
                    onAction: () async {
                      await NotificationService.requestExactPermission();
                      if (context.mounted) {
                        await context.read<RemindersProvider>().refreshExact();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (p.lastError != null) ...[
                  _Notice(
                    icon: Icons.error_outline_rounded,
                    text: p.lastError!,
                    isError: true,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                const KitSectionTitle(
                  text: 'الأذكار والعبادة',
                  caption: 'اضغط على التذكير لتعديل أيامه ووقته',
                ),
                for (final r in builtIn) _ReminderCard(reminder: r),
                const SizedBox(height: 12),
                KitSectionTitle(
                  text: 'تذكيراتي',
                  caption: custom.isEmpty
                      ? null
                      : '${toArabicDigits(custom.length)} تذكير',
                ),
                if (custom.isEmpty)
                  _EmptyCustom(onAdd: () => _addCustom(context))
                else
                  for (final r in custom) _ReminderCard(reminder: r),
              ],
            ),
    );
  }
}

// ───────────────────────── الملخص ─────────────────────────

class _SummaryHero extends StatelessWidget {
  final _NextUp? next;
  final int activeCount;
  final VoidCallback onTest;
  const _SummaryHero(
      {required this.next, required this.activeCount, required this.onTest});

  @override
  Widget build(BuildContext context) {
    return KitHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kHeroGold.withValues(alpha: .16),
                  shape: BoxShape.circle,
                  border: Border.all(color: kHeroGold.withValues(alpha: .6)),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: kHeroGold, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('التذكير القادم',
                        style: cairoStyle(12.5, color: kHeroSoft)),
                    const SizedBox(height: 2),
                    Text(
                      next == null
                          ? 'لا توجد تذكيرات مفعّلة'
                          : next!.reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairoStyle(18,
                          weight: 700, color: kHeroInk, height: 1.3),
                    ),
                    if (next != null)
                      Text(_whenLabel(next!.at),
                          style: cairoStyle(13, color: kHeroGold, weight: 600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              KitHeroPill(
                icon: Icons.check_circle_outline_rounded,
                text: '${toArabicDigits(activeCount)} مفعّل',
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onTest,
                style: TextButton.styleFrom(
                  foregroundColor: kHeroInk,
                  backgroundColor: Colors.white.withValues(alpha: .10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text('إشعار تجريبي',
                    style: cairoStyle(12.5, weight: 600, color: kHeroInk)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final bool isError;
  const _Notice({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final tone = isError ? Theme.of(context).colorScheme.error : tk.gold;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child:
                Text(text, style: cairoStyle(12.5, color: tk.ink, height: 1.6)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!,
                  style: cairoStyle(13, weight: 700, color: tone)),
            ),
        ],
      ),
    );
  }
}

class _EmptyCustom extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCustom({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return KitCard(
      onTap: onAdd,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          const KitIcon(icon: Icons.add_alarm_rounded, size: 48),
          const SizedBox(height: 10),
          Text('أضف تذكيرك الخاص',
              style: cairoStyle(15, weight: 700, color: tk.ink)),
          const SizedBox(height: 4),
          Text('صلاة الضحى، الاستغفار، قيام الليل… اختر ما يناسبك.',
              textAlign: TextAlign.center,
              style: cairoStyle(12.5, color: tk.muted, height: 1.6)),
        ],
      ),
    );
  }
}

// ───────────────────────── كرت التذكير ─────────────────────────

class _ReminderCard extends StatefulWidget {
  final Reminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  bool _open = false;

  Future<void> _pickTime(RemindersProvider p, Reminder r) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
    );
    if (t != null) await p.setTime(r, t.hour, t.minute);
  }

  Future<void> _rename(RemindersProvider p, Reminder r) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: r.title),
    );
    if (name != null) await p.rename(r, name);
  }

  Future<void> _delete(RemindersProvider p, Reminder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التذكير'),
        content: Text('هل تريد حذف «${r.title}»؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) await p.remove(r);
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final p = context.read<RemindersProvider>();
    final r = widget.reminder;
    final parts =
        formatClock(DateTime(2000, 1, 1, r.hour, r.minute)).split(' ');
    final muted = !r.enabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KitCard(
        padding: EdgeInsets.zero,
        borderColor: r.enabled ? tk.gold.withValues(alpha: .45) : tk.line,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Opacity(
                      opacity: muted ? .55 : 1,
                      child: KitIcon(icon: _iconFor(r.kind), size: 46),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: cairoStyle(15,
                                  weight: 700,
                                  color: muted ? tk.muted : tk.ink)),
                          const SizedBox(height: 2),
                          Text(r.daysLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: cairoStyle(12, color: tk.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(parts.first,
                            style: cairoStyle(20,
                                weight: 700, color: muted ? tk.muted : tk.ink)),
                        const SizedBox(width: 3),
                        Text(parts.length > 1 ? parts.last : '',
                            style: cairoStyle(12, color: tk.muted)),
                      ],
                    ),
                    Switch(
                      value: r.enabled,
                      onChanged: (v) async {
                        final ok = await p.setEnabled(r, v);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(const SnackBar(
                                content: Text(
                                    'اسمح بالإشعارات من إعدادات النظام أولًا.')));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(height: 1, color: tk.line),
                          const SizedBox(height: 12),
                          Text('الأيام',
                              style: cairoStyle(12.5,
                                  weight: 600, color: tk.muted)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final d in weekdayDisplayOrder)
                                Expanded(
                                  child: _DayDot(
                                    label: _dayInitial[d]!,
                                    semantic: weekdayNames[d]!,
                                    selected: r.days.contains(d),
                                    onTap: () => p.toggleDay(r, d),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _ActionChip(
                                icon: Icons.schedule_rounded,
                                label: 'تغيير الوقت',
                                onTap: () => _pickTime(p, r),
                              ),
                              if (r.isCustom) ...[
                                _ActionChip(
                                  icon: Icons.edit_outlined,
                                  label: 'تعديل الاسم',
                                  onTap: () => _rename(p, r),
                                ),
                                _ActionChip(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'حذف',
                                  danger: true,
                                  onTap: () => _delete(p, r),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label, semantic;
  final bool selected;
  final VoidCallback onTap;
  const _DayDot({
    required this.label,
    required this.semantic,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Semantics(
      label: semantic,
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? tk.mintInk : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? tk.mintInk : tk.line),
            ),
            child: Text(label,
                style: cairoStyle(13,
                    weight: 700, color: selected ? tk.mint : tk.muted)),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final color = danger ? Theme.of(context).colorScheme.error : tk.mintInk;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(label, style: cairoStyle(13, weight: 600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── إضافة / تسمية ─────────────────────────

class _NewReminder {
  final String title;
  final int hour;
  final int minute;
  const _NewReminder(this.title, this.hour, this.minute);
}

class _CustomReminderSheet extends StatefulWidget {
  const _CustomReminderSheet();

  @override
  State<_CustomReminderSheet> createState() => _CustomReminderSheetState();
}

class _CustomReminderSheetState extends State<_CustomReminderSheet> {
  final _title = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تذكير جديد', style: cairoStyle(18, weight: 700, color: tk.ink)),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'نص التذكير',
              hintText: 'مثال: صلاة الضحى',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s, style: cairoStyle(12.5, color: tk.ink)),
                  onPressed: () => setState(() => _title.text = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final t =
                  await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: tk.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: tk.mintInk),
                  const SizedBox(width: 10),
                  Text('الوقت',
                      style: cairoStyle(14, weight: 600, color: tk.mintInk)),
                  const Spacer(),
                  Text(
                    formatClock(DateTime(2000, 1, 1, _time.hour, _time.minute)),
                    style: cairoStyle(18, weight: 700, color: tk.mintInk),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          KitPrimaryButton(
            label: 'إضافة التذكير',
            icon: Icons.add_alarm_rounded,
            onPressed: () => Navigator.of(context)
                .pop(_NewReminder(_title.text, _time.hour, _time.minute)),
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String initial;
  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اسم التذكير'),
      content: TextField(controller: _c, autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(_c.text),
            child: const Text('حفظ')),
      ],
    );
  }
}
