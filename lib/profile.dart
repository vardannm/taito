import 'dart:convert';
import 'dart:async';
import 'ball_cosmetics.dart';
import 'platforms.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'levels.dart';
import 'rewards.dart';
import 'laser_maze.dart';

class PlayerProfile {
  PlayerProfile({
    this.unlimitedCoins = const bool.fromEnvironment('GILT_UNLIMITED_COINS'),
  });

  final bool unlimitedCoins;
  String get _economyKey =>
      unlimitedCoins ? 'gilt.economy.coinsTest.v1' : 'gilt.economy.v1';
  bool canAfford(int cost) => unlimitedCoins || wallet >= cost;

  late final SharedPreferencesAsync storage = SharedPreferencesAsync();
  int best = 0, runs = 0;
  int infiniteBest = 0, infiniteRuns = 0, infiniteBestScore = 0;
  int wallet = 0;
  BallCosmetic selectedBall = BallCosmetic.steel;
  double analogSensitivity = 1, twoFingerSensitivity = 1;
  PlatformStyle selectedPlatform = PlatformStyle.classic;
  final ownedPlatforms = <PlatformStyle>{PlatformStyle.classic};
  double get equipmentMultiplier =>
      1 + selectedBall.scoreBonus + selectedPlatform.scoreBonus;
  final ownedBalls = <BallCosmetic>{BallCosmetic.steel};
  final _bankedCoins = Expando<({int serial, int count})>();
  Future<void> _economyWrites = Future<void>.value();

  bool bankCoins(BalanceGame game) {
    if (!game.infinite && !game.mazeEndless) return false;
    final previous = _bankedCoins[game];
    final count = previous?.serial == game.runSerial ? previous!.count : 0;
    final delta = game.coinsCollected - count;
    if (delta <= 0) return false;
    _bankedCoins[game] = (serial: game.runSerial, count: game.coinsCollected);
    wallet += delta;
    unawaited(saveEconomy());
    return true;
  }

  bool selectBall(BallCosmetic ball) {
    if (!ownedBalls.contains(ball)) {
      if (!canAfford(ball.cost)) return false;
      if (!unlimitedCoins) wallet -= ball.cost;
      ownedBalls.add(ball);
    }
    selectedBall = ball;
    unawaited(saveEconomy());
    return true;
  }

  bool selectPlatform(PlatformStyle platform) {
    if (!ownedPlatforms.contains(platform)) {
      if (!canAfford(platform.cost)) return false;
      if (!unlimitedCoins) wallet -= platform.cost;
      ownedPlatforms.add(platform);
    }
    selectedPlatform = platform;
    unawaited(saveEconomy());
    return true;
  }

  Future<void> saveEconomy() {
    // Snapshot and serialize wallet transactions; an older save cannot undo a purchase.
    final data = jsonEncode({
      'wallet': wallet,
      'owned': ownedBalls.map((b) => b.name).toList(),
      'selected': selectedBall.name,
      'bestScore': infiniteBestScore,
      'platforms': ownedPlatforms.map((p) => p.name).toList(),
      'platform': selectedPlatform.name,
    });
    _economyWrites = _economyWrites.then((_) async {
      try {
        await storage.setString(_economyKey, data);
      } catch (_) {
        available = false;
      }
    });
    return _economyWrites;
  }

  void _loadEconomy(String? raw) {
    if (raw == null) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      if (data['wallet'] is int)
        wallet = (data['wallet'] as int).clamp(0, 1 << 30);
      if (data['bestScore'] is int)
        infiniteBestScore = (data['bestScore'] as int).clamp(0, 1 << 30);
      final platforms = data['platforms'];
      if (platforms is List)
        ownedPlatforms.addAll(
          PlatformStyle.values.where((p) => platforms.contains(p.name)),
        );
      selectedPlatform =
          ownedPlatforms.where((p) => p.name == data['platform']).firstOrNull ??
          PlatformStyle.classic;
      final owned = data['owned'];
      if (owned is List)
        ownedBalls.addAll(
          BallCosmetic.values.where((b) => owned.contains(b.name)),
        );
      selectedBall =
          ownedBalls.where((b) => b.name == data['selected']).firstOrNull ??
          BallCosmetic.steel;
    } catch (_) {
      /* Invalid economy data does not prevent launching the game. */
    }
  }

  int mergeBest = 0, mergeHighest = 2, mergeRuns = 0;
  bool sound = true, haptics = true;
  bool available = true;
  bool tutorialSeen = false;
  ControlMode controlMode = ControlMode.twoFinger;
  int classicLevel = 1;
  int mazeLevel = 1, mazeRuns = 0;
  int mazeEndlessBest = 0, mazeEndlessRuns = 0;
  final mazeBestTimes = <String, double>{};
  double? mazeBestTime(int route, [ControlMode? control]) =>
      mazeBestTimes[recordKey(route, control ?? controlMode)];
  CabinetStyle cabinet = CabinetStyle.brass;
  final levelRecords = <String, LevelRecord>{};
  final dailyRecords = <String, LevelRecord>{};
  final _recordedRuns = Expando<int>();
  String recordKey(int level, ControlMode control) => '${control.name}:$level';
  LevelRecord levelRecord(int level, [ControlMode? control]) =>
      levelRecords[recordKey(level, control ?? controlMode)] ??
      const LevelRecord();
  LevelRecord dailyRecord(String date, [ControlMode? control]) =>
      dailyRecords['${(control ?? controlMode).name}:$date'] ??
      const LevelRecord();
  int get totalStars {
    var total = 0;
    for (var level = 1; level <= ClassicLevels.count; level++) {
      total += LevelRecord.starCount(
        ControlMode.values.fold(
          0,
          (mask, mode) => mask | levelRecord(level, mode).starMask,
        ),
      );
    }
    return total;
  }

  bool isClassicLevelUnlocked(int level) =>
      ClassicLevels.isUnlocked(level, totalStars);

  bool selectClassicLevel(int level) {
    if (!isClassicLevelUnlocked(level)) return false;
    classicLevel = level;
    return true;
  }

  bool isUnlocked(CabinetStyle style) => totalStars >= style.requiredStars;
  bool selectCabinet(CabinetStyle style) {
    if (!isUnlocked(style)) return false;
    cabinet = style;
    return true;
  }

  Future<void> completeTutorial() async {
    tutorialSeen = true;
    try {
      await storage.setBool('gilt.tutorial.v1.seen', true);
    } catch (_) {
      available = false;
    }
  }

  bool recordResult(BalanceGame game) {
    bankCoins(game);
    if (game.mazeEndless) {
      if (!game.finished || _recordedRuns[game] == game.runSerial) return false;
      _recordedRuns[game] = game.runSerial;
      mazeEndlessRuns++;
      final improved = game.score > mazeEndlessBest;
      if (improved) mazeEndlessBest = game.score;
      return improved;
    }
    if (game.maze) {
      if (!game.finished || _recordedRuns[game] == game.runSerial) return false;
      _recordedRuns[game] = game.runSerial;
      mazeRuns++;
      if (!game.won) return false;
      final key = recordKey(game.level, game.controlMode);
      final previous = mazeBestTimes[key];
      final improved = previous == null || game.elapsed < previous;
      if (improved) mazeBestTimes[key] = game.elapsed;
      return improved;
    }
    if (game.merging && game.finished) {
      final improved = game.score > mergeBest;
      if (improved) mergeBest = game.score;
      if (game.mergeRun.highest > mergeHighest)
        mergeHighest = game.mergeRun.highest;
      if (_recordedRuns[game] != game.runSerial) mergeRuns++;
      _recordedRuns[game] = game.runSerial;
      return improved;
    }
    if (!game.finished ||
        game.practice ||
        _recordedRuns[game] == game.runSerial)
      return false;
    _recordedRuns[game] = game.runSerial;
    if (game.infinite) {
      infiniteRuns++;
      final improved = game.score > infiniteBestScore;
      if (improved) infiniteBestScore = game.score;
      if (game.metres > infiniteBest) infiniteBest = game.metres;
      return improved;
    }
    final records = game.daily ? dailyRecords : levelRecords;
    final key = game.daily
        ? '${game.controlMode.name}:${game.dailyKey}'
        : recordKey(game.level, game.controlMode);
    final previous = records[key] ?? const LevelRecord();
    records[key] = previous.withRun(
      mask: game.earnedStarMask,
      score: game.score,
      seconds: game.elapsed,
      won: game.won,
    );
    if (game.daily) {
      final dates =
          dailyRecords.keys.map((k) => k.split(':').last).toSet().toList()
            ..sort();
      final expired = dates
          .take((dates.length - 32).clamp(0, dates.length))
          .toSet();
      dailyRecords.removeWhere((k, _) => expired.contains(k.split(':').last));
    } else {
      runs++;
      if (game.score > best) best = game.score;
    }
    return game.score > previous.bestScore;
  }

  void _loadRecords(String? raw) {
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final pair in [('levels', levelRecords), ('daily', dailyRecords)]) {
        final source = data[pair.$1];
        if (source is! Map<String, dynamic>) continue;
        for (final entry in source.entries) {
          final validKey = pair.$1 == 'levels'
              ? RegExp(
                  r'^(oneFinger|twoFinger|analog):([1-9]|[1-4][0-9]|50)$',
                ).hasMatch(entry.key)
              : RegExp(
                  r'^(oneFinger|twoFinger|analog):\d{4}-\d{2}-\d{2}$',
                ).hasMatch(entry.key);
          if (validKey && entry.value is Map<String, dynamic>) {
            pair.$2[entry.key] = LevelRecord.fromJson(entry.value);
          }
        }
      }
      final saved = CabinetStyle.values
          .where((c) => c.name == data['cabinet'])
          .firstOrNull;
      if (saved != null && isUnlocked(saved)) cabinet = saved;
    } catch (_) {
      /* A damaged progression record must not prevent launch. */
    }
  }

  void _loadMaze(String? raw) {
    if (raw == null) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      if (data['selected'] is int)
        mazeLevel = (data['selected'] as int).clamp(1, LaserMazeRoute.count);
      if (data['runs'] is int)
        mazeRuns = (data['runs'] as int).clamp(0, 1 << 30);
      if (data['endlessBest'] is int)
        mazeEndlessBest = (data['endlessBest'] as int).clamp(0, 1 << 30);
      if (data['endlessRuns'] is int)
        mazeEndlessRuns = (data['endlessRuns'] as int).clamp(0, 1 << 30);
      final times = data['times'];
      if (times is! Map<String, dynamic>) return;
      for (final entry in times.entries) {
        final match = RegExp(
          r'^(oneFinger|twoFinger|analog):([1-9][0-9]*)$',
        ).firstMatch(entry.key);
        if (match == null ||
            (int.tryParse(match.group(2)!) ?? (LaserMazeRoute.count + 1)) >
                LaserMazeRoute.count)
          continue;
        final value = entry.value;
        if (value is num && value.isFinite && value > 0)
          mazeBestTimes[entry.key] = value.toDouble();
      }
    } catch (_) {
      // Ignore a damaged route record without affecting the other modes.
    }
  }

  Future<void> load() async {
    try {
      tutorialSeen = await storage.getBool('gilt.tutorial.v1.seen') ?? false;
      controlMode = await storage.getBool('gilt.oneFinger') == true
          ? ControlMode.oneFinger
          : ControlMode.twoFinger;
      final analog = await storage.getDouble('gilt.analogSensitivity');
      final direct = await storage.getDouble('gilt.twoFingerSensitivity');
      analogSensitivity = analog != null && analog.isFinite
          ? analog.clamp(0.0, 1.0)
          : 1;
      twoFingerSensitivity = direct != null && direct.isFinite
          ? direct.clamp(0.0, 1.0)
          : 1;
      final savedMode = await storage.getString('gilt.controlMode');
      controlMode =
          ControlMode.values.where((m) => m.name == savedMode).firstOrNull ??
          controlMode;
      classicLevel = (await storage.getInt('gilt.classicLevel') ?? 1).clamp(
        1,
        ClassicLevels.count,
      );
      best = await storage.getInt('gilt.best') ?? 0;
      runs = await storage.getInt('gilt.runs') ?? 0;
      mergeBest = await storage.getInt('gilt.merge.best') ?? 0;
      mergeHighest = await storage.getInt('gilt.merge.highest') ?? 2;
      mergeRuns = await storage.getInt('gilt.merge.runs') ?? 0;
      infiniteBest = await storage.getInt('gilt.ascent.best') ?? 0;
      infiniteRuns = await storage.getInt('gilt.ascent.runs') ?? 0;
      sound = await storage.getBool('gilt.sound') ?? true;
      haptics = await storage.getBool('gilt.haptics') ?? true;
      _loadRecords(await storage.getString('gilt.mastery.v1'));
      _loadMaze(await storage.getString('gilt.maze.v1'));
      _loadEconomy(await storage.getString(_economyKey));
    } catch (_) {
      available = false;
    }
  }

  Future<void> save() async {
    await saveEconomy();
    try {
      await storage.setString(
        'gilt.maze.v1',
        jsonEncode({
          'selected': mazeLevel,
          'runs': mazeRuns,
          'endlessBest': mazeEndlessBest,
          'endlessRuns': mazeEndlessRuns,
          'times': mazeBestTimes,
        }),
      );
      await storage.setInt('gilt.merge.best', mergeBest);
      await storage.setInt('gilt.merge.highest', mergeHighest);
      await storage.setInt('gilt.merge.runs', mergeRuns);
      await storage.setInt('gilt.best', best);
      await storage.setInt('gilt.runs', runs);
      await storage.setInt('gilt.ascent.best', infiniteBest);
      await storage.setInt('gilt.ascent.runs', infiniteRuns);
      await storage.setBool('gilt.sound', sound);
      await storage.setBool('gilt.haptics', haptics);
      await storage.setBool(
        'gilt.oneFinger',
        controlMode == ControlMode.oneFinger,
      );
      await storage.setString('gilt.controlMode', controlMode.name);
      await storage.setDouble('gilt.analogSensitivity', analogSensitivity);
      await storage.setDouble(
        'gilt.twoFingerSensitivity',
        twoFingerSensitivity,
      );
      await storage.setInt('gilt.classicLevel', classicLevel);
      await storage.setString(
        'gilt.mastery.v1',
        jsonEncode({
          'levels': levelRecords.map((k, v) => MapEntry(k, v.toJson())),
          'daily': dailyRecords.map((k, v) => MapEntry(k, v.toJson())),
          'cabinet': cabinet.name,
        }),
      );
    } catch (_) {
      available = false;
    }
  }
}

class GameFeedback {
  AudioPlayer? _player;
  Future<void> play(GameEvent event, PlayerProfile profile) async {
    if (profile.haptics) {
      if (event == GameEvent.miss) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
    if (!profile.sound) return;
    try {
      await (_player ??= AudioPlayer()).play(
        AssetSource(
          'audio/${event == GameEvent.merge
              ? 'target'
              : event == GameEvent.coin
              ? 'target'
              : event.name}.wav',
        ),
        volume: event == GameEvent.coin ? .25 : .55,
      );
    } catch (_) {
      /* Audio restrictions must never interrupt a run. */
    }
  }

  void dispose() {
    _player?.dispose();
  }
}
