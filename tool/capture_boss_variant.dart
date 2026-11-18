import 'dart:io';
import '../lib/capture_run.dart';
import '../lib/infinite_boss.dart';

/// Resimulate existing inputs against a different boss; never reuse the old
/// checkpoints or suppress divergence checking on the resulting take.
void main(List<String> args) {
  try {
    if (args.length != 3) {
      stderr.writeln(
        'Usage: dart run tool/capture_boss_variant.dart input.json output.json venomCrown',
      );
      exitCode = 64;
      return;
    }
    final source = CaptureFile.decode(File(args[0]).readAsStringSync());
    if (source.setup.level != null) {
      throw const FormatException(
        'Boss variants require an Infinite recording.',
      );
    }
    CapturePlayer(source).verify();
    final s = source.setup;
    final kind = BossKind.values.byName(args[2]);
    final recorder = CaptureRecorder(
      CaptureSetup(
        ball: s.ball,
        platform: s.platform,
        cabinet: s.cabinet,
        hearts: s.hearts,
        shieldSeconds: s.shieldSeconds,
        magnetSeconds: s.magnetSeconds,
        firstBoss: kind,
      ),
    );
    source.geometry.apply(recorder.game);
    var command = 0;
    var seenBoss = false, cleared = false;
    for (var tick = 0; tick < source.ticks && !recorder.stopped; tick++) {
      while (command < source.commands.length &&
          source.commands[command].tick == tick) {
        final c = source.commands[command++];
        if (c.name == 'clear') {
          recorder.clearControls();
        } else {
          c.apply(recorder.game);
        }
      }
      recorder.step();
      if (!seenBoss && recorder.game.boss != null) {
        seenBoss = true;
        stdout.writeln(
          'First boss ${recorder.game.boss!.kind.name} at ${(recorder.ticks / captureHz).toStringAsFixed(2)}s',
        );
      }
      if (!cleared && recorder.game.bossesCleared > 0) {
        cleared = true;
        stdout.writeln(
          'Boss cleared at ${(recorder.ticks / captureHz).toStringAsFixed(2)}s with ${recorder.game.lives} hearts',
        );
      }
      recorder.game.event = null;
    }
    if (!seenBoss)
      throw const FormatException('Inputs ended before the requested boss.');
    if (!cleared)
      throw const FormatException(
        'These inputs do not survive the requested boss. Record a new take.',
      );
    final result = recorder.snapshot();
    result.summary['variant'] =
        'Original inputs resimulated with ${kind.name} first';
    CapturePlayer(result).verify();
    File(args[1]).writeAsStringSync(result.encode());
    stdout.writeln(
      'Verified new take: ${result.summary}; ${result.checkpoints.length} checkpoints.',
    );
  } catch (e) {
    stderr.writeln('Variant rejected: $e');
    exitCode = 1;
  }
}
