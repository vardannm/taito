import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/level_picker.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/mastery_widgets.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('Classic wins bank once per run, persist, and reward replays', () async {
    final profile = PlayerProfile()..wallet = 73;
    final game = BalanceGame()..start();
    game.won = true;
    game.phase = GamePhase.over;
    profile.recordResult(game);
    profile.recordResult(game);
    expect(profile.wallet, 73 + classicLevelCoinPrize);
    expect(game.coinsCollected, classicLevelCoinPrize);
    expect(profile.runs, 1);
    await profile.save();

    final restored = PlayerProfile();
    await restored.load();
    expect(restored.wallet, 73 + classicLevelCoinPrize);
    game.start();
    expect(game.coinsCollected, 0);
    game.won = true;
    game.phase = GamePhase.over;
    restored.recordResult(game);
    restored.recordResult(game);
    expect(restored.wallet, 73 + classicLevelCoinPrize * 2);
    await restored.save();
  });

  test(
    'unfinished and lost levels and other modes earn no level prize',
    () async {
      final profile = PlayerProfile();
      final game = BalanceGame()..start();
      profile.recordResult(game);
      expect(profile.wallet, 0);
      game.phase = GamePhase.over;
      profile.recordResult(game);
      expect(profile.wallet, 0);
      for (final mode in GameMode.values.where((m) => m != GameMode.classic)) {
        game.start(gameMode: mode);
        game.won = true;
        game.phase = GamePhase.over;
        profile.recordResult(game);
        expect(profile.wallet, 0, reason: mode.name);
      }
      await profile.save();
    },
  );

  testWidgets('level picker shows coin prizes without level names', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LevelPicker(selected: 1, onSelected: (_) {})),
      ),
    );
    expect(find.text('+$classicLevelCoinPrize COINS'), findsWidgets);
    for (final name in ClassicLevels.names) {
      expect(find.text(name), findsNothing);
    }
    final semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('level-1')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.label, contains('Level 1, 50 coin'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'finale briefing uses level number and keeps hazard instructions',
    (tester) async {
      final game = BalanceGame()..start(levelNumber: 10);
      await tester.pumpWidget(
        MaterialApp(
          home: FinaleBriefing(game: game, onPlay: () {}, onBack: () {}),
        ),
      );
      expect(find.text('Level 10'), findsOneWidget);
      expect(find.text(game.finaleTitle), findsNothing);
      expect(find.text(ClassicLevels.finaleRule(10)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
