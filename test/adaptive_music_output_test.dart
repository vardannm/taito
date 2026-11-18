import 'dart:async';

import 'package:balance_arcade/adaptive_music_output.dart';
import 'package:balance_arcade/infinite_music.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter_test/flutter_test.dart';

class _Voice implements LoopVoice {
  final calls = <String>[];
  final volumes = <double>[];
  Completer<void>? loading;
  bool fail = false, playing = false;
  Duration? at = Duration.zero;

  @override
  Future<void> prepare(String asset) async {
    calls.add('prepare:$asset');
    volumes.add(0);
    if (fail) throw StateError('Decoder unavailable');
    await loading?.future;
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    at = position;
  }

  @override
  Future<Duration?> position() async => at;
  @override
  Future<void> resume() async {
    playing = true;
    calls.add('resume');
  }

  @override
  Future<void> pause() async {
    playing = false;
    calls.add('pause');
  }

  @override
  Future<void> stop() async {
    playing = false;
    calls.add('stop');
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);
  @override
  void dispose() {
    playing = false;
    calls.add('dispose');
  }
}

AdaptiveAudioMusicOutput _output(WidgetTester tester, List<_Voice> voices) {
  var next = 0;
  final origin = tester.binding.clock.now();
  return AdaptiveAudioMusicOutput(
    voiceFactory: () => voices[next++],
    elapsed: () => tester.binding.clock.now().difference(origin),
  );
}

Future<void> _fade(WidgetTester tester) async {
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  testWidgets(
    'level loop uses its own period without doubling identical overlap audio',
    (tester) async {
      final first = _Voice(), second = _Voice();
      final loop = CrossfadingLoopVoice(
        first: first,
        second: second,
        period: const Duration(seconds: 2),
        overlap: const Duration(seconds: 1),
        equalPower: false,
      );
      await loop.prepare('audio/theme_classic_1_40.wav');
      await loop.setVolume(.23);
      await loop.resume();
      first.at = const Duration(seconds: 2);
      await tester.pump(const Duration(milliseconds: 40));
      expect(second.playing, isTrue);
      second.at = const Duration(milliseconds: 500);
      await tester.pump(const Duration(milliseconds: 40));
      expect(first.volumes.last + second.volumes.last, closeTo(.23, .001));
      second.at = const Duration(seconds: 1);
      await tester.pump(const Duration(milliseconds: 40));
      expect(first.playing, isFalse);
      expect(second.volumes.last, .23);
      loop.dispose();
    },
  );
  testWidgets(
    'loop handoff overlaps before EOF and keeps complementary volume',
    (tester) async {
      final first = _Voice(), second = _Voice();
      final loop = CrossfadingLoopVoice(first: first, second: second);
      await loop.prepare(InfiniteMusic.asset);
      await loop.seek(Duration.zero);
      await loop.setVolume(.32);
      await loop.resume();
      expect(first.playing, isTrue);
      expect(second.playing, isFalse);
      first.at = const Duration(milliseconds: 30040);
      await tester.pump(const Duration(milliseconds: 40));
      expect(first.playing && second.playing, isTrue);
      expect(second.calls, contains('seek:40'));
      expect(first.calls.where((call) => call == 'seek:0'), hasLength(1));
      second.at = const Duration(milliseconds: 1250);
      await tester.pump(const Duration(milliseconds: 40));
      expect(first.volumes.last, closeTo(.226, .001));
      expect(second.volumes.last, closeTo(.226, .001));
      expect(
        first.volumes.last * first.volumes.last +
            second.volumes.last * second.volumes.last,
        closeTo(.32 * .32, .001),
      );
      second.at = InfiniteMusic.loopOverlap;
      await tester.pump(const Duration(milliseconds: 40));
      expect(first.playing, isFalse);
      expect(second.playing, isTrue);
      expect(second.volumes.last, closeTo(.32, .001));
      // Repeat with the other bank: every wrap must overlap, not just the first.
      second.at = const Duration(milliseconds: 30040);
      await tester.pump(const Duration(milliseconds: 40));
      expect(first.playing && second.playing, isTrue);
      expect(first.calls.last, 'resume');
      expect(first.calls, contains('seek:40'));
      loop.dispose();
    },
  );

  testWidgets(
    'pause during a loop handoff holds both copies and resumes the fade',
    (tester) async {
      final first = _Voice(), second = _Voice();
      final loop = CrossfadingLoopVoice(first: first, second: second);
      await loop.prepare(InfiniteMusic.asset);
      await loop.setVolume(.32);
      await loop.resume();
      first.at = const Duration(seconds: 30);
      await tester.pump(const Duration(milliseconds: 40));
      second.at = const Duration(seconds: 1);
      await tester.pump(const Duration(milliseconds: 40));
      await loop.pause();
      final counts = (first.volumes.length, second.volumes.length);
      await tester.pump(const Duration(seconds: 10));
      expect((first.volumes.length, second.volumes.length), counts);
      expect(first.playing || second.playing, isFalse);
      await loop.resume();
      expect(first.playing && second.playing, isTrue);
      second.at = InfiniteMusic.loopOverlap;
      await tester.pump(const Duration(milliseconds: 40));
      expect(first.playing, isFalse);
      expect(second.volumes.last, .32);
      await loop.stop();
      expect(second.playing, isFalse);
      loop.dispose();
    },
  );

  testWidgets('all arrangements prepare silently before any starts', (
    tester,
  ) async {
    final voices = List.generate(3, (_) => _Voice());
    voices.last.loading = Completer<void>();
    final output = _output(tester, voices);
    final start = output.play(InfiniteMusic.asset, .32);
    await tester.pump();
    expect(voices.every((voice) => !voice.playing), isTrue);
    expect(voices.every((voice) => voice.volumes.single == 0), isTrue);
    voices.last.loading!.complete();
    await start;
    expect(voices.every((voice) => voice.playing), isTrue);
    expect(voices.every((voice) => voice.calls.contains('seek:0')), isTrue);
    output.dispose();
  });

  testWidgets('build, boss, and return crossfade without restarting any loop', (
    tester,
  ) async {
    final voices = List.generate(3, (_) => _Voice());
    final output = _output(tester, voices);
    await output.play(InfiniteMusic.asset, .32);
    await _fade(tester);
    expect(voices[0].volumes.last, closeTo(.32, .002));
    expect(voices[1].volumes.last, 0);
    await output.setMix(MusicMix.forClimb(.75));
    await _fade(tester);
    expect(voices[0].volumes.last, closeTo(.08, .002));
    expect(voices[1].volumes.last, closeTo(.24, .002));
    await output.setMix(const MusicMix(0, 0, 1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(voices[2].volumes.last, inExclusiveRange(0, .32));
    await _fade(tester);
    expect(voices[2].volumes.last, closeTo(.32, .002));
    await output.setMix(MusicMix.forClimb(.75));
    await _fade(tester);
    expect(voices[2].volumes.last, closeTo(0, .002));
    expect(voices[1].volumes.last, closeTo(.24, .002));
    for (final voice in voices) {
      expect(
        voice.calls.where((call) => call.startsWith('prepare:')),
        hasLength(1),
      );
      expect(voice.calls.where((call) => call == 'resume'), hasLength(1));
      expect(
        voice.volumes.every((volume) => volume >= 0 && volume <= .32),
        isTrue,
      );
    }
    output.dispose();
  });

  testWidgets('pause freezes fades and resume re-aligns arrangements', (
    tester,
  ) async {
    final voices = List.generate(3, (_) => _Voice());
    final output = _output(tester, voices);
    await output.play(InfiniteMusic.asset, .32);
    await _fade(tester);
    await output.pause();
    final counts = voices.map((voice) => voice.volumes.length).toList();
    await output.setMix(const MusicMix(0, 0, 1));
    await tester.pump(const Duration(seconds: 5));
    expect(voices.map((voice) => voice.volumes.length), counts);
    expect(voices.every((voice) => !voice.playing), isTrue);
    voices.first.at = const Duration(seconds: 7);
    await output.resume();
    expect(
      voices.skip(1).every((voice) => voice.calls.contains('seek:7000')),
      isTrue,
    );
    await _fade(tester);
    expect(voices[2].volumes.last, closeTo(.32, .002));
    output.dispose();
  });

  testWidgets('a silent boss arrangement re-aligns before becoming audible', (
    tester,
  ) async {
    final voices = List.generate(3, (_) => _Voice());
    final output = _output(tester, voices);
    await output.play(InfiniteMusic.asset, .32);
    await _fade(tester);
    voices[0].at = const Duration(seconds: 12);
    voices[2].at = const Duration(seconds: 3);
    await output.setMix(const MusicMix(0, 0, 1));
    expect(voices[2].calls.last, 'seek:12000');
    expect(voices[2].volumes.last, 0);
    await _fade(tester);
    expect(voices[2].volumes.last, closeTo(.32, .002));
    output.dispose();
  });

  testWidgets(
    'mute during asset loading stops every voice before it fades in',
    (tester) async {
      final voices = List.generate(3, (_) => _Voice());
      voices.last.loading = Completer<void>();
      final output = _output(tester, voices);
      final feedback = GameFeedback(musicOutput: () => output);
      final start = feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
      );
      await tester.pump();
      final mute = feedback.updateMusic(track: null, playing: false);
      voices.last.loading!.complete();
      await Future.wait([start, mute]);
      await tester.pump(const Duration(seconds: 2));
      expect(voices.every((voice) => !voice.playing), isTrue);
      expect(
        voices.every((voice) => voice.volumes.every((volume) => volume == 0)),
        isTrue,
      );
      feedback.dispose();
    },
  );

  testWidgets(
    'a new run resets all positions and starts with the requested mix',
    (tester) async {
      final voices = List.generate(3, (_) => _Voice());
      final output = _output(tester, voices);
      final feedback = GameFeedback(musicOutput: () => output);
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
        playbackSession: 1,
        mix: const MusicMix(0, 0, 1),
      );
      await _fade(tester);
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: false,
        playbackSession: 2,
      );
      expect(voices.every((voice) => !voice.playing), isTrue);
      await feedback.updateMusic(
        track: InfiniteMusic.asset,
        playing: true,
        playbackSession: 2,
      );
      await _fade(tester);
      expect(voices[0].volumes.last, closeTo(.32, .002));
      expect(voices[2].volumes.last, 0);
      expect(
        voices.every(
          (voice) => voice.calls.where((call) => call == 'seek:0').length == 2,
        ),
        isTrue,
      );
      feedback.dispose();
    },
  );

  testWidgets('decoder failure cleans up every partially prepared voice', (
    tester,
  ) async {
    final voices = List.generate(3, (_) => _Voice());
    voices[1].fail = true;
    final output = _output(tester, voices);
    await expectLater(output.play(InfiniteMusic.asset, .32), throwsStateError);
    expect(
      voices.every((voice) => !voice.playing && voice.calls.contains('stop')),
      isTrue,
    );
    output.dispose();
  });
}
