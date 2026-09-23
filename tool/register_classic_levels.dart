import 'dart:io';

/// Registers exported files without renumbering or rewriting any level.
void main(List<String> args) {
  final project = args.isEmpty ? Directory.current : Directory(args.single);
  final directory = Directory('${project.path}/lib/classic_levels');
  final registry = File('${project.path}/lib/classic_levels.dart');
  final files = <int, String>{};
  for (final file in directory.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    final match = RegExp(r'^level_(\d+)\.dart$').firstMatch(name);
    if (match == null) continue;
    final number = int.parse(match[1]!);
    final id = number.toString().padLeft(2, '0');
    if (number < 1 || files.containsKey(number) || name != 'level_$id.dart') {
      throw FormatException('Invalid or duplicate level filename: $name');
    }
    final source = file.readAsStringSync();
    if (!source.contains("part of '../classic_levels.dart';") ||
        !RegExp(
          'const\\s+classicLevel$id\\s*=\\s*ClassicLevelDefinition\\(',
        ).hasMatch(source)) {
      throw FormatException(
        '$name must declare const classicLevel$id and be part of ../classic_levels.dart.',
      );
    }
    files[number] = name;
  }
  if (files.isEmpty) throw StateError('No level files found.');
  final numbers = files.keys.toList()..sort();
  for (var i = 0; i < numbers.length; i++) {
    if (numbers[i] != i + 1)
      throw StateError('Missing level ${i + 1}. Levels must be consecutive.');
  }
  var source = registry.readAsStringSync();
  final parts = RegExp(r"part 'classic_levels/level_\d+\.dart';");
  final matches = parts.allMatches(source).toList();
  if (matches.isEmpty)
    throw StateError('Registry part declarations not found.');
  source = source.replaceRange(
    matches.first.start,
    matches.last.end,
    numbers.map((n) => "part 'classic_levels/${files[n]}';").join('\n'),
  );
  final list = RegExp(r'const classicLevelDefinitions = \[[\s\S]*?\];');
  if (!list.hasMatch(source)) throw StateError('Registry list not found.');
  source = source.replaceFirst(
    list,
    'const classicLevelDefinitions = [\n'
    '${numbers.map((n) => '  classicLevel${n.toString().padLeft(2, '0')},').join('\n')}\n];',
  );
  registry.writeAsStringSync(source);
  stdout.writeln(
    'Registered ${numbers.length} Classic levels. Existing level IDs are unchanged.',
  );
}
