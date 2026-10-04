import 'package:flutter/material.dart';

/// نجمة النقش الإسلامي (نفس نجمة آية اليوم)، إحداثياتها في بلاطة 44×44.
const List<Offset> kIslamicStarPoints = [
  Offset(22, 3), Offset(26.5, 13.5), Offset(37, 9), Offset(32.5, 19.5),
  Offset(41, 22), Offset(32.5, 24.5), Offset(37, 35), Offset(26.5, 30.5),
  Offset(22, 41), Offset(17.5, 30.5), Offset(7, 35), Offset(11.5, 24.5),
  Offset(3, 22), Offset(11.5, 19.5), Offset(7, 9), Offset(17.5, 13.5),
];

/// مسار النجمة مقيَّسًا ليملأ [size] بالكامل.
Path islamicStarPath(Size size) {
  final s = size.width / 38;
  final p = Path();
  for (var i = 0; i < kIslamicStarPoints.length; i++) {
    final o = kIslamicStarPoints[i];
    final x = (o.dx - 3) * s, y = (o.dy - 3) * (size.height / 38);
    i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p..close();
}

class IslamicStarPainter extends CustomPainter {
  final Color color;
  const IslamicStarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(islamicStarPath(size), Paint()..color = color);

  @override
  bool shouldRepaint(IslamicStarPainter old) => old.color != color;
}

/// نجمة مملوءة بلون مع [child] في المنتصف.
class IslamicStar extends StatelessWidget {
  final double size;
  final Color color;
  final Widget? child;
  const IslamicStar(
      {super.key, required this.size, required this.color, this.child});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: IslamicStarPainter(color), child: Center(child: child)),
      );
}
