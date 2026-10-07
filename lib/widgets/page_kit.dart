import 'package:flutter/material.dart';

import '../core/home_tokens.dart';
import '../features/home/home_art.dart';

/// مكوّنات مشتركة لشاشات: التذكيرات، ادعم التطبيق، عن ذِكر.
/// تحافظ على لغة بصرية واحدة (نفس الهيرو، العناوين، الكروت).

const kHeroDark = Color(0xFF0C2B31);
const kHeroGreen = Color(0xFF16473F);
const kHeroGold = Color(0xFFE2BC63);
const kHeroInk = Color(0xFFF1EEE2);
const kHeroSoft = Color(0xFFB9D3C6);

/// بطاقة هيرو داكنة بنقش إسلامي خفيف.
class KitHero extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const KitHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 22),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [kHeroDark, kHeroGreen],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: IslamicPatternPainter(opacity: .10)),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// شارة صغيرة داخل الهيرو (حبة بحدّ ذهبي).
class KitHeroPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  const KitHeroPill({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kHeroGold.withValues(alpha: .55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: kHeroGold),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: cairoStyle(12.5, weight: 700, color: kHeroGold)),
          ),
        ],
      ),
    );
  }
}

/// عنوان قسم: شريط ذهبي + نص + (اختياري) إجراء في الطرف.
class KitSectionTitle extends StatelessWidget {
  final String text;
  final String? caption;
  final Widget? trailing;
  const KitSectionTitle(
      {super.key, required this.text, this.caption, this.trailing});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: tk.gold, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: cairoStyle(15.5, weight: 700, color: tk.ink)),
                if (caption != null)
                  Text(caption!,
                      style: cairoStyle(12, color: tk.muted, height: 1.5)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// كرت أبيض بحدّ ناعم؛ قابل للّمس عند تمرير [onTap].
class KitCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  const KitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Material(
      color: color ?? tk.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor ?? tk.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// دائرة أيقونة بخلفية نعناعية.
class KitIcon extends StatelessWidget {
  final IconData? icon;
  final String? svg; // أيقونة SVG مخصّصة (من HomeIcons) بدل IconData
  final double size;
  final Color? background;
  final Color? foreground;
  const KitIcon(
      {super.key,
      this.icon,
      this.svg,
      this.size = 44,
      this.background,
      this.foreground});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final fg = foreground ?? tk.mintInk;
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: background ?? tk.mint, shape: BoxShape.circle),
      child: svg != null
          ? Center(child: HomeIcon(svg!, size: size * .5, color: fg))
          : Icon(icon, size: size * .5, color: fg),
    );
  }
}

/// صف داخل كرت: أيقونة + عنوان + وصف + (سهم أو عنصر نهاية).
class KitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool ltrSubtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const KitTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ltrSubtitle = false,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          KitIcon(icon: icon, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: cairoStyle(14.5, weight: 700, color: tk.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!,
                      textDirection: ltrSubtitle ? TextDirection.ltr : null,
                      style: cairoStyle(12.5, color: tk.muted, height: 1.5)),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_left_rounded, color: tk.gold, size: 26),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// فاصل رفيع بين صفوف كرت واحد (يبدأ بعد الأيقونة).
class KitDivider extends StatelessWidget {
  const KitDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Divider(
        height: 1, thickness: 1, indent: 70, endIndent: 14, color: tk.line);
  }
}

/// زر رئيسي بعرض كامل.
class KitPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  const KitPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2F6B3A),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFF2F6B3A).withValues(alpha: .55),
          disabledForegroundColor: Colors.white70,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon ?? Icons.check_rounded, size: 20),
        label: Text(label,
            style: cairoStyle(15, weight: 700, color: Colors.white)),
      ),
    );
  }
}
