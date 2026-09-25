import 'package:balance_arcade/app_analytics.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/mode_navigation.dart';

void main() {
  test('previews do not start runs; starts and finishes are deduplicated', () {
    final events = <(String, Map<String, Object>)>[];
    final analytics = AppAnalytics(
      send: (name, values) async {
        events.add((name, values));
      },
    );
    final game = BalanceGame()..start(waitForInput: true);
    analytics.startRun(game);
    analytics.finishRun(game);
    expect(events, isEmpty);

    game.beginInput();
    analytics.startRun(game);
    analytics.startRun(game);
    game.phase = GamePhase.over;
    analytics.finishRun(game);
    analytics.finishRun(game);
    expect(events.map((e) => e.$1), ['run_started', 'run_finished']);
    expect(events.last.$2['active_seconds'], game.elapsed);
    expect(events.last.$2['won'], isA<int>());

    game.start();
    analytics.startRun(game);
    game.phase = GamePhase.over;
    analytics.finishRun(game);
    expect(events.length, 4);
  });

  test('mode refreshes are ignored and each shop visit is counted', () {
    final names = <String>[];
    final analytics = AppAnalytics(send: (name, _) async => names.add(name));
    analytics.selectMode(GameMode.infinite);
    analytics.selectMode(GameMode.infinite);
    analytics.selectMode(GameMode.classic);
    analytics.openShop(GameMode.classic);
    analytics.openShop(GameMode.classic);
    expect(names, [
      'mode_selected',
      'mode_selected',
      'shop_opened',
      'shop_opened',
    ]);
  });

  test('reporting failures do not escape into gameplay', () async {
    final analytics = AppAnalytics(
      send: (_, _) async => throw StateError('offline'),
    );
    analytics.openShop(GameMode.infinite);
    await Future<void>.delayed(Duration.zero);
  });

  test('an unconfigured Firebase project leaves analytics inactive', () async {
    // The placeholder is replaced at setup; this also exercises the fallback
    // when no native Firebase implementation exists in a unit test.
    final analytics = await AppAnalytics.initialize();
    analytics.openShop(GameMode.infinite);
  });

  testWidgets(
    'screen reports selections, shop visits and actual run lifecycle',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final events = <String>[];
      await tester.pumpWidget(
        ArcadeApp(
          profile: PlayerProfile()
            ..tutorialSeen = true
            ..sound = false
            ..haptics = false,
          analytics: AppAnalytics(send: (name, _) async => events.add(name)),
        ),
      );
      await tester.pump();
      expect(events, ['mode_selected']);
      await tester.tap(find.byKey(const ValueKey('board-shop')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(events, ['mode_selected', 'shop_opened']);
      Navigator.of(tester.element(find.byType(PivotBoard))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(events.where((name) => name == 'mode_selected').length, 1);
      await startWorld(tester);
      expect(events.where((name) => name == 'run_started').length, 1);
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      game.phase = GamePhase.over;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(events.where((name) => name == 'run_finished').length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
