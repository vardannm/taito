import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'game.dart';

typedef AnalyticsSender =
    Future<void> Function(String name, Map<String, Object> parameters);

/// Optional reporting: analytics failures must never interrupt a game.
class AppAnalytics {
  AppAnalytics({AnalyticsSender? send}) : _send = send;

  final AnalyticsSender? _send;
  int? _startedRun, _finishedRun;
  GameMode? _selectedMode;

  static Future<AppAnalytics> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(true);
      return AppAnalytics(
        send: (name, parameters) =>
            analytics.logEvent(name: name, parameters: parameters),
      );
    } catch (error) {
      debugPrint('Analytics unavailable: $error');
      return AppAnalytics();
    }
  }

  void selectMode(GameMode mode) {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    _record('mode_selected', {'mode': mode.name});
  }

  void startRun(BalanceGame game) {
    if (!game.started ||
        game.waitingForInput ||
        _startedRun == game.runSerial) {
      return;
    }
    _startedRun = game.runSerial;
    _record('run_started', _runParameters(game));
  }

  void finishRun(BalanceGame game) {
    if (!game.finished ||
        _startedRun != game.runSerial ||
        _finishedRun == game.runSerial) {
      return;
    }
    _finishedRun = game.runSerial;
    _record('run_finished', {
      ..._runParameters(game),
      'won': game.won ? 1 : 0,
      'score': game.score,
      'active_seconds': game.elapsed,
    });
  }

  void openShop(GameMode mode) => _record('shop_opened', {'mode': mode.name});

  Map<String, Object> _runParameters(BalanceGame game) => {
    'mode': game.mode.name,
    'control': game.controlMode.name,
    'level': game.level,
    'practice': game.practice ? 1 : 0,
  };

  void _record(String name, Map<String, Object> parameters) {
    unawaited(_deliver(name, parameters));
  }

  Future<void> _deliver(String name, Map<String, Object> parameters) async {
    try {
      await _send?.call(name, parameters);
    } catch (error) {
      debugPrint('Analytics event $name failed: $error');
    }
  }
}
