import 'package:flutter/material.dart';

/// Bundled vector illustrations; no network images or platform emoji required.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.style, required this.size});
  final int style;
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _AvatarPainter(style));
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.style);
  final int style;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    void oval(Rect rect, Color color) =>
        canvas.drawOval(rect, Paint()..color = color);
    void circle(double x, double y, double r, Color color) =>
        canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
    void line(Offset a, Offset b) => canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF29364D)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    const ink = Color(0xFF29364D);
    const orange = Color(0xFFF79850);
    final body = [
      const Color(0xFF9ADACD),
      const Color(0xFFC89D72),
      const Color(0xFFD5DDF7),
      orange,
      const Color(0xFFACB6DF),
    ][style];
    circle(50, 50, 49, const Color(0xFFE7EEFF));
    circle(78, 21, 3, Colors.white);
    circle(19, 39, 2, Colors.white);
    oval(const Rect.fromLTWH(22, 68, 56, 32), body);
    if (style == 1 || style == 3 || style == 4) {
      final ears = Path()
        ..moveTo(23, 39)
        ..lineTo(21, 12)
        ..lineTo(43, 29)
        ..moveTo(57, 29)
        ..lineTo(79, 12)
        ..lineTo(77, 39)
        ..close();
      canvas.drawPath(ears, Paint()..color = body);
    }
    oval(const Rect.fromLTWH(20, 24, 60, 55), body);
    if (style == 0) {
      for (final x in [32.0, 44.0, 56.0, 68.0]) {
        circle(x, 28, 10, const Color(0xFFF2ABC3));
      }
      line(const Offset(43, 19), const Offset(41, 30));
      line(const Offset(56, 20), const Offset(59, 29));
    }
    if (style == 2) {
      circle(50, 49, 34, Colors.white);
      oval(const Rect.fromLTWH(23, 30, 54, 42), ink);
      oval(const Rect.fromLTWH(29, 33, 24, 9), const Color(0xFF7DCEDB));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(34, 80, 32, 14),
          const Radius.circular(4),
        ),
        Paint()..color = orange,
      );
    } else {
      if (style == 1 || style == 3) {
        oval(const Rect.fromLTWH(25, 39, 25, 30), const Color(0xFFFFEACC));
        oval(const Rect.fromLTWH(50, 39, 25, 30), const Color(0xFFFFEACC));
      }
      circle(38, 49, 4, ink);
      circle(62, 49, 4, ink);
      circle(39, 48, 1, Colors.white);
      circle(63, 48, 1, Colors.white);
      circle(50, 59, 3, ink);
      canvas.drawArc(
        const Rect.fromLTWH(43, 59, 14, 10),
        0,
        3.14,
        false,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (style == 0) {
        for (final x in [37.0, 63.0]) {
          canvas.drawCircle(
            Offset(x, 49),
            10,
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        line(const Offset(47, 49), const Offset(53, 49));
      }
      if (style == 4) {
        line(const Offset(29, 59), const Offset(14, 56));
        line(const Offset(29, 64), const Offset(14, 67));
        line(const Offset(71, 59), const Offset(86, 56));
        line(const Offset(71, 64), const Offset(86, 67));
      }
    }
    if (style == 1) {
      canvas.drawPath(
        Path()
          ..moveTo(46, 57)
          ..lineTo(54, 57)
          ..lineTo(50, 65)
          ..close(),
        Paint()..color = orange,
      );
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) => oldDelegate.style != style;
}
