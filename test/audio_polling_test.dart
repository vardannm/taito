import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/music_output.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _AudioCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async => '/fake/$fileName';
}

void main() {
  testWidgets('repeated pickup sounds do not accumulate frame position polls', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const playerChannel = MethodChannel('xyz.luan/audioplayers');
    const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
    const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
    const codec = StandardMethodCodec();
    final channels = <MethodChannel>[];
    var positionQueries = 0, starts = 0;
    final previousCache = AudioCache.instance;
    AudioCache.instance = _AudioCache();
    messenger.setMockMethodCallHandler(globalChannel, (_) async => null);
    messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
    messenger.setMockMethodCallHandler(playerChannel, (call) async {
      final id = (call.arguments as Map)['playerId'] as String;
      final channel = MethodChannel('xyz.luan/audioplayers/events/$id');
      if (call.method == 'create') {
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      } else if (call.method == 'setSourceUrl') {
        tester.binding.channelBuffers.push(
          channel.name,
          codec.encodeSuccessEnvelope({
            'event': 'audio.onPrepared',
            'value': true,
          }),
          (_) {},
        );
      } else if (call.method == 'getCurrentPosition') {
        positionQueries++;
        return 0;
      } else if (call.method == 'resume') {
        starts++;
      }
      return null;
    });
    var time = Duration.zero;
    final feedback = GameFeedback(soundClock: () => time);
    final profile = PlayerProfile()..haptics = false;
    try {
      // Android low-latency sounds do not emit completion events. Reusing the
      // same effect must not start another polling chain after each pickup.
      for (var i = 0; i < 120; i++) {
        time += const Duration(milliseconds: 600);
        await feedback.play(GameEvent.coin, profile);
      }
      expect(starts, 120);
      final before = positionQueries;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 17));
      }
      expect(positionQueries - before, 0);
      expect(tester.binding.transientCallbackCount, 0);

      // Crossfading music reads its clock explicitly; disabling the unused
      // position stream must preserve this direct platform query.
      final music = createGameAudioPlayer();
      try {
        await music.resume();
        final beforeMusicFrame = positionQueries;
        await tester.pump(const Duration(milliseconds: 17));
        expect(positionQueries, beforeMusicFrame);
        expect(await music.getCurrentPosition(), Duration.zero);
        expect(positionQueries, beforeMusicFrame + 1);
      } finally {
        unawaited(music.dispose());
        await tester.pump();
        await tester.pump();
      }
    } finally {
      feedback.dispose();
      await tester.pump();
      await tester.pump();
      AudioCache.instance = previousCache;
      for (final channel in [
        playerChannel,
        globalChannel,
        globalEvents,
        ...channels,
      ]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    }
  });
}
