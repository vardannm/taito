import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';

/// A frozen neighboring page, kept separate from the live board's painter.
class ModeWorldPreview extends CustomPainter {
  ModeWorldPreview(this.game);
  final BalanceGame game;
  @override
  void paint(Canvas canvas, Size size) => BoardPainter(
    game,
    reducedMotion: true,
    showHud: false,
  ).paint(canvas, size);
  @override
  bool shouldRepaint(ModeWorldPreview old) => old.game != game;
}
