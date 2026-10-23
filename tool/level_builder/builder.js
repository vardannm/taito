(async function () {
  'use strict';
  const M = LevelModel, $ = id => document.getElementById(id);
  const canvas = $('board'), ctx = canvas.getContext('2d');
  let presets = [], draft, selection = null, tool = 'target', waveIndex = -1, filter = 0;
  let undo = [], redo = [], drag = null, toastTimer;
  // viewing: number of a level shown read-only; stash keeps the real draft meanwhile.
  // baseline: {source, snapshot} of the draft as last opened or saved, for unsaved-change checks.
  let viewing = null, stash = null, baseline = null;
  // The level-check message last clicked, which of its objects is shown, and a brief board highlight.
  let activeIssue = null, highlight = null;
  const storageKey = 'gilt-developer-level-builder-v1', baselineKey = `${storageKey}-baseline`;
  const icons = {
    eye: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>',
    pencil: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/><path d="M14.5 5.5l3 3"/></svg>',
  };
  try {
    const response = await fetch('/api/levels');
    if (!response.ok) throw Error('Could not load built-in levels.');
    presets = await response.json();
  } catch (e) { toast(e.message); }
  const nextNumber = () => Math.max(0, ...presets.map(p => p.number)) + 1;
  try { draft = M.parseDraft(localStorage.getItem(storageKey)); }
  catch (_) { draft = M.blank(nextNumber()); }
  try { baseline = JSON.parse(localStorage.getItem(baselineKey)); } catch (_) {}
  if (draft.hazards.length) waveIndex = 0;
  // Key-sorted JSON with wave defaults filled, so the inspector's default-filling doesn't count as an edit.
  const snapshot = d => JSON.stringify({...d, holes: d.holes.map(h => ({size: 1, motion: null, pulse: null, ...h})), hazards: d.hazards.map(w => ({...M.waveDefaults, ...w}))},
    (_, v) => v && typeof v === 'object' && !Array.isArray(v) ? Object.fromEntries(Object.keys(v).sort().map(k => [k, v[k]])) : v);
  const working = () => viewing ? stash.draft : draft;
  function unsaved() {
    const d = working();
    return d.holes.length + d.spiders.length + d.hazards.length > 0 && snapshot(d) !== baseline?.snapshot;
  }
  function markClean(source = baseline?.source ?? null) {
    baseline = {source, snapshot: snapshot(draft)};
    try { localStorage.setItem(baselineKey, JSON.stringify(baseline)); } catch (_) {}
  }

  const tools = [['select', '↖', 'Select'], ['target', '①', 'Target'], ['trap', '●', 'Trap hole'],
    ['spider', '✳', 'Spider'], ['laser', '↕', 'Laser'], ['movingHole', '↔', 'Moving hole'], ['erase', '×', 'Erase']];
  for (const [id, icon, label] of tools) {
    const button = document.createElement('button'); button.className = 'tool'; button.dataset.tool = id;
    const symbol = document.createElement('span'); symbol.textContent = icon;
    button.append(symbol, document.createTextNode(label)); button.onclick = () => {tool = id; refreshTools();};
    $('tools').append(button);
  }
  for (let i = 1; i <= 10; i++) $('filter').add(new Option(`Target ${i}`, i));
  function toast(message) {
    $('toast').textContent = message; $('toast').classList.add('show');
    clearTimeout(toastTimer); toastTimer = setTimeout(() => $('toast').classList.remove('show'), 3500);
  }
  function remember() { undo.push(M.clone(draft)); if (undo.length > 100) undo.shift(); redo = []; }
  function change(action) { remember(); action(); render(); }
  function restore(stack, other) {
    if (!stack.length) return;
    other.push(M.clone(draft)); draft = stack.pop(); selection = null;
    waveIndex = Math.min(waveIndex, draft.hazards.length - 1); render();
  }
  function replaceDraft(next, source = null) { remember(); draft = next; selection = null; waveIndex = draft.hazards.length ? 0 : -1; filter = 0; $('filter').value = '0'; markClean(source); render(); }
  function view(level) {
    if (!viewing) stash = {draft, waveIndex, selection};
    viewing = level.number; draft = M.clone(level); selection = null; waveIndex = draft.hazards.length ? 0 : -1;
    $('open-dialog').close(); render();
  }
  function leaveView() {
    if (!viewing) return;
    ({draft, waveIndex, selection} = stash); viewing = null; stash = null; render();
  }
  function edit(level) {
    $('open-dialog').close();
    if (baseline?.source === level.number && working().number === level.number) { leaveView(); toast(`Already editing level ${level.number}`); return; }
    if (unsaved() && !confirm(`Your draft (level ${working().number}) has unsaved changes. Discard them and edit level ${level.number}?`)) return;
    leaveView(); replaceDraft(M.clone(level), level.number); toast(`Editing level ${level.number}`);
  }
  function levelList() {
    $('level-list').replaceChildren();
    for (const p of presets) {
      const row = document.createElement('div'), name = document.createElement('span');
      const editing = !viewing && baseline?.source === p.number && draft.number === p.number;
      row.className = 'level-row'; row.classList.toggle('viewing', viewing === p.number); row.classList.toggle('editing', editing);
      name.className = 'level-name'; name.textContent = `${String(p.number).padStart(2, '0')} · ${p.name}`;
      if (viewing === p.number || editing) { const badge = document.createElement('em'); badge.textContent = editing ? 'Editing' : 'Viewing'; name.append(badge); }
      row.append(name);
      for (const [icon, label, action] of [['eye', 'View', view], ['pencil', 'Edit', edit]]) {
        const button = document.createElement('button'); button.className = 'icon'; button.innerHTML = icons[icon];
        button.title = `${label} level ${p.number}`; button.setAttribute('aria-label', button.title); button.onclick = () => action(p); row.append(button);
      }
      $('level-list').append(row);
    }
  }
  function selectedObject() {
    if (!selection) return null;
    if (selection.type === 'hole') return draft.holes[selection.index];
    if (selection.type === 'spider') return draft.spiders[selection.index];
    return draft.hazards[selection.wave]?.positions[selection.index];
  }
  function labelFor(ref) {
    if (ref.type === 'hole') {
      const h = draft.holes[ref.index], size = h.size ?? 1;
      const sizeText = h.pulse ? ` · ${h.pulse.minSize}–${h.pulse.maxSize}×` : size !== 1 ? ` · ${size}×` : '';
      return `${h.motion ? 'moving ' : ''}${h.pulse ? 'breathing ' : ''}${h.target ? `target ${h.target}` : 'trap hole'}${sizeText}`.replace(/^./, c => c.toUpperCase());
    }
    if (ref.type === 'spider') return `Spider ${ref.index + 1}`;
    const w = draft.hazards[ref.wave], p = w.positions[ref.index];
    return `${w.kind === 'laser' ? 'Laser' : 'Moving hole'} · target ${p.target}`;
  }
  function objects() {
    return [
      ...draft.holes.map((o, index) => ({type: 'hole', index, o})),
      ...draft.spiders.map((o, index) => ({type: 'spider', index, o})),
      ...draft.hazards.flatMap((w, wave) => w.positions.map((o, index) => ({type: 'hazard', wave, index, o}))),
    ];
  }
  const same = (a, b) => a && b && a.type === b.type && a.index === b.index && a.wave === b.wave;
  function deleteSelection() {
    if (!selectedObject()) return;
    change(() => {
      if (selection.type === 'hole') draft.holes.splice(selection.index, 1);
      else if (selection.type === 'spider') draft.spiders.splice(selection.index, 1);
      else draft.hazards[selection.wave].positions.splice(selection.index, 1);
      selection = null;
    });
  }
  function refreshTools() {
    for (const button of $('tools').children) { button.classList.toggle('active', !viewing && button.dataset.tool === tool); button.disabled = !!viewing; }
    canvas.style.cursor = viewing || tool === 'select' ? 'default' : 'crosshair';
  }
  function field(container, label, key, object, options = {}) {
    const wrap = document.createElement('label'); wrap.textContent = label;
    const input = document.createElement('input'); input.type = 'number'; input.value = object[key];
    input.step = options.step ?? '0.1'; if (options.min !== undefined) input.min = options.min;
    if (options.max !== undefined) input.max = options.max;
    input.onchange = () => {
      if (!input.value.trim() || !Number.isFinite(input.valueAsNumber)) { input.value = object[key]; return; }
      change(() => { object[key] = input.valueAsNumber; });
    };
    wrap.append(input); container.append(wrap);
  }
  function inspector() {
    const panel = $('inspector'); panel.replaceChildren();
    const object = selectedObject();
    $('selection-title').textContent = object ? labelFor(selection) : 'Nothing selected';
    $('selection-hint').hidden = !!object; $('delete').hidden = !object;
    if (object) {
      field(panel, selection.type === 'spider' ? 'Patrol center X' : 'X position', 'x', object, {min: 24, max: 336});
      field(panel, selection.type === 'spider' ? 'Patrol center Y' : 'Y position', 'y', object, {min: 24, max: 490});
      if (selection.type === 'hole') {
        field(panel, 'Target number (0 = trap)', 'target', object, {min: 0, max: 10, step: 1});
        holeSettings(panel, object);
      }
      if (selection.type === 'spider') {
        field(panel, 'Territory radius', 'zoneRadius', object, {min: 10, max: 150});
        field(panel, 'Chase speed', 'chaseSpeed', object, {min: 1});
        field(panel, 'Body radius', 'bodyRadius', object, {min: 1, max: 30});
        field(panel, 'Initial patrol angle (radians)', 'phase', object);
      }
      if (selection.type === 'hazard') field(panel, 'Active during target', 'target', object, {min: 1, max: 10, step: 1});
    }
    const wave = draft.hazards[selection?.type === 'hazard' ? selection.wave : waveIndex];
    if (wave) {
      const heading = document.createElement('div'); heading.className = 'section-title'; heading.textContent = 'ACTIVE WAVE SETTINGS'; panel.append(heading);
      const label = document.createElement('label'); label.textContent = 'Wave type';
      const select = document.createElement('select'); select.add(new Option('Laser', 'laser')); select.add(new Option('Moving hole', 'movingHole')); select.value = wave.kind;
      select.onchange = () => change(() => {wave.kind = select.value;}); label.append(select); panel.append(label);
      Object.assign(wave, {...M.waveDefaults, ...wave});
      for (const [key, title, choices] of [
        ['motion','Movement path',[['legacy','Original sway'],['stationary','Stationary'],['horizontal','Side to side'],['vertical','Up and down'],['circle','Circle'],['oval','Oval']]],
        ['orientation','Laser direction',[['vertical','Vertical beam'],['horizontal','Horizontal beam']]],
      ]) {
        if(key==='orientation' && wave.kind!=='laser')continue;
        const label=document.createElement('label');label.textContent=title;
        const input=document.createElement('select');for(const [value,text] of choices)input.add(new Option(text,value));input.value=wave[key];
        input.onchange=()=>change(()=>{wave[key]=input.value;});label.append(input);panel.append(label);
      }
      field(panel,'Horizontal radius','radiusX',wave,{min:0,max:150});
      field(panel,'Vertical radius (oval / vertical)','radiusY',wave,{min:0,max:200});
      field(panel,'Movement period (seconds)','period',wave,{min:.1});
      field(panel,'Starting angle (radians)','phase',wave);
      field(panel, 'Warning time (seconds)', 'warningSeconds', wave, {min: .1});
      field(panel, 'Active time (seconds)', 'liveSeconds', wave, {min: .1});
    }
    if (viewing) for (const control of panel.querySelectorAll('input,select')) control.disabled = true;
  }
  function holeSettings(panel, hole) {
    hole.size ??= 1; hole.motion ??= null; hole.pulse ??= null;
    const growLabel = document.createElement('label'); growLabel.textContent = 'Size over time';
    const grow = document.createElement('select');
    grow.add(new Option('Fixed size', 'fixed')); grow.add(new Option('Grow and shrink (whole level)', 'pulse'));
    grow.value = hole.pulse ? 'pulse' : 'fixed';
    grow.onchange = () => change(() => { hole.pulse = grow.value === 'pulse' ? {...M.holePulseDefaults} : null; });
    growLabel.append(grow); panel.append(growLabel);
    if (hole.pulse) {
      field(panel, `Smallest size (${M.holeSize.min}–${M.holeSize.max} × normal)`, 'minSize', hole.pulse, {min: M.holeSize.min, max: M.holeSize.max, step: .05});
      field(panel, `Biggest size (${M.holeSize.min}–${M.holeSize.max} × normal)`, 'maxSize', hole.pulse, {min: M.holeSize.min, max: M.holeSize.max, step: .05});
      field(panel, 'Seconds per grow-and-shrink', 'period', hole.pulse, {min: .1});
      field(panel, 'Starting angle (radians, 0 = smallest)', 'phase', hole.pulse);
    }
    const sizeLabel = document.createElement('label'); sizeLabel.textContent = `Hole size (${M.holeSize.min}–${M.holeSize.max} × normal)`;
    const row = document.createElement('div'); row.className = 'size-row';
    const range = document.createElement('input'); range.type = 'range'; range.min = M.holeSize.min; range.max = M.holeSize.max; range.step = '0.05'; range.value = hole.size;
    const exact = document.createElement('input'); exact.type = 'number'; exact.min = M.holeSize.min; exact.max = M.holeSize.max; exact.step = '0.05'; exact.value = hole.size;
    // Dragging previews live; one undo step is recorded when the drag ends.
    let before = null;
    range.oninput = () => { before ??= M.clone(draft); hole.size = range.valueAsNumber; exact.value = hole.size; draw(); };
    range.onchange = () => { if (before) { undo.push(before); redo = []; before = null; } render(); };
    exact.onchange = () => {
      if (!Number.isFinite(exact.valueAsNumber)) { exact.value = hole.size; return; }
      change(() => { hole.size = Math.round(Math.min(M.holeSize.max, Math.max(M.holeSize.min, exact.valueAsNumber)) * 100) / 100; });
    };
    row.append(range, exact); sizeLabel.append(row); if (!hole.pulse) growLabel.before(sizeLabel);
    const heading = document.createElement('div'); heading.className = 'section-title'; heading.textContent = 'MOVEMENT'; panel.append(heading);
    const label = document.createElement('label'); label.textContent = 'Movement path';
    const select = document.createElement('select');
    for (const [value, text] of [['none', 'Stationary'], ['horizontal', 'Side to side'], ['vertical', 'Up and down'], ['circle', 'Circle'], ['oval', 'Oval']]) select.add(new Option(text, value));
    select.value = hole.motion?.path ?? 'none';
    select.onchange = () => change(() => { hole.motion = select.value === 'none' ? null : {...M.holeMotionDefaults, ...hole.motion, path: select.value}; });
    label.append(select); panel.append(label);
    if (!hole.motion) return;
    if (hole.motion.path !== 'vertical') field(panel, 'Horizontal radius', 'radiusX', hole.motion, {min: 0, max: 150});
    if (['vertical', 'oval'].includes(hole.motion.path)) field(panel, 'Vertical radius', 'radiusY', hole.motion, {min: 0, max: 200});
    field(panel, 'Seconds per cycle', 'period', hole.motion, {min: .1});
    field(panel, 'Starting angle (radians)', 'phase', hole.motion);
    const hint = document.createElement('p'); hint.className = 'hint'; hint.textContent = 'X / Y above are the center of the path. Turn on Preview movement to watch it.'; panel.append(hint);
  }
  function validation() {
    const result = M.validate(draft); const box = $('validation'); box.replaceChildren();
    for (const [kind, items] of [['error', result.errors], ['warn', result.warnings]]) {
      if (!items.length) continue;
      const card = document.createElement('div'); card.className = `status ${kind}`;
      const title = document.createElement('strong'); title.textContent = `${items.length} ${kind === 'error' ? 'to fix' : 'to review'}`;
      const list = document.createElement('ul');
      for (const issue of result.issues.filter(i => i.level === kind)) {
        const li = document.createElement('li'); li.textContent = issue.text;
        if (issue.refs.length) {
          li.className = 'issue'; li.tabIndex = 0; li.setAttribute('role', 'button');
          li.title = issue.refs.length > 1 ? 'Click to show it on the board. Click again for the next one.' : 'Click to show it on the board.';
          li.classList.toggle('active', activeIssue?.text === issue.text);
          li.onclick = () => focusIssue(issue, li);
          li.onkeydown = e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); focusIssue(issue, li); } };
        }
        list.append(li);
      }
      card.append(title, list); box.append(card);
    }
    if (!result.errors.length) { const card = document.createElement('div'); card.className = 'status'; card.textContent = '✓ Ready to export'; box.prepend(card); }
    if (!viewing && presets.some(p => p.number === draft.number)) {
      const warning = document.createElement('p'); warning.className = 'hint'; warning.textContent = `Level ${draft.number} already exists. Use ${nextNumber()} to add a new level.`; box.append(warning);
    }
  }
  function refPoints(ref) {
    if (ref.type === 'hole') { const h = draft.holes[ref.index]; return h ? [{x: h.x, y: h.y, r: Math.max(18, M.holeRim(M.largestSize({size: 1, pulse: null, ...h})) + 6)}] : []; }
    if (ref.type === 'spider') { const s = draft.spiders[ref.index]; return s ? [{x: s.x, y: s.y, r: s.zoneRadius + 6}] : []; }
    if (ref.type === 'hazard') { const p = draft.hazards[ref.wave]?.positions[ref.index]; return p ? [{x: p.x, y: p.y, r: 14}] : []; }
    if (ref.type === 'wave') return (draft.hazards[ref.wave]?.positions ?? []).map(p => ({x: p.x, y: p.y, r: 14}));
    return [];
  }
  // Selects what a level-check message is about; repeated clicks step through its objects.
  function focusIssue(issue, item) {
    // The inspector above changes height as the selection changes; keep the clicked message under the pointer.
    const top = item.getBoundingClientRect().top;
    const keepInPlace = () => {
      const again = document.querySelector('#validation li.issue.active');
      if (again) window.scrollBy(0, again.getBoundingClientRect().top - top);
      again?.focus({preventScroll: true});
    };
    const step = activeIssue?.text === issue.text ? (activeIssue.step + 1) % issue.refs.length : 0;
    activeIssue = {text: issue.text, step};
    const ref = issue.refs[step];
    highlight = {points: issue.refs.flatMap(refPoints), until: performance.now() + 1600};
    if (ref.type === 'hole' || ref.type === 'spider' || ref.type === 'hazard') {
      selection = {...ref}; tool = 'select';
      if (ref.type === 'hazard') {
        waveIndex = ref.wave;
        const target = draft.hazards[ref.wave]?.positions[ref.index]?.target;
        if (filter && filter !== target) { filter = 0; $('filter').value = '0'; }
      }
      render(); keepInPlace();
    } else if (ref.type === 'wave') {
      waveIndex = ref.wave; selection = null; render(); keepInPlace();
    } else if (ref.type === 'field') {
      render(); const input = $(ref.id); input.closest('details')?.setAttribute('open', '');
      input.scrollIntoView({behavior: 'smooth', block: 'center'}); input.focus();
    } else if (ref.type === 'tool') {
      tool = ref.tool; selection = null; render(); keepInPlace(); toast('Click the board to place it.');
    }
  }
  function render() {
    for (const key of ['number', 'name', 'finaleTitle', 'finaleRule', 'firstHazardAfter', 'hazardInterval']) $(key).value = draft[key];
    $('file-name').textContent = `level_${String(draft.number).padStart(2, '0')}.dart`;
    $('undo').disabled = viewing || !undo.length; $('redo').disabled = viewing || !redo.length;
    for (const id of ['number', 'name', 'finaleTitle', 'finaleRule', 'firstHazardAfter', 'hazardInterval', 'snap', 'add-wave', 'delete', 'new', 'import', 'save', 'save-game']) $(id).disabled = !!viewing;
    document.body.classList.toggle('viewing', !!viewing); $('view-banner').hidden = !viewing;
    if (viewing) $('view-title').textContent = `Level ${viewing} · ${draft.name}`;
    $('wave').replaceChildren();
    if (!draft.hazards.length) $('wave').add(new Option('No waves yet', -1));
    draft.hazards.forEach((w, i) => $('wave').add(new Option(`${i + 1}. ${w.kind === 'laser' ? 'Laser' : 'Moving hole'} · ${w.positions.length} positions`, i)));
    $('wave').value = String(waveIndex); $('wave-up').disabled = viewing || waveIndex <= 0; $('delete-wave').disabled = viewing || waveIndex < 0;
    const all = objects(); $('objects').replaceChildren(); $('object-count').textContent = `(${all.length})`;
    for (const ref of all) {
      const button = document.createElement('button'); button.className = 'object-item'; button.classList.toggle('selected', !!same(selection, ref));
      const label = document.createElement('span'); label.textContent = labelFor(ref);
      const coord = document.createElement('span'); coord.textContent = `${Math.round(ref.o.x)}, ${Math.round(ref.o.y)}`;
      button.append(label, coord); button.onclick = () => {selection = ref; tool = 'select'; if(ref.type === 'hazard') waveIndex = ref.wave; render();};
      $('objects').append(button);
    }
    $('counts').textContent = `${draft.holes.filter(h => h.target).length}/10 targets · ${draft.holes.filter(h => !h.target).length} traps · ${draft.spiders.length} spiders`;
    if (viewing) $('autosave').textContent = 'Read-only preview · your draft is untouched';
    else try { localStorage.setItem(storageKey, JSON.stringify(draft)); $('autosave').textContent = unsaved() ? 'Unsaved changes · autosaved in this browser' : 'No unsaved changes'; }
    catch (_) { $('autosave').textContent = 'Autosave unavailable — use Save draft'; }
    refreshTools(); inspector(); validation(); draw();
  }
  function circle(x, y, radius, fill, stroke, width = 1) {
    ctx.beginPath(); ctx.arc(x, y, radius, 0, Math.PI * 2); if (fill) {ctx.fillStyle = fill; ctx.fill();}
    if (stroke) {ctx.strokeStyle = stroke; ctx.lineWidth = width; ctx.stroke();}
  }
  function movingPoint(w, p, seconds) {
    const motion = w.motion || 'legacy', angle = (w.phase || 0) + seconds * Math.PI * 2 / (w.period || 4);
    if (motion === 'circle' || motion === 'oval') return {x:p.x+w.radiusX*Math.cos(angle),y:p.y+(motion==='circle'?w.radiusX:w.radiusY)*Math.sin(angle)};
    if (motion === 'horizontal') return {x:p.x+w.radiusX*Math.sin(angle),y:p.y};
    if (motion === 'vertical') return {x:p.x,y:p.y+w.radiusY*Math.sin(angle)};
    if (motion === 'legacy' && w.kind === 'movingHole') return {x:p.x+48*Math.sin(seconds*2.2),y:p.y};
    return p;
  }
  function draw() {
    ctx.setTransform(2, 0, 0, 2, 0, 0); ctx.clearRect(0, 0, 360, 560);
    ctx.fillStyle = '#f3edd9'; ctx.fillRect(0, 0, 360, 560);
    ctx.strokeStyle = '#e1dac1'; ctx.lineWidth = .4;
    for (let x = 10; x < 360; x += 10) {ctx.beginPath();ctx.moveTo(x, 20);ctx.lineTo(x, 540);ctx.stroke();}
    for (let y = 20; y < 550; y += 10) {ctx.beginPath();ctx.moveTo(10, y);ctx.lineTo(350, y);ctx.stroke();}
    ctx.strokeStyle = '#b7b291';ctx.lineWidth = 1;ctx.strokeRect(16, 16, 328, 528);
    ctx.font = 'bold 8px Segoe UI';ctx.textAlign = 'center';ctx.fillStyle = '#7e866b';ctx.fillText('GILT  /  CLASSIC', 180, 12);
    for (const [wave, w] of draft.hazards.entries()) for (const [index, p] of w.positions.entries()) {
      const q = movingPoint(w,p,$('animate').checked ? performance.now()/1000 : 0);
      ctx.save(); ctx.globalAlpha = filter && filter !== p.target ? .06 : .45;
      ctx.strokeStyle='#b9845f';ctx.lineWidth=1;ctx.setLineDash([3,4]);
      if(w.motion==='circle'||w.motion==='oval'){
        ctx.beginPath();ctx.ellipse(p.x,p.y,w.radiusX,w.motion==='circle'?w.radiusX:w.radiusY,0,0,Math.PI*2);ctx.stroke();
      }else if(w.motion==='horizontal'||w.motion==='vertical'){
        const dx=w.motion==='horizontal'?w.radiusX:0,dy=w.motion==='vertical'?w.radiusY:0;
        ctx.beginPath();ctx.moveTo(p.x-dx,p.y-dy);ctx.lineTo(p.x+dx,p.y+dy);ctx.stroke();
      }
      ctx.setLineDash([]);
      if (w.kind === 'laser') {
        const horizontal=w.orientation==='horizontal';
        ctx.fillStyle='#e37965';
        if(horizontal)ctx.fillRect(24,q.y-3,312,6);else ctx.fillRect(q.x-3,33,6,504);
        ctx.strokeStyle='#b74335';ctx.beginPath();
        if(horizontal){ctx.moveTo(24,q.y);ctx.lineTo(336,q.y);}else{ctx.moveTo(q.x,33);ctx.lineTo(q.x,537);}ctx.stroke();
      } else {circle(q.x,q.y,9,'#c27a4c','#8b4b26');}
      ctx.restore();ctx.save();ctx.globalAlpha=filter && filter!==p.target ? .1 : 1;
      circle(p.x,p.y,6,w.kind==='laser'?'#ba4c3c':'#b07435','#fff8e6');
      if (same(selection,{type:'hazard',wave,index})) circle(p.x,p.y,12,null,'#2f7a68',2);
      ctx.restore();
    }
    for (const [index, s] of draft.spiders.entries()) {
      circle(s.x,s.y,s.zoneRadius,'#ce9b2420','#b39654');
      ctx.setLineDash([3,4]);circle(s.x,s.y,12,null,'#b39654');ctx.setLineDash([]);
      const x=s.x+Math.cos(s.phase)*12, y=s.y+Math.sin(s.phase)*12;
      ctx.strokeStyle='#725632';ctx.lineWidth=1.5;
      for(let i=0;i<4;i++){const dy=(i-1.5)*4;for(const sign of [-1,1]){ctx.beginPath();ctx.moveTo(x+sign*3,y+dy*.5);ctx.lineTo(x+sign*9,y+dy);ctx.lineTo(x+sign*12,y+dy+3);ctx.stroke();}}
      circle(x,y,s.bodyRadius,'#705435');circle(s.x,s.y,2,'#9a8042');
      if(same(selection,{type:'spider',index})) circle(s.x,s.y,s.zoneRadius+3,null,'#2f7a68',2);
    }
    const seconds=$('animate').checked?performance.now()/1000:0;
    for (const [index,h] of draft.holes.entries()) {
      const s=M.holeSizeAt({size:1,pulse:null,...h},seconds),m=h.motion,q=M.holeAt(h,seconds);
      if(m){
        ctx.save();ctx.strokeStyle='#5d7f72';ctx.lineWidth=1;ctx.setLineDash([3,4]);ctx.beginPath();
        if(m.path==='horizontal'){ctx.moveTo(h.x-m.radiusX,h.y);ctx.lineTo(h.x+m.radiusX,h.y);}
        else if(m.path==='vertical'){ctx.moveTo(h.x,h.y-m.radiusY);ctx.lineTo(h.x,h.y+m.radiusY);}
        else ctx.ellipse(h.x,h.y,m.radiusX,m.path==='circle'?m.radiusX:m.radiusY,0,0,Math.PI*2);
        ctx.stroke();ctx.restore();circle(h.x,h.y,2,'#5d7f72');
      }
      // Size scales only the opening; the rim around it keeps its width, like the game.
      const opening=h.target?8.5:6.5,rimAt=size=>opening*size+3.5;
      if(h.pulse){ctx.save();ctx.setLineDash([2,3]);circle(q.x,q.y,rimAt(M.largestSize(h)),null,'#7d8f6c',1);circle(q.x,q.y,rimAt(Math.min(h.pulse.minSize,h.pulse.maxSize)),null,'#7d8f6c',1);ctx.restore();}
      circle(q.x,q.y,rimAt(s),h.target?'#ead28b':'#384c40',h.target?'#a68b43':'#7a8469',1.5);
      circle(q.x,q.y,opening*s,h.target?'#31574a':'#1c352e');
      if(h.target){ctx.fillStyle='#fff6ce';ctx.font=`bold ${Math.round(10*Math.min(2.5,Math.max(.75,s)))}px Segoe UI`;ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(String(h.target),q.x,q.y+.2);}
      if(same(selection,{type:'hole',index})) circle(h.x,h.y,Math.max(16,M.holeRim(M.largestSize({size:1,pulse:null,...h}))+4),null,'#2f7a68',2);
    }
    ctx.fillStyle='#6c7960';ctx.fillRect(32,527,296,3);circle(180,519,7,'#e6e4d6','#a3a993');
    ctx.font='9px Segoe UI';ctx.fillStyle='#7a8167';ctx.textAlign='center';ctx.fillText('START',180,547);
    if(highlight){
      const left=highlight.until-performance.now();
      if(left<=0)highlight=null;
      else for(const p of highlight.points){ctx.save();ctx.globalAlpha=Math.min(1,left/400);circle(p.x,p.y,p.r+3*Math.sin(performance.now()/90),null,'#d9822b',2.5);ctx.restore();}
    }
  }
  function point(event, snap = false) {
    const rect=canvas.getBoundingClientRect(); let x=(event.clientX-rect.left)*360/rect.width,y=(event.clientY-rect.top)*560/rect.height;
    if(snap && $('snap').checked){x=Math.round(x/10)*10;y=Math.round(y/10)*10;}
    return {x:Math.max(24,Math.min(336,Math.round(x*10)/10)),y:Math.max(24,Math.min(490,Math.round(y*10)/10))};
  }
  function hit(p) {
    return objects().reverse().find(ref => (!filter || ref.type!=='hazard' || ref.o.target===filter) && Math.hypot(ref.o.x-p.x,ref.o.y-p.y)<(ref.type==='hole'?Math.max(16,M.holeRim(M.largestSize({size:1,pulse:null,...ref.o}))+3):16));
  }
  function add(p) {
    if(tool==='target' && draft.holes.filter(h=>h.target>0).length>=10){toast('All 10 targets are placed. Select one to move it.');return;}
    change(()=>{
      if(tool==='target'||tool==='trap'){
        let target=0;if(tool==='target'){target=1;while(draft.holes.some(h=>h.target===target))target++;}
        draft.holes.push({...p,target,size:1,motion:null});selection={type:'hole',index:draft.holes.length-1};
      }else if(tool==='spider'){
        draft.spiders.push({...p,zoneRadius:40,phase:0,chaseSpeed:72,bodyRadius:6});selection={type:'spider',index:draft.spiders.length-1};
      }else{
        if(!draft.hazards[waveIndex]||draft.hazards[waveIndex].kind!==tool){
          draft.hazards.push({...M.waveDefaults,kind:tool,warningSeconds:2.4,liveSeconds:tool==='laser'?1.2:3,positions:[]});waveIndex=draft.hazards.length-1;
        }
        const positions=draft.hazards[waveIndex].positions;positions.push({...p,target:filter||1});selection={type:'hazard',wave:waveIndex,index:positions.length-1};
      }
    });
  }
  canvas.onpointerdown=e=>{
    if(e.button!==0||viewing)return;
    const p=point(e),found=hit(p);
    if(tool==='erase'){selection=found||null;deleteSelection();return;}
    if(found){selection=found;if(found.type==='hazard')waveIndex=found.wave;remember();drag={id:e.pointerId,start:point(e),x:found.o.x,y:found.o.y};canvas.setPointerCapture(e.pointerId);render();}
    else if(tool==='select'){selection=null;render();}
    else add(point(e,true));
  };
  canvas.onpointermove=e=>{
    const p=point(e);$('cursor').textContent=`x ${Math.round(p.x)} · y ${Math.round(p.y)}`;
    if(!drag)return;const obj=selectedObject();if(!obj)return;
    let x=drag.x+p.x-drag.start.x,y=drag.y+p.y-drag.start.y;
    if($('snap').checked){x=Math.round(x/10)*10;y=Math.round(y/10)*10;}
    obj.x=Math.max(24,Math.min(336,Math.round(x*10)/10));obj.y=Math.max(24,Math.min(490,Math.round(y*10)/10));draw();
  };
  canvas.onpointerup=canvas.onpointercancel=()=>{if(drag){drag=null;render();}};
  $('undo').onclick=()=>restore(undo,redo);$('redo').onclick=()=>restore(redo,undo);$('delete').onclick=deleteSelection;
  $('filter').onchange=()=>{filter=Number($('filter').value);draw();};
  $('wave').onchange=()=>{waveIndex=Number($('wave').value);selection=null;render();};
  $('add-wave').onclick=()=>change(()=>{draft.hazards.push({...M.waveDefaults,kind:'laser',warningSeconds:2.4,liveSeconds:1.2,positions:[]});waveIndex=draft.hazards.length-1;selection=null;tool='laser';});
  $('wave-up').onclick=()=>{if(waveIndex>0)change(()=>{[draft.hazards[waveIndex-1],draft.hazards[waveIndex]]=[draft.hazards[waveIndex],draft.hazards[waveIndex-1]];waveIndex--;selection=null;});};
  $('delete-wave').onclick=()=>{if(waveIndex>=0 && confirm('Delete this wave and all its positions?'))change(()=>{draft.hazards.splice(waveIndex,1);waveIndex=Math.min(waveIndex,draft.hazards.length-1);selection=null;});};
  for(const key of ['number','name','finaleTitle','finaleRule','firstHazardAfter','hazardInterval'])$(key).onchange=()=>{
    const el=$(key),value=el.type==='number'?el.valueAsNumber:el.value;
    if(typeof value==='number' && (!Number.isFinite(value)||(key==='number' && (!Number.isInteger(value)||value<1)))){render();return;}
    change(()=>{draft[key]=value;});
  };
  $('new').onclick=()=>{if(!unsaved()||confirm('Start a new draft? Your unsaved changes will be lost.'))replaceDraft(M.blank(nextNumber()));};
  $('load').onclick=()=>{levelList();$('open-dialog').showModal();};
  $('view-edit').onclick=()=>edit(presets.find(level=>level.number===viewing));
  $('view-back').onclick=leaveView;
  for(const button of document.querySelectorAll('[data-close]'))button.onclick=()=>$(button.dataset.close).close();
  function download(text,filename,type){const url=URL.createObjectURL(new Blob([text],{type}));const a=document.createElement('a');a.href=url;a.download=filename;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
  $('save').onclick=()=>{download(JSON.stringify(draft,null,2),`level_${String(draft.number).padStart(2,'0')}.draft.json`,'application/json');markClean();render();};
  $('save-game').onclick=async()=>{
    const button=$('save-game');
    try {
      M.exportDart(draft);
      button.disabled=true;button.textContent='Saving…';
      const session=await fetch('/api/session').then(r=>r.json());
      const response=await fetch('/api/save',{method:'POST',headers:{'Content-Type':'application/json','X-Builder-Token':session.token},body:JSON.stringify(draft)});
      const result=await response.json();if(!response.ok)throw Error(result.error||'Save failed.');
      presets=await fetch('/api/levels').then(r=>r.json());
      markClean(draft.number);render();$('autosave').textContent=`Saved to ${result.file}`;
      toast(`Saved level ${draft.number} to game. Rebuild the game to play it.`);
    } catch(e){toast(e.message);} finally {button.disabled=false;button.textContent='Save to game';}
  };
  $('import').onclick=()=>$('import-file').click();
  $('import-file').onchange=async()=>{const file=$('import-file').files[0];if(!file)return;try{
    if(file.size>2_000_000)throw Error('Draft is too large (maximum 2 MB).');
    const next=M.parseDraft(await file.text());if(unsaved()&&!confirm('Replace your unsaved draft with the imported file?'))return;replaceDraft(next);toast('Draft imported');
  }catch(e){toast(e.message);}finally{$('import-file').value='';}};
  $('export').onclick=()=>{try{
    $('code').value=M.exportDart(draft);$('export-title').textContent=`Export level_${String(draft.number).padStart(2,'0')}.dart`;
    const warnings=M.validate(draft).warnings;
    $('export-status').textContent=warnings.length?`Ready to export. Review ${warnings.length} placement warning(s) in the inspector and playtest before release.`:'Ready to add to your game. The source includes holes, spiders and hazards.';
    $('export-dialog').showModal();
  }catch(e){toast('Finish the level checks before exporting.');$('validation').scrollIntoView({behavior:'smooth',block:'nearest'});}};
  $('copy').onclick=async()=>{try{await navigator.clipboard.writeText($('code').value);toast('Dart code copied');}catch(_){$('code').select();toast('Select and copy the code from the text area.');}};
  $('download').onclick=()=>download($('code').value,`level_${String(draft.number).padStart(2,'0')}.dart`,'text/plain');
  document.addEventListener('keydown',e=>{
    if(['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName)||document.querySelector('dialog[open]'))return;
    if(viewing){if(e.key==='Escape')leaveView();return;}
    if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='z'){e.preventDefault();e.shiftKey?restore(redo,undo):restore(undo,redo);}
    else if(e.key==='Delete'||e.key==='Backspace'){e.preventDefault();deleteSelection();}
    else if(e.key==='Escape'){selection=null;tool='select';render();}
  });
  render();
  function animate(){if($("animate").checked||highlight)draw();requestAnimationFrame(animate);} requestAnimationFrame(animate);
})();
