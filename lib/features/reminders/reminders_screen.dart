import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../models/reminder.dart';
import '../../providers/notification_service.dart';
import '../../providers/reminders_provider.dart';
import '../../widgets/app_ui.dart';

IconData _iconFor(String kind) {
  switch (kind) {
    case 'morning':
      return CupertinoIcons.sun_max_fill;
    case 'evening':
      return CupertinoIcons.sunset_fill;
    case 'sleep':
      return CupertinoIcons.moon_stars_fill;
    case 'quran':
      return CupertinoIcons.book_fill;
    case 'challenges':
      return CupertinoIcons.checkmark_seal_fill;
    default:
      return CupertinoIcons.alarm;
  }
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addCustom(BuildContext context) async {
    final result = await showDialog<_NewReminder>(
      context: context,
      builder: (_) => const _CustomReminderDialog(),
    );
    if (result == null || !context.mounted) return;
    await context.read<RemindersProvider>().addCustom(result.title, result.hour, result.minute);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RemindersProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('التذكيرات'),
        actions: [
          IconButton(
            tooltip: 'إشعار تجريبي',
            icon: const Icon(CupertinoIcons.bell_fill),
            onPressed: () async {
              final ok = await NotificationService.requestPermission();
              if (!context.mounted) return;
              if (!ok) {
                _snack(context, 'الإشعارات غير مسموحة. فعّلها من إعدادات النظام.');
                return;
              }
              await NotificationService.showTest();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCustom(context),
        icon: const Icon(Icons.add),
        label: const Text('تذكير مخصص'),
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                AppCard(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      const AppIconBadge(icon: CupertinoIcons.bell_fill),
                      const SizedBox(width: 14),
                      Expanded(child: Text(
                        'فعّل المفتاح، اختر الأيام والوقت، وسيعمل التذكير تلقائيًا حتى لو أغلقت التطبيق.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, height: 1.45),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(child: Text('المجدول الآن: ${p.scheduledCount}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      TextButton.icon(
                        onPressed: () async {
                          final ok = await NotificationService.requestPermission();
                          if (!context.mounted) return;
                          if (!ok) {
                            _snack(context, 'اسمح بالإشعارات من إعدادات النظام أولًا.');
                            return;
                          }
                          await NotificationService.showTest();
                          _snack(context, 'أرسلنا إشعار اختبار الآن.');
                        },
                        icon: const Icon(CupertinoIcons.paperplane_fill),
                        label: const Text('اختبار الآن'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!p.exactAllowed)
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'الجهاز لا يسمح بالتنبيهات الدقيقة، فقد تتأخر التذكيرات بضع دقائق. '
                              'يمكنك السماح بها من إعدادات النظام.'),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () async {
                              await NotificationService.requestExactPermission();
                              if (context.mounted) {
                                await context.read<RemindersProvider>().refreshExact();
                              }
                            },
                            child: const Text('فتح الإعدادات'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (p.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(p.lastError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                for (final r in p.items) _ReminderCard(reminder: r),
              ],
            ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final p = context.read<RemindersProvider>();
    final r = reminder;
    final time = formatClock(DateTime(2000, 1, 1, r.hour, r.minute));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: AppIconBadge(icon: _iconFor(r.kind)),
            title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$time · ${r.daysLabel}'),
            trailing: CupertinoSwitch(
              value: r.enabled,
              onChanged: (v) async {
                final ok = await p.setEnabled(r, v);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسمح بالإشعارات من إعدادات النظام أولًا.')));
                }
              },
            ),
          ),
          if (r.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final d in weekdayDisplayOrder)
                        FilterChip(
                          label: Text(weekdayNames[d]!),
                          selected: r.days.contains(d),
                          onSelected: (_) => p.toggleDay(r, d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: const Text('تغيير الوقت'),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
                          );
                          if (t != null) await p.setTime(r, t.hour, t.minute);
                        },
                      ),
                      if (r.isCustom) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('الاسم'),
                          onPressed: () async {
                            final name = await showDialog<String>(
                              context: context,
                              builder: (_) => _RenameDialog(initial: r.title),
                            );
                            if (name != null) await p.rename(r, name);
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('حذف'),
                          onPressed: () => p.remove(r),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          if (!r.enabled && r.isCustom)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('حذف'),
                onPressed: () => p.remove(r),
              ),
            ),
        ],
      ),
    );
  }
}

class _NewReminder {
  final String title;
  final int hour;
  final int minute;
  const _NewReminder(this.title, this.hour, this.minute);
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog();

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  final _title = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تذكير مخصص'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'نص التذكير'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text(formatClock(DateTime(2000, 1, 1, _time.hour, _time.minute))),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_NewReminder(_title.text, _time.hour, _time.minute)),
          child: const Text('إضافة'),
        ),
      ],
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
  late final TextEditingController _c = TextEditingController(text: widget.initial);

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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_c.text), child: const Text('حفظ')),
      ],
    );
  }
}
