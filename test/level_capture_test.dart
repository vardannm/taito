import 'dart:convert';

import 'package:balance_arcade/capture_run.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/record_completed_level.dart';

void main() {
  test(
    'a complete level is recorded through real inputs and replays to a win',
    () {
      final file = CaptureFile.decode(recordCompletedLevel().encode());
      expect(file.setup.level, 1);
      expect(file.summary['completed'], 10);
      expect(file.summary['won'], isTrue);
      expect(jsonDecode(file.encode())['version'], 2);
      final replay = CapturePlayer(file)..verify();
      expect(replay.game.finished, isTrue);
      expect(replay.game.won, isTrue);
      expect(replay.game.completed, 10);
      expect(replay.game.earnedStarMask, file.summary['starMask']);
      expect(captureFingerprint(replay.game), file.checkpoints[file.ticks]);
    },
  );

  for (final level in [1, 24, 31, ClassicLevels.count]) {
    test(
      'level $level, moving hazards and recorded geometry remain deterministic',
      () {
        final recorder = CaptureRecorder(CaptureSetup(level: level));
        final game = recorder.game;
        game.arenaStretch = 1.05;
        game.visibleTop = -160;
        game.visibleBottom = 650;
        // Waiting is not part of the take and must not advance animated holes.
        final initial = captureFingerprint(game);
        for (var i = 0; i < 720; i++) recorder.step();
        expect(captureFingerprint(game), initial);
        game.grabPivot(0);
        game.grabPivot(1);
        for (var i = 0; i < 1800 && !recorder.stopped; i++) {
          if (game.canControl && i % 240 == 0) {
            game.grabPivot(0);
            game.grabPivot(1);
            game.dragPivot(0, -12);
            game.dragPivot(1, -8);
          }
          recorder.step();
        }
        final file = CaptureFile.decode(recorder.snapshot().encode());
        final player = CapturePlayer(file);
        while (!player.complete) {
          // Simulate the destination renderer setting a different screen shape.
          player.game.arenaStretch = 2.4;
          player.game.visibleTop = 0;
          player.game.visibleBottom = 560;
          player.step();
        }
        expect(player.game.mode, GameMode.classic);
        expect(player.game.level, level);
        expect(captureFingerprint(player.game), file.checkpoints[file.ticks]);
      },
    );
  }

  test('invalid levels and mismatched capture versions are rejected', () {
    final file =
        jsonDecode(recordCompletedLevel().encode()) as Map<String, dynamic>;
    for (final bad in [0, ClassicLevels.count + 1, '1', 1.5]) {
      final setup = Map<String, dynamic>.from(file['setup'] as Map)
        ..['level'] = bad;
      expect(
        () => CaptureFile.decode(jsonEncode({...file, 'setup': setup})),
        throwsFormatException,
      );
    }
    expect(
      () => CaptureFile.decode(jsonEncode({...file, 'version': 1})),
      throwsFormatException,
    );
    final noLevel = Map<String, dynamic>.from(file['setup'] as Map)
      ..remove('level');
    expect(
      () => CaptureFile.decode(jsonEncode({...file, 'setup': noLevel})),
      throwsFormatException,
    );
    final changed = Map<String, dynamic>.from(file['setup'] as Map)
      ..['level'] = 2;
    expect(
      () => CapturePlayer(
        CaptureFile.decode(jsonEncode({...file, 'setup': changed})),
      ).verify(),
      throwsFormatException,
    );
  });
}
