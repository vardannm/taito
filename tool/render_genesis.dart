import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_world.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/platforms.dart';

void main() {
  testWidgets('render Genesis scenery and actual gameplay', (tester) async {
    final sdk =
        [
          Platform.environment['FLUTTER_ROOT'],
          '.tools/flutter',
          '/opt/homebrew/share/flutter',
        ].whereType<String>().firstWhere(
          (path) => Directory(
            '$path/bin/cache/artifacts/material_fonts',
          ).existsSync(),
        );
    for (final family in ['sans-serif', 'Roboto', 'MaterialIcons']) {
      final file = family == 'MaterialIcons'
          ? 'materialicons-regular.otf'
          : 'roboto-regular.ttf';
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '$sdk/bin/cache/artifacts/material_fonts/$file',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    const label = String.fromEnvironment(
      'GENESIS_LABEL',
      defaultValue: 'updated',
    );
    final dir = Directory('artifacts/genesis')..createSync(recursive: true);
    for (final (name, size, mode, power) in [
      ('world', const Size(390, 650), GameMode.classic, 0.0),
      ('classic', const Size(390, 844), GameMode.classic, 0.0),
      ('infinite', const Size(390, 844), GameMode.infinite, 0.0),
      ('combo', const Size(390, 844), GameMode.infinite, 1.0),
      ('wide', const Size(1280, 800), GameMode.classic, 0.0),
    ]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final game = BalanceGame()
        ..cosmetic = BallCosmetic.genesis
        ..platformStyle = PlatformStyle.genesis
        ..start(gameMode: mode);
      game.survival.visualCombo = power;
      if (name == 'world') {
        BallWorldPreview(
          BallCosmetic.genesis,
          ballScale: .10,
        ).paint(canvas, size);
      } else {
        BoardPainter(
          game,
          reducedMotion: name != 'combo',
          fillWidth: 1,
          fitHeight: true,
        ).paint(canvas, size);
      }
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(
          size.width.round(),
          size.height.round(),
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${dir.path}/$label-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      picture.dispose();
    }
  });
}
