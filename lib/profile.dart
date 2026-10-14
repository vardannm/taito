import 'dart:convert';
import 'dart:async';
import 'ball_cosmetics.dart';
import 'platforms.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'enemy_sounds.dart';
import 'enemy_audio.dart';
import 'music_output.dart';
import 'levels.dart';
import 'rewards.dart';
import 'onboarding.dart';
import 'daily_prizes.dart';
import 'achievements.dart';
import 'survival_upgrades.dart';
import 'infinite_progress.dart';

class PlayerProfile {
  PlayerProfile({
    this.unlimitedCoins = false,
    this.temporaryLevelAccess = const bool.fromEnvironment(
      'GILT_UNLOCK_ALL_LEVELS',
      defaultValue: true,
    ),
  });

  final bool unlimitedCoins;
  // Temporary playtest access. Disable with GILT_UNLOCK_ALL_LEVELS=false.
  // Never persisted as stars or completion records.
  final bool temporaryLevelAccess;
  String get _economyKey =>
      unlimitedCoins ? 'gilt.economy.coinsTest.v1' : 'gilt.economy.v1';
  bool canAfford(int cost) => unlimitedCoins || wallet >= cost;

  /// Hint only for a purchasable improvement beyond the gear already owned.
  bool get shopUpgradeAvailable {
    final strongerBall = BallCosmetic.values.any(
      (ball) =>
          !ball.purchaseOnly &&
          !ownedBalls.contains(ball) &&
          canAfford(ball.cost) &&
          (ownedBalls.every((owned) => owned.scoreBonus < ball.scoreBonus) ||
              ownedBalls.every(
                (owned) => owned.magnetRadius < ball.magnetRadius,
              )),
    );
    final strongerPlatform = PlatformStyle.values.any(
      (platform) =>
          !platform.purchaseOnly &&
          !ownedPlatforms.contains(platform) &&
          canAfford(platform.cost) &&
          ownedPlatforms.every(
            (owned) => owned.scoreBonus < platform.scoreBonus,
          ),
    );
    return strongerBall ||
        strongerPlatform ||
        SurvivalUpgrade.values.any(
          (upgrade) =>
              upgradeLevel(upgrade) < upgrade.maxLevel &&
              canAfford(upgrade.costAt(upgradeLevel(upgrade))),
        );
  }

  late final SharedPreferencesAsync storage = SharedPreferencesAsync();
  int best = 0, runs = 0;
  int infiniteBest = 0, infiniteRuns = 0, infiniteBestScore = 0;
  bool infiniteFastStart = true;

  void applyInfiniteStart(BalanceGame game, {bool tutorial = false}) {
    final bestScore = infiniteFastStart && !tutorial ? infiniteBestScore : 0;
    game.infiniteStartingPace = InfiniteTuning.startingPace(bestScore);
    game.infiniteStartingSpeedMultiplier =
        InfiniteTuning.startingSpeedMultiplier(bestScore);
  }

  int wallet = 0;
  final survivalUpgrades = <SurvivalUpgrade, int>{};
  int upgradeLevel(SurvivalUpgrade upgrade) => survivalUpgrades[upgrade] ?? 0;
  double get magnetDuration =>
      SurvivalUpgrade.magnet.valueAt(upgradeLevel(SurvivalUpgrade.magnet));
  double get shieldDuration =>
      SurvivalUpgrade.shield.valueAt(upgradeLevel(SurvivalUpgrade.shield));
  int get startingHearts => SurvivalUpgrade.hearts
      .valueAt(upgradeLevel(SurvivalUpgrade.hearts))
      .toInt();

  bool buySurvivalUpgrade(SurvivalUpgrade upgrade) {
    final level = upgradeLevel(upgrade);
    if (level >= upgrade.maxLevel || !canAfford(upgrade.costAt(level)))
      return false;
    if (!unlimitedCoins) wallet -= upgrade.costAt(level);
    survivalUpgrades[upgrade] = level + 1;
    unawaited(saveEconomy());
    return true;
  }

  void applySurvivalUpgrades(BalanceGame game) {
    game.infiniteMaxLives = startingHearts;
    game.shieldDuration = shieldDuration;
    game.magnetDuration = magnetDuration;
  }

  DailyPrizes dailyPrizes = DailyPrizes();
  final _claimedAchievements = <Achievement>{};

  bool achievementClaimed(Achievement achievement) =>
      _claimedAchievements.contains(achievement);

  int achievementProgress(Achievement achievement) {
    if (achievementClaimed(achievement)) return achievement.target;
    final progress = switch (achievement) {
      Achievement.firstRun ||
      Achievement.runs25 ||
      Achievement.runs100 => infiniteRuns,
      Achievement.distance500 ||
      Achievement.distance1000 ||
      Achievement.distance2500 ||
      Achievement.distance5000 => infiniteBest,
      Achievement.score10000 || Achievement.score25000 => infiniteBestScore,
      Achievement.stars12 ||
      Achievement.stars30 ||
      Achievement.stars60 ||
      Achievement.stars120 => totalStars,
      Achievement.merge128 ||
      Achievement.merge256 ||
      Achievement.merge512 ||
      Achievement.merge1024 ||
      Achievement.merge2048 ||
      Achievement.merge4096 => mergeHighest,
      Achievement.mergeRuns25 || Achievement.mergeRuns100 => mergeRuns,
      Achievement.visits3 ||
      Achievement.visits7 ||
      Achievement.visits14 ||
      Achievement.visits30 ||
      Achievement.visits60 => dailyPrizes.claimed,
    };
    return progress.clamp(0, achievement.target);
  }

  bool achievementEarned(Achievement achievement) =>
      achievementProgress(achievement) >= achievement.target;

  int get achievementsReady => Achievement.values
      .where((a) => achievementEarned(a) && !achievementClaimed(a))
      .length;

  Future<bool> claimAchievement(Achievement achievement) async {
    if (achievementClaimed(achievement) || !achievementEarned(achievement)) {
      return false;
    }
    // Mark and credit together before awaiting, so repeated taps cannot pay twice.
    _claimedAchievements.add(achievement);
    wallet += achievement.coins;
    await saveEconomy();
    return true;
  }

  BallCosmetic? get prizeBall {
    final choices =
        BallCosmetic.values
            .where((b) => !b.purchaseOnly && !ownedBalls.contains(b))
            .toList()
          ..sort((a, b) => a.cost.compareTo(b.cost));
    return choices.firstOrNull;
  }

  PlatformStyle? get prizePlatform {
    final choices =
        PlatformStyle.values
            .where((p) => !p.purchaseOnly && !ownedPlatforms.contains(p))
            .toList()
          ..sort((a, b) => a.cost.compareTo(b.cost));
    return choices.firstOrNull;
  }

  Future<String?> claimDailyPrize({
    DateTime? now,
    bool platform = false,
  }) async {
    final date = now ?? DateTime.now();
    if (!dailyPrizes.canClaim(date)) return null;
    final day = dailyPrizes.nextDay;
    final String reward;
    if (day < 5) {
      final coins = DailyPrizes.coins[day - 1];
      wallet += coins;
      reward = '$coins coins';
    } else {
      final ball = prizeBall;
      final rail = prizePlatform;
      if (rail != null && (platform || ball == null)) {
        ownedPlatforms.add(rail);
        reward = '${rail.label} platform';
      } else if (ball != null) {
        ownedBalls.add(ball);
        reward = '${ball.label} ball';
      } else {
        wallet += 100;
        reward = '100 coins';
      }
    }
    // Update before awaiting storage so rapid taps cannot claim twice.
    dailyPrizes.claimed++;
    dailyPrizes.lastClaim = DailyChallenge.day(date);
    await saveEconomy();
    return reward;
  }

  BallCosmetic selectedBall = BallCosmetic.steel;
  double analogSensitivity = 1, twoFingerSensitivity = 1;
  PlatformStyle selectedPlatform = PlatformStyle.classic;
  final ownedPlatforms = <PlatformStyle>{PlatformStyle.classic};
  double get equipmentMultiplier =>
      1 + selectedBall.scoreBonus + selectedPlatform.scoreBonus;
  final ownedBalls = <BallCosmetic>{BallCosmetic.steel};
  final _bankedCoins = Expando<({int serial, int count})>();
  final _doubledCoinRuns = Expando<int>();
  Future<void> _economyWrites = Future<void>.value();

  bool infiniteCoinsDoubled(BalanceGame game) =>
      _doubledCoinRuns[game] == game.runSerial;

  bool canDoubleInfiniteCoins(BalanceGame game) =>
      game.started &&
      game.infinite &&
      game.finished &&
      game.lives <= 0 &&
      !game.won &&
      !game.practice &&
      game.coinsCollected > 10 &&
      !infiniteCoinsDoubled(game);

  /// Called only after the ad reward is earned and the ad has closed.
  /// The collected-coin ledger stays unchanged, so banking cannot pay again.
  bool doubleInfiniteCoins(BalanceGame game) {
    if (!canDoubleInfiniteCoins(game)) return false;
    bankCoins(game);
    _doubledCoinRuns[game] = game.runSerial;
    wallet += game.coinsCollected;
    unawaited(saveEconomy());
    return true;
  }

  bool bankCoins(BalanceGame game) {
    if (!game.infinite) return false;
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
      if (ball.purchaseOnly || !canAfford(ball.cost)) return false;
      if (!unlimitedCoins) wallet -= ball.cost;
      ownedBalls.add(ball);
    }
    selectedBall = ball;
    unawaited(saveEconomy());
    return true;
  }

  bool selectPlatform(PlatformStyle platform) {
    if (!ownedPlatforms.contains(platform)) {
      if (platform.purchaseOnly || !canAfford(platform.cost)) return false;
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
      'survivalUpgrades': survivalUpgrades.map(
        (upgrade, level) => MapEntry(upgrade.name, level),
      ),
      'dailyPrizes': dailyPrizes.toJson(),
      'claimedAchievements': _claimedAchievements.map((a) => a.name).toList(),
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
      final upgrades = data['survivalUpgrades'];
      if (upgrades is Map) {
        for (final upgrade in SurvivalUpgrade.values) {
          final level = upgrades[upgrade.name];
          if (level is int)
            survivalUpgrades[upgrade] = level.clamp(0, upgrade.maxLevel);
        }
      }
      dailyPrizes = DailyPrizes.fromJson(data['dailyPrizes']);
      final claimed = data['claimedAchievements'];
      if (claimed is List) {
        _claimedAchievements.addAll(
          Achievement.values.where((a) => claimed.contains(a.name)),
        );
      }
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
  bool sound = true, music = true, haptics = true;
  bool available = true;
  bool tutorialSeen = false;
  TutorialProgress tutorial = TutorialProgress();
  Future<void> _tutorialWrites = Future<void>.value();
  ControlMode controlMode = ControlMode.oneFinger;
  int classicLevel = 1;
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
      level >= 1 &&
      level <= ClassicLevels.count &&
      (temporaryLevelAccess || ClassicLevels.isUnlocked(level, totalStars));

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
    tutorial.step = TutorialStep.completed;
    await saveTutorial();
    try {
      await storage.setBool('gilt.tutorial.v1.seen', true);
    } catch (_) {
      available = false;
    }
  }

  Future<void> saveTutorial() {
    final snapshot = jsonEncode(tutorial.toJson());
    _tutorialWrites = _tutorialWrites.then((_) async {
      try {
        await storage.setString('gilt.tutorial.v2', snapshot);
      } catch (_) {
        available = false;
      }
    });
    return _tutorialWrites;
  }

  Future<void> replayTutorial() {
    tutorialSeen = false;
    tutorial = TutorialProgress();
    return saveTutorial();
  }

  bool recordResult(BalanceGame game) {
    bankCoins(game);
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
                      r'^(oneFinger|twoFinger|analog|tiltLift|boardTilt):[1-9]\d*$',
                    ).hasMatch(entry.key) &&
                    int.parse(entry.key.split(':').last) <= ClassicLevels.count
              : RegExp(
                  r'^(oneFinger|twoFinger|analog|tiltLift|boardTilt):\d{4}-\d{2}-\d{2}$',
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

  // Recognize returning players without loading retired route records.
  static bool _hasLegacyMazeProgress(String? raw) {
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw);
      return data is Map &&
          ((data['runs'] is num && data['runs'] > 0) ||
              (data['times'] is Map && (data['times'] as Map).isNotEmpty));
    } catch (_) {
      return false;
    }
  }

  Future<void> load() async {
    try {
      tutorialSeen = await storage.getBool('gilt.tutorial.v1.seen') ?? false;
      controlMode = await storage.getBool('gilt.oneFinger') == false
          ? ControlMode.twoFinger
          : ControlMode.oneFinger;
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
          (ControlMode.values.where((m) => m.name == savedMode).firstOrNull ??
                  controlMode)
              .supportedMode;
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
      infiniteFastStart =
          await storage.getBool('gilt.ascent.fastStart') ?? true;
      sound = await storage.getBool('gilt.sound') ?? true;
      // Preserve an existing player's mute preference when migrating.
      music = await storage.getBool('gilt.music') ?? sound;
      haptics = await storage.getBool('gilt.haptics') ?? true;
      _loadRecords(await storage.getString('gilt.mastery.v1'));
      final legacyMaze = await storage.getString('gilt.maze.v1');
      _loadEconomy(await storage.getString(_economyKey));
      final savedTutorial = await storage.getString('gilt.tutorial.v2');
      if (savedTutorial != null) {
        try {
          final data = jsonDecode(savedTutorial);
          if (data is Map<String, dynamic>)
            tutorial = TutorialProgress.fromJson(data);
        } catch (_) {
          /* A damaged tutorial save must not discard the profile. */
        }
        tutorialSeen = !tutorial.active;
      } else if (tutorialSeen ||
          runs + infiniteRuns + mergeRuns > 0 ||
          levelRecords.isNotEmpty ||
          dailyRecords.isNotEmpty ||
          _hasLegacyMazeProgress(legacyMaze)) {
        tutorial = TutorialProgress(step: TutorialStep.completed);
        tutorialSeen = true;
      }
    } catch (_) {
      available = false;
    }
  }

  Future<void> save() async {
    await saveEconomy();
    try {
      await storage.setInt('gilt.merge.best', mergeBest);
      await storage.setInt('gilt.merge.highest', mergeHighest);
      await storage.setInt('gilt.merge.runs', mergeRuns);
      await storage.setInt('gilt.best', best);
      await storage.setInt('gilt.runs', runs);
      await storage.setInt('gilt.ascent.best', infiniteBest);
      await storage.setInt('gilt.ascent.runs', infiniteRuns);
      await storage.setBool('gilt.ascent.fastStart', infiniteFastStart);
      await storage.setBool('gilt.sound', sound);
      await storage.setBool('gilt.music', music);
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
  GameFeedback({MusicOutput Function()? musicOutput})
    : _musicFactory = musicOutput ?? AudioMusicOutput.new;
  final MusicOutput Function() _musicFactory;
  AudioPlayer? _player;
  final _enemyAudio = EnemyAudio();
  void setEnemyEffectsEnabled(bool enabled) => _enemyAudio.setEnabled(enabled);
  Future<void> playEnemy(EnemyCue cue) => _enemyAudio.play(cue);
  static bool _sharedContext = false;

  /// Effects and music are two players in one app. Left at the plugin's
  /// default, every effect requests full audio focus, and Android answers by
  /// revoking it from the music, which then stops for good. Mixing instead of
  /// grabbing focus lets the coin land over the loop.
  Future<void> _shareAudioFocus() async {
    if (_sharedContext) return;
    _sharedContext = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
    } catch (_) {
      /* An unavailable audio platform must never interrupt a run. */
    }
  }

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
      await _shareAudioFocus();
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

  MusicOutput? _music;
  String? _track;
  bool _musicPlaying = false;
  bool _disposed = false;
  double _musicRate = 1, _musicVolume = .32;
  ({String? track, bool playing, double volume, double rate})? _wantedMusic;
  ({String? track, bool playing, double volume, double rate})? _handledMusic;
  Future<void>? _musicUpdate;

  /// Background music for the modes that want one. Passing a null track stops
  /// it; [playing] false holds it where it is, so pausing a run and resuming
  /// picks the loop up again rather than restarting it.
  Future<void> updateMusic({
    required String? track,
    required bool playing,
    double volume = .32,
    double playbackRate = 1,
  }) async {
    if (_disposed ||
        (track == null && _track == null && _musicUpdate == null)) {
      return;
    }
    final request = (
      track: track,
      playing: playing,
      volume: volume.clamp(0.0, 1.0),
      rate: playbackRate.clamp(.5, 2.0),
    );
    _wantedMusic = request;
    // Coalesce ticker updates during asset loading. A later mute, pause or
    // rate replaces pending work instead of starting overlapping players.
    while (!_disposed && _handledMusic != _wantedMusic) {
      final pending = _musicUpdate;
      if (pending != null) {
        await pending;
        continue;
      }
      final completion = Completer<void>();
      _musicUpdate = completion.future;
      try {
        await _flushMusic();
      } finally {
        _musicUpdate = null;
        completion.complete();
      }
    }
  }

  Future<void> _flushMusic() async {
    while (!_disposed) {
      final request = _wantedMusic!;
      try {
        await _applyMusic(request);
      } catch (_) {
        /* Audio restrictions must never interrupt a run. */
      }
      _handledMusic = request;
      if (request == _wantedMusic) return;
    }
  }

  Future<void> _applyMusic(
    ({String? track, bool playing, double volume, double rate}) request,
  ) async {
    final track = request.track;
    if (track == null) {
      _track = null;
      _musicPlaying = false;
      _musicRate = 1;
      await _music?.stop();
      return;
    }
    if (_disposed) return;
    final music = _music ??= _musicFactory();
    if (track != _track) {
      await music.play(track, request.volume);
      _track = track;
      _musicPlaying = true;
      _musicVolume = request.volume;
      _musicRate = double.nan;
    }
    if (_disposed || request != _wantedMusic) return;
    if (request.playing != _musicPlaying) {
      await (request.playing ? music.resume() : music.pause());
      _musicPlaying = request.playing;
    }
    // The platform expects playback to have started before changing rate.
    // Pause keeps position; resume re-applies a changed rate without seeking.
    if (request.playing && request.rate != _musicRate) {
      await music.setPlaybackRate(request.rate);
      _musicRate = request.rate;
    }
    if (request.volume != _musicVolume) {
      await music.setVolume(request.volume);
      _musicVolume = request.volume;
    }
  }

  void dispose() {
    _disposed = true;
    _enemyAudio.dispose();
    _player?.dispose();
    _music?.dispose();
  }
}
