import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'music_output.dart';

enum UiCue { tap, back, toggle, select }

typedef UiSoundStart = Future<StopFunction> Function(UiCue cue);

class UiAudio {
  UiAudio({required this.enabled, this.volume, UiSoundStart? start})
    : _start = start;
  final bool Function() enabled;
  final double Function()? volume;
  final UiSoundStart? _start;
  final _pools = <UiCue, Future<AudioPool>>{};
  final _active = <StopFunction>{};
  final _timers = <Timer>{};
  bool _disposed = false;
  int _epoch = 0;
  int _pending = 0;
  DateTime? _last;

  Future<void> play(UiCue cue) async {
    if (_disposed) return;
    if (!enabled() || (volume?.call() ?? 1) <= 0) {
      silence();
      return;
    }
    if (_pending + _active.length >= 2) return;
    final now = DateTime.now();
    if (_last != null && now.difference(_last!).inMilliseconds < 60) return;
    _last = now;
    final epoch = _epoch;
    _pending++;
    try {
      final StopFunction stop;
      if (_start != null) {
        stop = await _start(cue);
      } else {
        final pool = await _pools.putIfAbsent(
          cue,
          () => AudioPool.create(
            source: AssetSource('audio/ui_${cue.name}.wav'),
            minPlayers: 1,
            maxPlayers: 2,
            playerMode: PlayerMode.lowLatency,
            audioContext: gameAudioContext(),
          ),
        );
        if (_disposed || !enabled() || epoch != _epoch) return;
        stop = await pool.start(
          volume: .18 * (volume?.call() ?? 1).clamp(0.0, 1.0),
        );
      }
      if (_disposed || !enabled() || epoch != _epoch) {
        await stop();
        return;
      }
      _active.add(stop);
      late final Timer timer;
      timer = Timer(const Duration(milliseconds: 220), () {
        _timers.remove(timer);
        _active.remove(stop);
        unawaited(stop().catchError((Object _) {}));
      });
      _timers.add(timer);
    } catch (_) {
      // Audio availability must never prevent a button action.
    } finally {
      _pending--;
    }
  }

  void silence() {
    _epoch++;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    for (final stop in _active) {
      unawaited(stop().catchError((Object _) {}));
    }
    _active.clear();
  }

  void dispose() {
    _disposed = true;
    silence();
    for (final pool in _pools.values) {
      unawaited(
        pool.then((value) => value.dispose()).catchError((Object _) {}),
      );
    }
  }
}

class UiAudioScope extends StatefulWidget {
  const UiAudioScope({
    super.key,
    required this.enabled,
    required this.child,
    this.volume,
  });
  final bool Function() enabled;
  final double Function()? volume;
  final Widget child;
  @override
  State<UiAudioScope> createState() => _UiAudioScopeState();
}

class _UiAudioScopeState extends State<UiAudioScope>
    with WidgetsBindingObserver {
  bool foreground = true;
  late final audio = UiAudio(
    enabled: () => foreground && widget.enabled(),
    volume: () => widget.volume?.call() ?? 1,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) audio.silence();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _UiAudio(audio: audio, child: widget.child);
}

class _UiAudio extends InheritedWidget {
  const _UiAudio({required this.audio, required super.child});
  final UiAudio audio;
  @override
  bool updateShouldNotify(_UiAudio oldWidget) => oldWidget.audio != audio;
}

VoidCallback? uiAction(
  BuildContext context,
  VoidCallback? action, {
  UiCue cue = UiCue.tap,
}) {
  if (action == null) return null;
  final audio = context.getInheritedWidgetOfExactType<_UiAudio>()?.audio;
  return () {
    action();
    if (audio != null) unawaited(audio.play(cue));
  };
}

ValueChanged<T>? uiChange<T>(BuildContext context, ValueChanged<T>? action) {
  if (action == null) return null;
  final audio = context.getInheritedWidgetOfExactType<_UiAudio>()?.audio;
  return (value) {
    action(value);
    if (audio != null) unawaited(audio.play(UiCue.toggle));
  };
}
