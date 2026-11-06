import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

import 'infinite_music.dart';
import 'level_music.dart';
import 'music_output.dart';

/// Native players are hidden behind this small boundary for lifecycle tests.
abstract interface class LoopVoice {
  Future<void> prepare(String asset);
  Future<void> seek(Duration position);
  Future<Duration?> position();
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);
  void dispose();
}

class _AudioLoopVoice implements LoopVoice {
  final _player = AudioPlayer();

  @override
  Future<void> prepare(String asset) async {
    await _player.setAudioContext(gameAudioContext());
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(0);
    await _player.setSource(AssetSource(asset));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<Duration?> position() => _player.getCurrentPosition();
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  void dispose() => unawaited(_player.dispose());
}

/// Two prepared copies hand off before the native file ends. The asset contains
/// a natural 2.5-second continuation after its 30-second repeating body, plus
/// 250 ms of scheduling headroom. No audible player seeks back at its endpoint.
class CrossfadingLoopVoice implements LoopVoice {
  CrossfadingLoopVoice({
    required LoopVoice first,
    required LoopVoice second,
    this.period = InfiniteMusic.loopDuration,
    this.overlap = InfiniteMusic.loopOverlap,
    this.equalPower = true,
  }) : _copies = [first, second];
  final List<LoopVoice> _copies;
  final Duration period, overlap;
  final bool equalPower;
  int _lead = 0;
  bool _playing = false, _disposed = false, _overlapping = false;
  double _volume = 0, _blend = 0;
  final _sentVolumes = [-1.0, -1.0];
  Timer? _timer;
  Future<void>? _pending;
  LoopVoice get _out => _copies[_lead];
  LoopVoice get _incoming => _copies[1 - _lead];

  @override
  Future<void> prepare(String asset) async {
    _cancel();
    await _pending;
    _lead = 0;
    _overlapping = false;
    _blend = _volume = 0;
    _sentVolumes.fillRange(0, 2, -1);
    await Future.wait(_copies.map((copy) => copy.prepare(asset)));
  }

  void _cancel() {
    _timer?.cancel();
    _playing = false;
  }

  void _startTimer() {
    _playing = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_playing || _disposed || _pending != null) return;
      _pending = _step()
          .catchError((Object _) {})
          .whenComplete(() => _pending = null);
    });
  }

  Future<void> _step() async {
    final position = await (_overlapping ? _incoming : _out).position();
    if (position == null || !_playing || _disposed) return;
    if (!_overlapping && position >= period) {
      // Account for timer latency rather than shifting the rhythm by a tick.
      final offset = position - period;
      await _incoming.setVolume(0);
      await _incoming.seek(offset);
      if (!_playing || _disposed) return;
      await _incoming.resume();
      _overlapping = true;
      _blend = (offset.inMicroseconds / overlap.inMicroseconds).clamp(0.0, 1.0);
    } else if (_overlapping) {
      _blend = (position.inMicroseconds / overlap.inMicroseconds).clamp(
        0.0,
        1.0,
      );
    }
    if (_overlapping && _blend >= 1) {
      await _out.setVolume(0);
      await _out.pause();
      _lead = 1 - _lead;
      _overlapping = false;
      _blend = 0;
    }
    await _applyVolumes();
  }

  Future<void> _applyVolumes() async {
    final angle = _overlapping ? math.pi * _blend / 2 : 0.0;
    final gains = List<double>.filled(2, 0);
    final outgoing = equalPower
        ? math.cos(angle)
        : math.pow(math.cos(angle), 2).toDouble();
    final incoming = equalPower ? math.sin(angle) : 1 - outgoing;
    gains[_lead] = (_volume * outgoing * 1000).round() / 1000;
    gains[1 - _lead] = (_volume * incoming * 1000).round() / 1000;
    await Future.wait([
      for (var i = 0; i < 2; i++)
        if ((gains[i] * 1000).round() / 1000 != _sentVolumes[i])
          _copies[i]
              .setVolume(gains[i])
              .then((_) => _sentVolumes[i] = gains[i]),
    ]);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    if (!_disposed) await _applyVolumes();
  }

  @override
  Future<void> seek(Duration position) async {
    final playing = _playing;
    _cancel();
    await _pending;
    await Future.wait(_copies.map((copy) => copy.pause()));
    _overlapping = false;
    _blend = 0;
    final wrapped = Duration(
      microseconds: position.inMicroseconds % period.inMicroseconds,
    );
    await Future.wait([_out.seek(wrapped), _incoming.seek(Duration.zero)]);
    if (_disposed) return;
    await _applyVolumes();
    if (playing) {
      await _out.resume();
      _startTimer();
    }
  }

  @override
  Future<Duration?> position() async {
    final current = await (_overlapping ? _incoming : _out).position();
    return current == null
        ? null
        : Duration(
            microseconds: current.inMicroseconds % period.inMicroseconds,
          );
  }

  @override
  Future<void> resume() async {
    if (_disposed) return;
    await _out.resume();
    if (_overlapping) await _incoming.resume();
    if (!_disposed) _startTimer();
  }

  @override
  Future<void> pause() async {
    _cancel();
    await _pending;
    await Future.wait(_copies.map((copy) => copy.pause()));
  }

  @override
  Future<void> stop() async {
    _cancel();
    await _pending;
    await Future.wait(_copies.map((copy) => copy.stop()));
    _overlapping = false;
    _blend = _volume = 0;
    _sentVolumes.fillRange(0, 2, -1);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    for (final copy in _copies) {
      copy.dispose();
    }
  }
}

/// Keep all three equal-length arrangements on the same musical timeline.
/// Changes only crossfade their volumes; they never restart a melody or alter
/// pitch. Preparation and resume seek while silent/paused before starting.
class AdaptiveAudioMusicOutput implements AdaptiveMusicOutput {
  AdaptiveAudioMusicOutput({
    LoopVoice Function()? voiceFactory,
    Duration Function()? elapsed,
  }) : _voiceFactory =
           voiceFactory ??
           (() => CrossfadingLoopVoice(
             first: _AudioLoopVoice(),
             second: _AudioLoopVoice(),
           )) {
    final watch = Stopwatch()..start();
    _elapsed = elapsed ?? () => watch.elapsed;
  }

  final LoopVoice Function() _voiceFactory;
  late final Duration Function() _elapsed;
  final _voices = <LoopVoice>[];
  final _gains = [0.0, 0.0, 0.0];
  final _sent = [-1.0, -1.0, -1.0];
  MusicMix _target = const MusicMix(1, 0, 0);
  double _volume = .32;
  bool _playing = false, _disposed = false, _adaptive = false;
  Timer? _timer;
  Future<void>? _tickPending;
  Duration _lastTick = Duration.zero;
  AudioMusicOutput? _single;
  CrossfadingLoopVoice? _level;
  bool _levelActive = false;

  @override
  Future<void> setMix(MusicMix mix) async {
    if (_disposed || mix == _target) return;
    // Native loop/start timing can drift. Re-align a silent arrangement to the
    // audible one before fading it in, so correction never clicks mid-note.
    if (_playing && _adaptive) {
      final before = _target.gains;
      final after = mix.gains;
      final entering = [
        for (var i = 0; i < 3; i++)
          if (before[i] == 0 && after[i] > 0 && _gains[i] < .002) i,
      ];
      if (entering.isNotEmpty) {
        var lead = 0;
        for (var i = 1; i < 3; i++) {
          if (_gains[i] > _gains[lead]) lead = i;
        }
        final position = await _voices[lead].position();
        if (_disposed) return;
        if (position != null) {
          await Future.wait([
            for (final i in entering) _voices[i].seek(position),
          ]);
        }
      }
    }
    _target = mix;
  }

  @override
  Future<void> play(String asset, double volume) async {
    await stop();
    if (_disposed) return;
    _volume = volume;
    _adaptive = asset == InfiniteMusic.asset;
    _levelActive = LevelMusic.assets.contains(asset);
    if (_levelActive) {
      final voice = _level ??= CrossfadingLoopVoice(
        first: _AudioLoopVoice(),
        second: _AudioLoopVoice(),
        period: LevelMusic.loopDuration,
        overlap: LevelMusic.overlap,
        equalPower: false,
      );
      await voice.prepare(asset);
      if (_disposed) return;
      await voice.seek(Duration.zero);
      await voice.setVolume(volume);
      await voice.resume();
      return;
    }
    if (!_adaptive) {
      await (_single ??= AudioMusicOutput()).play(asset, volume);
      return;
    }
    if (_voices.isEmpty) {
      _voices.addAll(List.generate(3, (_) => _voiceFactory()));
    }
    try {
      await Future.wait([
        for (var i = 0; i < 3; i++) _voices[i].prepare(InfiniteMusic.assets[i]),
      ]);
      if (_disposed) return;
      await Future.wait(_voices.map((voice) => voice.seek(Duration.zero)));
      if (_disposed) return;
      await Future.wait(_voices.map((voice) => voice.resume()));
      if (_disposed) return;
      _playing = true;
      _startFades();
    } catch (_) {
      // A partially prepared soundtrack must never leave a lone player running.
      await stop();
      rethrow;
    }
  }

  void _startFades() {
    _lastTick = _elapsed();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (_tickPending != null || !_playing || _disposed) return;
      _tickPending = _fade()
          .catchError((Object _) {
            // Music failures must not interrupt play or become unhandled futures.
          })
          .whenComplete(() => _tickPending = null);
    });
  }

  Future<void> _fade() async {
    final now = _elapsed();
    final dt = ((now - _lastTick).inMicroseconds / 1e6).clamp(0.0, .2);
    _lastTick = now;
    final alpha = 1 - math.exp(-dt / .35);
    final target = _target.gains;
    final updates = <Future<void>>[];
    for (var i = 0; i < 3; i++) {
      final goal = target[i] * _volume;
      _gains[i] += (goal - _gains[i]) * alpha;
      if ((_gains[i] - goal).abs() < .0005) _gains[i] = goal;
      final quantized = (_gains[i] * 1000).round() / 1000;
      if (quantized == _sent[i]) continue;
      final index = i;
      updates.add(
        _voices[i].setVolume(quantized).then((_) {
          _sent[index] = quantized;
        }),
      );
    }
    await Future.wait(updates);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_levelActive) {
      await _level?.setVolume(_volume);
    } else if (!_adaptive)
      await _single?.setVolume(_volume);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    // Infinite's tension comes from its arrangements; keep the shared 96 BPM.
    if (!_adaptive && !_levelActive) await _single?.setPlaybackRate(rate);
  }

  @override
  Future<void> pause() async {
    _timer?.cancel();
    _playing = false;
    await _tickPending;
    if (_levelActive) {
      await _level?.pause();
    } else if (_adaptive) {
      await Future.wait(_voices.map((voice) => voice.pause()));
    } else {
      await _single?.pause();
    }
  }

  @override
  Future<void> resume() async {
    if (_disposed) return;
    if (_levelActive) {
      await _level?.resume();
      return;
    }
    if (!_adaptive) {
      await _single?.resume();
      return;
    }
    // Re-align paused arrangements before any becomes audible again.
    final position = await _voices.first.position();
    if (_disposed) return;
    if (position != null) {
      await Future.wait(_voices.skip(1).map((voice) => voice.seek(position)));
    }
    if (_disposed) return;
    await Future.wait(_voices.map((voice) => voice.resume()));
    if (_disposed) return;
    _playing = true;
    _startFades();
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _playing = false;
    await _tickPending;
    await Future.wait([
      for (final voice in _voices) voice.stop(),
      if (_single != null) _single!.stop(),
      if (_level != null) _level!.stop(),
    ]);
    for (var i = 0; i < 3; i++) {
      _gains[i] = 0;
      _sent[i] = -1;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _playing = false;
    _timer?.cancel();
    for (final voice in _voices) {
      voice.dispose();
    }
    _single?.dispose();
    _level?.dispose();
  }
}
