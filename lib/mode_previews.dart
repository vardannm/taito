import 'game.dart';

/// Baked by tool/bake_mode_previews.dart, never by an inactive runtime engine.
String modePreviewAsset(GameMode mode, int level) => switch (mode) {
  GameMode.classic => 'assets/mode_previews/classic-$level.png',
  GameMode.laserMaze => 'assets/mode_previews/laserMaze-$level.png',
  _ => 'assets/mode_previews/${mode.name}.png',
};
