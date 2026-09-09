import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'levels.dart';
import 'rewards.dart';
import 'laser_maze.dart';

class PlayerProfile {
  late final SharedPreferencesAsync storage = SharedPreferencesAsync();
  int best = 0, runs = 0;
  int infiniteBest = 0, infiniteRuns = 0;
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
      final improved = game.score > infiniteBest;
      if (improved) infiniteBest = game.score;
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
        if (!RegExp(
          r'^(oneFinger|twoFinger|analog):([1-9]|10)$',
        ).hasMatch(entry.key))
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
    } catch (_) {
      available = false;
    }
  }

  Future<void> save() async {
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
