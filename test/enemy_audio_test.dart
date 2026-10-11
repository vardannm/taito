import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/enemy_audio.dart';
import 'package:balance_arcade/enemy_sounds.dart';

void main() {
  testWidgets(
    'muted effects never start; mixer caps and releases four voices',
    (tester) async {
      var starts = 0, stops = 0;
      final audio = EnemyAudio(
        start: (_) async {
          starts++;
          return () async {
            stops++;
          };
        },
      );
      await audio.play(EnemyCue.bullet);
      expect(starts, 0);
      audio.setEnabled(true);
      await Future.wait([
        for (var i = 0; i < 10; i++) audio.play(EnemyCue.bullet),
      ]);
      expect(starts, 4);
      expect(audio.activeVoices, 4);
      await tester.pump(const Duration(milliseconds: 200));
      expect(stops, 4);
      expect(audio.activeVoices, 0);
      audio.dispose();
    },
  );

  testWidgets('pause/mute stops active effects immediately without replay', (
    tester,
  ) async {
    var starts = 0, stops = 0;
    final audio = EnemyAudio(
      start: (_) async {
        starts++;
        return () async {
          stops++;
        };
      },
    );
    audio.setEnabled(true);
    await audio.play(EnemyCue.laserFire);
    audio.setEnabled(false);
    expect(stops, 1);
    expect(audio.activeVoices, 0);
    audio.setEnabled(true);
    await tester.pump(const Duration(seconds: 2));
    expect(starts, 1);
    expect(stops, 1);
    audio.dispose();
  });

  testWidgets('pending sound cannot survive a pause and resume', (
    tester,
  ) async {
    var stops = 0;
    final loading = Completer<Future<void> Function()>();
    final audio = EnemyAudio(start: (_) => loading.future);
    audio.setEnabled(true);
    final pending = audio.play(EnemyCue.laserFire);
    expect(audio.activeVoices, 1);
    audio.setEnabled(false);
    audio.setEnabled(true);
    loading.complete(() async {
      stops++;
    });
    await pending;
    expect(audio.activeVoices, 0);
    expect(stops, 1);
    audio.dispose();
  });

  testWidgets(
    'unavailable audio releases voices and disposal blocks new effects',
    (tester) async {
      var starts = 0;
      final audio = EnemyAudio(
        start: (_) async {
          starts++;
          throw StateError('No audio device');
        },
      );
      audio.setEnabled(true);
      await audio.play(EnemyCue.bullet);
      expect(audio.activeVoices, 0);
      audio.dispose();
      audio.setEnabled(true);
      await audio.play(EnemyCue.bullet);
      expect(starts, 1);
    },
  );
}
