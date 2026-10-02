import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/zikr.dart';
import '../providers/activity_provider.dart';
import '../providers/azkar_provider.dart';

class ZikrCard extends StatelessWidget {
  final Zikr zikr;
  final VoidCallback? onCompleted;
  const ZikrCard({super.key, required this.zikr, this.onCompleted});

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
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Text(
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
                  ),
                ),
              ),
              if (provider.showSources) ...[
                const SizedBox(height: 14),
                Text(zikr.source,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey)),
              ],
              Row(
                children: [
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
