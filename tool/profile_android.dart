// Host-side capture; the game and its settings are left untouched.
// Run a profile build first, then:
// dart tool/profile_android.dart <VM service URL> <device id> <output dir> [seconds]
// Create <output dir>/capture-now to save a CPU/timeline snapshot, or
// <output dir>/stop to finish. Frame times describe submitted Flutter frames,
// not guaranteed on-screen FPS; idle menus must be distinguished from play.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

class Service {
  Service(this.socket) {
    socket.listen(
      (message) {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final id = data['id'];
        if (id != null) {
          final pending = requests.remove(id);
          if (data['error'] != null) {
            pending?.completeError(StateError(jsonEncode(data['error'])));
          } else {
            pending?.complete(data['result'] as Map<String, dynamic>);
          }
        } else if (data['method'] == 'streamNotify') {
          events.add(data['params']['event'] as Map<String, dynamic>);
        }
      },
      onDone: () {
        for (final request in requests.values) {
          request.completeError(StateError('VM service disconnected'));
        }
        requests.clear();
        unawaited(events.close());
      },
    );
  }

  final WebSocket socket;
  final requests = <String, Completer<Map<String, dynamic>>>{};
  final events = StreamController<Map<String, dynamic>>.broadcast();
  int serial = 0;

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final id = '${++serial}';
    final result = Completer<Map<String, dynamic>>();
    requests[id] = result;
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    try {
      return await result.future.timeout(const Duration(seconds: 15));
    } finally {
      requests.remove(id);
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      'Usage: dart tool/profile_android.dart <VM URL> <device> <output dir> [seconds]',
    );
    exitCode = 64;
    return;
  }
  final input = Uri.parse(args[0]);
  final uri = input.replace(
    scheme: 'ws',
    path: input.path.endsWith('/ws')
        ? input.path
        : '${input.path.endsWith('/') ? input.path : '${input.path}/'}ws',
    query: '',
  );
  final device = args[1];
  final directory = Directory(args[2])..createSync(recursive: true);
  final duration = args.length > 3 ? int.parse(args[3]) : 900;
  final adb = File('.tools/android-sdk/platform-tools/adb.exe').absolute.path;
  const package = 'com.giltarcade.balance_arcade';
  final clock = Stopwatch()..start();
  final log = File('${directory.path}/samples.jsonl').openWrite();
  void record(String type, Object? value) => log.writeln(
    jsonEncode({
      'type': type,
      'utc': DateTime.now().toUtc().toIso8601String(),
      'seconds': clock.elapsedMilliseconds / 1000,
      'data': value,
    }),
  );
  Future<String> shell(List<String> command) async {
    final result = await Process.run(adb, [
      '-s',
      device,
      'shell',
      ...command,
    ]).timeout(const Duration(seconds: 20));
    if (result.exitCode != 0) {
      throw StateError('${command.join(' ')}: ${result.stderr}');
    }
    return result.stdout as String;
  }

  final service = Service(await WebSocket.connect(uri.toString()));
  service.socket.pingInterval = const Duration(seconds: 15);
  final vm = await service.call('getVM');
  final isolates = (vm['isolates'] as List).cast<Map<String, dynamic>>();
  final isolate =
      isolates.firstWhere(
            (item) => item['name'] == 'main',
            orElse: () => isolates.first,
          )['id']
          as String;
  record('metadata', {'device': device, 'vm': vm, 'durationSeconds': duration});
  record('display', await shell(['dumpsys', 'display']));
  final frames = <Map<String, dynamic>>[];
  final subscription = service.events.stream.listen((event) {
    if (event['extensionKind'] == 'Flutter.Frame') {
      final frame = event['extensionData'] as Map<String, dynamic>;
      frames.add(frame);
      record('frame', frame);
    } else if (event['kind'] == 'GC') {
      record('gc', event);
    }
  });
  await service.call('streamListen', {'streamId': 'Extension'});
  await service.call('streamListen', {'streamId': 'GC'});
  final pid = (await shell(['pidof', package])).trim().split(' ').first;
  final appLog = File('${directory.path}/app-logcat.txt').openWrite();
  final logcat = await Process.start(adb, [
    '-s',
    device,
    'logcat',
    '--pid=$pid',
    '-v',
    'threadtime',
    '-T',
    '1',
  ]);
  final logSubscription = logcat.stdout.listen(appLog.add);
  final errorSubscription = logcat.stderr
      .transform(utf8.decoder)
      .listen((message) => record('logcatError', message));
  double percentile(List<double> sorted, double fraction) => sorted.isEmpty
      ? 0
      : sorted[math.min(sorted.length - 1, (sorted.length * fraction).floor())];
  Future<void> snapshot(String label) async {
    final stamp = await service.call('getVMTimelineMicros');
    final end = stamp['timestamp'] as int;
    for (final method in ['getCpuSamples', 'getVMTimeline']) {
      try {
        final value = await service.call(method, {
          if (method == 'getCpuSamples') 'isolateId': isolate,
          'timeOriginMicros': end - 10000000,
          'timeExtentMicros': 10000000,
        });
        await File(
          '${directory.path}/$label-$method.json',
        ).writeAsString(jsonEncode(value));
      } catch (error) {
        record('snapshotError', {'method': method, 'error': '$error'});
      }
    }
    record('snapshot', label);
    stdout.writeln('Saved $label CPU/timeline snapshot.');
  }

  stdout.writeln('CAPTURE READY: ${directory.absolute.path}');
  final captured = <int>{};
  var nextDeviceSample = 0;
  try {
    while (clock.elapsed.inSeconds < duration &&
        !File('${directory.path}/stop').existsSync() &&
        service.socket.readyState == WebSocket.open) {
      final batch = List<Map<String, dynamic>>.of(frames);
      frames.clear();
      final builds = batch.map((f) => (f['build'] as num) / 1000).toList()
        ..sort();
      final rasters = batch.map((f) => (f['raster'] as num) / 1000).toList()
        ..sort();
      // Explicitly labelled 60 Hz reference, not an assumed display refresh rate.
      final slow = batch
          .where(
            (f) => (f['build'] as num) > 16667 || (f['raster'] as num) > 16667,
          )
          .length;
      final summary = {
        'frames': batch.length,
        'uiP50Ms': percentile(builds, .5),
        'uiP95Ms': percentile(builds, .95),
        'rasterP50Ms': percentile(rasters, .5),
        'rasterP95Ms': percentile(rasters, .95),
        'over60HzBudget': slow,
      };
      record('summary', summary);
      stdout.writeln(
        '${clock.elapsed.inSeconds}s: ${batch.length} frames; '
        'UI p95 ${percentile(builds, .95).toStringAsFixed(1)}ms; '
        'raster p95 ${percentile(rasters, .95).toStringAsFixed(1)}ms; '
        '$slow over 16.67ms',
      );
      try {
        record(
          'memory',
          await service.call('getMemoryUsage', {'isolateId': isolate}),
        );
      } catch (error) {
        record('memoryError', '$error');
      }
      // Keep device samples available even if the Dart isolate is frozen.
      try {
        if (clock.elapsed.inSeconds >= nextDeviceSample) {
          for (final entry in {
            'thermal': ['dumpsys', 'thermalservice'],
            'nativeMemory': ['dumpsys', 'meminfo', package],
            'battery': ['dumpsys', 'battery'],
          }.entries) {
            try {
              record(entry.key, await shell(entry.value));
            } catch (error) {
              record('deviceSampleError', {
                'sample': entry.key,
                'error': '$error',
              });
            }
          }
          nextDeviceSample = clock.elapsed.inSeconds + 30;
        }
        final marker = File('${directory.path}/capture-now');
        if (marker.existsSync()) {
          marker.deleteSync();
          await snapshot('manual-${clock.elapsed.inSeconds}');
        }
        for (final seconds in [45, 360, 720]) {
          if (clock.elapsed.inSeconds >= seconds && captured.add(seconds)) {
            await snapshot('at-${clock.elapsed.inSeconds}s');
          }
        }
      } catch (error) {
        record('sampleError', '$error');
        stdout.writeln('Sample error: $error');
      }
      // IOSink.flush temporarily binds its input stream. Frame events keep
      // arriving while it awaits, so writes during that interval can throw.
      // Let IOSink drain normally; close() flushes after listeners are stopped.
      // Short waits keep an external stop marker responsive.
      for (var i = 0; i < 10; i++) {
        if (File('${directory.path}/stop').existsSync()) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  } finally {
    record('finished', {'seconds': clock.elapsed.inSeconds});
    await subscription.cancel();
    await service.socket.close();
    logcat.kill();
    await logSubscription.cancel();
    await errorSubscription.cancel();
    await appLog.close();
    await log.close();
    stdout.writeln('Capture finished: ${directory.absolute.path}');
  }
}
