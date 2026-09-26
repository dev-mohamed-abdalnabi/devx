import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/zikr.dart';
import '../providers/azkar_provider.dart';

class ZikrCard extends StatelessWidget {
  final Zikr zikr;
  const ZikrCard({super.key, required this.zikr});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final scheme = Theme.of(context).colorScheme;
    final done = zikr.remaining == 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: done ? scheme.primaryContainer.withOpacity(0.35) : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (!done) {
            HapticFeedback.lightImpact();
            provider.tapZikr(zikr);
            if (zikr.remaining == 0) {
              HapticFeedback.mediumImpact();
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
                  color: done ? scheme.onSurface.withOpacity(0.6) : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(zikr.source, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      provider.isFavorite(zikr) ? Icons.favorite : Icons.favorite_border,
                      color: provider.isFavorite(zikr) ? Colors.redAccent : Colors.grey,
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
