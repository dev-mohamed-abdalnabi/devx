import 'dart:math' as math;

import 'package:flutter/material.dart';

/// مكوّنات واجهة مشتركة تحافظ على إيقاع بصري واحد عبر التطبيق.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool pattern;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.pattern = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget content = Padding(padding: padding, child: child);
    if (pattern) content = PatternBackground(child: content);
    return Card(
      color: color ?? scheme.surface,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const AppIconBadge({super.key, required this.icon, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: tint, size: size * 0.5),
    );
  }
}

class AppProgressBar extends StatelessWidget {
  final double value;
  final Color? color;

  const AppProgressBar({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1).toDouble(),
        minHeight: 7,
        color: color ?? scheme.primary,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconBadge(icon: icon, size: 64),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}


/// نقش إسلامي بسيط: نجمة ثمانية (مربعان متراكبان) تتكرر بشبكة خفيفة.
class IslamicPatternPainter extends CustomPainter {
  final Color color;
  final double cell;
  final double strokeWidth;

  const IslamicPatternPainter({required this.color, this.cell = 44, this.strokeWidth = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final r = cell * 0.36;
    for (double y = cell / 2; y < size.height + cell; y += cell) {
      for (double x = cell / 2; x < size.width + cell; x += cell) {
        _star(canvas, Offset(x, y), r, paint);
      }
    }
  }

  static void _star(Canvas canvas, Offset c, double r, Paint paint) {
    for (final rot in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = rot + math.pi / 4 + i * math.pi / 2;
        final pt = Offset(c.dx + r * math.cos(a) * 1.414, c.dy + r * math.sin(a) * 1.414);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(IslamicPatternPainter old) =>
      old.color != color || old.cell != cell || old.strokeWidth != strokeWidth;
}

/// يرسم النقش خلف [child] بشفافية منخفضة (لا يتفاعل مع اللمس).
class PatternBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double cell;
  final Color? color;

  const PatternBackground({super.key, required this.child, this.opacity = 0.07, this.cell = 44, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: opacity);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: IslamicPatternPainter(color: tint, cell: cell)),
          ),
        ),
        child,
      ],
    );
  }
}

/// فاصل زخرفي صغير تحت العناوين: خط - نجمة - خط.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.55);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: c.withValues(alpha: 0.25))),
        const SizedBox(width: 8),
        SizedBox(width: 18, height: 18, child: CustomPaint(painter: IslamicPatternPainter(color: c, cell: 18, strokeWidth: 1))),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: c.withValues(alpha: 0.25))),
      ],
    );
  }
}

/// مربع شبكة بنفس روح شاشة القرآن صوتيًا: حدود رفيعة + نقش خفيف في الخلفية.
class AppGridTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? footer;
  final VoidCallback? onTap;

  const AppGridTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: PatternBackground(
          opacity: 0.06,
          cell: 36,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(height: 10),
                Text(title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.25)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11)),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
