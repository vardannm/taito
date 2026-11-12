import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch;
import 'support/mode_navigation.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'levels migrate at full calibrated mix; mute remembers and persists levels',
    () async {
      final profile = PlayerProfile();
      await profile.load();
      expect(profile.soundVolume, 1);
      profile.setAudioLevel(forMusic: true, value: .42);
      profile.setAudioLevel(forMusic: false, value: .27);
      profile.toggleAudioMute(forMusic: true);
      expect(profile.effectiveMusicVolume, 0);
      expect(profile.musicVolume, .42);
      await profile.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.effectiveMusicVolume, 0);
      restored.toggleAudioMute(forMusic: true);
      expect(restored.effectiveMusicVolume, .42);
      expect(restored.effectiveSoundVolume, .27);
      restored.setAudioLevel(forMusic: false, value: 0);
      restored.toggleAudioMute(forMusic: false);
      expect(restored.effectiveSoundVolume, .27);
      await SharedPreferencesAsync().setBool('gilt.music', false);
      await restored.load();
      expect(restored.effectiveMusicVolume, 0);
    },
  );

  test(
    'sound scale preserves the quiet pickup mix and mutes all gameplay effects',
    () async {
      final heard = <double>[];
      final feedback = GameFeedback(
        effectOutput: (_, volume) async {
          heard.add(volume);
        },
      );
      final profile = PlayerProfile()..haptics = false;
      profile.setAudioLevel(forMusic: false, value: .5);
      await feedback.play(GameEvent.coin, profile);
      await feedback.play(GameEvent.miss, profile);
      expect(heard, [.0125, .14]);
      profile.setAudioLevel(forMusic: false, value: 0);
      await feedback.play(GameEvent.target, profile);
      expect(heard.length, 2);
      feedback.dispose();
    },
  );

  testWidgets(
    'pause sliders control independent channels and icons restore volume',
    (tester) async {
      await launch(tester, ControlMode.oneFinger);
      await startWorld(tester);
      final dynamic state = tester.state(find.byType(GameScreen));
      state.pause();
      await tester.pump();
      final profile = tester.widget<ArcadeApp>(find.byType(ArcadeApp)).profile;
      final music = find.byKey(const ValueKey('pause-music-slider'));
      final sound = find.byKey(const ValueKey('pause-sound-slider'));
      tester.widget<Slider>(music).onChanged!(42);
      tester.widget<Slider>(sound).onChanged!(27);
      await tester.pump();
      expect(profile.effectiveMusicVolume, .42);
      expect(profile.effectiveSoundVolume, .27);
      await tester.tap(find.byKey(const ValueKey('pause-music-mute')));
      await tester.pump();
      expect(profile.effectiveMusicVolume, 0);
      expect(profile.effectiveSoundVolume, .27);
      await tester.tap(find.byKey(const ValueKey('pause-music-mute')));
      await tester.pump();
      expect(tester.widget<Slider>(music).value, 42);
      await tester.tap(find.byKey(const ValueKey('pause-sound-mute')));
      await tester.pump();
      expect(profile.effectiveSoundVolume, 0);
      expect(profile.effectiveMusicVolume, .42);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
