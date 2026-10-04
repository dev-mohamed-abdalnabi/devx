import 'package:flutter/material.dart';

import '../features/more/support_screen.dart';

/// مفتاح الـ Navigator العام: شريط الدعم يعيش فوق الـ Navigator فيحتاجه للتنقل.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// يتحكم في إخفاء شريط الدعم مؤقتًا (مثلًا داخل شاشة الدعم نفسها).
class SupportBarVisibility {
  SupportBarVisibility._();
  static final ValueNotifier<int> _hiders = ValueNotifier<int>(0);

  static void hide() => WidgetsBinding.instance.addPostFrameCallback((_) => _hiders.value++);
  static void show() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_hiders.value > 0) _hiders.value--;
      });
}

/// حاوية قديمة متاحة للتوافق، لكن لا تُستخدم لعرض الدعم فوق الهيدر.
class SupportTopBar extends StatelessWidget {
  final Widget child;
  const SupportTopBar({super.key, required this.child});

  static const double _barHeight = 34;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: SupportBarVisibility._hiders,
      builder: (context, hidden, _) {
        final show = hidden == 0;
        return Column(
          children: [
            if (show)
              Container(
                color: Colors.transparent,
                padding: EdgeInsets.only(top: mq.padding.top),
                height: mq.padding.top + _barHeight,
                alignment: AlignmentDirectional.centerStart,
                child: const Padding(
                  padding: EdgeInsetsDirectional.only(start: 12),
                  child: SupportPill(),
                ),
              )
            else
              const SizedBox.shrink(),
            Expanded(
              child: MediaQuery(
                data: show ? mq.removePadding(removeTop: true) : mq,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class SupportPill extends StatelessWidget {
  const SupportPill({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => appNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const SupportScreen()),
        ),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              scheme.primary.withValues(alpha: 0.20),
              scheme.tertiary.withValues(alpha: 0.20),
            ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, size: 13, color: scheme.primary),
              const SizedBox(width: 5),
              Text(
                'ادعم التطبيق',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
