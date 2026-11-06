import 'dart:convert';
import 'dart:math' as math;

import 'package:balance_arcade/capture_run.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/infinite_boss.dart' show BossKind;
import 'package:flutter_test/flutter_test.dart';

CaptureFile makeTake({int limit = 3600}) {
  final r = CaptureRecorder(const CaptureSetup(hearts: 6));
  r.game.arenaStretch = 1.15;
  r.game.visibleTop = -120;
  r.game.visibleBottom = 640;
  r.game.grabPivot(0);
  r.game.grabPivot(1);
  for (var i = 0; i < limit && !r.stopped; i++) {
    if (i % 240 == 0) {
      r.game.grabPivot(0);
      r.game.grabPivot(1);
    }
    if (i % 4 == 0) {
      r.game.dragPivot(0, -.6 + math.sin(i / 90) * .45);
      r.game.dragPivot(1, -.6 - math.sin(i / 90) * .45);
    }
    if (i % 311 == 310) r.game.releasePivot(0);
    if (i % 751 == 750) {
      r.clearControls();
      r.game.paused = true;
      final before = r.ticks;
      for (var pause = 0; pause < 120; pause++) {
        r.step();
      }
      expect(r.ticks, before);
      r.game.paused = false;
      r.game.grabPivot(1);
    }
    r.step();
    r.game.event = null;
  }
  return r.snapshot();
}

void main() {
  test(
    'capture first-boss override preserves thresholds and unique boss order',
    () {
      final normal = const CaptureSetup().createGame();
      final chosen = const CaptureSetup(
        firstBoss: BossKind.venomCrown,
      ).createGame();
      expect(chosen.nextBossKind, BossKind.venomCrown);
      expect(chosen.bossScoreThresholds, normal.bossScoreThresholds);
      normal.grabPivot(0);
      chosen.grabPivot(0);
      expect(chosen.nextBossKind, BossKind.venomCrown);
      expect(chosen.bossOrder.toSet().length, BossKind.values.length);
      expect(chosen.bossScoreThresholds, normal.bossScoreThresholds);
      final setup = CaptureSetup.fromJson(
        const CaptureSetup(firstBoss: BossKind.venomCrown).toJson(),
      );
      expect(setup.firstBoss, BossKind.venomCrown);
      expect(
        CaptureSetup.fromJson(const CaptureSetup().toJson()).firstBoss,
        isNull,
      );
    },
  );
  test(
    'shop appearance changes visuals without changing recorded equipment physics',
    () {
      final file = makeTake();
      for (final ball in [
        BallCosmetic.coral,
        BallCosmetic.nova,
        BallCosmetic.aether,
      ]) {
        final player = CapturePlayer(
          file,
          visualBall: ball,
          visualPlatform: PlatformStyle.sovereign,
        )..verify();
        expect(player.game.renderCosmetic, ball);
        expect(player.game.renderPlatformStyle, PlatformStyle.sovereign);
        expect(player.game.cosmetic, file.setup.ball);
        expect(player.game.platformStyle, file.setup.platform);
        expect(captureFingerprint(player.game), file.checkpoints[file.ticks]);
      }
    },
  );
  test('waiting does not record time; snapshots cannot save an empty take', () {
    final r = CaptureRecorder(const CaptureSetup());
    for (var i = 0; i < 600; i++) {
      r.step();
    }
    expect(r.ticks, 0);
    expect(r.started, isFalse);
    expect(r.snapshot, throwsFormatException);
  });

  test('fresh recording attempts use the same scenario and inputs', () {
    expect(makeTake().encode(), makeTake().encode());
  });

  test(
    'JSON round trip includes controls, equipment, geometry and checkpoints',
    () {
      final original = makeTake();
      final file = CaptureFile.decode(original.encode());
      expect(file.encode(), original.encode());
      expect(
        file.commands.map((c) => c.name),
        containsAll(['grab', 'drag', 'release', 'clear']),
      );
      expect(file.ticks, greaterThan(751));
      final p = CapturePlayer(file)..verify();
      expect(p.game.score, file.summary['score']);
      expect(p.game.lives, file.summary['hearts']);
      expect(captureFingerprint(p.game), file.checkpoints[file.ticks]);
    },
  );

  for (final (name, stretch, top, bottom, fps) in [
    ('iPhone 18 Pro', 1.0, -280.0, 560.0, 120),
    ('iPad 13', 1.8, 0.0, 620.0, 60),
    ('Duo unfolded', 2.8, 0.0, 560.0, 30),
  ]) {
    test(
      'replay remains exact on $name despite viewport and frame-rate changes',
      () {
        final file = CaptureFile.decode(makeTake().encode());
        final p = CapturePlayer(file);
        while (!p.complete) {
          // Mirror PivotBoard assigning display geometry between rendered frames.
          p.game.arenaStretch = stretch;
          p.game.visibleTop = top;
          p.game.visibleBottom = bottom;
          for (var i = 0; i < captureHz ~/ fps && !p.complete; i++) {
            p.step();
          }
        }
        expect(captureFingerprint(p.game), file.checkpoints[file.ticks]);
      },
    );
  }

  test('finishing on pause discards pending commands and still verifies', () {
    final r = CaptureRecorder(const CaptureSetup());
    r.game.grabPivot(0);
    for (var i = 0; i < 200; i++) {
      r.step();
    }
    r.game.dragPivot(0, -20);
    r.clearControls();
    r.game.paused = true;
    final snapshot = CaptureFile.decode(r.snapshot().encode());
    expect(snapshot.commands.every((c) => c.tick < snapshot.ticks), isTrue);
    CapturePlayer(snapshot).verify();
  });

  test('a modified input stops playback at a checkpoint', () {
    final j = jsonDecode(makeTake().encode()) as Map<String, dynamic>;
    final drag = (j['inputs'] as List).firstWhere((c) => c[1] == 'drag');
    drag[3] = -100;
    final p = CapturePlayer(CaptureFile.decode(jsonEncode(j)));
    expect(p.verify, throwsFormatException);
  });

  test(
    'incompatible rules, missing checkpoints and invalid inputs are rejected',
    () {
      final source = makeTake(limit: 300).encode();
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => j['rules'] = 'other-version',
        (j) => j['seed'] = 55,
        (j) => j['hz'] = 60,
        (j) => j['ticks'] = captureMaxTicks + 1,
        (j) => (j['checkpoints'] as Map).remove('120'),
        (j) => j['inputs'][0][2] = 7,
        (j) => j['inputs'][0][1] = 'execute',
        (j) => j['geometry'][0] = -1,
        (j) => j['setup']['ball'] = 'unrecognized',
      ]) {
        final j = jsonDecode(source) as Map<String, dynamic>;
        mutate(j);
        expect(() => CaptureFile.decode(jsonEncode(j)), throwsFormatException);
      }
    },
  );

  test(
    'normal games have no recorder and existing controls work unchanged',
    () {
      final g = BalanceGame(seed: 7)..start(gameMode: GameMode.infinite);
      expect(g.onPivotInput, isNull);
      g.grabPivot(0);
      final left = g.left;
      g.dragPivot(0, -10);
      g.step(1 / captureHz);
      expect(g.left, lessThan(left));
    },
  );
}
