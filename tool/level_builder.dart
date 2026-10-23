// Developer-only entry point. Nothing under lib/ imports this tool.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../lib/classic_levels.dart';
import 'register_classic_levels.dart' as registry;

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8765 : int.parse(args.first);
  final root = File.fromUri(Platform.script).parent;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  final levels = [
    for (var i = 0; i < classicLevelDefinitions.length; i++)
      _json(i + 1, classicLevelDefinitions[i]),
  ];
  final token = base64Url.encode(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  );
  stdout.writeln('GILT Level Builder: http://127.0.0.1:${server.port}');
  stdout.writeln('Developer tool only. Press Ctrl+C to stop.');
  await for (final request in server) {
    request.response.headers.set('Cache-Control', 'no-store');
    request.response.headers.set('X-Content-Type-Options', 'nosniff');
    if (request.method == 'POST' && request.uri.path == '/api/save') {
      request.response.headers.contentType = ContentType.json;
      try {
        if (request.headers.value('X-Builder-Token') != token ||
            request.headers.value('Origin') != 'http://127.0.0.1:$port') {
          throw const FormatException(
            'Reload the local builder before saving.',
          );
        }
        final bytes = <int>[];
        await for (final chunk in request) {
          bytes.addAll(chunk);
          if (bytes.length > 2000000)
            throw const FormatException('Draft exceeds 2 MB.');
        }
        final saved = await saveLevel(root.parent, utf8.decode(bytes));
        final number = saved['number'] as int;
        levels.removeWhere((level) => level['number'] == number);
        levels.add(saved.cast<String, Object>());
        levels.sort(
          (a, b) => (a['number'] as int).compareTo(b['number'] as int),
        );
        request.response.write(
          jsonEncode({
            'file':
                'lib/classic_levels/level_${number.toString().padLeft(2, '0')}.dart',
          }),
        );
      } catch (error) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': error.toString()}));
      }
    } else if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
    } else if (request.uri.path == '/api/levels') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(levels));
    } else if (request.uri.path == '/api/session') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'token': token}));
    } else {
      final asset = switch (request.uri.path) {
        '/' => ('index.html', 'text/html; charset=utf-8'),
        '/builder.css' => ('builder.css', 'text/css; charset=utf-8'),
        '/builder.js' => ('builder.js', 'text/javascript; charset=utf-8'),
        '/model.js' => ('model.js', 'text/javascript; charset=utf-8'),
        _ => null,
      };
      if (asset == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.set('Content-Type', asset.$2);
        request.response.add(
          await File('${root.path}/level_builder/${asset.$1}').readAsBytes(),
        );
      }
    }
    await request.response.close();
  }
}

Future<Map<String, dynamic>> saveLevel(Directory project, String draft) async {
  // Export through the same validated model used by the UI; never accept Dart
  // source or filesystem paths from the browser.
  final process = await Process.start('node', [
    '${project.path}/tool/level_builder/export.cjs',
  ]);
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  process.stdin.write(draft);
  await process.stdin.close();
  if (await process.exitCode != 0) throw FormatException(await errors);
  final result = jsonDecode(await output) as Map<String, dynamic>;
  final data = result['draft'] as Map<String, dynamic>;
  final number = data['number'] as int;
  final count = Directory('${project.path}/lib/classic_levels')
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'level_\d+\.dart$').hasMatch(f.path))
      .length;
  if (number > count + 1)
    throw const FormatException(
      'New levels must use the next consecutive number.',
    );
  final file = File(
    '${project.path}/lib/classic_levels/level_${number.toString().padLeft(2, '0')}.dart',
  );
  final registryFile = File('${project.path}/lib/classic_levels.dart');
  final original = file.existsSync() ? file.readAsBytesSync() : null;
  final originalRegistry = registryFile.readAsBytesSync();
  if (original != null) {
    final backup = File(
      '${project.path}/artifacts/level-builder-backups/${DateTime.now().microsecondsSinceEpoch}-${file.uri.pathSegments.last}',
    );
    backup.parent.createSync(recursive: true);
    backup.writeAsBytesSync(original);
  }
  try {
    file.writeAsStringSync(result['source'] as String);
    registry.main([project.path]);
  } catch (_) {
    if (original == null) {
      if (file.existsSync()) file.deleteSync();
    } else {
      file.writeAsBytesSync(original);
    }
    registryFile.writeAsBytesSync(originalRegistry);
    rethrow;
  }
  return data;
}

Map<String, Object> _json(int number, ClassicLevelDefinition level) => {
  'version': 1,
  'number': number,
  'name': level.name,
  'holes': [
    for (final h in level.holes)
      {
        'x': h.homeX,
        'y': h.homeY,
        'target': h.target,
        'size': h.size,
        'motion': switch (h.motion) {
          null => null,
          final m => {
            'path': m.path.name,
            'radiusX': m.radiusX,
            'radiusY': m.radiusY,
            'period': m.period,
            'phase': m.phase,
          },
        },
      },
  ],
  'spiders': [
    for (final s in level.spiders)
      {
        'x': s.x,
        'y': s.y,
        'zoneRadius': s.zoneRadius,
        'phase': s.phase,
        'chaseSpeed': s.chaseSpeed,
        'bodyRadius': s.bodyRadius,
      },
  ],
  'hazards': [
    for (final h in level.hazards)
      {
        'kind': h.kind.name,
        'warningSeconds': h.warningSeconds,
        'liveSeconds': h.liveSeconds,
        'motion': h.motion.name,
        'orientation': h.orientation.name,
        'radiusX': h.radiusX,
        'radiusY': h.radiusY,
        'period': h.period,
        'phase': h.phase,
        'positions': [
          for (final p in h.positions) {'target': p.target, 'x': p.x, 'y': p.y},
        ],
      },
  ],
  'finaleTitle': level.finaleTitle,
  'finaleRule': level.finaleRule,
  'firstHazardAfter': level.firstHazardAfter,
  'hazardInterval': level.hazardInterval,
};
