// Synthetic data only. No app activation, telemetry, storage, or API calls.
const variants = {
  A: {name:'石墨机械',description:'把实体键盘的凹面、倒角和短键程，带回熟悉的全键盘面板。克制，但摸得到层次。',material:'细磨砂顶面 · 石墨侧壁',motion:'3 px 短键程 · 阴影随按压收拢',layout:'完整键盘 · 目标信息留在底部'},
  B: {name:'银瓷工作台',description:'像一块精密加工的浅银键盘。目标先被看见，再用一枚温润的键帽完成切换。',material:'微凹银瓷 · 铝色底座',motion:'4 px 清晰下沉 · 柔和回位',layout:'顶部放大当前目标 · 键盘更轻巧'},
  C: {name:'烟晶控制台',description:'薄透的键帽边缘，局部亮起的冰蓝。紧凑键盘旁，始终留着清楚的目标预览。',material:'烟晶边缘 · 冰蓝局部背光',motion:'2 px 低键程 · 单键边缘回应',layout:'左侧大目标 · 右侧紧凑键盘'}
};
const glyphs = {
  safari:'<circle cx="16" cy="16" r="12"/><path d="m21 10-3 9-8 3 3-9Z" fill="white" stroke="none"/><path d="m21 10-8 3 5 6Z" fill="#ff786f" stroke="none"/>',
  mail:'<rect x="4" y="7" width="24" height="18" rx="2"/><path d="m4 8 12 10L28 8M4 25l8-8m16 8-8-8"/>',
  finder:'<path d="M16 4v15h5v9M8 11v2m15-2v2M8 22c5 4 11 4 16-1"/>',
  notes:'<path d="M7 7h18M7 13h18M7 19h15M7 25h12"/>',
  music:'<path d="M13 22V9l13-3v13M13 13l13-3"/><ellipse cx="9" cy="24" rx="4" ry="3" fill="white"/><ellipse cx="22" cy="21" rx="4" ry="3" fill="white"/>',
  terminal:'<path d="m6 9 7 7-7 7m10 0h10"/>',
  calendar:'<rect x="5" y="6" width="22" height="23" rx="3"/><path d="M5 12h22M11 3v6m10-6v6"/><path d="M11 18h3v6m5-6h4l-4 6"/>',
  arc:'<path d="M5 26 16 5l11 21M9 19c4 4 10 4 14 0" stroke-width="3"/>',
  figma:'<rect x="7" y="3" width="9" height="9" rx="4.5"/><rect x="16" y="3" width="9" height="9" rx="4.5"/><rect x="7" y="12" width="9" height="9" rx="4.5"/><circle cx="20.5" cy="16.5" r="4.5"/><path d="M16 21H11.5a4.5 4.5 0 1 0 4.5 4.5Z"/>',
  messages:'<path d="M27 14c0 6-5 10-11 10h-4l-6 4 1-7c-3-2-4-4-4-7C3 8 8 4 15 4s12 4 12 10Z"/><path d="M9 14h.1m6 0h.1m6 0h.1" stroke-width="3"/>',
  photos:'<path d="M16 15C3 1 28 1 16 15c14-12 14 13 0 1 12 14-13 14 0 0-14 12-14-13 0-1Z"/>',
  code:'<path d="m12 8-9 8 9 8m8-16 9 8-9 8m-2-20-5 25"/>'
};
const apps = {
  Q:['QQ','messages','#73b1f8','#346bbb','聊一聊，保持连接。'], W:['微信','messages','#63d986','#21a856','与朋友保持联系。'], E:['Terminal','terminal','#454e59','#1e252d','回到命令行。'], R:['Arc','arc','#d89d9b','#947ae0','让探索继续。'], T:['备忘录','notes','#e5bd56','#ba9331','记下刚刚的灵感。'], Y:['照片','photos','#bd8cae','#7698c0','收好每一个画面。'], A:['App Store','arc','#57b5ff','#2674dd','发现下一款好工具。'], S:['Safari','safari','#65cded','#2e8bd9','浏览网页，继续探索。'], D:['日历','calendar','#f38982','#d55a57','看一眼接下来的安排。'], F:['Finder','finder','#78cffa','#489ae1','文件都在熟悉的位置。'], M:['音乐','music','#f68c9c','#de4666','回到喜欢的旋律。'], V:['VS Code','code','#59b7ed','#257db8','回到未完成的代码。']
};
const $ = selector => document.querySelector(selector);
let variant='A', selected='S', pointerKey=null, heldKeys=new Set();
function icon(app){return `<span class="app-icon" style="--icon-top:${app[2]};--icon-bottom:${app[3]}"><svg viewBox="0 0 32 32" aria-hidden="true">${glyphs[app[1]]}</svg></span>`;}
function renderKeyboard(){
  $('#keyboard').innerHTML=['QWERTYUIOP','ASDFGHJKL','ZXCVBNM'].map(row=>`<div class="key-row">${[...row].map(key=>{
    const app=apps[key];
    return `<button type="button" class="key${app?'':' empty'}" data-key="${key}" ${app?`aria-label="${key}，${app[0]}，模拟切换"`:'disabled aria-label="'+key+'，未分配"'}><span class="key-face"><span class="key-letter">${key}</span>${app?icon(app)+`<span class="key-name">${app[0]}</span>`:''}</span></button>`;
  }).join('')}</div>`).join('');
  document.querySelectorAll('.key:not(.empty)').forEach(button=>{
    const key=button.dataset.key;
    button.addEventListener('pointerenter',()=>select(key));
    button.addEventListener('focus',()=>select(key));
    button.addEventListener('pointerdown',event=>{if(event.button!==0)return;clearPress();pointerKey=key;press(key);});
    button.addEventListener('click',()=>activate(key));
  });
}
function select(key){
  if(!apps[key])return;
  selected=key;
  document.querySelectorAll('.key').forEach(el=>{const active=el.dataset.key===key;el.classList.toggle('selected',active);if(!el.disabled)el.setAttribute('aria-pressed',String(active));});
  const app=apps[key];
  $('.target-name').textContent=app[0];$('.target-description').textContent=app[4];$('.target-key').textContent=key;$('.spotlight-icon').innerHTML=icon(app);$('#selection-name').textContent=app[0];$('#interaction-state').textContent='已选中';
}
function press(key){select(key);document.querySelector(`[data-key="${key}"]`)?.classList.add('pressed');$('#interaction-state').textContent='按住 · 键帽下沉';}
function clearPress(){document.querySelectorAll('.pressed').forEach(el=>el.classList.remove('pressed'));pointerKey=null;heldKeys.clear();$('#interaction-state').textContent='已选中';}
function activate(key){select(key);$('#interaction-state').textContent='✓ 模拟切换';$('#result').textContent=`${key} → ${apps[key][0]} · 已模拟切换；真实应用未受影响。可以继续试按。`;}
function setVariant(key,writeURL=true){
  clearPress();variant=variants[key]?key:'A';document.body.dataset.variant=variant;
  const data=variants[variant];$('#study-title').textContent=data.name;$('#study-description').textContent=data.description;
  $('#material-note').textContent=data.material;$('#motion-note').textContent=data.motion;$('#layout-note').textContent=data.layout;
  document.querySelectorAll('[data-variant-choice]').forEach(el=>el.setAttribute('aria-current',String(el.dataset.variantChoice===variant)));
  if(writeURL){const url=new URL(location.href);url.searchParams.set('variant',variant);history.replaceState(null,'',url);}
  select(selected);$('#result').textContent=`方案 ${variant} · ${data.name}。试着按住一个键帽，再松开。这里只模拟，不切换真实应用。`;
}
function cycle(delta){setVariant(['A','B','C'][(['A','B','C'].indexOf(variant)+delta+3)%3]);}
document.querySelectorAll('[data-variant-choice]').forEach(el=>el.addEventListener('click',()=>setVariant(el.dataset.variantChoice)));
$('#previous').addEventListener('click',()=>cycle(-1));$('#next').addEventListener('click',()=>cycle(1));
window.addEventListener('pointerup',()=>{if(pointerKey)clearPress();});window.addEventListener('pointercancel',clearPress);window.addEventListener('blur',clearPress);
document.addEventListener('visibilitychange',()=>{if(document.hidden)clearPress();});
document.addEventListener('keydown',event=>{
  if(event.target.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"])')||event.metaKey||event.ctrlKey||event.altKey||event.isComposing)return;
  if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();if(!event.repeat)cycle(event.key==='ArrowRight'?1:-1);return;}
  const key=event.code.startsWith('Key')?event.code.slice(3):null;
  if(apps[key]){event.preventDefault();if(!event.repeat){heldKeys.add(key);press(key);activate(key);$('#interaction-state').textContent='按住 · 已模拟切换';}return;}
  if((event.key==='Enter'||event.key===' ')&&event.target.closest('.key:not(.empty)')){if(!event.repeat)press(event.target.closest('.key').dataset.key);else event.preventDefault();}
  if(event.key==='Enter' && !event.target.closest('button')){event.preventDefault();if(!event.repeat){press(selected);activate(selected);}}
  if(event.key==='Escape'){clearPress();$('#result').textContent='演示已复位。真实面板中 Esc 会收起面板。';}
});
document.addEventListener('keyup',event=>{const key=event.code.startsWith('Key')?event.code.slice(3):null;if(heldKeys.has(key)){heldKeys.delete(key);document.querySelector(`[data-key="${key}"]`)?.classList.remove('pressed');$('#interaction-state').textContent='✓ 模拟切换';}if(event.key==='Enter'||event.key===' ')clearPress();});
window.addEventListener('popstate',()=>setVariant(new URLSearchParams(location.search).get('variant'),false));
$('.prototype-switcher').hidden=!(['localhost','127.0.0.1',''].includes(location.hostname));
renderKeyboard();setVariant(new URLSearchParams(location.search).get('variant')||'A',false);
