import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/level_music.dart';

void main() {
  test('Classic track changes at 41; later levels retain music', () {
    expect(LevelMusic.trackFor(GameMode.classic, 1), LevelMusic.early);
    expect(LevelMusic.trackFor(GameMode.classic, 40), LevelMusic.early);
    expect(LevelMusic.trackFor(GameMode.classic, 41), LevelMusic.later);
    expect(LevelMusic.trackFor(GameMode.classic, 80), LevelMusic.later);
    expect(LevelMusic.trackFor(GameMode.classic, 120), LevelMusic.later);
    expect(LevelMusic.trackFor(GameMode.daily, 15), LevelMusic.early);
    expect(LevelMusic.trackFor(GameMode.merge2048, 1), isNull);
    expect(LevelMusic.trackFor(GameMode.infinite, 1), isNull);
  });
  test(
    'both approved tracks are bundled with full overlap and no gain boost',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final asset in LevelMusic.assets) {
        expect(pubspec, contains('assets/$asset'));
        final raw = File('assets/$asset').readAsBytesSync();
        final bytes = ByteData.sublistView(raw);
        expect(bytes.getUint32(24, Endian.little), 44100);
        final frames = bytes.getUint32(40, Endian.little) ~/ 4;
        final body = (LevelMusic.loopDuration.inMicroseconds * 44100 / 1e6)
            .round();
        expect(frames, body + (1.25 * 44100).round());
        // Tail is an identical continuation, paired with complementary fades.
        expect(
          raw.sublist(44 + body * 4),
          raw.sublist(44, 44 + (frames - body) * 4),
        );
      }
    },
  );
}
