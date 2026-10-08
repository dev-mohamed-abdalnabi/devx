import 'package:flutter/material.dart';
import '../../core/home_tokens.dart';
import '../../core/star_shape.dart';
import '../../core/text_utils.dart';

/// علامة نهاية الآية: نجمة التطبيق (نفس نجمة الزخرفة) بحدّ ذهبي وتعبئة نعناعية
/// وحلقة داخلية رفيعة، والرقم بالأرقام العربية في المنتصف.
class AyahMarker extends StatelessWidget {
  final int number;
  final double size;
  final HomeTokens tk;
  const AyahMarker(
      {super.key, required this.number, required this.size, required this.tk});

  @override
  Widget build(BuildContext context) {
    final s = toArabicDigits(number);
    // الرقم يصغر مع عدد الخانات ليبقى داخل الحلقة.
    final fs = size * (s.length >= 3 ? .27 : (s.length == 2 ? .34 : .42));
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkerPainter(tk.mint, tk.gold),
        child: Center(
          child: Text(
            s,
            textScaler: TextScaler.noScaling,
            textDirection: TextDirection.rtl,
            style: cairoStyle(fs, weight: 700, color: tk.mintInk, height: 1.0),
          ),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final Color fill, stroke;
  const _MarkerPainter(this.fill, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final path = islamicStarPath(size);
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: .9));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .045
          ..strokeJoin = StrokeJoin.round
          ..color = stroke);
    canvas.drawCircle(
        size.center(Offset.zero),
        size.width * .27,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .025
          ..color = stroke.withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(_MarkerPainter o) => o.fill != fill || o.stroke != stroke;
}
