// Shared by the developer UI and its Node tests. No game import uses this file.
(function (root) {
  'use strict';
  const clone = value => JSON.parse(JSON.stringify(value));
  const waveDefaults = {motion: 'legacy', orientation: 'vertical', radiusX: 40, radiusY: 25, period: 4, phase: 0};
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
    if (!d.holes.every(h => finite(h, ['x', 'y', 'target'])) ||
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
  function validate(d) {
    const errors = [], warnings = [];
    try { d = parseDraft(JSON.stringify(d)); } catch (e) { return {errors: [e.message], warnings}; }
    if (!d.name.trim()) errors.push('Give this level a name.');
    const targets = d.holes.filter(h => h.target > 0);
    for (let n = 1; n <= 10; n++) {
      const count = targets.filter(h => h.target === n).length;
      if (count !== 1) errors.push(count ? `Target ${n} appears more than once.` : `Place target ${n}.`);
    }
    for (const h of d.holes) {
      if (!Number.isInteger(h.target) || h.target < 0 || h.target > 10) errors.push('Hole targets must be 0 (trap) or 1–10.');
      if (h.x < 24 || h.x > 336 || h.y < 24 || h.y > 490) errors.push('Keep holes inside x 24–336 and y 24–490.');
    }
    for (let i = 0; i < d.holes.length; i++) for (let j = i + 1; j < d.holes.length; j++) {
      if (Math.hypot(d.holes[i].x - d.holes[j].x, d.holes[i].y - d.holes[j].y) < 28)
        errors.push(`Holes ${i + 1} and ${j + 1} overlap or leave too little clearance.`);
    }
    for (const s of d.spiders) {
      if (s.x < 24 || s.x > 336 || s.y < 24 || s.y > 490 || s.zoneRadius < 10 ||
          s.zoneRadius > 150 || s.chaseSpeed <= 0 || s.bodyRadius < 1 || s.bodyRadius > 30)
        errors.push('Check spider bounds, radius and speed.');
      if (targets.some(h => Math.hypot(h.x - s.x, h.y - s.y) < s.zoneRadius + 24))
        warnings.push('A spider territory is close to a numbered target.');
    }
    for (const [i, w] of d.hazards.entries()) {
      if (w.period <= 0 || w.radiusX < 0 || w.radiusY < 0 || w.radiusX > 150 || w.radiusY > 200)
        errors.push(`Wave ${i + 1} needs a positive period and valid movement radii.`);
      if (w.warningSeconds <= 0 || w.liveSeconds <= 0) errors.push(`Wave ${i + 1} needs positive warning and active times.`);
      if (!w.positions.length) errors.push(`Wave ${i + 1} has no positions. Add one or delete the wave.`);
      for (const p of w.positions) {
        if (!Number.isInteger(p.target) || p.target < 1 || p.target > 10 ||
            p.x < 24 || p.x > 336 || p.y < 24 || p.y > 490) errors.push(`Check wave ${i + 1} target numbers and coordinates.`);
        const h = targets.find(h => h.target === p.target);
        const rx = ['horizontal', 'circle', 'oval'].includes(w.motion) ? w.radiusX : 0;
        const ry = w.motion === 'circle' ? w.radiusX : ['vertical', 'oval'].includes(w.motion) ? w.radiusY : 0;
        if (w.motion !== 'legacy' && (p.x-rx<24 || p.x+rx>336 || p.y-ry<24 || p.y+ry>490))
          errors.push(`Wave ${i + 1} movement leaves the board. Move its center or reduce its radii.`);
        if (h && (w.kind === 'laser' ?
          (w.orientation === 'horizontal' ? Math.abs(h.y-p.y)<=32+ry : Math.abs(h.x-p.x)<=32+rx) :
          Math.hypot(Math.max(0,Math.abs(h.x-p.x)-rx), Math.max(0,Math.abs(h.y-p.y)-ry))<=32))
          warnings.push(`Wave ${i + 1} is close to target ${p.target}.`);
      }
    }
    if (d.firstHazardAfter < 0 || d.hazardInterval <= 0) errors.push('First hazard delay must be nonnegative; repeat interval must be positive.');
    if (d.hazards.length && !d.finaleTitle.trim()) warnings.push('Add a briefing title and rule to introduce the hazards.');
    return {errors: [...new Set(errors)], warnings: [...new Set(warnings)]};
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
    for (const h of d.holes) lines.push(`    Hole(${num(h.x)}, ${num(h.y)}${h.target ? `, target: ${h.target}` : ''}),`);
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
  const api = {blank, clone, parseDraft, validate, exportDart, waveDefaults};
  if (typeof module !== 'undefined') module.exports = api;
  else root.LevelModel = api;
})(globalThis);
