// Developer-only entry point. Nothing under lib/ imports this tool.
import 'dart:convert';
import 'dart:io';
import '../lib/classic_levels.dart';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8765 : int.parse(args.first);
  final root = File.fromUri(Platform.script).parent;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  final levels = jsonEncode([
    for (var i = 0; i < classicLevelDefinitions.length; i++)
      _json(i + 1, classicLevelDefinitions[i]),
  ]);
  stdout.writeln('GILT Level Builder: http://127.0.0.1:${server.port}');
  stdout.writeln('Developer tool only. Press Ctrl+C to stop.');
  await for (final request in server) {
    request.response.headers.set('Cache-Control', 'no-store');
    request.response.headers.set('X-Content-Type-Options', 'nosniff');
    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
    } else if (request.uri.path == '/api/levels') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(levels);
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

Map<String, Object> _json(int number, ClassicLevelDefinition level) => {
  'version': 1,
  'number': number,
  'name': level.name,
  'holes': [
    for (final h in level.holes) {'x': h.x, 'y': h.y, 'target': h.target},
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
