import 'dart:convert';
import 'dart:io';
import '../lib/capture_run.dart';

void main(List<String> args) {
  try {
    if (args.length != 2 || !['verify', 'prepare'].contains(args[0])) {
      stderr.writeln(
        'Usage: dart run tool/capture_replay.dart verify|prepare capture.json',
      );
      exitCode = 64;
      return;
    }
    final file = CaptureFile.decode(File(args[1]).readAsStringSync());
    final player = CapturePlayer(file)..verify();
    stdout.writeln(
      'Verified ${file.commands.length} inputs, ${file.ticks} ticks, '
      '${file.checkpoints.length} checkpoints. ${file.summary}',
    );
    stdout.writeln('Final state: ${captureFingerprint(player.game)}');
    if (args[0] == 'prepare') {
      final encoded = base64Encode(utf8.encode(file.encode()));
      File('lib/capture_replay_data.dart').writeAsStringSync(
        '// Generated from a validated capture. Temporary App Store capture only.\n'
        "const bundledCaptureReplay = '$encoded';\n",
      );
      stdout.writeln(
        'Replay bundled. Run flutter run -t lib/capture_main.dart -d DEVICE_UUID',
      );
    }
  } catch (error) {
    stderr.writeln('Capture rejected: $error');
    exitCode = 1;
  }
}
