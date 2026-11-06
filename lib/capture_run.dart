import 'dart:convert';

import 'ball_cosmetics.dart';
import 'game.dart';
import 'levels.dart';
import 'infinite_boss.dart' show BossKind;
import 'platforms.dart';
import 'rewards.dart';

/// Explicitly version this whenever physics or generation changes. Replays
/// fail closed at checkpoints instead of silently filming a different run.
const captureRules = 'rollrise-0.13.6+24-capture-1';
const captureSeed = 7112026;
const captureHz = 120;
const captureMaxTicks = captureHz * 60 * 10;

class CaptureSetup {
  const CaptureSetup({
    this.ball = BallCosmetic.steel,
    this.platform = PlatformStyle.classic,
    this.cabinet = CabinetStyle.brass,
    this.hearts = 3,
    this.shieldSeconds = 8,
    this.magnetSeconds = 9,
    this.firstBoss,
    this.level,
  });
  final BallCosmetic ball;
  final PlatformStyle platform;
  final CabinetStyle cabinet;
  final int hearts;
  final double shieldSeconds, magnetSeconds;
  final BossKind? firstBoss;

  /// Null preserves the original fixed Infinite recording format.
  final int? level;

  BalanceGame createGame() => BalanceGame(seed: captureSeed)
    ..cosmetic = ball
    ..platformStyle = platform
    ..cabinet = cabinet
    ..infiniteMaxLives = hearts
    ..shieldDuration = shieldSeconds
    ..magnetDuration = magnetSeconds
    ..firstBossOverride = firstBoss
    ..setControlMode(ControlMode.twoFinger)
    ..start(
      gameMode: level == null ? GameMode.infinite : GameMode.classic,
      levelNumber: level ?? 1,
      waitForInput: true,
    );

  Map<String, Object> toJson() => {
    'ball': ball.name,
    'platform': platform.name,
    'cabinet': cabinet.name,
    'hearts': hearts,
    'shieldSeconds': shieldSeconds,
    'magnetSeconds': magnetSeconds,
    if (firstBoss != null) 'firstBoss': firstBoss!.name,
    if (level != null) 'level': level!,
  };

  factory CaptureSetup.fromJson(Map<String, dynamic> json) => CaptureSetup(
    ball: BallCosmetic.values.byName(json['ball'] as String),
    platform: PlatformStyle.values.byName(json['platform'] as String),
    cabinet: CabinetStyle.values.byName(json['cabinet'] as String),
    hearts: _integer(json['hearts'], 3, 6),
    shieldSeconds: _number(json['shieldSeconds'], 1, 60),
    magnetSeconds: _number(json['magnetSeconds'], 1, 60),
    firstBoss: json['firstBoss'] == null
        ? null
        : BossKind.values.byName(json['firstBoss'] as String),
    level: json['level'] == null
        ? null
        : _integer(json['level'], 1, ClassicLevels.count),
  );
}

int _integer(dynamic value, int low, int high) {
  if (value is! int || value < low || value > high)
    throw const FormatException('Invalid integer.');
  return value;
}

double _number(dynamic value, double low, double high) {
  if (value is! num || !value.isFinite || value < low || value > high) {
    throw const FormatException('Invalid number.');
  }
  return value.toDouble();
}

/// Physics coordinates of the recording, independent of the playback viewport.
class CaptureGeometry {
  const CaptureGeometry(this.stretch, this.top, this.bottom);
  factory CaptureGeometry.of(BalanceGame g) =>
      CaptureGeometry(g.arenaStretch, g.visibleTop, g.visibleBottom);
  final double stretch, top, bottom;
  List<double> toJson() => [stretch, top, bottom];
  void apply(BalanceGame g) {
    g.arenaStretch = stretch;
    g.visibleTop = top;
    g.visibleBottom = bottom;
  }

  factory CaptureGeometry.fromJson(List<dynamic> json) {
    if (json.length != 3) throw const FormatException('Invalid geometry.');
    return CaptureGeometry(
      _number(json[0], .1, 20),
      _number(json[1], -3000, 0),
      _number(json[2], 560, 4000),
    );
  }
}

class CaptureCommand {
  const CaptureCommand(this.tick, this.name, this.side, this.delta);
  final int tick, side;
  final String name;
  final double delta;
  List<Object> toJson() => [tick, name, side, delta];
  void apply(BalanceGame g) {
    switch (name) {
      case 'grab':
        g.grabPivot(side);
      case 'drag':
        g.dragPivot(side, delta);
      case 'release':
        g.releasePivot(side);
      case 'clear':
        g.clearInput();
    }
  }

  factory CaptureCommand.fromJson(List<dynamic> json, int total) {
    if (json.length != 4 ||
        !['grab', 'drag', 'release', 'clear'].contains(json[1])) {
      throw const FormatException('Invalid input command.');
    }
    return CaptureCommand(
      _integer(json[0], 0, total - 1),
      json[1] as String,
      _integer(json[2], 0, 1),
      _number(json[3], -10000, 10000),
    );
  }
}

/// Stable, quantized world-state fingerprint: float noise below .00001 is
/// tolerated, but score, hearts, terrain and moving attacks must agree.
String captureFingerprint(BalanceGame g) {
  int q(double n) => (n * 100000).round();
  final state = [
    q(g.ballX),
    q(g.ballY),
    q(g.left),
    q(g.right),
    q(g.velocity),
    q(g.cameraOffset),
    q(g.maxHeight),
    g.lives,
    g.phase.name,
    g.score,
    g.coinsCollected,
    g.survival.combo,
    q(g.survival.points),
    q(g.survival.shield),
    q(g.survival.recovery),
    q(g.survival.magnet),
    for (final h in g.board) [q(h.x), q(h.y), h.target],
    for (final p in g.porcupines) [q(p.x), q(p.y), p.bursts],
    for (final s in g.spiders) [q(s.x), q(s.y)],
    for (final s in g.quills) [q(s.x), q(s.y)],
    for (final s in g.webShots) [q(s.x), q(s.y)],
    for (final h in g.specialHazards) [h.kind.name, q(h.x), q(h.y), q(h.age)],
    for (final gate in g.mazeGates) [q(gate.y), q(gate.gapCenter)],
    for (final snake in g.snakes)
      [
        for (final p in snake.points) [q(p.x), q(p.y)],
      ],
    if (g.boss != null) [g.boss!.kind.name, q(g.boss!.age)],
    if (g.lateEnemy != null) [g.lateEnemy!.kind.name, q(g.lateEnemy!.age)],
    // Additional Classic state is versioned separately; old Infinite hashes
    // remain byte-for-byte compatible with the existing recordings.
    if (g.mode == GameMode.classic)
      [
        g.level,
        g.target,
        g.completed,
        g.misses,
        g.won,
        q(g.elapsed),
        q(g.phaseTime),
        q(g.legTime),
        q(g.holeTime),
        g.lastSuccess,
        g.levelStarCollected,
        g.earnedStarMask,
      ],
  ];
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(jsonEncode(state))) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

class CaptureFile {
  CaptureFile({
    required this.setup,
    required this.geometry,
    required this.ticks,
    required this.commands,
    required this.checkpoints,
    required this.summary,
  });
  final CaptureSetup setup;
  final CaptureGeometry geometry;
  final int ticks;
  final List<CaptureCommand> commands;
  final Map<int, String> checkpoints;
  final Map<String, dynamic> summary;
  String encode() => jsonEncode({
    'format': 'rollrise-input-capture',
    'version': setup.level == null ? 1 : 2,
    'rules': captureRules,
    'seed': captureSeed,
    'hz': captureHz,
    'ticks': ticks,
    'setup': setup.toJson(),
    'geometry': geometry.toJson(),
    'inputs': commands.map((c) => c.toJson()).toList(),
    'checkpoints': {for (final e in checkpoints.entries) '${e.key}': e.value},
    'summary': summary,
  });

  static CaptureFile decode(String text) {
    try {
      if (text.length > 20 * 1024 * 1024)
        throw const FormatException('Capture file is too large.');
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['format'] != 'rollrise-input-capture' ||
          ![1, 2].contains(j['version']) ||
          j['rules'] != captureRules ||
          j['seed'] != captureSeed ||
          j['hz'] != captureHz) {
        throw const FormatException(
          'Unsupported capture rules; use the same game build as the recording.',
        );
      }
      final ticks = _integer(j['ticks'], 1, captureMaxTicks);
      final inputs = j['inputs'] as List;
      if (inputs.isEmpty || inputs.length > 500000)
        throw const FormatException('Invalid input count.');
      final commands = inputs
          .map((c) => CaptureCommand.fromJson(c as List, ticks))
          .toList();
      if (commands.first.tick != 0 || commands.first.name != 'grab')
        throw const FormatException('Missing first touch.');
      for (var i = 1; i < commands.length; i++) {
        if (commands[i].tick < commands[i - 1].tick)
          throw const FormatException('Inputs are out of order.');
      }
      final checks = <int, String>{};
      for (final e in (j['checkpoints'] as Map).entries) {
        final tick = _integer(int.parse(e.key as String), 1, ticks);
        final hash = e.value as String;
        if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(hash))
          throw const FormatException('Invalid checkpoint.');
        checks[tick] = hash;
      }
      for (var tick = captureHz; tick < ticks; tick += captureHz) {
        if (!checks.containsKey(tick))
          throw const FormatException('Missing checkpoint.');
      }
      if (!checks.containsKey(ticks))
        throw const FormatException('Missing final checkpoint.');
      final setup = CaptureSetup.fromJson(j['setup'] as Map<String, dynamic>);
      if ((j['version'] == 2) != (setup.level != null)) {
        throw const FormatException('Capture version does not match its mode.');
      }
      return CaptureFile(
        setup: setup,
        geometry: CaptureGeometry.fromJson(j['geometry'] as List),
        ticks: ticks,
        commands: commands,
        checkpoints: checks,
        summary: j['summary'] as Map<String, dynamic>,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid capture file.');
    }
  }
}

class CaptureRecorder {
  CaptureRecorder(this.setup) : game = setup.createGame() {
    game.onPivotInput = (name, side, delta) {
      if (stopped) return;
      geometry ??= CaptureGeometry.of(game);
      geometry!.apply(game);
      commands.add(CaptureCommand(ticks, name, side, delta));
    };
  }
  final CaptureSetup setup;
  final BalanceGame game;
  CaptureGeometry? geometry;
  final commands = <CaptureCommand>[];
  final checkpoints = <int, String>{};
  int ticks = 0;
  bool stopped = false;
  bool get started => geometry != null;
  void clearControls() {
    if (started && !stopped) commands.add(CaptureCommand(ticks, 'clear', 0, 0));
    game.clearInput();
  }

  void step() {
    if (!started || stopped || game.paused) return;
    geometry!.apply(game);
    game.step(1 / captureHz);
    ticks++;
    if (ticks % captureHz == 0) checkpoints[ticks] = captureFingerprint(game);
    if (game.finished || ticks >= captureMaxTicks) stopped = true;
  }

  CaptureFile snapshot() {
    if (ticks == 0) throw const FormatException('Play the run before saving.');
    return CaptureFile(
      setup: setup,
      geometry: geometry!,
      ticks: ticks,
      commands: commands.where((c) => c.tick < ticks).toList(),
      checkpoints: {...checkpoints, ticks: captureFingerprint(game)},
      summary: {
        'seconds': ticks / captureHz,
        'score': game.score,
        'metres': game.metres,
        'hearts': game.lives,
        'coins': game.coinsCollected,
        if (setup.level != null) ...{
          'level': game.level,
          'completed': game.completed,
          'won': game.won,
          'starMask': game.earnedStarMask,
        },
      },
    );
  }
}

class CapturePlayer {
  CapturePlayer(
    this.file, {
    BallCosmetic? visualBall,
    PlatformStyle? visualPlatform,
  }) : game = file.setup.createGame() {
    game.visualBallOverride = visualBall;
    game.visualPlatformOverride = visualPlatform;
  }
  final CaptureFile file;
  final BalanceGame game;
  int ticks = 0, _next = 0;
  bool get complete => ticks >= file.ticks;
  void step() {
    if (complete) return;
    file.geometry.apply(game);
    while (_next < file.commands.length && file.commands[_next].tick == ticks) {
      file.commands[_next++].apply(game);
    }
    game.step(1 / captureHz);
    ticks++;
    final expected = file.checkpoints[ticks];
    if (expected != null && captureFingerprint(game) != expected) {
      throw FormatException(
        'Replay diverged at ${(ticks / captureHz).toStringAsFixed(2)} seconds. Do not use this take.',
      );
    }
  }

  void verify() {
    while (!complete) {
      step();
    }
  }
}
