import 'game.dart';

abstract final class LevelMusic {
  static const early = 'audio/theme_classic_1_40.wav';
  static const later = 'audio/theme_classic_41_80.wav';
  static const assets = [early, later];
  static const loopDuration = Duration(microseconds: 18461542);
  static const overlap = Duration(seconds: 1);

  static String? trackFor(GameMode mode, int level) =>
      mode == GameMode.classic || mode == GameMode.daily
      ? (level <= 40 ? early : later)
      : null;
}
