import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:balance_arcade/infinite_music.dart';
import 'package:balance_arcade/music_output.dart';
import 'package:balance_arcade/profile.dart';

class _MusicOutput implements MusicOutput {
  final calls = <String>[];
  final rates = <double>[];
  Completer<void>? loading;

  @override
  Future<void> play(String asset, double volume) async {
    calls.add('play:$asset');
    await loading?.future;
  }

  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');
  @override
  Future<void> setPlaybackRate(double rate) async {
    calls.add('rate');
    rates.add(rate);
  }

  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  void dispose() => calls.add('dispose');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'build bundles the chosen Infinite track and keeps sound effects',
    () async {
      expect(InfiniteMusic.bundled, isTrue);
      expect(
        (await rootBundle.load('assets/${InfiniteMusic.asset}')).lengthInBytes,
        greaterThan(0),
      );
      for (final asset in [
        'target.wav',
        'miss.wav',
        'complete.wav',
        'enemy_laserFire.wav',
      ]) {
        expect(
          (await rootBundle.load('assets/audio/$asset')).lengthInBytes,
          greaterThan(0),
        );
      }
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final asset in ['theme_infinite.wav', 'theme_dark.wav']) {
        expect(manifest.listAssets(), isNot(contains('assets/audio/$asset')));
      }
    },
  );

  test('a quiet screen never reaches for the audio platform', () async {
    final feedback = GameFeedback();
    // Every screen outside Infinite asks for no track, repeatedly.
    // That must stay a no-op: no player is built, so nothing can fail and
    // nothing plays over a mode that wants silence.
    for (var i = 0; i < 5; i++) {
      await feedback.updateMusic(track: null, playing: i.isEven);
    }
    feedback.dispose();
  });

  test(
    'waiting for the first touch never creates or starts a music player',
    () async {
      var created = 0;
      final output = _MusicOutput();
      final feedback = GameFeedback(
        musicOutput: () {
          created++;
          return output;
        },
      );
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: false,
        playbackSession: 1,
      );
      expect(created, 0);
      expect(output.calls, isEmpty);
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
        playbackSession: 1,
      );
      expect(created, 1);
      expect(output.calls, ['play:${InfiniteMusic.asset}', 'rate']);
      feedback.dispose();
    },
  );

  test(
    'a prepared retry pauses old music and waits before replaying its opening',
    () async {
      final output = _MusicOutput();
      final feedback = GameFeedback(musicOutput: () => output);
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
        playbackSession: 1,
      );
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: false,
        playbackSession: 2,
      );
      expect(output.calls, ['play:${InfiniteMusic.asset}', 'rate', 'pause']);
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
        playbackSession: 2,
      );
      expect(output.calls, [
        'play:${InfiniteMusic.asset}',
        'rate',
        'pause',
        'play:${InfiniteMusic.asset}',
        'rate',
      ]);
      feedback.dispose();
    },
  );

  test('Infinite tempo builds with active time and pace, then caps', () {
    double rate(double seconds, double pace) =>
        InfiniteMusic.rateFor(seconds: seconds, pace: pace);
    expect(rate(0, 1), 1.00);
    expect(rate(60, 1), 1.03);
    expect(rate(180, 1), 1.08);
    expect(rate(0, 5), 1.04);
    expect(rate(180, 5), 1.12);
    expect(rate(10000, 100), 1.12);
    expect(rate(-10, -1), 1.00);
    for (var seconds = 0; seconds < 240; seconds++) {
      expect(
        rate(seconds + 1.0, 3),
        greaterThanOrEqualTo(rate(seconds.toDouble(), 3)),
      );
    }
  });

  test(
    'tempo changes update one player without restarting its track',
    () async {
      final output = _MusicOutput();
      final feedback = GameFeedback(musicOutput: () => output);
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
        playbackRate: 1.06,
      );
      for (var i = 0; i < 120; i++) {
        await feedback.updateMusic(
          track: InfiniteMusic.asset,
          playing: true,
          playbackRate: 1.06,
        );
      }
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
        playbackRate: 1.20,
      );
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
        playbackRate: 1.30,
      );
      expect(
        output.calls.where((call) => call.startsWith('play:')),
        hasLength(1),
      );
      expect(output.calls.where((call) => call == 'resume'), isEmpty);
      expect(output.rates, [1.06, 1.20, 1.30]);
      feedback.dispose();
    },
  );

  test('pause holds the loop and resume uses the current tempo', () async {
    final output = _MusicOutput();
    final feedback = GameFeedback(musicOutput: () => output);
    await feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.17,
    );
    await feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: false,
      playbackRate: 1.17,
    );
    await feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: false,
      playbackRate: 1.17,
    );
    await feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.17,
    );
    expect(output.calls, [
      'play:${InfiniteMusic.asset}',
      'rate',
      'pause',
      'resume',
    ]);
    expect(output.rates, [1.17]);
    feedback.dispose();
  });

  test('a new run restarts the recording opening and resets tempo', () async {
    final output = _MusicOutput();
    final feedback = GameFeedback(musicOutput: () => output);
    await feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.12,
      playbackSession: 1,
    );
    await feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.00,
      playbackSession: 2,
    );
    expect(
      output.calls.where((call) => call.startsWith('play:')),
      hasLength(2),
    );
    expect(output.rates, [1.12, 1.00]);
    feedback.dispose();
  });

  test('a different track can switch back to normal speed', () async {
    final output = _MusicOutput();
    final feedback = GameFeedback(musicOutput: () => output);
    await feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.30,
    );
    await feedback.updateMusic(track: 'audio/theme_dark.wav', playing: true);
    expect(output.rates, [1.30, 1]);
    expect(
      output.calls.where((call) => call.startsWith('play:')),
      hasLength(2),
    );
    feedback.dispose();
  });

  test('loading coalesces rates and a pending mute wins', () async {
    final output = _MusicOutput()..loading = Completer<void>();
    final feedback = GameFeedback(musicOutput: () => output);
    final first = feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.06,
    );
    final faster = feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.30,
    );
    final muted = feedback.updateMusic(track: null, playing: false);
    output.loading!.complete();
    await Future.wait([first, faster, muted]);
    expect(output.calls, ['play:${InfiniteMusic.asset}', 'stop']);
    expect(output.rates, isEmpty);
    feedback.dispose();
  });

  test('a pending rate change applies after the source is ready', () async {
    final output = _MusicOutput()..loading = Completer<void>();
    final feedback = GameFeedback(musicOutput: () => output);
    final first = feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.06,
    );
    final faster = feedback.updateMusic(
      track: InfiniteMusic.asset,
      playing: true,
      playbackRate: 1.22,
    );
    output.loading!.complete();
    await Future.wait([first, faster]);
    expect(output.calls, ['play:${InfiniteMusic.asset}', 'rate']);
    expect(output.rates, [1.22]);
    feedback.dispose();
    await feedback.updateMusic(track: InfiniteMusic.asset, playing: true);
    expect(output.calls.last, 'dispose');
  });
}
