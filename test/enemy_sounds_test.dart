import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/enemy_sounds.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'package:balance_arcade/porcupines.dart';
import 'package:balance_arcade/spider_web.dart';
import 'infinite_boss_test.dart' show run;

void main() {
  test(
    'every cue has a bounded, unclipped PCM asset with a matching duration',
    () {
      for (final cue in EnemyCue.values) {
        final bytes = File('assets/${cue.asset}').readAsBytesSync();
        final header = ByteData.sublistView(bytes);
        expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
        expect(header.getUint16(22, Endian.little), 1);
        expect(header.getUint32(24, Endian.little), 44100);
        expect(header.getUint16(34, Endian.little), 16);
        expect((bytes.length - 44) / (44100 * 2), closeTo(cue.seconds, .001));
        var peak = 0, nonzero = 0;
        for (var offset = 44; offset < bytes.length; offset += 2) {
          final sample = header.getInt16(offset, Endian.little).abs();
          if (sample > peak) peak = sample;
          if (sample > 0) nonzero++;
        }
        expect(peak, inInclusiveRange(1000, 24000));
        expect(nonzero, greaterThan(100));
        expect(header.getInt16(44, Endian.little).abs(), lessThan(10));
        expect(
          header.getInt16(bytes.length - 2, Endian.little).abs(),
          lessThan(100),
        );
      }
    },
  );

  test(
    'moth plays one arrival and six paired volley cues, never per bullet',
    () {
      final game = run();
      final sound = EnemySoundDirector();
      final visitor = LateEnemyEncounter(
        kind: LateEnemyKind.moth,
        origin: (x: 180, y: 130),
        target: (x: 180, y: 430),
      );
      game.lateEnemy = visitor;
      final heard = <EnemyCue>[];
      for (var i = 0; i < 4 * 120; i++) {
        visitor.step(1 / 120);
        game.elapsed += 1 / 120;
        heard.addAll(sound.capture(game));
      }
      expect(heard.where((s) => s == EnemyCue.wingArrival).length, 1);
      expect(heard.where((s) => s == EnemyCue.petal).length, 6);
    },
  );

  test('laser charge and fire happen once at their actual transitions', () {
    final game = run();
    final sound = EnemySoundDirector();
    final laser = SpecialHazard(
      HazardKind.laser,
      x: 180,
      y: 160,
      warningSeconds: 1,
    );
    game.specialHazards.add(laser);
    expect(sound.capture(game), [EnemyCue.laserCharge]);
    expect(sound.capture(game), isEmpty);
    game.setPaused(true);
    game.step(.1);
    expect(sound.capture(game), isEmpty);
    game.setPaused(false);
    laser.step(.9, 0);
    game.elapsed += .9;
    expect(sound.capture(game), isEmpty);
    laser.step(.11, 0);
    game.elapsed += .11;
    expect(sound.capture(game), [EnemyCue.laserFire]);
    expect(sound.capture(game), isEmpty);
  });

  for (final kind in BossKind.values) {
    test('$kind emits its own arrival and synchronized weapon cues', () {
      final game = run();
      final sound = EnemySoundDirector();
      final boss = InfiniteBoss(kind: kind);
      game.boss = boss;
      final counts = <EnemyCue, int>{};
      for (var frame = 0; frame < 28 * 120; frame++) {
        boss.step(1 / 120, target: (x: 180, y: 430));
        game.elapsed += 1 / 120;
        for (final cue in sound.capture(game)) {
          counts.update(cue, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      final bounces = counts.remove(EnemyCue.bounce);
      if (kind == BossKind.stormColossus) {
        // Nearly simultaneous wall impacts share a cue, while separated
        // reflections remain individually audible.
        expect(bounces, inInclusiveRange(4, 8));
      } else {
        expect(bounces, isNull);
      }
      expect(counts, switch (kind) {
        BossKind.skyWarden => {
          EnemyCue.wardenArrival: 1,
          EnemyCue.bullet: 5,
          EnemyCue.laserCharge: 3,
          EnemyCue.laserFire: 3,
          EnemyCue.bombThrow: 3,
          EnemyCue.poolLand: 3,
        },
        BossKind.stormColossus => {
          EnemyCue.colossusArrival: 1,
          EnemyCue.ricochet: 4,
          EnemyCue.petal: 4,
          EnemyCue.mineCharge: 3,
          EnemyCue.mineFire: 3,
        },
        BossKind.eclipseSeraph => {
          EnemyCue.seraphArrival: 1,
          EnemyCue.crystal: 4,
          EnemyCue.laserCharge: 3,
          EnemyCue.laserFire: 3,
          EnemyCue.cometCharge: 3,
          EnemyCue.cometFire: 3,
        },
      });
    });
  }

  test('web release and quill burst play once for whole groups', () {
    final game = run();
    final sound = EnemySoundDirector();
    final web = SpiderWebShot(x: 100, y: 160, targetX: 180, targetY: 430);
    game.webShots.add(web);
    expect(sound.capture(game), isEmpty);
    web.step(web.warningSeconds + .01);
    game.elapsed += 1;
    expect(sound.capture(game), [EnemyCue.web]);
    game.quills.addAll(BoardPorcupine(180, 160).burst());
    expect(sound.capture(game), [EnemyCue.quills]);
    expect(sound.capture(game), isEmpty);
  });

  test(
    'waiting, paused and finished screens are silent; a new run resets cues',
    () {
      final game = run();
      final sound = EnemySoundDirector();
      game.boss = InfiniteBoss();
      game.waitingForInput = true;
      expect(sound.capture(game), isEmpty);
      game.waitingForInput = false;
      game.setPaused(true);
      expect(sound.capture(game), isEmpty);
      game.setPaused(false);
      expect(sound.capture(game), [EnemyCue.wardenArrival]);
      expect(sound.capture(game), isEmpty);
      game.phase = GamePhase.over;
      expect(sound.capture(game), isEmpty);
      game.start(gameMode: GameMode.infinite);
      game.boss = InfiniteBoss();
      expect(sound.capture(game), [EnemyCue.wardenArrival]);
    },
  );
}
