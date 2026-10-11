// Paste into the Firefly tab's javascript_exec (https://firefly.adobe.com/generate/image, logged in, viewport 1440x900 via resize_window).
// Defines __runList(list) [with reference image url] and __runNoRef(list). Items: {key, ref(url), prompt (<1000 chars!), quality:'medium'|'high', aspect?}
// Log: __qLog (items 'key|clicked|UTC time', then 'DONE'); stop with __stopList=true. Never run two loops at once.
// Model = 'openai:firefly:colligo:gpt-image-2.5-prism'; pickers: [0]=model [1]=aspect [2]=quality.
function deepAll(sel, root = document, out = []) { root.querySelectorAll(sel).forEach(e => out.push(e)); root.querySelectorAll('*').forEach(e => { if (e.shadowRoot) deepAll(sel, e.shadowRoot, out); }); return out; }
window.__deepAll = deepAll; window.__sleep = ms => new Promise(r => setTimeout(r, ms));
window.__btn = () => __deepAll('[data-testid="generate-image-generate-button"]')[0];
window.__pm = () => __deepAll('div.ProseMirror[contenteditable=true]')[0];
window.__pick = async (idx, value) => { const p = __deepAll('sp-picker')[idx]; if (idx === 2) { p.value = value; p.dispatchEvent(new Event('change', { bubbles: true, composed: true })); await __sleep(900); return __deepAll('sp-picker')[2].value; } p.open = true; await __sleep(700); const it = __deepAll('sp-menu-item').find(i => (i.value || '') === value); if (it) it.click(); await __sleep(900); return __deepAll('sp-picker')[idx].value; };
window.__setPrompt = (text) => { const el = __pm(); el.focus(); document.execCommand('selectAll', false); document.execCommand('insertText', false, text); return { len: el.innerText.length, disabled: __btn().disabled }; };
window.__busy = () => __deepAll('sp-progress-circle, sp-progress-bar, [role=progressbar]').filter(e => e.offsetParent !== null || e.getClientRects().length).length;
window.__seen = new Set();
window.__blobs = () => { __deepAll('img').forEach(i => { const s = i.currentSrc || i.src; if (s && s.startsWith('blob:')) __seen.add(s); }); return __seen.size; };
window.__setRef = async (url, name) => { const res = await fetch(url, { credentials: 'omit' }); const blob = await res.blob(); const file = new File([blob], name, { type: blob.type || 'image/png' }); const input = __deepAll('input[type=file]#file-input')[0]; const dt = new DataTransfer(); dt.items.add(file); input.files = dt.files; input.dispatchEvent(new Event('input', { bubbles: true, composed: true })); input.dispatchEvent(new Event('change', { bubbles: true, composed: true })); return { status: res.status }; };
window.__clearRefs = () => { const b = __deepAll('[data-testid="uploaded-image-remove-button"]'); b.forEach(x => x.click()); return b.length; };
window.__qLog = []; window.__stopList = false;
// 10/12: quality picker click does not take -> value+change (idx 2). Guard: if the quality value changes unexpectedly during a run, set __stopList=true (a stray High = 5 credits).
async function _one(it, useRef) {
  const S = __sleep; let t0 = Date.now();
  while (__busy() > 0 && Date.now() - t0 < 240000) await S(1000);
  __clearRefs(); await S(1500);
  if (useRef) { await __setRef(it.ref, it.key + '_ref.png'); t0 = Date.now(); while (__deepAll('[data-testid="uploaded-image-remove-button"]').length === 0 && Date.now() - t0 < 30000) await S(800); await S(2500); }
  if (__deepAll('sp-picker')[0].value !== 'openai:firefly:colligo:gpt-image-2.5-prism') await __pick(0, 'openai:firefly:colligo:gpt-image-2.5-prism');
  const asp = it.aspect || '{"height":1024,"width":1024}';
  if (__deepAll('sp-picker')[1].value !== asp) await __pick(1, asp);
  const q = it.quality || 'high';
  if (__deepAll('sp-picker')[2].value !== q) await __pick(2, q);
  if (__deepAll('sp-picker')[2].value !== q) { __qLog.push(it.key + '|QUALITY_MISMATCH'); window.__stopList = true; return; }
  const before = __blobs();
  __setPrompt(it.prompt); await S(1500);
  let g = 'disabled';
  if (!__btn().disabled) { __btn().click(); g = 'clicked'; }
  else { await S(2000); __setPrompt(it.prompt + ' '); await S(1000); if (!__btn().disabled) { __btn().click(); g = 'clicked2'; } }
  t0 = Date.now(); while (__busy() === 0 && Date.now() - t0 < 15000) await S(500);
  t0 = Date.now(); while ((__busy() > 0 || __blobs() <= before) && Date.now() - t0 < 300000) await S(1500);
  __qLog.push(it.key + '|' + g + '|' + new Date().toISOString().slice(11, 19));
}
window.__runList = async (list) => { for (const it of list) { if (window.__stopList) { __qLog.push('STOPPED'); return; } await _one(it, true); } __clearRefs(); __qLog.push('DONE'); };
window.__runNoRef = async (list) => { for (const it of list) { if (window.__stopList) { __qLog.push('STOPPED'); return; } await _one(it, false); } __qLog.push('DONE'); };
