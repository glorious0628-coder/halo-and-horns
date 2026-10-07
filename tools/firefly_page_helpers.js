// Firefly web (firefly.adobe.com/generate/image) page helpers for the built-in browser (javascript_exec), image
// sessions. Paste the whole file once per page load (a reload loses them). The Firefly app renders in a tab opened by
// preview_start (the first "seed" tab can stay blank); wait until __ready() is true.
// Pickers: 0 = model ('openai:firefly:colligo:gpt-image-2.5-prism'), 1 = aspect ('{"height":1024,"width":1024}'),
// 2 = quality ('low' | 'medium' | 'high'; high = 5 credits, needs approval). Prompts must be <= 1024 characters.
// Download the result afterwards with the Adobe MCP: asset_search (GenAIAsset, createDate desc) ->
// asset_get_presigned_urls -> curl -sL. Put quality back to 'medium' and clear references when done.
function deepAll(sel, root = document, out = []) {
  root.querySelectorAll(sel).forEach(e => out.push(e));
  root.querySelectorAll('*').forEach(e => { if (e.shadowRoot) deepAll(sel, e.shadowRoot, out); });
  return out;
}
window.__deepAll = deepAll;
window.__sleep = ms => new Promise(r => setTimeout(r, ms));
window.__ta = () => __deepAll('textarea')[0];
window.__btn = () => __deepAll('[data-testid="generate-image-generate-button"]')[0];
window.__ready = () => !!(__ta() && __btn());
window.__pick = async (idx, value) => {
  const p = __deepAll('sp-picker')[idx];
  p.open = true;
  await __sleep(700);
  const it = __deepAll('sp-menu-item').find(i => (i.value || i.getAttribute('value') || '') === value);
  if (it) it.click();
  await __sleep(900);
  return __deepAll('sp-picker')[idx].value;
};
window.__setPrompt = (text) => {
  const ta = __ta();
  ta.focus();
  Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(ta, text);
  ta.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
  ta.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
  return { len: ta.value.length, disabled: __btn().disabled };
};
window.__realGen = () => { const b = __btn(); if (b.disabled) return 'disabled'; b.click(); return 'clicked'; };
window.__busy = () => __deepAll('sp-progress-circle, sp-progress-bar, [role=progressbar]')
  .filter(e => e.offsetParent !== null || e.getClientRects().length).length;
window.__seenBlobs = new Set();
window.__blobs = () => {
  __deepAll('img').forEach(i => { const s = i.currentSrc || i.src; if (s && s.startsWith('blob:')) __seenBlobs.add(s); });
  return __seenBlobs.size;
};
// reference image from a CORS-readable URL (at.adobe.com presigned links work)
window.__setRef = async (url, name) => {
  const res = await fetch(url, { credentials: 'omit' });
  const blob = await res.blob();
  const file = new File([blob], name, { type: blob.type || 'image/png' });
  const input = __deepAll('input[type=file]#file-input')[0];
  if (!input) return { status: res.status, size: blob.size, input: false };
  const dt = new DataTransfer();
  dt.items.add(file);
  input.files = dt.files;
  input.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
  input.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
  return { status: res.status, size: blob.size, type: blob.type };
};
window.__clearRefs = () => { const b = __deepAll('[data-testid="uploaded-image-remove-button"]'); b.forEach(x => x.click()); return b.length; };
// queue: [{ key, prompt, n?, ref?, quality? ('medium' default) }] -> window.__qLog lines "key#i|clicked|time|..."
window.__qLog = [];
window.__runList = async (list) => {
  const S = __sleep;
  for (const it of list) {
    for (let rep = 0; rep < (it.n || 1); rep++) {
      if (window.__stopList) { __qLog.push('STOPPED'); return; }
      let t0 = Date.now(); while (__busy() > 0 && Date.now() - t0 < 240000) await S(1000);
      if (rep === 0) {
        __clearRefs(); await S(1500);
        if (it.ref) {
          await __setRef(it.ref, it.key + '_ref.png');
          t0 = Date.now(); while (__deepAll('[data-testid="uploaded-image-remove-button"]').length === 0 && Date.now() - t0 < 30000) await S(800);
          await S(2500);
        }
        if (__deepAll('sp-picker')[0].value !== 'openai:firefly:colligo:gpt-image-2.5-prism') await __pick(0, 'openai:firefly:colligo:gpt-image-2.5-prism');
        if (__deepAll('sp-picker')[1].value !== (it.aspect || '{"height":1024,"width":1024}')) await __pick(1, it.aspect || '{"height":1024,"width":1024}');
        if (__deepAll('sp-picker')[2].value !== (it.quality || 'medium')) await __pick(2, it.quality || 'medium');
      }
      const before = __blobs();
      __setPrompt(it.prompt + ' '.repeat(rep)); await S(800);
      let g = __realGen();
      if (g === 'disabled') { await S(1500); __setPrompt(it.prompt + ' '.repeat(rep + 1)); await S(800); g = __realGen(); }
      t0 = Date.now(); while (__busy() === 0 && Date.now() - t0 < 15000) await S(500);
      t0 = Date.now(); while ((__busy() > 0 || __blobs() <= before) && Date.now() - t0 < 300000) await S(1500);
      __qLog.push(it.key + '#' + (rep + 1) + '|' + g + '|' + new Date().toISOString().slice(11, 19) + '|q=' + __deepAll('sp-picker')[2].value);
    }
  }
  __clearRefs();
  if (__deepAll('sp-picker')[2].value !== 'medium') await __pick(2, 'medium');
  __qLog.push('DONE');
};
JSON.stringify({ ready: __ready(), pickers: __deepAll('sp-picker').map(p => p.value) });
