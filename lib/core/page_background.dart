import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../features/home/home_art.dart';
import 'home_tokens.dart';

/// يضيف خلفية الرئيسية (اللون + نقش النجمة) تحت كل صفحة تُفتح بـ Navigator،
/// فتصير كل الشاشات بنفس الخلفية. الـ Scaffold شفاف من الثيم.
class PatternedPageTransitions extends PageTransitionsBuilder {
  const PatternedPageTransitions();

  static const _inner = CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final tk = HomeTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _inner.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      ColoredBox(
        color: tk.bg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: IslamicPatternPainter(opacity: dark ? .07 : .10),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
