import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'enemy_sounds.dart';

typedef EnemySoundStart = Future<StopFunction> Function(EnemyCue cue);

class _EnemyVoice {
  Timer? timer;
  StopFunction? stop;
}

/// Short preloaded effects use Android's low-latency sound pool. The four-voice
/// cap keeps noisy volleys bounded; critical hit/coin feedback has its own player.
class EnemyAudio {
  EnemyAudio({EnemySoundStart? start}) : _injectedStart = start;
  final EnemySoundStart? _injectedStart;
  final _pools = <EnemyCue, Future<AudioPool>>{};
  final _voices = <_EnemyVoice>{};
  bool _enabled = false, _disposed = false;
  bool _warming = false;
  int _epoch = 0;
  int get activeVoices => _voices.length;

  void setEnabled(bool value) {
    if (_disposed || value == _enabled) return;
    _enabled = value;
    if (value && _injectedStart == null) unawaited(_warm());
    if (!value) {
      _epoch++;
      for (final voice in _voices) {
        voice.timer?.cancel();
        if (voice.stop != null) unawaited(_quietStop(voice.stop!));
      }
      _voices.clear();
    }
  }

  Future<void> _quietStop(StopFunction stop) async {
    try {
      await stop();
    } catch (_) {
      /* Audio can disappear on backgrounding. */
    }
  }

  Future<AudioPool> _pool(EnemyCue cue) => _pools.putIfAbsent(
    cue,
    () => AudioPool.create(
      source: AssetSource(cue.asset),
      minPlayers: 1,
      maxPlayers: 4,
      playerMode: PlayerMode.lowLatency,
      audioContext: AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build(),
    ),
  );

  Future<void> _warm() async {
    if (_warming) return;
    _warming = true;
    try {
      for (final cue in EnemyCue.values) {
        if (!_enabled || _disposed) break;
        try {
          await _pool(cue);
        } catch (_) {
          /* Platform may be unavailable. */
        }
      }
    } finally {
      _warming = false;
    }
  }

  Future<StopFunction> _start(EnemyCue cue) async {
    final epoch = _epoch;
    final pool = await _pool(cue);
    if (!_enabled || _disposed || epoch != _epoch) return () async {};
    return pool.start(volume: cue.volume);
  }

  Future<void> play(EnemyCue cue) async {
    if (!_enabled || _disposed || _voices.length >= 4) return;
    final epoch = _epoch;
    final voice = _EnemyVoice();
    // Reserve before loading to cap concurrent async starts.
    _voices.add(voice);
    try {
      final stop = await (_injectedStart ?? _start)(cue);
      if (_disposed || !_enabled || epoch != _epoch) {
        await _quietStop(stop);
        _voices.remove(voice);
        return;
      }
      voice.stop = stop;
      voice.timer = Timer(
        Duration(milliseconds: (cue.seconds * 1000).ceil() + 30),
        () {
          _voices.remove(voice);
          unawaited(_quietStop(stop));
        },
      );
    } catch (_) {
      _voices.remove(voice);
      // A missing/unavailable audio platform must never interrupt gameplay.
    }
  }

  void dispose() {
    if (_disposed) return;
    setEnabled(false);
    _disposed = true;
    for (final future in _pools.values) {
      unawaited(
        future.then((pool) => pool.dispose()).catchError((Object _) {}),
      );
    }
    _pools.clear();
  }
}
