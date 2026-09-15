import 'dart:convert';

/// Local, explicitly started observation. No network or participant identity.
class PlaytestRecorder {
  bool active = false;
  final events = <Map<String, Object?>>[];
  final clock = Stopwatch();
  void start() {
    events.clear();
    clock
      ..reset()
      ..start();
    active = true;
    record('session_started');
  }

  void record(String event, [Map<String, Object?> details = const {}]) {
    if (!active || events.length >= 1000) return;
    events.add({
      'event': event,
      'seconds': clock.elapsedMilliseconds / 1000,
      ...details,
    });
  }

  void stop() {
    record('session_stopped');
    active = false;
    clock.stop();
  }

  String export() => const JsonEncoder.withIndent('  ').convert({
    'format': 'gilt-playtest',
    'version': 1,
    'active': active,
    'note':
        'Local observations; timestamps include time in menus and background. Not retention or frame-time measurements.',
    'events': events,
  });
}
