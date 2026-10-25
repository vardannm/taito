import 'onboarding.dart';
import 'daily_prizes.dart';
import 'dart:convert';
import 'game.dart';
import 'profile.dart';
import 'levels.dart';
import 'ball_cosmetics.dart';
import 'platforms.dart';
import 'rewards.dart';
import 'survival_upgrades.dart';
import 'achievements.dart';

/// Portable, versioned profile data. No credentials or device identifiers.
class ProgressBackup {
  static const maxLength = 262144;
  static String encode(PlayerProfile p) => jsonEncode({
    'format': 'gilt-progress',
    'version': 1,
    'testEconomy': p.unlimitedCoins,
    'dailyPrizes': p.dailyPrizes.toJson(),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'counts': [
      p.best,
      p.runs,
      p.infiniteBest,
      p.infiniteRuns,
      p.infiniteBestScore,
      p.mergeBest,
      p.mergeHighest,
      p.mergeRuns,
      0, // Retired Maze run counter; keep version 1 positions stable.
      // Two retired Maze Infinite counters. The slots stay so codes written
      // before the mode was removed still decode by position.
      0,
      0,
      p.wallet,
    ],
    'control': p.preferredControlMode.name,
    'haloJoystick': p.haloJoystick,
    'level': p.classicLevel,
    'maze': 1, // Reserved for version 1 readers.
    'sound': p.sound,
    'music': p.music,
    'haptics': p.haptics,
    'fastStart': p.infiniteFastStart,
    'bestBosses': p.infiniteBestBosses,
    'achievements': p.claimedAchievements.map((a) => a.name).toList(),
    'tutorial': p.tutorialSeen,
    'onboarding':
        (p.tutorialSeen
                ? TutorialProgress(step: TutorialStep.completed)
                : p.tutorial)
            .toJson(),
    'sensitivity': [p.analogSensitivity, p.twoFingerSensitivity],
    'cabinet': p.cabinet.name,
    'balls': p.ownedBalls.map((e) => e.name).toList(),
    'ball': p.selectedBall.name,
    'platforms': p.ownedPlatforms.map((e) => e.name).toList(),
    'platform': p.selectedPlatform.name,
    'survivalUpgrades': p.survivalUpgrades.map(
      (upgrade, level) => MapEntry(upgrade.name, level),
    ),
    'levels': p.levelRecords.map((k, v) => MapEntry(k, v.toJson())),
    'daily': p.dailyRecords.map((k, v) => MapEntry(k, v.toJson())),
    'times': <String, double>{}, // Retired route records.
  });

  static PlayerProfile decode(String raw, {required bool testEconomy}) {
    if (raw.length > maxLength)
      throw const FormatException('Backup is too large.');
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('Paste a complete Rollrise backup.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'gilt-progress' ||
        decoded['version'] != 1) {
      throw const FormatException('This is not a supported Rollrise backup.');
    }
    final d = decoded;
    Never invalid() => throw const FormatException(
      'Backup contains invalid progress. Nothing was changed.',
    );
    if (d['testEconomy'] != testEconomy)
      throw const FormatException(
        'Test and normal economy backups cannot be mixed.',
      );
    int integer(dynamic value, [int max = 1 << 52]) {
      if (value is! int || value < 0 || value > max) invalid();
      return value;
    }

    T choice<T extends Enum>(dynamic value, List<T> choices) =>
        choices.where((e) => e.name == value).firstOrNull ?? invalid();
    bool flag(String key) {
      if (d[key] is! bool) invalid();
      return d[key] as bool;
    }

    final counts = d['counts'];
    if (counts is! List || counts.length != 12) invalid();
    final n = counts.map((v) => integer(v)).toList();
    final p = PlayerProfile(unlimitedCoins: testEconomy)
      ..best = n[0]
      ..runs = n[1]
      ..infiniteBest = n[2]
      ..infiniteRuns = n[3]
      ..infiniteBestScore = n[4]
      ..mergeBest = n[5]
      ..mergeHighest = n[6]
      ..mergeRuns = n[7]
      // n[8], n[9] and n[10] belong to retired modes.
      // The same ceiling the saved wallet uses on load.
      ..wallet = n[11].clamp(0, 1 << 30)
      ..controlMode = choice(d['control'], ControlMode.values)
      ..classicLevel = integer(d['level'], ClassicLevels.count)
      ..sound = flag('sound')
      ..haptics = flag('haptics')
      ..tutorialSeen = flag('tutorial');
    // Older backups predate the music switch; music followed sound then.
    p.music = d['music'] != null ? flag('music') : p.sound;
    p.haloJoystick = d['haloJoystick'] != null ? flag('haloJoystick') : false;
    if (d['fastStart'] != null) p.infiniteFastStart = flag('fastStart');
    // Older backups predate boss records; they restore as none outlasted.
    if (d['bestBosses'] != null)
      p.infiniteBestBosses = integer(d['bestBosses'], 99);
    final upgrades = d['survivalUpgrades'];
    if (upgrades != null) {
      if (upgrades is! Map) invalid();
      for (final upgrade in SurvivalUpgrade.values) {
        p.survivalUpgrades[upgrade] = integer(
          upgrades[upgrade.name] ?? 0,
          upgrade.maxLevel,
        );
      }
    }
    p.dailyPrizes = DailyPrizes.fromJson(d['dailyPrizes']);
    final achievements = d['achievements'];
    if (achievements != null) {
      if (achievements is! List) invalid();
      p.replaceClaimedAchievements(
        achievements.map((name) => choice(name, Achievement.values)),
      );
    }
    p.tutorial = d['onboarding'] is Map<String, dynamic>
        ? TutorialProgress.fromJson(d['onboarding'] as Map<String, dynamic>)
        : TutorialProgress(
            step: p.tutorialSeen
                ? TutorialStep.completed
                : TutorialStep.controls,
          );
    p.tutorialSeen = !p.tutorial.active;
    if (p.classicLevel < 1 || p.mergeHighest < 2) invalid();
    final sensitivity = d['sensitivity'];
    if (sensitivity is! List ||
        sensitivity.length != 2 ||
        sensitivity.any((v) => v is! num || !v.isFinite || v < 0 || v > 1))
      invalid();
    // Validate old exports, but movement now always uses full response.
    void records(String name, Map<String, LevelRecord> target, RegExp key) {
      final source = d[name];
      final maxRecords = name == 'levels' ? ClassicLevels.count * 3 : 160;
      if (source is! Map<String, dynamic> || source.length > maxRecords)
        invalid();
      for (final entry in source.entries) {
        final v = entry.value;
        if (!key.hasMatch(entry.key) || v is! Map<String, dynamic>) invalid();
        if (name == 'levels' &&
            int.parse(entry.key.split(':').last) > ClassicLevels.count)
          invalid();
        integer(v['stars'], name == 'levels' ? 15 : 7);
        integer(v['score']);
        integer(v['attempts']);
        final t = v['time'];
        if (t != null && (t is! num || !t.isFinite || t <= 0 || t > 1e9))
          invalid();
        target[entry.key] = LevelRecord.fromJson(v);
      }
    }

    records(
      'levels',
      p.levelRecords,
      RegExp(r'^(oneFinger|twoFinger|analog|tiltLift|boardTilt):[1-9]\d*$'),
    );
    records(
      'daily',
      p.dailyRecords,
      RegExp(
        r'^(oneFinger|twoFinger|analog|tiltLift|boardTilt):\d{4}-\d{2}-\d{2}$',
      ),
    );
    p.clearUnwonLevelStars();
    void owned<T extends Enum>(String key, Set<T> target, List<T> values) {
      final source = d[key];
      if (source is! List || source.isEmpty || source.length > values.length)
        invalid();
      target.clear();
      for (final v in source) {
        target.add(choice(v, values));
      }
    }

    owned('balls', p.ownedBalls, BallCosmetic.values);
    owned('platforms', p.ownedPlatforms, PlatformStyle.values);
    final ball = choice(d['ball'], BallCosmetic.values);
    p.selectedBall = p.ownedBalls.contains(ball) ? ball : BallCosmetic.steel;
    final platform = choice(d['platform'], PlatformStyle.values);
    p.selectedPlatform = p.ownedPlatforms.contains(platform)
        ? platform
        : PlatformStyle.classic;
    p.cabinet = choice(d['cabinet'], CabinetStyle.values);
    // Backups written before claims were exported carry coins already paid
    // for every earned achievement; treat those as claimed.
    if (achievements == null) {
      p.replaceClaimedAchievements(
        Achievement.values.where(p.achievementEarned),
      );
    }
    if (!p.ownedBalls.contains(BallCosmetic.steel) ||
        !p.ownedPlatforms.contains(PlatformStyle.classic) ||
        !p.isUnlocked(p.cabinet))
      invalid();
    return p;
  }

  /// Call only after previewing and confirming the validated snapshot.
  static Future<void> restore(
    PlayerProfile target,
    PlayerProfile source,
  ) async {
    if (target.unlimitedCoins != source.unlimitedCoins)
      throw const FormatException('Economy mismatch.');
    target
      ..best = source.best
      ..runs = source.runs
      ..infiniteBest = source.infiniteBest
      ..infiniteRuns = source.infiniteRuns
      ..infiniteBestScore = source.infiniteBestScore
      ..infiniteBestBosses = source.infiniteBestBosses
      ..mergeBest = source.mergeBest
      ..mergeHighest = source.mergeHighest
      ..mergeRuns = source.mergeRuns
      ..wallet = source.wallet
      ..dailyPrizes = DailyPrizes.fromJson(source.dailyPrizes.toJson())
      ..controlMode = source.preferredControlMode.supportedMode
      ..haloJoystick = source.haloJoystick
      ..classicLevel = source.classicLevel
      ..sound = source.sound
      ..music = source.music
      ..infiniteFastStart = source.infiniteFastStart
      ..haptics = source.haptics
      ..tutorialSeen = source.tutorialSeen
      ..tutorial = TutorialProgress.fromJson(source.tutorial.toJson())
      ..cabinet = source.cabinet
      ..selectedBall = source.selectedBall
      ..selectedPlatform = source.selectedPlatform;
    target.replaceClaimedAchievements(source.claimedAchievements);
    // Every saved field now comes from the backup, so it is safe to write
    // even if this session's own load had failed.
    target.resumeSavingAfterRestore();
    target.survivalUpgrades
      ..clear()
      ..addAll(source.survivalUpgrades);
    target.levelRecords
      ..clear()
      ..addAll(source.levelRecords);
    target.dailyRecords
      ..clear()
      ..addAll(source.dailyRecords);
    target.ownedBalls
      ..clear()
      ..addAll(source.ownedBalls);
    target.ownedPlatforms
      ..clear()
      ..addAll(source.ownedPlatforms);
    await target.save();
    await target.saveTutorial();
    await target.storage.setBool('gilt.tutorial.v1.seen', target.tutorialSeen);
    if (!target.available)
      throw StateError(
        'Restored for this session, but device storage could not save it. Keep your backup.',
      );
  }
}
