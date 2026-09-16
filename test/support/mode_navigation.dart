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

Future<void> openMazeRoutes(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Modes'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Maze routes'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> selectWorld(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('mode-$index')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> startWorld(WidgetTester tester) async {
  final board = find.byType(PivotBoard);
  final game = tester.widget<PivotBoard>(board).game;
  final point = game.analog
      ? tester.getCenter(find.byKey(const ValueKey('analog-left')))
      : game.oneFinger
      ? tester.getCenter(find.byType(OneFingerControls))
      : tester.getTopLeft(board) +
            BoardViewport(
              tester.getSize(board),
            ).project(Offset(20, game.screenY(game.left)));
  await tester.tapAt(point);
  await tester.pump();
}
