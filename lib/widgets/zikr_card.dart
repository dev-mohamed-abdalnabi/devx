import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/home_tokens.dart';
import '../core/text_utils.dart';
import '../models/zikr.dart';
import '../providers/activity_provider.dart';
import '../providers/azkar_provider.dart';
import '../features/home/home_art.dart';
import 'home_style.dart';

/// كارت الذكر بنفس لغة الرئيسية: خلفية card، radius 18، إطار line (ذهبي عند الضغط)،
/// نص Amiri، مصدر ذهبي Cairo، وعدّاد نعناعي يتحوّل لأخضر عند الإكمال.
class ZikrCard extends StatefulWidget {
  final Zikr zikr;
  final VoidCallback? onCompleted;
  const ZikrCard({super.key, required this.zikr, this.onCompleted});

  @override
  State<ZikrCard> createState() => _ZikrCardState();
}

class _ZikrCardState extends State<ZikrCard> {
  bool _down = false;

  Zikr get zikr => widget.zikr;
  String get _full => '${zikr.text}\n\n${zikr.source}';

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  Future<void> _copy() async {
    final tk = HomeTokens.of(context);
    await Clipboard.setData(ClipboardData(text: _full));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: tk.card,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tk.line),
        ),
        content: Text('تم النسخ',
            style: cairoStyle(13, weight: 600, color: tk.ink)),
      ));
  }

  Future<void> _share() => Share.share(_full);

  void _toggleFav() => context.read<AzkarProvider>().toggleFavorite(zikr);

  void _tap() {
    if (zikr.remaining == 0) return;
    final provider = context.read<AzkarProvider>();
    HapticFeedback.lightImpact();
    provider.tapZikr(zikr);
    context.read<ActivityProvider>().addZikr(
          categoryId: zikr.categoryId,
          categoryDone: provider.categoryProgress(zikr.categoryId) >= 1,
        );
    if (zikr.remaining == 0) {
      HapticFeedback.mediumImpact();
      widget.onCompleted?.call();
    }
  }

  void _longPressMenu() {
    HapticFeedback.selectionClick();
    final p = context.read<AzkarProvider>();
    final tk = HomeTokens.of(context);
    final fav = p.isFavorite(zikr);
    showHomeSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeSheetRow(
            tk: tk,
            icon: ZikrIcons.copy,
            label: 'نسخ',
            onTap: () {
              Navigator.pop(ctx);
              _copy();
            },
          ),
          HomeSheetRow(
            tk: tk,
            icon: ZikrIcons.share,
            label: 'مشاركة',
            onTap: () {
              Navigator.pop(ctx);
              _share();
            },
          ),
          HomeSheetRow(
            tk: tk,
            icon: HomeIcons.heart,
            iconFill: fav ? tk.gold : null,
            label: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
            onTap: () {
              Navigator.pop(ctx);
              _toggleFav();
            },
          ),
        ],
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
    final tk = HomeTokens.of(context);
    final provider = context.watch<AzkarProvider>();
    final done = zikr.remaining == 0;
    final fav = provider.isFavorite(zikr);

    return AnimatedScale(
      scale: _down ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onLongPress: _longPressMenu,
        onTap: _tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          decoration: BoxDecoration(
            color: done ? tk.mint : tk.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _down
                  ? tk.gold
                  : (done ? tk.leaf.withValues(alpha: .45) : tk.line),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                zikr.text,
                textAlign: TextAlign.right,
                style: amiriStyle(
                  21 * provider.fontScale,
                  color: done ? tk.mintInk.withValues(alpha: .8) : tk.ink,
                  height: 1.9,
                ),
              ),
              if (provider.showSources)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_shortSource,
                      style: cairoStyle(11.5, weight: 600, color: tk.gold)),
                ),
              const SizedBox(height: 8),
              Container(height: 1, color: done ? tk.leaf.withValues(alpha: .25) : tk.line),
              const SizedBox(height: 4),
              Row(
                children: [
                  _ActionIcon(
                    icon: ZikrIcons.copy,
                    color: tk.muted,
                    label: 'نسخ',
                    onTap: _copy,
                  ),
                  _ActionIcon(
                    icon: ZikrIcons.share,
                    color: tk.muted,
                    label: 'مشاركة',
                    onTap: _share,
                  ),
                  const Spacer(),
                  if (zikr.remaining < zikr.count)
                    _ActionIcon(
                      icon: ZikrIcons.undo,
                      color: tk.gold,
                      label: 'تراجع عن الضغطة الأخيرة',
                      onTap: () => provider.undoZikr(zikr),
                    ),
                  _ActionIcon(
                    icon: HomeIcons.heart,
                    color: tk.gold,
                    fill: fav ? tk.gold : null,
                    label: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                    onTap: _toggleFav,
                  ),
                  const SizedBox(width: 6),
                  _CounterBadge(tk: tk, zikr: zikr, done: done),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final String icon;
  final Color color;
  final Color? fill;
  final String label;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
              child: StyledIcon(icon, size: 20, color: color, fill: fill)),
        ),
      ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  final HomeTokens tk;
  final Zikr zikr;
  final bool done;
  const _CounterBadge(
      {required this.tk, required this.zikr, required this.done});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? tk.leaf : tk.mint,
        border: Border.all(color: done ? tk.leaf : tk.leaf.withValues(alpha: .5)),
      ),
      child: Center(
        child: done
            ? const StyledIcon(ZikrIcons.check, size: 20, color: Colors.white)
            : Text(
                toArabicDigits(zikr.remaining),
                style: cairoStyle(16, weight: 700, color: tk.mintInk),
              ),
      ),
    );
  }
}
