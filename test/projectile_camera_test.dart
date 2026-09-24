import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/porcupines.dart';
import 'package:balance_arcade/porcupine_painter.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:balance_arcade/spider_web.dart';
import 'package:balance_arcade/spider_painter.dart';

BalanceGame scrolledRun() {
  final g = BalanceGame(seed: 12)..start(gameMode: GameMode.infinite);
  g.mazeSectionsEnabled = false;
  g.cameraOffset = 1000;
  g.left -= 1000;
  g.right -= 1000;
  g.dangerY -= 1000;
  g.board.clear();
  g.survival.items.clear();
  return g;
}

void main() {
  test('horizontal bullets keep world height while the camera scrolls', () {
    final g = scrolledRun();
    final web = SpiderWebShot(
      x: 100,
      y: -800,
      targetX: 200,
      targetY: -800,
      warningSeconds: 0,
    );
    final quill = PorcupineQuill(x: 100, y: -750, angle: 0);
    g.webShots.add(web);
    g.quills.add(quill);
    final cameraBefore = g.cameraOffset;
    for (var i = 0; i < 12; i++) {
      g.step(1 / 120);
    }
    expect(g.cameraOffset, greaterThan(cameraBefore));
    expect(web.y, -800);
    expect(quill.y, -750);
    expect(web.x, closeTo(109, 1e-6));
    expect(quill.x, closeTo(109.5, 1e-6));
    expect(
      g.screenY(web.y),
      closeTo(200 + g.cameraOffset - cameraBefore, 1e-6),
    );
    expect(g.webShots, contains(web));
    expect(g.quills, contains(quill));
    g.cameraOffset += 500;
    g.left -= 500;
    g.right -= 500;
    g.step(1 / 120);
    expect(g.webShots, isEmpty);
    expect(g.quills, isEmpty);
  });

  test('enemy launches use world positions after scrolling', () {
    final g = scrolledRun();
    final spider = BoardSpider(85, -740, 38);
    g.spiders.add(spider);
    g.step(1 / 120);
    expect(g.webShots.single.y, spider.y);
    expect(g.webShots.single.targetY, g.ballY);
    g.webShots.clear();
    g.spiders.clear();
    final p = BoardPorcupine(85, -740)..charge = 1.1;
    g.porcupines.add(p);
    g.step(1 / 120);
    expect(g.quills.first.y, p.y);
  });

  for (final web in [true, false]) {
    test('scrolled ${web ? 'web' : 'quill'} hits the ball in world space', () {
      final g = scrolledRun();
      if (web) {
        g.webShots.add(
          SpiderWebShot(
            x: g.ballX,
            y: g.ballY,
            targetX: g.ballX + 100,
            targetY: g.ballY,
            warningSeconds: 0,
          ),
        );
      } else {
        g.quills.add(PorcupineQuill(x: g.ballX, y: g.ballY, angle: 0));
      }
      g.step(1 / 120);
      expect(g.lives, 2);
      expect(g.webShots, isEmpty);
      expect(g.quills, isEmpty);
    });
  }

  testWidgets('projectile painters apply the camera exactly once', (
    tester,
  ) async {
    Future<List<int>> render(double offset, bool warning) async {
      final g = BalanceGame(seed: 12)..start(gameMode: GameMode.infinite);
      g.cameraOffset = offset;
      g.webShots.add(
        SpiderWebShot(
          x: 100,
          y: 200 - offset,
          targetX: 180,
          targetY: 300 - offset,
        )..step(warning ? .5 : 1),
      );
      g.quills.add(PorcupineQuill(x: 250, y: 250 - offset, angle: .5));
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintSpiderWebShots(canvas, g, true);
      paintPorcupines(canvas, g, true);
      final picture = recorder.endRecording();
      final image = await picture.toImage(360, 560);
      final bytes = await tester.runAsync(() => image.toByteData());
      final result = bytes!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return result;
    }

    for (final warning in [true, false]) {
      expect(await render(1000, warning), await render(0, warning));
    }
  });
}
