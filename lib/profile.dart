import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';

class PlayerProfile {
  late final SharedPreferencesAsync storage = SharedPreferencesAsync();
  int best = 0, runs = 0;
  int infiniteBest = 0, infiniteRuns = 0;
  bool sound = true, haptics = true;
  bool available = true;
  bool tutorialSeen = false;

  Future<void> completeTutorial() async {
    tutorialSeen = true;
    try {
      await storage.setBool('gilt.tutorial.v1.seen', true);
    } catch (_) {
      available = false;
    }
  }

  bool recordResult(BalanceGame game) {
    if (!game.finished || game.practice) return false;
    if (game.infinite) {
      infiniteRuns++;
      final improved = game.score > infiniteBest;
      if (improved) infiniteBest = game.score;
      return improved;
    }
    runs++;
    final improved = game.score > best;
    if (improved) best = game.score;
    return improved;
  }

  Future<void> load() async {
    try {
      tutorialSeen = await storage.getBool('gilt.tutorial.v1.seen') ?? false;
      best = await storage.getInt('gilt.best') ?? 0;
      runs = await storage.getInt('gilt.runs') ?? 0;
      infiniteBest = await storage.getInt('gilt.ascent.best') ?? 0;
      infiniteRuns = await storage.getInt('gilt.ascent.runs') ?? 0;
      sound = await storage.getBool('gilt.sound') ?? true;
      haptics = await storage.getBool('gilt.haptics') ?? true;
    } catch (_) {
      available = false;
    }
  }

  Future<void> save() async {
    try {
      await storage.setInt('gilt.best', best);
      await storage.setInt('gilt.runs', runs);
      await storage.setInt('gilt.ascent.best', infiniteBest);
      await storage.setInt('gilt.ascent.runs', infiniteRuns);
      await storage.setBool('gilt.sound', sound);
      await storage.setBool('gilt.haptics', haptics);
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
        AssetSource('audio/${event.name}.wav'),
        volume: .55,
      );
    } catch (_) {
      /* Audio restrictions must never interrupt a run. */
    }
  }

  void dispose() {
    _player?.dispose();
  }
}
