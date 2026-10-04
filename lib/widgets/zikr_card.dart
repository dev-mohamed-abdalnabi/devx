import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/zikr.dart';
import '../providers/activity_provider.dart';
import '../providers/azkar_provider.dart';

class ZikrCard extends StatelessWidget {
  final Zikr zikr;
  final VoidCallback? onCompleted;
  const ZikrCard({super.key, required this.zikr, this.onCompleted});

  String get _full => '${zikr.text}\n\n${zikr.source}';

  Future<void> _run(BuildContext context, String action) async {
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: _full));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('تم النسخ'), duration: Duration(seconds: 1)));
      }
    } else if (action == 'share') {
      await Share.share(_full);
    } else if (action == 'fav') {
      context.read<AzkarProvider>().toggleFavorite(zikr);
    }
  }

  void _longPressMenu(BuildContext context) {
    HapticFeedback.selectionClick();
    final p = context.read<AzkarProvider>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('نسخ'),
              onTap: () {
                Navigator.pop(ctx);
                _run(context, 'copy');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('مشاركة'),
              onTap: () {
                Navigator.pop(ctx);
                _run(context, 'share');
              },
            ),
            ListTile(
              leading: Icon(p.isFavorite(zikr)
                  ? Icons.favorite
                  : Icons.favorite_border),
              title: Text(p.isFavorite(zikr)
                  ? 'إزالة من المفضلة'
                  : 'إضافة للمفضلة'),
              onTap: () {
                Navigator.pop(ctx);
                _run(context, 'fav');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// "حصن المسلم · أذكار الصباح والمساء · رقم 76" ← "حصن المسلم · رقم 76"
  String get _shortSource {
    final parts = zikr.source.split('·').map((e) => e.trim()).toList();
    if (parts.length >= 3 && parts.last.startsWith('رقم')) {
      return '${parts.first} · ${parts.last}';
    }
    return zikr.source;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final scheme = Theme.of(context).colorScheme;
    final done = zikr.remaining == 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color:
            done ? scheme.primaryContainer.withOpacity(0.35) : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onLongPress: () => _longPressMenu(context),
        onTap: () {
          if (!done) {
            HapticFeedback.lightImpact();
            provider.tapZikr(zikr);
            context.read<ActivityProvider>().addZikr(
                  categoryId: zikr.categoryId,
                  categoryDone: provider.categoryProgress(zikr.categoryId) >= 1,
                );
            if (zikr.remaining == 0) {
              HapticFeedback.mediumImpact();
              onCompleted?.call();
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zikr.text,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 19 * provider.fontScale,
                  height: 1.9,
                  fontWeight: FontWeight.w500,
                  color: done
                      ? scheme.onSurface.withOpacity(0.6)
                      : scheme.onSurface,
                ),
              ),
              if (provider.showSources) ...[
                const SizedBox(height: 14),
                Text(_shortSource,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey)),
              ],
              Row(
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'المزيد',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: Colors.grey),
                    onSelected: (v) => _run(context, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'copy',
                          child: ListTile(
                              dense: true,
                              leading: Icon(Icons.copy_rounded),
                              title: Text('نسخ'))),
                      PopupMenuItem(
                          value: 'share',
                          child: ListTile(
                              dense: true,
                              leading: Icon(Icons.share_outlined),
                              title: Text('مشاركة'))),
                    ],
                  ),
                  const Spacer(),
                  if (zikr.remaining < zikr.count)
                    IconButton(
                      tooltip: 'تراجع عن الضغطة الأخيرة',
                      icon: const Icon(Icons.undo_rounded),
                      color: scheme.primary,
                      onPressed: () => provider.undoZikr(zikr),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      provider.isFavorite(zikr)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: provider.isFavorite(zikr)
                          ? Colors.redAccent
                          : Colors.grey,
                    ),
                    onPressed: () => provider.toggleFavorite(zikr),
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: done ? Colors.green : scheme.primary,
                    child: done
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            '${zikr.remaining}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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
}
