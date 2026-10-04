import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/mode_carousel.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'legacy backups preserve active progress while discarding retired records',
    () async {
      final source = PlayerProfile(unlimitedCoins: false)
        ..wallet = 450
        ..classicLevel = 8
        ..infiniteBest = 900
        ..mergeHighest = 256;
      source.levelRecords['oneFinger:8'] = const LevelRecord(starMask: 3);
      final legacy =
          jsonDecode(ProgressBackup.encode(source)) as Map<String, dynamic>;
      legacy['maze'] = 20;
      legacy['times'] = {'analog:20': 123.5};
      legacy['counts'][8] = 32;
      final restored = ProgressBackup.decode(
        jsonEncode(legacy),
        testEconomy: false,
      );
      await ProgressBackup.restore(
        PlayerProfile(unlimitedCoins: false),
        restored,
      );
      final loaded = PlayerProfile(unlimitedCoins: false);
      await loaded.load();
      expect(loaded.wallet, 450);
      expect(loaded.classicLevel, 8);
      expect(loaded.levelRecord(8).starMask, 3);
      expect(loaded.infiniteBest, 900);
      expect(loaded.mergeHighest, 256);
      final encoded = jsonDecode(ProgressBackup.encode(loaded));
      expect(encoded['counts'][8], 0);
      expect(encoded['times'], isEmpty);
    },
  );

  test(
    'returning Maze-only players keep their onboarding completion',
    () async {
      final old = PlayerProfile();
      await old.storage.setString(
        'gilt.maze.v1',
        jsonEncode({
          'selected': 4,
          'runs': 3,
          'times': {'oneFinger:1': 40.0},
        }),
      );
      final loaded = PlayerProfile();
      await loaded.load();
      expect(loaded.tutorialSeen, isTrue);
      await loaded.save();
      expect(await loaded.storage.getString('gilt.maze.v1'), isNotNull);
    },
  );

  testWidgets('only three worlds remain and menu has no Maze entry', (
    tester,
  ) async {
    expect(arcadeModes, [
      GameMode.infinite,
      GameMode.classic,
      GameMode.merge2048,
    ]);
    await tester.pumpWidget(
      ArcadeApp(profile: PlayerProfile()..tutorialSeen = true),
    );
    expect(find.byKey(const ValueKey('mode-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-3')), findsNothing);
    await tester.tap(find.byTooltip('Modes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Classic levels'), findsOneWidget);
    expect(find.text('Maze routes'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
