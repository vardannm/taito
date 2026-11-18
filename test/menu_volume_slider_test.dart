import 'package:balance_arcade/menu_design.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Options volume runs 0-100 and mutes like the pause menu', (
    tester,
  ) async {
    final profile = PlayerProfile()..soundVolume = .6;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => MenuVolumeSlider(
              name: 'sound',
              title: 'Sound Effects',
              icon: Icons.graphic_eq_rounded,
              mutedIcon: Icons.volume_off_rounded,
              level: profile.effectiveSoundVolume,
              onChanged: (v) => update(
                () => profile.setAudioLevel(forMusic: false, value: v),
              ),
              onChangeEnd: (v) {
                update(() => profile.setAudioLevel(forMusic: false, value: v));
                saves++;
              },
              onToggleMute: () =>
                  update(() => profile.toggleAudioMute(forMusic: false)),
            ),
          ),
        ),
      ),
    );
    final slider = find.byKey(const ValueKey('settings-sound-slider'));
    final value = find.byKey(const ValueKey('settings-sound-value'));
    expect(tester.widget<Slider>(slider).min, 0);
    expect(tester.widget<Slider>(slider).max, 100);
    expect(tester.widget<Slider>(slider).divisions, 100);
    expect(tester.widget<Text>(value).data, '60');

    final box = tester.getRect(slider);
    await tester.tapAt(Offset(box.left + 1, box.center.dy));
    await tester.pump();
    expect(profile.sound, isFalse);
    expect(tester.widget<Text>(value).data, '0');
    expect(saves, 1);

    // Unmuting restores the last audible level instead of jumping to 100.
    await tester.tap(find.byKey(const ValueKey('settings-sound-mute')));
    await tester.pump();
    expect(profile.sound, isTrue);
    expect(tester.widget<Text>(value).data, '60');

    await tester.tapAt(Offset(box.right - 1, box.center.dy));
    await tester.pump();
    expect(tester.widget<Text>(value).data, '100');
    expect(profile.effectiveSoundVolume, 1);
  });
}
