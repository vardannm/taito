import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'platforms.dart';

void paintPlatformDetail(
  Canvas canvas,
  Offset a,
  Offset b,
  PlatformStyle style,
) {
  if (style == PlatformStyle.classic) return;
  final tint = Color(style.color), span = (b - a).distance;
  canvas.save();
  canvas.translate(a.dx, a.dy);
  canvas.rotate(math.atan2(b.dy - a.dy, b.dx - a.dx));
  if (style == PlatformStyle.ion || style == PlatformStyle.solar) {
    canvas.drawLine(
      const Offset(0, -1),
      Offset(span, -1),
      Paint()
        ..color = tint.withAlpha(65)
        ..strokeWidth = 11,
    );
  }
  canvas.drawLine(
    Offset.zero,
    Offset(span, 0),
    Paint()
      ..color = tint
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    const Offset(0, -1.6),
    Offset(span, -1.6),
    Paint()
      ..color = Colors.white.withAlpha(180)
      ..strokeWidth = .8,
  );
  for (var x = 12.0; x < span - 8; x += 22) {
    if (style == PlatformStyle.copper) {
      canvas.drawCircle(
        Offset(x, .3),
        1.2,
        Paint()..color = const Color(0xFF785442),
      );
    } else {
      canvas.drawLine(
        Offset(x - 2, 2),
        Offset(x + 2, -2),
        Paint()
          ..color = style == PlatformStyle.prism
              ? const Color(0xFF8FFFE0)
              : const Color(0xFF2E6862)
          ..strokeWidth = 1.2,
      );
    }
  }
  canvas.restore();
}

class PlatformPreview extends CustomPainter {
  const PlatformPreview(this.style);
  final PlatformStyle style;
  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(3, size.height * .6),
        b = Offset(size.width - 3, size.height * .4);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF244A46)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Color(style.color)
        ..strokeWidth = 5,
    );
    paintPlatformDetail(canvas, a, b, style);
  }

  @override
  bool shouldRepaint(PlatformPreview old) => old.style != style;
}
