import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/home_tokens.dart';
import '../features/home/home_art.dart';
import '../features/quran/audio_player_ui.dart' show StarBadge;

/// أيقونات إضافية بنفس أسلوب أيقونات الرئيسية (viewBox 24×24، stroke 1.7، round).
class ZikrIcons {
  ZikrIcons._();
  static const chevronRight = '<path d="M9 5l7 7-7 7"/>';
  static const search = '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>';
  static const close = '<path d="M6 6l12 12M18 6L6 18"/>';
  static const copy =
      '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/>';
  static const share =
      '<circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="M8.2 11l7.6-4M8.2 13l7.6 4"/>';
  static const undo = '<path d="M9 14L4 9l5-5M4 9h10a6 6 0 0 1 0 12h-3"/>';
  static const check = '<path d="M5 12.5l4.5 4.5L19 7.5"/>';
  static const fontSize =
      '<path d="M3 19l5-13 5 13M5 14h6M15 19l3.5-9L22 19M16.3 16.5h4.4"/>';
  static const dots =
      '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>';
  static const eye =
      '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>';
  static const eyeOff =
      '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/><path d="M4 4l16 16"/>';
  static const mic =
      '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>';
  static const download = '<path d="M12 4v11M7 11l5 5 5-5M5 20h14"/>';
  static const refresh =
      '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 5v6h-6"/>';

  // أيقونات الأقسام (تقابل مفاتيح icon في بيانات الأذكار).
  static const drop = '<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>';
  static const mosque =
      '<path d="M5 21v-8a7 7 0 0 1 14 0v8M3 21h18M12 2.5v3M9.5 21v-3.5a2.5 2.5 0 0 1 5 0V21"/>';
  static const megaphone =
      '<path d="M4 10v4h3l7 4V6L7 10H4zM17.5 9.5a4 4 0 0 1 0 5"/>';
  static const restaurant =
      '<path d="M7 3v7a2 2 0 0 0 2 2v9M7 3v5M11 3v5a2 2 0 0 1-2 2M17 21V3c-2.5 1.5-3 5-3 8h3"/>';
  static const shirt =
      '<path d="M8 4l-5 3 2 4 3-1v10h8V10l3 1 2-4-5-3a4 4 0 0 1-8 0z"/>';
  static const plane = '<path d="M21 4L3 11l7 3 3 7zM10 14L21 4"/>';
  static const store =
      '<path d="M3 9l2-5h14l2 5M3 9a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0M5 12v8h14v-8M10 20v-4h4v4"/>';
  static const medical = '<path d="M9 4h6v5h5v6h-5v5H9v-5H4V9h5z"/>';
  static const cloud =
      '<path d="M7 18a4 4 0 0 1-.5-7.9 5.5 5.5 0 0 1 10.6-1.1A4.5 4.5 0 0 1 17 18z"/>';
  static const storm =
      '<path d="M7 15a4 4 0 0 1-.5-7.9 5.5 5.5 0 0 1 10.6-1.1A4.5 4.5 0 0 1 17 15M12 11l-2.5 4h3.5L10.5 20"/>';
  static const frown =
      '<circle cx="12" cy="12" r="9"/><path d="M8 16c1-1.5 3-2 4-2s3 .5 4 2M9 10h.01M15 10h.01"/>';
  static const coin =
      '<circle cx="12" cy="12" r="9"/><path d="M14.5 9.5c-.5-1-1.5-1.5-2.5-1.5-1.5 0-2.5.8-2.5 2s1 1.7 2.5 2 2.5.8 2.5 2-1 2-2.5 2c-1 0-2-.5-2.5-1.5M12 6.5V8M12 16v1.5"/>';
  static const thermometer =
      '<path d="M14 14.5V5a2 2 0 0 0-4 0v9.5a4 4 0 1 0 4 0zM12 9v7"/>';
  static const route =
      '<circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M8 18h8a3 3 0 0 0 0-6H8a3 3 0 0 1 0-6h8"/>';
  static const child =
      '<circle cx="12" cy="8" r="4"/><path d="M5 21c0-4 3-6 7-6s7 2 7 6"/>';

  /// يحوّل مفتاح الأيقونة في البيانات إلى أيقونة بأسلوب الرئيسية.
  static String forKey(String key) {
    switch (key) {
      case 'wb_sunny':
        return HomeIcons.sun;
      case 'nightlight_round':
      case 'bedtime':
        return HomeIcons.moon;
      case 'alarm':
        return HomeIcons.clock;
      case 'mosque':
        return mosque;
      case 'favorite':
        return HomeIcons.heart;
      case 'home':
        return HomeIcons.home;
      case 'campaign':
        return megaphone;
      case 'water_drop':
      case 'wc':
        return drop;
      case 'self_improvement':
      case 'back_hand':
        return HomeIcons.hand;
      case 'restaurant':
        return restaurant;
      case 'checkroom':
        return shirt;
      case 'flight':
        return plane;
      case 'storefront':
        return store;
      case 'healing':
        return medical;
      case 'sentiment_stressed':
        return cloud;
      case 'mood_bad':
        return frown;
      case 'payments':
        return coin;
      case 'thunderstorm':
        return storm;
      case 'sick':
        return thermometer;
      case 'route':
        return route;
      case 'child_care':
        return child;
      default:
        return HomeIcons.quran;
    }
  }
}

/// أيقونة SVG بنفس إعدادات HomeIcon، مع إمكانية التعبئة (للمفضّلة مثلًا).
class StyledIcon extends StatelessWidget {
  final String paths;
  final double size;
  final Color color;
  final Color? fill;
  const StyledIcon(this.paths,
      {super.key, required this.size, required this.color, this.fill});

  @override
  Widget build(BuildContext context) {
    final f = fill == null ? 'none' : hexOf(fill!);
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$f" '
      'stroke="${hexOf(color)}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">$paths</svg>',
      width: size,
      height: size,
    );
  }
}

/// زر دائري 36 بنفس شكل زر «ادعم التطبيق» في هيدر الرئيسية.
class HeaderButton extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  final Color? color;
  final String? label;
  const HeaderButton(
      {super.key, required this.icon, this.onTap, this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final visual = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: tk.card,
        border: Border.all(color: tk.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
          child: StyledIcon(icon, size: 18, color: color ?? tk.gold)),
    );
    if (onTap == null) return visual;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: visual,
      ),
    );
  }
}

/// هيدر الصفحات الداخلية: ارتفاع 58 مثل الرئيسية — رجوع + العنوان (يمين) · أزرار (شمال).
class PageHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  const PageHeader({super.key, required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final compact = MediaQuery.of(context).size.height < 640;
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            HeaderButton(
              icon: ZikrIcons.chevronRight,
              color: tk.ink,
              label: 'رجوع',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: amiriStyle(compact ? 24 : 28, bold: true, color: tk.ink),
            ),
          ),
          for (final a in actions) ...[
            const SizedBox(width: 8),
            a,
          ],
        ],
      ),
    );
  }
}

/// كارت النعناعي بالنقش والمسجد (نفس كارت أذكار الوقت في الرئيسية) لكن بمحتوى متغيّر.
class HomeHeroCard extends StatelessWidget {
  final HomeTokens tk;
  final String icon;
  final String eyebrow;
  final String title;
  final double? progress;
  final String? caption;
  final double height;
  final VoidCallback? onTap;
  const HomeHeroCard({
    super.key,
    required this.tk,
    required this.icon,
    required this.eyebrow,
    required this.title,
    this.progress,
    this.caption,
    this.height = 112,
    this.onTap,
  });

  Widget _card(bool pressed) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tk.mint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pressed ? tk.gold : Colors.transparent),
      ),
      child: LayoutBuilder(builder: (context, box) {
        return Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: IslamicPatternPainter(opacity: .22)),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: MosqueArt(width: box.maxWidth * .40, tokens: tk),
            ),
            Positioned.fill(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                child: LayoutBuilder(builder: (context, c) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeIcon(icon, size: 24, color: tk.gold),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: SizedBox(
                            width: c.maxWidth * .62,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(eyebrow,
                                      maxLines: 1,
                                      style: cairoStyle(11.5,
                                          color: tk.mintInk
                                              .withValues(alpha: .75))),
                                ),
                                Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: amiriStyle(22,
                                        bold: true,
                                        color: tk.mintInk,
                                        height: 1.2)),
                                if (progress != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: HomeProgressBar(
                                        value: progress!, tokens: tk),
                                  ),
                                if (caption != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(caption!,
                                        maxLines: 1,
                                        style: cairoStyle(11.5,
                                            color: tk.mintInk
                                                .withValues(alpha: .75))),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: onTap == null
          ? _card(false)
          : PressableCard(onTap: onTap!, builder: (context, p) => _card(p)),
    );
  }
}

/// حقل بحث بشكل الكروت: ارتفاع 46، radius 18، إطار line.
class HomeSearchField extends StatelessWidget {
  final HomeTokens tk;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool autofocus;
  const HomeSearchField({
    super.key,
    required this.tk,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.line),
      ),
      child: Row(
        children: [
          StyledIcon(ZikrIcons.search, size: 20, color: tk.gold),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: tk.gold,
              style: cairoStyle(14, weight: 600, color: tk.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: cairoStyle(14, color: tk.muted),
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: StyledIcon(ZikrIcons.close, size: 18, color: tk.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// شريحة تصفية: ارتفاع 34، المحدّدة نعناعي بإطار ذهبي.
class HomeChip extends StatelessWidget {
  final HomeTokens tk;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const HomeChip({
    super.key,
    required this.tk,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? tk.mint : tk.card,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? tk.gold : tk.line),
        ),
        child: Text(
          label,
          style: cairoStyle(13,
              weight: selected ? 700 : 600,
              color: selected ? tk.mintInk : tk.muted),
        ),
      ),
    );
  }
}

/// زر بنفس لغة الكروت (أساسي = نعناعي، ثانوي = أبيض بإطار).
class HomeButton extends StatelessWidget {
  final HomeTokens tk;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const HomeButton({
    super.key,
    required this.tk,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? tk.mint : tk.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: pressed ? tk.gold : (primary ? tk.leaf : tk.line)),
        ),
        child: Text(label,
            style: cairoStyle(14,
                weight: 700, color: primary ? tk.mintInk : tk.ink)),
      ),
    );
  }
}

/// صف داخل الـ bottom sheet (أيقونة ذهبية + نص).
class HomeSheetRow extends StatelessWidget {
  final HomeTokens tk;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconFill;
  const HomeSheetRow({
    super.key,
    required this.tk,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.iconFill,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            StyledIcon(icon,
                size: 22, color: iconColor ?? tk.gold, fill: iconFill),
            const SizedBox(width: 14),
            Text(label, style: cairoStyle(15, weight: 600, color: tk.ink)),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet بنفس ألوان الكروت: خلفية card، radius 22، مقبض صغير.
Future<T?> showHomeSheet<T>(BuildContext context,
    {required WidgetBuilder builder}) {
  final tk = HomeTokens.of(context);
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: tk.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    showDragHandle: false,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: tk.line),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tk.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

/// حالة فارغة بنفس الأسلوب: دائرة نعناعية + أيقونة ذهبية.
class HomeEmpty extends StatelessWidget {
  final HomeTokens tk;
  final String icon;
  final String title;
  final String? message;
  const HomeEmpty({
    super.key,
    required this.tk,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tk.mint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(child: StyledIcon(icon, size: 28, color: tk.gold)),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: cairoStyle(16, weight: 700, color: tk.ink)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: cairoStyle(12.5, color: tk.muted)),
            ],
          ],
        ),
      ),
    );
  }
}


/// كارت رقم + عنوان (سورة/جزء) بنفس شكل HomeTile: نجمة فوق، والاسم والتفاصيل تحت.
class NumberCard extends StatelessWidget {
  final HomeTokens tk;
  final int number;
  final String title;
  final String? subtitle;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const NumberCard({
    super.key,
    required this.tk,
    required this.number,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: PressableCard(
        onTap: onTap,
        builder: (context, pressed) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? tk.mint : tk.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: (pressed || selected) ? tk.gold : tk.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarBadge(
                    number: number,
                    size: 36,
                    fill: selected ? tk.card : tk.mint,
                    textColor: tk.mintInk,
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairoStyle(16,
                          weight: 700,
                          color: selected ? tk.mintInk : tk.ink,
                          height: 1.25)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cairoStyle(11.5,
                              color: selected
                                  ? tk.mintInk.withValues(alpha: .75)
                                  : tk.muted)),
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
