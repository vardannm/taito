import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// One audio context for every game sound. It mixes with other apps instead
/// of taking focus (so effects never stop the music), and on iOS it uses the
/// ambient category, which follows the Silent switch like players expect.
AudioContext gameAudioContext() => AudioContext(
  android: AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).buildAndroid(),
  iOS: defaultTargetPlatform == TargetPlatform.iOS
      ? AudioContextIOS(category: AVAudioSessionCategory.ambient)
      : null,
);

abstract interface class MusicOutput {
  Future<void> play(String asset, double volume);
  Future<void> setVolume(double volume);
  Future<void> setPlaybackRate(double rate);
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  void dispose();
}

class AudioMusicOutput implements MusicOutput {
  final _player = AudioPlayer();

  @override
  Future<void> play(String asset, double volume) async {
    await _player.setAudioContext(gameAudioContext());
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(
      AssetSource(asset),
      volume: volume,
      position: Duration.zero,
    );
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> setPlaybackRate(double rate) => _player.setPlaybackRate(rate);
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  void dispose() => unawaited(_player.dispose());
}
