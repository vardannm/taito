import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';

/// Two-finger guidance in place of grab handles, since a touch anywhere on a
/// half drives that half's end. Before the first touch a faint split marks the
/// two halves; while fingers are down, a ring under each finger and a lit
/// platform end show which end it moves. Nothing is drawn otherwise.
class TwoFingerFeedbackPainter extends CustomPainter {
  TwoFingerFeedbackPainter(
    this.game,
    this.viewport,
    this.fingers, {
    this.arrows = true,
    super.repaint,
  });
  final BalanceGame game;
  final BoardViewport Function() viewport;

  /// Live finger positions by side (0 left, 1 right), in this widget's space.
  final Map<int, Offset> fingers;

  /// False while an animated ControlHint already demonstrates the drag.
  final bool arrows;

  /// Middle of a half at a comfortable thumb height near its platform end.
  static Offset halfCenter(BoardViewport view, BalanceGame game, int side) {
    final area = view.gripArea, middle = view.rect.center.dx;
    return Offset(
      side == 0 ? (area.left + middle) / 2 : (middle + area.right) / 2,
      view.gripCenter(game, side).dy,
    );
  }

  /// Seconds the halves hint takes to fade once play begins.
  static const hintFade = .6;

  static final _drag = TextPainter(
    text: const TextSpan(
      text: 'DRAG',
      style: TextStyle(
        color: cream,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// Opacity of the halves hint: full while waiting, then fading out.
  double get hintOpacity => !game.started
      ? 0
      : game.waitingForInput
      ? 1
      : (1 - game.elapsed / hintFade).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final view = viewport();
    final area = view.gripArea;
    final hint = hintOpacity;
    if (hint > 0) {
      final middle = view.rect.center.dx;
      final line = Paint()
        ..color = cream.withValues(alpha: .28 * hint)
        ..strokeWidth = 1.2;
      for (var y = area.top + 10; y < area.bottom - 10; y += 14) {
        canvas.drawLine(Offset(middle, y), Offset(middle, y + 7), line);
      }
      for (final side in arrows ? [0, 1] : const <int>[]) {
        final center = halfCenter(view, game, side);
        final arrow = Paint()
          ..color = cream.withValues(alpha: .7 * hint)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          center - const Offset(0, 16),
          center + const Offset(0, 16),
          arrow,
        );
        for (final dy in [-1.0, 1.0]) {
          final tip = center + Offset(0, 16 * dy);
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx - 6, tip.dy - 6 * dy)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(tip.dx + 6, tip.dy - 6 * dy),
            arrow,
          );
        }
        canvas.saveLayer(
          null,
          Paint()..color = Colors.white.withValues(alpha: .7 * hint),
        );
        _drag.paint(canvas, center + Offset(-_drag.width / 2, 24));
        canvas.restore();
      }
    }
    for (final MapEntry(key: side, value: finger) in fingers.entries) {
      final end = view.project(
        Offset(
          side == 0 ? 20 : 340,
          game.screenY(side == 0 ? game.left : game.right),
        ),
      );
      canvas.drawLine(
        finger,
        end,
        Paint()
          ..color = cream.withValues(alpha: .3)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        end,
        13,
        Paint()
          ..color = brass.withValues(alpha: .55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        end,
        7,
        Paint()
          ..color = cream
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        finger,
        26,
        Paint()..color = Colors.white.withValues(alpha: .16),
      );
      canvas.drawCircle(
        finger,
        26,
        Paint()
          ..color = cream.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TwoFingerFeedbackPainter oldDelegate) => true;
}
