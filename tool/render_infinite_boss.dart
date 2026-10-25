import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';

void main() {
  for (final kind in BossKind.values) {
    testWidgets('render $kind attacks on light and dark boards', (
      tester,
    ) async {
      await (FontLoader('monospace')..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
      final times = switch (kind) {
        BossKind.skyWarden => [3.6, 10.7, 11.6, 18.5, 19.5],
        BossKind.stormColossus => [4.1, 11.5, 13.1, 18.6, 19.5],
        BossKind.eclipseSeraph => [4.5, 10.8, 11.7, 18.5, 20.4],
        BossKind.prismReaver => [3.2, 4.5, 12.0, 18.5, 20.4],
        BossKind.venomCrown => [3.0, 5.8, 13.4, 19.0, 23.8],
        BossKind.novaPulsar => [3.2, 5.6, 12.6, 16.4, 21.5],
      };
      final labels = switch (kind) {
        BossKind.skyWarden => [
          'BULLETS',
          'LASER WARNING',
          'LASER',
          'THROW WARNING',
          'POOLS',
        ],
        BossKind.stormColossus => [
          'BOUNCING ORBS',
          'CURVED BLADES',
          'BLADE VOLLEYS',
          'MINES CHARGING',
          'MINE BLAST',
        ],
        BossKind.eclipseSeraph => [
          'CRYSTAL PETALS',
          'CURTAIN WARNING',
          'LASER CURTAINS',
          'COMET WARNING',
          'COMET RAIN',
        ],
        BossKind.prismReaver => [
          'SWEEP WARNING',
          'MOVING LASER',
          'TWIN LASERS',
          'ROTOR PATHS',
          'SPINNING ROTORS',
        ],
        BossKind.venomCrown => [
          'TOXIC WARNING',
          'POISON SLALOM',
          'PULSING WALLS',
          'GAUNTLET WARNING',
          'TOXIC GAUNTLET',
        ],
        BossKind.novaPulsar => [
          'RING WARNING',
          'NOVA RINGS',
          'DASHED RAILS',
          'RAIL CORRIDOR',
          'NOVA LANCE',
        ],
      };
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFE7E7DE), BlendMode.src);
      for (var row = 0; row < 2; row++) {
        for (var column = 0; column < times.length; column++) {
          final game = BalanceGame(seed: 4)..start(gameMode: GameMode.infinite);
          game.board.clear();
          game.coins.clear();
          game.survival.items.clear();
          game.score = bossScoreWindows.first.$1;
          if (row == 1) {
            game.survival.combo = 10;
            game.survival.visualCombo = 1;
          }
          final boss = InfiniteBoss(kind: kind);
          game.boss = boss;
          for (var age = 0.0; age < times[column]; age += 1 / 120) {
            boss.step(
              1 / 120,
              target: (x: 180, y: game.screenY(game.ballY)),
              scrollDistance: 100 / 120,
            );
          }
          canvas.save();
          canvas.translate(column * 380.0 + 10, row * 620.0 + 12);
          final title = TextPainter(
            text: TextSpan(
              text: labels[column],
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          title.paint(canvas, const Offset(10, 0));
          title.dispose();
          canvas.translate(0, 35);
          BoardPainter(
            game,
            reducedMotion: false,
          ).paint(canvas, const Size(360, 560));
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1900, 1240);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts').create(recursive: true);
        await File(switch (kind) {
          BossKind.skyWarden => 'artifacts/infinite-boss.png',
          BossKind.stormColossus => 'artifacts/infinite-colossus.png',
          BossKind.eclipseSeraph => 'artifacts/infinite-seraph.png',
          BossKind.prismReaver => 'artifacts/infinite-reaver.png',
          BossKind.venomCrown => 'artifacts/infinite-venom-crown.png',
          BossKind.novaPulsar => 'artifacts/infinite-nova-pulsar.png',
        }).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
      picture.dispose();
    });
  }
}
