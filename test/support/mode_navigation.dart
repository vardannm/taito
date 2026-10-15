import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/one_finger_controls.dart';

Future<void> openClassicLevels(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Modes'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Classic levels'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> selectWorld(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('mode-$index')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> armWorld(WidgetTester tester) async {
  if (find
      .byKey(const ValueKey('start-control-prompt'))
      .evaluate()
      .isNotEmpty) {
    return;
  }
  if (find.byKey(const ValueKey('menu-play')).evaluate().isEmpty) return;
  await tester.tap(find.byKey(const ValueKey('menu-play')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> startWorld(WidgetTester tester) async {
  await armWorld(tester);
  final board = find.byType(PivotBoard);
  final game = tester.widget<PivotBoard>(board).game;
  final point = game.boardTilt
      ? tester.getCenter(board)
      : game.tiltLift
      ? tester.getCenter(find.byKey(const ValueKey('tilt-lift-tilt')))
      : game.analog
      ? tester.getCenter(find.byKey(const ValueKey('analog-left')))
      : game.oneFinger
      ? tester.getCenter(find.byType(OneFingerControls))
      : tester.getTopLeft(board) +
            BoardViewport.forGame(
              tester.getSize(board),
              game,
              fillWidth: tester.widget<PivotBoard>(board).fillWidth,
            ).gripCenter(game, 0);
  await tester.tapAt(point);
  await tester.pump();
}
