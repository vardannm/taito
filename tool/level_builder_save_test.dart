import 'dart:convert';
import 'dart:io';
import 'level_builder.dart' as builder;

Future<void> main() async {
  final temp = Directory('artifacts').createTempSync('builder-save-');
  try {
    for (final folder in ['lib/classic_levels', 'tool/level_builder']) {
      Directory('${temp.path}/$folder').createSync(recursive: true);
      for (final file in Directory(folder).listSync().whereType<File>()) {
        file.copySync('${temp.path}/$folder/${file.uri.pathSegments.last}');
      }
    }
    File(
      'lib/classic_levels.dart',
    ).copySync('${temp.path}/lib/classic_levels.dart');
    final original = File(
      '${temp.path}/lib/classic_levels/level_01.dart',
    ).readAsStringSync();
    final draft = {
      'version': 1,
      'number': 1,
      'name': 'Save integration check',
      'holes': [
        for (var i = 1; i <= 10; i++)
          {'x': i.isOdd ? 70 : 290, 'y': 500 - i * 40, 'target': i},
      ],
      'spiders': [],
      'hazards': [],
      'finaleTitle': '',
      'finaleRule': '',
      'firstHazardAfter': 3,
      'hazardInterval': 9,
    };
    await builder.saveLevel(temp, jsonEncode(draft));
    final saved = File(
      '${temp.path}/lib/classic_levels/level_01.dart',
    ).readAsStringSync();
    if (!saved.contains('Save integration check'))
      throw StateError('Existing level not saved');
    final backup = Directory(
      '${temp.path}/artifacts/level-builder-backups',
    ).listSync().whereType<File>().single;
    if (backup.readAsStringSync() != original)
      throw StateError('Backup differs');
    for (final invalid in [
      {...draft, 'holes': []},
      {...draft, 'number': 999},
    ]) {
      try {
        await builder.saveLevel(temp, jsonEncode(invalid));
        throw StateError('Invalid draft accepted');
      } on FormatException {
        /* expected */
      }
    }
    if (File(
          '${temp.path}/lib/classic_levels/level_01.dart',
        ).readAsStringSync() !=
        saved) {
      throw StateError('Rejected save changed source');
    }
    final count = Directory('${temp.path}/lib/classic_levels')
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'level_\d+\.dart$').hasMatch(f.path))
        .length;
    await builder.saveLevel(temp, jsonEncode({...draft, 'number': count + 1}));
    if (!File(
      '${temp.path}/lib/classic_levels.dart',
    ).readAsStringSync().contains('classicLevel${count + 1},')) {
      throw StateError('New level not registered');
    }
    stdout.writeln(
      'PASS: overwrite, backup, validation rejection, gap rejection and new-level registration',
    );
  } finally {
    temp.deleteSync(recursive: true);
  }
}
