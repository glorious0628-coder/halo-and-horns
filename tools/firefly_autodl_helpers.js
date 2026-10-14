// Firefly web (https://firefly.adobe.com/generate/image, logged in) -> generate with GPT Image 2.5 high (5 credits) and get the
// result URLs WITHOUT any download/save window (10/13 이미지 생성 2): the page loads each result from a pre-signed S3 URL
// (pre-signed-firefly-prod.s3-accelerate.amazonaws.com/images/<id>?x-resource-length=<bytes>&X-Amz-...; valid 24 h), a
// PerformanceObserver collects them in window.__s3, and __urlMap() pairs them with the labels by size. Then fetch them from
// the PC with `py tools/ff_fetch.py map.json <outdir>` (curl, no desktop change, no Downloads folder).
// Paste ONCE into the tab's javascript_exec (resize_window 1440x900 first), then call __runItems(items) (or __tasks).
// Items: {k, ref: 'https://at.adobe.com/<presigned upload url>', front: '<front prompt <1000 chars>', desc: 'short description'}.
//   - front = reference image `ref` (upload local crops once with Adobe MCP asset_initialize_file_upload -> curl PUT
//     -> asset_finalize_file_upload -> presignedAssetUrl); back/left/right = the NEW front blob (window.__fronts[k]) as ref.
// Log: __qLog ('<k>_<view>|ok|bytes|UTC', 'ALLDONE'); stop with __stopList = true. Results (blobs) also stay in window.__all.
// Model = openai:firefly:colligo:gpt-image-2.5-prism (pickers: [0] model [1] aspect [2] quality; set by value+change event).
performance.setResourceTimingBufferSize(3000);
window.__s3 = window.__s3 || []; window.__all = window.__all || {};
(function () { const have = new Set(window.__s3.map(x => x.u)); const add = e => { if (e.name.includes('pre-signed-firefly') && !have.has(e.name)) { window.__s3.push({ u: e.name, t: Math.round(e.startTime) }); have.add(e.name); } };
  performance.getEntriesByType('resource').forEach(add); if (!window.__po) { window.__po = new PerformanceObserver(l => l.getEntries().forEach(add)); window.__po.observe({ type: 'resource', buffered: true }); } })();
window.__urlMap = () => { const m = {}; const used = new Set(); Object.keys(__all).forEach(label => { const n = String(__all[label].size); const hit = __s3.find(x => !used.has(x.u) && (x.u.match(/x-resource-length=(\d+)/) || [])[1] === n); if (hit) { m[label] = hit.u; used.add(hit.u); } }); return m; };
function deepAll(sel, root = document, out = []) { root.querySelectorAll(sel).forEach(e => out.push(e)); root.querySelectorAll('*').forEach(e => { if (e.shadowRoot) deepAll(sel, e.shadowRoot, out); }); return out; }
window.__deepAll = deepAll; window.__sleep = ms => new Promise(r => setTimeout(r, ms));
window.__btn = () => __deepAll('[data-testid="generate-image-generate-button"]')[0];
window.__pm = () => __deepAll('div.ProseMirror[contenteditable=true]')[0];
window.__setPick = async (idx, value) => { const p = __deepAll('sp-picker')[idx]; p.value = value; p.dispatchEvent(new Event('change', { bubbles: true, composed: true })); await __sleep(1200); return __deepAll('sp-picker')[idx].value; };
window.__setPrompt = (text) => { const el = __pm(); el.focus(); document.execCommand('selectAll', false); document.execCommand('insertText', false, text); return { len: el.innerText.length, disabled: __btn().disabled }; };
window.__busy = () => __deepAll('sp-progress-circle, sp-progress-bar, [role=progressbar]').filter(e => e.offsetParent !== null || e.getClientRects().length).length;
window.__setRef = async (url, name) => { const res = await fetch(url, { credentials: 'omit' }); const blob = await res.blob(); const file = new File([blob], name, { type: blob.type || 'image/png' }); const input = __deepAll('input[type=file]#file-input')[0]; const dt = new DataTransfer(); dt.items.add(file); input.files = dt.files; input.dispatchEvent(new Event('input', { bubbles: true, composed: true })); input.dispatchEvent(new Event('change', { bubbles: true, composed: true })); return { status: res.status }; };
window.__clearRefs = () => { const b = __deepAll('[data-testid="uploaded-image-remove-button"]'); b.forEach(x => x.click()); return b.length; };
window.__qLog = []; window.__stopList = false; window.__fronts = window.__fronts || {};
window.__bigSet = () => { const s = new Set(); __deepAll('img').forEach(i => { const u = i.currentSrc || i.src || ''; if (u.startsWith('blob:') && i.naturalWidth >= 1000) s.add(u); }); return s; };
window.__setRefBlob = async (blob, name) => { const file = new File([blob], name, { type: 'image/png' }); const input = __deepAll('input[type=file]#file-input')[0]; const dt = new DataTransfer(); dt.items.add(file); input.files = dt.files; input.dispatchEvent(new Event('input', { bubbles: true, composed: true })); input.dispatchEvent(new Event('change', { bubbles: true, composed: true })); };

const LIGHT = ' Real volume, rounded edges, soft form shading. Soft even light-box light from all sides: NO cast shadow, NO ground shadow, NO contact shadow, NO dark side, NO dark crevices, no strong glare. Bright true colours. Plain light grey background. No text.';
window.__sidePrompt = (desc, view) => 'ref1 is the FRONT view of a small piece (' + desc + ') for a kid-friendly game. Draw the SAME piece exactly (same shapes, parts, colours, proportions, size) as a 3D-rendered toy-like object seen straight-on from the ' + view + ', at mid-height, centered, the same camera height and distance as ref1, only this one piece, no wall, no background objects. Anything that faces one way turns with the piece.' + LIGHT;
window.__VIEWS = { back: 'BACK (the opposite side from ref1)', left: 'LEFT SIDE (camera turned 90 degrees to the left of the front)', right: 'RIGHT SIDE (camera turned 90 degrees to the right of the front)' };
window.__gen = async function (label, refUrl, refBlob, prompt) {
  const S = __sleep; let t0 = Date.now();
  while (__busy() > 0 && Date.now() - t0 < 240000) await S(1000);
  __clearRefs(); await S(1500);
  if (refBlob) await __setRefBlob(refBlob, label + '_ref.png'); else await __setRef(refUrl, label + '_ref.png');
  t0 = Date.now(); while (__deepAll('[data-testid="uploaded-image-remove-button"]').length === 0 && Date.now() - t0 < 30000) await S(800); await S(2500);
  const M = 'openai:firefly:colligo:gpt-image-2.5-prism';
  if (__deepAll('sp-picker')[0].value !== M) await __setPick(0, M);
  const asp = '{"height":1024,"width":1024}'; if (__deepAll('sp-picker')[1].value !== asp) await __setPick(1, asp);
  if (__deepAll('sp-picker')[2].value !== 'high') await __setPick(2, 'high');
  if (__deepAll('sp-picker')[0].value !== M || __deepAll('sp-picker')[2].value !== 'high') { __qLog.push(label + '|PICKER_MISMATCH'); window.__stopList = true; return null; }
  const before = __bigSet();
  __setPrompt(prompt); await S(1500);
  let g = 'disabled';
  if (!__btn().disabled) { __btn().click(); g = 'clicked'; } else { await S(2000); __setPrompt(prompt + ' '); await S(1000); if (!__btn().disabled) { __btn().click(); g = 'clicked2'; } }
  if (g === 'disabled') { __qLog.push(label + '|DISABLED'); window.__stopList = true; return null; }
  t0 = Date.now(); while (__busy() === 0 && Date.now() - t0 < 15000) await S(500);
  let fresh = null; t0 = Date.now();
  while (Date.now() - t0 < 360000) { await S(2000); if (__busy() > 0) continue; const now = __bigSet(); const nu = [...now].filter(u => !before.has(u)); if (nu.length) { fresh = nu[0]; break; } }
  if (!fresh) { __qLog.push(label + '|NO_RESULT'); window.__stopList = true; return null; }
  const blob = await (await fetch(fresh)).blob(); window.__all[label] = blob; await S(800);
  __qLog.push(label + '|ok|' + blob.size + '|' + new Date().toISOString().slice(11, 19));
  return blob;
};
window.__runItems = async (items) => {
  for (const it of items) {
    if (window.__stopList) { __qLog.push('STOPPED'); return; }
    if (!__fronts[it.k]) { const b = await __gen(it.k + '_front', it.ref, null, it.front); if (!b) return; __fronts[it.k] = b; }
    for (const v of ['back', 'left', 'right']) { if (window.__stopList) { __qLog.push('STOPPED'); return; } const b = await __gen(it.k + '_' + v, null, __fronts[it.k], __sidePrompt(it.desc, __VIEWS[v])); if (!b) return; }
  }
  __clearRefs(); __qLog.push('ALLDONE');
};

// Free-form task list: [{k, view, ref: 'https://at.adobe.com/...' (front only) , prompt}] ; non-front tasks use the NEW front of k (__fronts[k]) as reference.
window.__tasks = async (tasks) => { for (const t of tasks) { if (window.__stopList) { __qLog.push('STOPPED'); return; } const front = t.view === 'front'; const b = await __gen(t.k + '_' + t.view, front ? t.ref : null, front ? null : __fronts[t.k], t.prompt); if (!b) return; if (front) __fronts[t.k] = b; } __clearRefs(); __qLog.push('ALLDONE'); };
