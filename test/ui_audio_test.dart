import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ui_audio.dart';

void main() {
  testWidgets('muted buttons remain functional and create no sound', (
    tester,
  ) async {
    var enabled = false, actions = 0, starts = 0;
    final audio = UiAudio(
      enabled: () => enabled,
      start: (_) async {
        starts++;
        return () async {};
      },
    );
    await audio.play(UiCue.tap);
    expect(starts, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: uiAction(context, () => actions++),
            child: const Text('Tap'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tap'));
    expect(actions, 1);
    enabled = true;
    await audio.play(UiCue.tap);
    expect(starts, 1);
    audio.dispose();
  });

  testWidgets('mute cancels pending UI audio and disposal prevents replay', (
    tester,
  ) async {
    var enabled = true, stops = 0, starts = 0;
    final pending = Completer<Future<void> Function()>();
    final audio = UiAudio(
      enabled: () => enabled,
      start: (_) {
        starts++;
        return pending.future;
      },
    );
    final play = audio.play(UiCue.tap);
    enabled = false;
    await audio.play(UiCue.toggle);
    pending.complete(() async {
      stops++;
    });
    await play;
    expect(stops, 1);
    audio.dispose();
    enabled = true;
    await audio.play(UiCue.tap);
    expect(starts, 1);
  });

  testWidgets('UI sound failures never block or throw into interactions', (
    tester,
  ) async {
    final audio = UiAudio(
      enabled: () => true,
      start: (_) async => throw StateError('No audio'),
    );
    await audio.play(UiCue.back);
    audio.dispose();
  });

  testWidgets('countdown replaces a recent tap and respects mute', (
    tester,
  ) async {
    final starts = <UiCue>[];
    final stops = <UiCue>[];
    var enabled = true;
    final audio = UiAudio(
      enabled: () => enabled,
      start: (cue) async {
        starts.add(cue);
        return () async => stops.add(cue);
      },
    );
    await audio.play(UiCue.tap);
    await audio.play(UiCue.countdown);
    expect(starts, [UiCue.tap, UiCue.countdown]);
    expect(stops, [UiCue.tap]);
    enabled = false;
    await audio.play(UiCue.countdown);
    expect(starts, [UiCue.tap, UiCue.countdown]);
    expect(stops, [UiCue.tap, UiCue.countdown]);
    audio.dispose();
  });

  testWidgets('a prize claim replaces a recent tap and rings past a tap', (
    tester,
  ) async {
    final starts = <UiCue>[];
    final stops = <UiCue>[];
    final audio = UiAudio(
      enabled: () => true,
      start: (cue) async {
        starts.add(cue);
        return () async => stops.add(cue);
      },
    );
    await audio.play(UiCue.tap);
    await audio.play(UiCue.claim);
    expect(starts, [UiCue.tap, UiCue.claim]);
    expect(stops, [UiCue.tap]);
    await tester.pump(const Duration(milliseconds: 300));
    expect(stops, [UiCue.tap], reason: 'a tap would be clipped by now');
    await tester.pump(const Duration(milliseconds: 250));
    expect(stops, [UiCue.tap, UiCue.claim]);
    audio.dispose();
  });

  test('every UI cue has a bundled sound', () {
    for (final cue in UiCue.values) {
      expect(File('assets/audio/ui_${cue.name}.wav').existsSync(), isTrue);
    }
  });
}
