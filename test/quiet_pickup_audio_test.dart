import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/enemy_sounds.dart';

void main() {
  test(
    'magnet pickup stream is quiet, limited, and never queued for later',
    () async {
      var time = Duration.zero;
      final heard = <(String, double)>[];
      final feedback = GameFeedback(
        soundClock: () => time,
        effectOutput: (asset, volume) async {
          heard.add((asset, volume));
        },
      );
      final profile = PlayerProfile()..haptics = false;
      for (var i = 0; i < 30; i++) {
        time = Duration(milliseconds: i * 50);
        await feedback.play(GameEvent.coin, profile);
      }
      expect(heard, hasLength(3));
      expect(heard.every((cue) => cue == ('audio/coin.wav', .025)), isTrue);
      await feedback.play(GameEvent.miss, profile);
      await feedback.play(GameEvent.target, profile);
      expect(heard[3], ('audio/miss.wav', .28));
      expect(heard[4], ('audio/target.wav', .25));
      expect(
        heard.length,
        5,
      ); // Pickup suppression never blocks important feedback.
      profile.sound = false;
      time = const Duration(seconds: 10);
      await feedback.play(GameEvent.coin, profile);
      expect(heard.length, 5);
      feedback.dispose();
    },
  );

  test('merge uses the quieter independent droplet cue', () async {
    final heard = <(String, double)>[];
    final feedback = GameFeedback(
      effectOutput: (asset, volume) async {
        heard.add((asset, volume));
      },
    );
    final profile = PlayerProfile()..haptics = false;
    await feedback.play(GameEvent.merge, profile);
    expect(heard, [('audio/merge.wav', .16)]);
    feedback.dispose();
  });

  test('maze gates share the laser sound at their original playback level', () {
    const gate = EnemyCue.mazeGateFire;
    expect(gate.asset, EnemyCue.laserFire.asset);
    expect(gate.volume, .18);
    expect(EnemyCue.laserCharge.volume, greaterThan(gate.volume));
    expect(EnemyCue.laserFire.volume, greaterThan(gate.volume));
  });
}
