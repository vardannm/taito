// Shared by the developer UI and its Node tests. No game import uses this file.
(function (root) {
  'use strict';
  const clone = value => JSON.parse(JSON.stringify(value));
  const waveDefaults = {motion: 'legacy', orientation: 'vertical', radiusX: 40, radiusY: 25, period: 4, phase: 0};
  // Hole size is a diameter multiple of a normal hole; motion is null or a path around its home.
  const holeSize = {min: .2, max: 2.5}, rimRadius = 12.8;
  // Size scales only the opening (10.4 at 1×); the 2.4-unit brass rim stays the same (Hole.reach in lib/game.dart).
  const holeRim = size => 10.4 * size + 2.4;
  const holePaths = ['horizontal', 'vertical', 'circle', 'oval'];
  const holeMotionDefaults = {path: 'horizontal', radiusX: 40, radiusY: 25, period: 4, phase: 0};
  // A breathing hole grows and shrinks between two sizes for the whole level (HolePulse in lib/game.dart).
  const holePulseDefaults = {minSize: .5, maxSize: 1.5, period: 3, phase: 0};
  const holeSizeAt = (h, seconds) => !h.pulse ? h.size : h.pulse.minSize +
    (h.pulse.maxSize - h.pulse.minSize) * (1 - Math.cos(h.pulse.phase + seconds * Math.PI * 2 / h.pulse.period)) / 2;
  const largestSize = h => h.pulse ? Math.max(h.pulse.minSize, h.pulse.maxSize) : h.size;
  // Matches HoleMotion.extent / offset in lib/game.dart.
  const holeExtent = m => !m ? 0 : m.path === 'vertical' ? m.radiusY : m.path === 'oval' ? Math.max(m.radiusX, m.radiusY) : m.radiusX;
  function holeAt(h, seconds) {
    const m = h.motion; if (!m) return {x: h.x, y: h.y};
    const a = m.phase + seconds * Math.PI * 2 / m.period;
    if (m.path === 'horizontal') return {x: h.x + m.radiusX * Math.sin(a), y: h.y};
    if (m.path === 'vertical') return {x: h.x, y: h.y + m.radiusY * Math.sin(a)};
    return {x: h.x + m.radiusX * Math.cos(a), y: h.y + (m.path === 'circle' ? m.radiusX : m.radiusY) * Math.sin(a)};
  }
  // Ball resting at the launch point, matching BalanceGame.launchHeight - ballRadius.
  const launch = {x: 180, y: 493};
  function blank(number = 51) {
    return {version: 1, number, name: 'Untitled level', holes: [], spiders: [], hazards: [],
      finaleTitle: '', finaleRule: '', firstHazardAfter: 3, hazardInterval: 9};
  }
  function parseDraft(text) {
    const d = JSON.parse(text);
    if (!d || d.version !== 1 || !Number.isInteger(d.number) || d.number < 1 ||
        typeof d.name !== 'string' || !Array.isArray(d.holes) || !Array.isArray(d.spiders) ||
        !Array.isArray(d.hazards) || d.holes.length > 500 || d.spiders.length > 100 || d.hazards.length > 50) {
      throw Error('This is not a supported level-builder draft.');
    }
    const finite = (item, keys) => item && keys.every(k => typeof item[k] === 'number' && Number.isFinite(item[k]));
    d.hazards = d.hazards.map(w => ({...waveDefaults, ...w}));
    d.holes = d.holes.map(h => ({...h, size: h.size ?? 1, motion: h.motion ? {...holeMotionDefaults, ...h.motion} : null,
      pulse: h.pulse ? {...holePulseDefaults, ...h.pulse} : null}));
    if (!d.holes.every(h => finite(h, ['x', 'y', 'target', 'size']) &&
          (h.motion === null || (holePaths.includes(h.motion.path) && finite(h.motion, ['radiusX', 'radiusY', 'period', 'phase']))) &&
          (h.pulse === null || finite(h.pulse, ['minSize', 'maxSize', 'period', 'phase']))) ||
        !d.spiders.every(s => finite(s, ['x', 'y', 'zoneRadius', 'phase', 'chaseSpeed', 'bodyRadius'])) ||
        !d.hazards.every(w => ['laser', 'movingHole'].includes(w.kind) &&
          finite(w, ['warningSeconds', 'liveSeconds', 'radiusX', 'radiusY', 'period', 'phase']) &&
          ['legacy', 'stationary', 'horizontal', 'vertical', 'circle', 'oval'].includes(w.motion) &&
          ['vertical', 'horizontal'].includes(w.orientation) && Array.isArray(w.positions) &&
          w.positions.length <= 500 && w.positions.every(p => finite(p, ['x', 'y', 'target']))) ||
        !finite(d, ['firstHazardAfter', 'hazardInterval']) ||
        typeof d.finaleTitle !== 'string' || typeof d.finaleRule !== 'string') {
      throw Error('The draft contains invalid objects or numbers.');
    }
    return clone(d);
  }
  // Each issue lists the objects it is about, so the builder can select them:
  // {type: 'hole'|'spider', index}, {type: 'hazard', wave, index}, {type: 'wave', wave},
  // {type: 'field', id} for a level setting, or {type: 'tool', tool} for something to place.
  function validate(d) {
    const issues = new Map();
    const note = (level, text, refs) => {
      if (!issues.has(text)) issues.set(text, {level, text, refs: []});
      issues.get(text).refs.push(...refs);
    };
    const err = (text, ...refs) => note('error', text, refs), warn = (text, ...refs) => note('warn', text, refs);
    const hole = index => ({type: 'hole', index});
    try { d = parseDraft(JSON.stringify(d)); } catch (e) { return {errors: [e.message], warnings: [], issues: [{level: 'error', text: e.message, refs: []}]}; }
    if (!d.name.trim()) err('Give this level a name.', {type: 'field', id: 'name'});
    const targets = d.holes.filter(h => h.target > 0);
    for (let n = 1; n <= 10; n++) {
      const matches = [...d.holes.entries()].filter(([, h]) => h.target === n).map(([i]) => hole(i));
      if (matches.length > 1) err(`Target ${n} appears more than once.`, ...matches);
      else if (!matches.length) err(`Place target ${n}.`, {type: 'tool', tool: 'target'});
    }
    for (const [i, h] of d.holes.entries()) {
      if (!Number.isInteger(h.target) || h.target < 0 || h.target > 10) err('Hole targets must be 0 (trap) or 1–10.', hole(i));
      if (h.x < 24 || h.x > 336 || h.y < 24 || h.y > 490) err('Keep holes inside x 24–336 and y 24–490.', hole(i));
      if (h.size < holeSize.min || h.size > holeSize.max) err(`Hole size must be ${holeSize.min}–${holeSize.max} × a normal hole.`, hole(i));
      const p = h.pulse;
      if (p) {
        if ([p.minSize, p.maxSize].some(v => v < holeSize.min || v > holeSize.max))
          err(`Breathing sizes must be ${holeSize.min}–${holeSize.max} × a normal hole.`, hole(i));
        if (p.minSize >= p.maxSize) err('A breathing hole needs a smallest size below its biggest size.', hole(i));
        if (p.period <= 0) err('A breathing hole needs a positive number of seconds per breath.', hole(i));
      }
      const m = h.motion;
      if (m) {
        if (m.period <= 0 || m.radiusX < 0 || m.radiusY < 0 || m.radiusX > 150 || m.radiusY > 200)
          err('Moving holes need a positive period and radii up to 150 (horizontal) and 200 (vertical).', hole(i));
        const rx = m.path === 'vertical' ? 0 : m.radiusX, ry = m.path === 'horizontal' ? 0 : m.path === 'circle' ? m.radiusX : m.radiusY;
        if (h.x - rx < 24 || h.x + rx > 336 || h.y - ry < 24 || h.y + ry > 490)
          err('A moving hole leaves the board. Move its center or reduce its radii.', hole(i));
      }
      // The ball rests at the launch point before the first touch; never start inside a hole.
      if (Math.hypot(h.x - launch.x, h.y - launch.y) < 8.5 * largestSize(h) + holeExtent(m) + 9)
        (m || p ? warn : err)(m || p ? 'A moving or breathing hole reaches the ball’s starting spot.' : 'A hole covers the ball’s starting spot.', hole(i));
    }
    for (let i = 0; i < d.holes.length; i++) for (let j = i + 1; j < d.holes.length; j++) {
      const a = d.holes[i], b = d.holes[j], distance = Math.hypot(a.x - b.x, a.y - b.y);
      // 28 between two normal holes; sized holes scale their share of that clearance.
      const animated = a.motion || b.motion || a.pulse || b.pulse;
      if (!animated && distance < 14 * (a.size + b.size))
        err(`Holes ${i + 1} and ${j + 1} overlap or leave too little clearance.`, hole(i), hole(j));
      else if (animated && distance < holeRim(largestSize(a)) + holeRim(largestSize(b)) + holeExtent(a.motion) + holeExtent(b.motion))
        warn(`Holes ${i + 1} and ${j + 1} can overlap while they move or grow.`, hole(i), hole(j));
    }
    for (const [i, s] of d.spiders.entries()) {
      const spider = {type: 'spider', index: i};
      if (s.x < 24 || s.x > 336 || s.y < 24 || s.y > 490 || s.zoneRadius < 10 ||
          s.zoneRadius > 150 || s.chaseSpeed <= 0 || s.bodyRadius < 1 || s.bodyRadius > 30)
        err('Check spider bounds, radius and speed.', spider);
      const near = [...d.holes.entries()].filter(([, h]) => h.target > 0 && Math.hypot(h.x - s.x, h.y - s.y) < s.zoneRadius + 24);
      if (near.length) warn('A spider territory is close to a numbered target.', spider, ...near.map(([j]) => hole(j)));
    }
    for (const [i, w] of d.hazards.entries()) {
      const wave = {type: 'wave', wave: i};
      if (w.period <= 0 || w.radiusX < 0 || w.radiusY < 0 || w.radiusX > 150 || w.radiusY > 200)
        err(`Wave ${i + 1} needs a positive period and valid movement radii.`, wave);
      if (w.warningSeconds <= 0 || w.liveSeconds <= 0) err(`Wave ${i + 1} needs positive warning and active times.`, wave);
      if (!w.positions.length) err(`Wave ${i + 1} has no positions. Add one or delete the wave.`, wave);
      for (const [j, p] of w.positions.entries()) {
        const position = {type: 'hazard', wave: i, index: j};
        if (!Number.isInteger(p.target) || p.target < 1 || p.target > 10 ||
            p.x < 24 || p.x > 336 || p.y < 24 || p.y > 490) err(`Check wave ${i + 1} target numbers and coordinates.`, position);
        const target = d.holes.findIndex(h => h.target > 0 && h.target === p.target), h = d.holes[target];
        const rx = ['horizontal', 'circle', 'oval'].includes(w.motion) ? w.radiusX : 0;
        const ry = w.motion === 'circle' ? w.radiusX : ['vertical', 'oval'].includes(w.motion) ? w.radiusY : 0;
        if (w.motion !== 'legacy' && (p.x-rx<24 || p.x+rx>336 || p.y-ry<24 || p.y+ry>490))
          err(`Wave ${i + 1} movement leaves the board. Move its center or reduce its radii.`, position);
        if (h && (w.kind === 'laser' ?
          (w.orientation === 'horizontal' ? Math.abs(h.y-p.y)<=32+ry : Math.abs(h.x-p.x)<=32+rx) :
          Math.hypot(Math.max(0,Math.abs(h.x-p.x)-rx), Math.max(0,Math.abs(h.y-p.y)-ry))<=32))
          warn(`Wave ${i + 1} is close to target ${p.target}.`, position, hole(target));
      }
    }
    if (d.firstHazardAfter < 0 || d.hazardInterval <= 0)
      err('First hazard delay must be nonnegative; repeat interval must be positive.', {type: 'field', id: d.firstHazardAfter < 0 ? 'firstHazardAfter' : 'hazardInterval'});
    if (d.hazards.length && !d.finaleTitle.trim()) warn('Add a briefing title and rule to introduce the hazards.', {type: 'field', id: 'finaleTitle'});
    const list = [...issues.values()];
    return {errors: list.filter(i => i.level === 'error').map(i => i.text), warnings: list.filter(i => i.level === 'warn').map(i => i.text), issues: list};
  }
  const num = value => Number.isInteger(value) ? String(value) : String(value);
  // JSON quoting plus Dart interpolation escaping; never insert raw draft text as code.
  const str = value => JSON.stringify(value).replace(/\$/g, '\\$').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
  function exportDart(d) {
    d = parseDraft(JSON.stringify(d));
    const result = validate(d);
    if (result.errors.length) throw Error(result.errors.join('\n'));
    const id = String(d.number).padStart(2, '0');
    const lines = ["part of '../classic_levels.dart';", '', `// Classic level ${d.number}. Coordinates use the 360 x 560 board.`,
      `const classicLevel${id} = ClassicLevelDefinition(`, `  name: ${str(d.name)},`, '  holes: ['];
    for (const h of d.holes) {
      const named = [];
      if (h.target) named.push(`target: ${h.target}`);
      if (h.size !== 1 && !h.pulse) named.push(`size: ${num(h.size)}`);
      if (h.motion) named.push(`motion: HoleMotion(path: HazardMotion.${h.motion.path}, radiusX: ${num(h.motion.radiusX)}, ` +
        `radiusY: ${num(h.motion.radiusY)}, period: ${num(h.motion.period)}, phase: ${num(h.motion.phase)})`);
      if (h.pulse) named.push(`pulse: HolePulse(minSize: ${num(h.pulse.minSize)}, maxSize: ${num(h.pulse.maxSize)}, ` +
        `period: ${num(h.pulse.period)}, phase: ${num(h.pulse.phase)})`);
      lines.push(`    Hole(${[num(h.x), num(h.y), ...named].join(', ')}),`);
    }
    lines.push('  ],', '  spiders: [');
    for (const s of d.spiders) lines.push('    ClassicSpiderPlacement(',
      ...['x', 'y', 'zoneRadius', 'phase', 'chaseSpeed', 'bodyRadius'].map(k => `      ${k}: ${num(s[k])},`), '    ),');
    lines.push('  ],', `  finaleTitle: ${str(d.finaleTitle)},`, `  finaleRule: ${str(d.finaleRule)},`, '  hazards: [');
    for (const w of d.hazards) {
      lines.push('    ClassicHazardWave(', `      kind: HazardKind.${w.kind},`,
        `      motion: HazardMotion.${w.motion},`, `      orientation: LaserOrientation.${w.orientation},`,
        `      radiusX: ${num(w.radiusX)},`, `      radiusY: ${num(w.radiusY)},`,
        `      period: ${num(w.period)},`, `      phase: ${num(w.phase)},`,
        `      warningSeconds: ${num(w.warningSeconds)},`, `      liveSeconds: ${num(w.liveSeconds)},`, '      positions: [');
      for (const p of w.positions) lines.push(`        ClassicHazardPosition(target: ${p.target}, x: ${num(p.x)}, y: ${num(p.y)}),`);
      lines.push('      ],', '    ),');
    }
    lines.push('  ],', `  firstHazardAfter: ${num(d.firstHazardAfter)},`, `  hazardInterval: ${num(d.hazardInterval)},`, ');', '');
    return lines.join('\n');
  }
  const api = {blank, clone, parseDraft, validate, exportDart, waveDefaults, holeSize, holePaths, holeMotionDefaults, holeAt, rimRadius, holeRim, holePulseDefaults, holeSizeAt, largestSize};
  if (typeof module !== 'undefined') module.exports = api;
  else root.LevelModel = api;
})(globalThis);
