import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'package:balance_arcade/late_enemy_painter.dart';
import 'combo_render_budget_test.dart' show DrawingBudget;

BalanceGame scene(LateEnemyKind kind, double age) {
  final game = BalanceGame()..start(gameMode: GameMode.infinite);
  game.lateEnemy = LateEnemyEncounter(
    kind: kind,
    origin: (x: 180, y: 160),
    target: (x: 210, y: 420),
  )..step(age);
  return game;
}

Future<Uint8List> bodyPixels(
  LateEnemyKind kind,
  double age,
  bool reducedMotion,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.clipRect(const Rect.fromLTWH(0, 0, 96, 96));
  canvas.translate(48 - 180, 48 - 160);
  paintLateEnemy(canvas, scene(kind, age), reducedMotion);
  final picture = recorder.endRecording();
  final image = await picture.toImage(96, 96);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in LateEnemyKind.values) {
    test('${kind.name} has bounded drawing work and no blur or layers', () {
      for (final reducedMotion in [false, true]) {
        for (final age in [.1, .7, 1.25, 1.5, 2.4, 3.5, 4.5]) {
          final game = scene(kind, age);
          final e = game.lateEnemy!;
          final positions = e.shots.map((s) => s.position).toList();
          final budget = DrawingBudget();
          paintLateEnemy(budget, game, reducedMotion);
          expect(budget.draws, lessThanOrEqualTo(65));
          expect(budget.blurs, 0);
          expect(budget.layers, 0);
          expect(e.age, age);
          expect(e.shots.map((s) => s.position), positions);
        }
      }
    });

    testWidgets('${kind.name} moves with a stable reduced-motion pose', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Crop just the perch after wind-up: no warning arc or projectile
        // crosses it. This checks the actual rendered character, not its math.
        final a = await bodyPixels(kind, 2.4, false);
        final b = await bodyPixels(kind, 2.65, false);
        expect(a, isNot(orderedEquals(b)));
        final stillA = await bodyPixels(kind, 2.4, true);
        final stillB = await bodyPixels(kind, 2.65, true);
        expect(stillA, orderedEquals(stillB));
      });
    });
  }
}
