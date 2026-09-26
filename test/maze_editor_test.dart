import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/laser_maze.dart';
import 'package:balance_arcade/maze_editor.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'laser_maze_test.dart' show walkCenterline;

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test('draft JSON preserves roads, widths, finish and unfinished work', () {
    final definition = CustomMazeDefinition.starter;
    final copy = CustomMazeDefinition.fromJson(
      jsonDecode(jsonEncode(definition.toJson())) as Map<String, dynamic>,
    );
    expect(copy.toJson(), definition.toJson());
    expect(copy.analyze().valid, true);
    final empty = definition.copyWith(roads: []);
    expect(CustomMazeDefinition.fromJson(empty.toJson()).roads, isEmpty);
    expect(
      () => CustomMazeDefinition.fromJson({'version': 10}),
      throwsFormatException,
    );
  });
  test(
    'validation rejects broken connections, unsafe widths and invalid finishes',
    () {
      final definition = CustomMazeDefinition.starter;
      for (final broken in [
        definition.copyWith(roads: []),
        definition.copyWith(finish: const MazePoint(180, 300)),
        definition.copyWith(
          roads: [
            ...definition.roads,
            const MazeRoad(MazePoint(40, 100), MazePoint(80, 100), 20),
          ],
        ),
        definition.copyWith(
          roads: [const MazeRoad(MazePoint(180, 480), MazePoint(200, 100), 20)],
        ),
        definition.copyWith(
          roads: [const MazeRoad(MazePoint(180, 480), MazePoint(180, 100), 9)],
        ),
        definition.copyWith(
          roads: [const MazeRoad(MazePoint(180, 480), MazePoint(185, 480), 20)],
        ),
      ]) {
        expect(broken.analyze().valid, false);
        expect(() => broken.toDart(), throwsStateError);
      }
    },
  );
  test(
    'custom branches and both short and tall routes clear the ball and win',
    () {
      final tall = CustomMazeDefinition.starter.copyWith(
        roads: [
          ...CustomMazeDefinition.starter.roads,
          const MazeRoad(MazePoint(180, 400), MazePoint(80, 400), 11),
          const MazeRoad(MazePoint(80, 400), MazePoint(80, 300), 11),
          const MazeRoad(MazePoint(80, 300), MazePoint(180, 300), 11),
        ],
      );
      const short = CustomMazeDefinition(
        name: 'Short route',
        height: 560,
        finish: MazePoint(180, 80),
        roads: [MazeRoad(MazePoint(180, 480), MazePoint(180, 80), 11)],
      );
      for (final definition in [tall, short]) {
        final run = LaserMazeRun.custom(definition);
        expect(walkCenterline(run).contacted, false);
        expect(run.won, true);
        expect(run.contactY, definition.finish.y);
        expect(run.route!.name, definition.name);
        final game = BalanceGame()..startCustomMaze(definition);
        expect(game.controlMode, ControlMode.twoFinger);
        game.step(1 / 120);
        expect(game.finished, false);
        expect(game.cameraOffset, greaterThanOrEqualTo(0));
        expect(game.scrolling, definition.height > 560);
      }
    },
  );
  test('history restores edits and truncates redo after a new edit', () {
    final history = MazeEditorHistory(CustomMazeDefinition.starter);
    history.change(history.value.copyWith(name: 'One'));
    history.change(history.value.copyWith(name: 'Two'));
    history.undo();
    expect(history.value.name, 'One');
    history.redo();
    expect(history.value.name, 'Two');
    history.undo();
    history.change(history.value.copyWith(name: 'Three'));
    expect(history.canRedo, false);
    for (var i = 0; i < 80; i++)
      history.change(history.value.copyWith(name: 'Name $i'));
    var count = 0;
    while (history.canUndo) {
      history.undo();
      count++;
    }
    expect(count, 60);
  });
  test(
    'export escapes Dart strings and produces a real registration smoke fixture',
    () {
      final definition = CustomMazeDefinition.starter.copyWith(
        name: r"Roof ' \ ${danger}" + '\n',
      );
      final code = definition.toDart();
      expect(code, contains(r'\${danger}'));
      expect(code, contains(r"\'"));
      const path = 'artifacts/editor-import-smoke';
      Directory(path).createSync(recursive: true);
      for (final file in [
        'laser_maze.dart',
        'maze_routes.dart',
        'maze_editor_model.dart',
      ]) {
        File('lib/$file').copySync('$path/$file');
      }
      File('$path/custom_maze_levels.dart').writeAsStringSync(
        "part of 'laser_maze.dart';\nconst customMazeLevels = <CustomMazeDefinition>[\n$code];\n",
      );
      File('$path/check.dart').writeAsStringSync("""
import 'laser_maze.dart';
void main() {
  if (LaserMazeRoute.count != 21 || LaserMazeRoute.names.length != 21) throw StateError('Registration failed');
  final run = LaserMazeRun(21);
  var previous = const MazePoint(180, 519);
  for (final point in run.corridor.centers.skip(1)) {
    run.step(previous.x, previous.y, point.x, point.y, 7);
    if (run.hitLaser) throw StateError('Exported route hits a wall');
    if (run.won) break;
    previous = point;
  }
  if (!run.won) throw StateError('Exported route cannot finish');
  print('Export compiles, registers as route 21, and completes.');
}
""");
    },
  );

  testWidgets(
    'command opens editor, draw/undo/export/save/playtest work on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..haptics = false
        ..controlMode = ControlMode.analog;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.byKey(const ValueKey('open-command')));
      await tester.tap(find.byKey(const ValueKey('open-command')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.byKey(const ValueKey('command-input')),
        '/wrong',
      );
      await tester.tap(find.text('Run'));
      await tester.pump();
      expect(find.text('Unknown command.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('command-input')),
        '/editor',
      );
      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(MazeEditorPage), findsOneWidget);
      final canvas = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('editor-canvas')),
      );
      Offset point(double x, double y) =>
          canvas.localToGlobal(Offset(x, y + 560));
      final drag = await tester.startGesture(point(180, 480));
      await drag.moveTo(point(100, 480));
      await drag.up();
      await tester.pump();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      await tester.tap(find.byTooltip('Redo'));
      await tester.pump();
      await tester.tap(find.byTooltip('Editor menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Save draft'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final saved = await SharedPreferencesAsync().getString(
        MazeEditorPage.draftKey,
      );
      expect(saved, isNotNull);
      expect((jsonDecode(saved!)['roads'] as List).length, 4);
      await tester.tap(find.text('Export Dart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('editor-code')), findsOneWidget);
      expect(
        tester
            .widget<SelectableText>(find.byKey(const ValueKey('editor-code')))
            .data,
        contains('CustomMazeDefinition('),
      );
      Navigator.of(
        tester.element(find.byKey(const ValueKey('editor-code'))),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Playtest'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MazeEditorPlaytest), findsOneWidget);
      expect(
        tester
            .widget<PivotBoard>(find.byType(PivotBoard).last)
            .game
            .controlMode,
        ControlMode.analog,
      );
      expect(find.byKey(const ValueKey('analog-left')), findsOneWidget);
      expect(profile.mazeRuns, 0);
      expect(profile.controlMode, ControlMode.analog);
      await tester.tap(find.text('Back to editor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MazeEditorPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
