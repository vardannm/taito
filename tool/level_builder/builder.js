(async function () {
  'use strict';
  const M = LevelModel, $ = id => document.getElementById(id);
  const canvas = $('board'), ctx = canvas.getContext('2d');
  let presets = [], draft, selection = null, tool = 'target', waveIndex = -1, filter = 0;
  let undo = [], redo = [], drag = null, toastTimer;
  const storageKey = 'gilt-developer-level-builder-v1';
  try {
    const response = await fetch('/api/levels');
    if (!response.ok) throw Error('Could not load built-in levels.');
    presets = await response.json();
  } catch (e) { toast(e.message); }
  const nextNumber = () => Math.max(0, ...presets.map(p => p.number)) + 1;
  try { draft = M.parseDraft(localStorage.getItem(storageKey)); }
  catch (_) { draft = M.blank(nextNumber()); }
  if (draft.hazards.length) waveIndex = 0;

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
  function replaceDraft(next) { remember(); draft = next; selection = null; waveIndex = draft.hazards.length ? 0 : -1; filter = 0; $('filter').value = '0'; render(); }
  function selectedObject() {
    if (!selection) return null;
    if (selection.type === 'hole') return draft.holes[selection.index];
    if (selection.type === 'spider') return draft.spiders[selection.index];
    return draft.hazards[selection.wave]?.positions[selection.index];
  }
  function labelFor(ref) {
    if (ref.type === 'hole') { const h = draft.holes[ref.index]; return h.target ? `Target ${h.target}` : 'Trap hole'; }
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
    for (const button of $('tools').children) button.classList.toggle('active', button.dataset.tool === tool);
    canvas.style.cursor = tool === 'select' ? 'default' : 'crosshair';
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
      if (selection.type === 'hole') field(panel, 'Target number (0 = trap)', 'target', object, {min: 0, max: 10, step: 1});
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
  }
  function validation() {
    const result = M.validate(draft); const box = $('validation'); box.replaceChildren();
    for (const [kind, items] of [['error', result.errors], ['warn', result.warnings]]) {
      if (!items.length) continue;
      const card = document.createElement('div'); card.className = `status ${kind}`;
      const title = document.createElement('strong'); title.textContent = `${items.length} ${kind === 'error' ? 'to fix' : 'to review'}`;
      const list = document.createElement('ul');
      for (const item of items) { const li = document.createElement('li'); li.textContent = item; list.append(li); }
      card.append(title, list); box.append(card);
    }
    if (!result.errors.length) { const card = document.createElement('div'); card.className = 'status'; card.textContent = '✓ Ready to export'; box.prepend(card); }
    if (presets.some(p => p.number === draft.number)) {
      const warning = document.createElement('p'); warning.className = 'hint'; warning.textContent = `Level ${draft.number} already exists. Use ${nextNumber()} to add a new level.`; box.append(warning);
    }
  }
  function render() {
    for (const key of ['number', 'name', 'finaleTitle', 'finaleRule', 'firstHazardAfter', 'hazardInterval']) $(key).value = draft[key];
    $('file-name').textContent = `level_${String(draft.number).padStart(2, '0')}.dart`;
    $('undo').disabled = !undo.length; $('redo').disabled = !redo.length;
    $('wave').replaceChildren();
    if (!draft.hazards.length) $('wave').add(new Option('No waves yet', -1));
    draft.hazards.forEach((w, i) => $('wave').add(new Option(`${i + 1}. ${w.kind === 'laser' ? 'Laser' : 'Moving hole'} · ${w.positions.length} positions`, i)));
    $('wave').value = String(waveIndex); $('wave-up').disabled = waveIndex <= 0; $('delete-wave').disabled = waveIndex < 0;
    const all = objects(); $('objects').replaceChildren(); $('object-count').textContent = `(${all.length})`;
    for (const ref of all) {
      const button = document.createElement('button'); button.className = 'object-item'; button.classList.toggle('selected', !!same(selection, ref));
      const label = document.createElement('span'); label.textContent = labelFor(ref);
      const coord = document.createElement('span'); coord.textContent = `${Math.round(ref.o.x)}, ${Math.round(ref.o.y)}`;
      button.append(label, coord); button.onclick = () => {selection = ref; tool = 'select'; if(ref.type === 'hazard') waveIndex = ref.wave; render();};
      $('objects').append(button);
    }
    $('counts').textContent = `${draft.holes.filter(h => h.target).length}/10 targets · ${draft.holes.filter(h => !h.target).length} traps · ${draft.spiders.length} spiders`;
    try { localStorage.setItem(storageKey, JSON.stringify(draft)); $('autosave').textContent = 'Draft saved in this browser'; }
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
    for (const [index,h] of draft.holes.entries()) {
      circle(h.x,h.y,h.target?12:10,h.target?'#ead28b':'#384c40',h.target?'#a68b43':'#7a8469',1.5);
      circle(h.x,h.y,h.target?8.5:6.5,h.target?'#31574a':'#1c352e');
      if(h.target){ctx.fillStyle='#fff6ce';ctx.font='bold 10px Segoe UI';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(String(h.target),h.x,h.y+.2);}
      if(same(selection,{type:'hole',index})) circle(h.x,h.y,16,null,'#2f7a68',2);
    }
    ctx.fillStyle='#6c7960';ctx.fillRect(32,527,296,3);circle(180,519,7,'#e6e4d6','#a3a993');
    ctx.font='9px Segoe UI';ctx.fillStyle='#7a8167';ctx.textAlign='center';ctx.fillText('START',180,547);
  }
  function point(event, snap = false) {
    const rect=canvas.getBoundingClientRect(); let x=(event.clientX-rect.left)*360/rect.width,y=(event.clientY-rect.top)*560/rect.height;
    if(snap && $('snap').checked){x=Math.round(x/10)*10;y=Math.round(y/10)*10;}
    return {x:Math.max(24,Math.min(336,Math.round(x*10)/10)),y:Math.max(24,Math.min(490,Math.round(y*10)/10))};
  }
  function hit(p) {
    return objects().reverse().find(ref => (!filter || ref.type!=='hazard' || ref.o.target===filter) && Math.hypot(ref.o.x-p.x,ref.o.y-p.y)<16);
  }
  function add(p) {
    if(tool==='target' && draft.holes.filter(h=>h.target>0).length>=10){toast('All 10 targets are placed. Select one to move it.');return;}
    change(()=>{
      if(tool==='target'||tool==='trap'){
        let target=0;if(tool==='target'){target=1;while(draft.holes.some(h=>h.target===target))target++;}
        draft.holes.push({...p,target});selection={type:'hole',index:draft.holes.length-1};
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
    if(e.button!==0)return;
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
  $('new').onclick=()=>{if(!objects().length||confirm('Start a new draft? Save a JSON draft first if you want to keep this one.'))replaceDraft(M.blank(nextNumber()));};
  for(const p of presets){const button=document.createElement('button');button.textContent=`${String(p.number).padStart(2,'0')} · ${p.name}`;button.onclick=()=>{
    if(objects().length&&!confirm('Replace this draft with a copy of the selected level?'))return;
    const copy=M.clone(p);copy.number=nextNumber();replaceDraft(copy);$('open-dialog').close();toast(`Copied level ${p.number} into level ${copy.number}`);
  };$('level-list').append(button);}
  $('load').onclick=()=>$('open-dialog').showModal();
  for(const button of document.querySelectorAll('[data-close]'))button.onclick=()=>$(button.dataset.close).close();
  function download(text,filename,type){const url=URL.createObjectURL(new Blob([text],{type}));const a=document.createElement('a');a.href=url;a.download=filename;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
  $('save').onclick=()=>download(JSON.stringify(draft,null,2),`level_${String(draft.number).padStart(2,'0')}.draft.json`,'application/json');
  $('import').onclick=()=>$('import-file').click();
  $('import-file').onchange=async()=>{const file=$('import-file').files[0];if(!file)return;try{
    if(file.size>2_000_000)throw Error('Draft is too large (maximum 2 MB).');
    const next=M.parseDraft(await file.text());if(objects().length&&!confirm('Replace this draft with the imported file?'))return;replaceDraft(next);toast('Draft imported');
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
    if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='z'){e.preventDefault();e.shiftKey?restore(redo,undo):restore(undo,redo);}
    else if(e.key==='Delete'||e.key==='Backspace'){e.preventDefault();deleteSelection();}
    else if(e.key==='Escape'){selection=null;tool='select';render();}
  });
  render();
  function animate(){if($("animate").checked)draw();requestAnimationFrame(animate);} requestAnimationFrame(animate);
})();
