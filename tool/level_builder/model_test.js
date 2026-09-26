'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const M = require('./model.js');

(async () => {
  const levels = await (await fetch('http://127.0.0.1:8765/api/levels')).json();
  assert.ok(levels.length >= 80);
  for (const d of levels) {
    assert.deepEqual(M.validate(d).errors, [], `Level ${d.number}`);
    assert.deepEqual(M.parseDraft(JSON.stringify(d)), d);
    assert.match(M.exportDart(d), /const classicLevel\d+ = ClassicLevelDefinition/);
  }
  const invalid = M.clone(levels[0]); invalid.holes[0].target = 2;
  assert.throws(() => M.exportDart(invalid), /Target 2 appears/);
  invalid.holes[0].x = NaN; assert.throws(() => M.parseDraft(JSON.stringify(invalid)), /invalid/);
  assert.throws(() => M.parseDraft('{"version":100}'), /supported/);

  const root = path.resolve(__dirname, '../..');
  const fixture = fs.mkdtempSync(path.join(root, '.dart_tool/builder-test-'));
  fs.cpSync(path.join(root, 'lib'), path.join(fixture, 'lib'), {recursive: true});
  // Export every existing level, plus a new one, and compile the real game against them.
  for (const d of levels) fs.writeFileSync(path.join(fixture, `lib/classic_levels/level_${String(d.number).padStart(2, '0')}.dart`), M.exportDart(d));
  const next = M.clone(levels[49]); next.number = levels.length + 1;
  next.name = 'A "quoted" $level \\ path\nSecond line — café';
  next.finaleRule = 'Literal ${notDartCode} and apostrophe\'s';
  fs.writeFileSync(path.join(fixture, `lib/classic_levels/level_${next.number}.dart`), M.exportDart(next));
  fs.writeFileSync(path.join(fixture, 'expected.json'), JSON.stringify(next));
  const dart = path.join(root, '.tools/flutter/bin/cache/dart-sdk/bin/dart.exe');
  const run = args => {
    const result = spawnSync(dart, args, {cwd: root, encoding: 'utf8'});
    assert.equal(result.status, 0, result.stdout + result.stderr);
    return result.stdout;
  };
  run(['tool/register_classic_levels.dart', fixture]);
  fs.writeFileSync(path.join(fixture, 'check.dart'), `
import 'dart:io';
import 'dart:convert';
import 'lib/game.dart';
import 'lib/levels.dart';
void main() {
  final expected = jsonDecode(File.fromUri(Platform.script.resolve('expected.json')).readAsStringSync());
  if (ClassicLevels.count != ${next.number} || ClassicLevels.names.last != expected['name']) throw StateError('Registration or escaping failed');
  final game = BalanceGame()..start(levelNumber: ${next.number});
  if (game.level != ${next.number} || game.spiders.length != 3 || !game.finale) throw StateError('New level is not playable');
  if (ClassicLevels.definition(${next.number}).finaleRule != expected['finaleRule']) throw StateError('String escaping failed');
  for (var n = 1; n <= ${next.number}; n++) {
    final board = ClassicLevels.build(n);
    if (board.where((h) => h.target > 0).length != 10) throw StateError('Export lost targets');
  }
  print('Exported Dart compiles; the next level is registered and playable.');
}
`);
  process.stdout.write(run([path.join(fixture, 'check.dart')]));
  const before = fs.readFileSync(path.join(fixture, 'lib/classic_levels.dart'), 'utf8');
  const gap = {...next, number: next.number + 2};
  fs.writeFileSync(path.join(fixture, `lib/classic_levels/level_${gap.number}.dart`), M.exportDart(gap));
  const rejected = spawnSync(dart, ['tool/register_classic_levels.dart', fixture], {cwd: root, encoding: 'utf8'});
  assert.notEqual(rejected.status, 0);
  assert.ok(rejected.stderr.includes(`Missing level ${next.number + 1}`));
  assert.equal(fs.readFileSync(path.join(fixture, 'lib/classic_levels.dart'), 'utf8'), before);
  console.log(`${levels.length} preset round trips, validation, safe Dart escaping, registration and gap rejection passed.`);
})().catch(error => { console.error(error); process.exitCode = 1; });
