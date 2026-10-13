// Tripo Studio web helpers (Blender 손보기, 10/13). Paste into the page (javascript_exec, tabId seed) after login.
// Then: await (eval(localStorage.getItem('hhSetFn')))(name,'/hh-bundleN','hhIdxN'); hhGoFn(); hhTexFn(id8,key,bname,idxName); hhPbrFn(id8).
// Bundles: one Adobe upload of concatenated PNGs -> caches.open('hh').put('/hh-bundleN') + localStorage hhIdxN {key:[offset,size]}.
localStorage.setItem('hhTexFn', `async (id,key,bname,idxName)=>{
const IDX=Object.assign({"HaloChunk_LampArm_front":[0,1259334]}, JSON.parse(localStorage.getItem(idxName||'hhIdx3')));
const P=()=>document.querySelector('#__nuxt').__vue_app__.config.globalProperties.$pinia.state.value; const out={id};
const bundle=await (await (await caches.open('hh')).match(bname||'/hh-bundle3')).blob(); const [o,s]=IDX[key];
if(!location.pathname.includes(id)) { out.err='wrong page'; return out; }
[...document.querySelectorAll('button')].find(b=>b.innerHTML.includes('i-tripo:add-image v-mid size-4'))?.click(); await new Promise(r=>setTimeout(r,1500));
const sw=document.querySelector('[role=switch]'); if(sw && sw.getAttribute('aria-checked')!=='true') sw.click(); await new Promise(r=>setTimeout(r,500));
const k8=[...document.querySelectorAll('button')].find(b=>b.innerText.trim()==='8K'); if(k8 && k8.getAttribute('data-state')!=='on') k8.click();
const inp=[...document.querySelectorAll('input[type=file]')].find(e=>(e.parentElement?.innerText||'').startsWith('업로드'));
const f=new File([bundle.slice(o,o+s,'image/png')],key+'_ns.png',{type:'image/png'}); out.size=f.size;
const dt=new DataTransfer(); dt.items.add(f); inp.files=dt.files; inp.dispatchEvent(new Event('input',{bubbles:true})); inp.dispatchEvent(new Event('change',{bubbles:true}));
await new Promise(r=>setTimeout(r,8000));
const ts=P()['workspace-texture-store']; out.before=P()['feature-user'].payment.wallet.total_credit;
out.ok=location.pathname.includes(id) && ts.textureTab==='imageGenerate' && ts.delight && ts.textureImage?.image_audit_result==='pass' && document.querySelector('[role=switch]').getAttribute('aria-checked')==='true' && [...document.querySelectorAll('button')].find(b=>b.innerText.trim()==='8K')?.getAttribute('data-state')==='on';
if(out.ok){ [...document.querySelectorAll('button')].find(b=>/텍스처 생성/.test(b.innerText)&&/30/.test(b.innerText)&&!b.disabled).click(); }
await new Promise(r=>setTimeout(r,5000)); out.after=P()['feature-user'].payment.wallet.total_credit; return out; }`);
localStorage.setItem('hhSetFn', `async (n,bname,idxName)=>{ const IDX=JSON.parse(localStorage.getItem(idxName)); const bundle=await (await (await caches.open('hh')).match(bname)).blob();
const setF=async(label,key)=>{const [o,s]=IDX[n+'_'+key]; const inp=[...document.querySelectorAll('input[type=file]')].find(e=>(e.parentElement?.innerText||'').trim().startsWith(label)); if(!inp) return label+': no input'; const f=new File([bundle.slice(o,o+s,'image/png')],n+'_'+key+'_ns.png',{type:'image/png'}); const dt=new DataTransfer(); dt.items.add(f); inp.files=dt.files; inp.dispatchEvent(new Event('input',{bubbles:true})); inp.dispatchEvent(new Event('change',{bubbles:true})); return label+': '+f.size;};
[...document.querySelectorAll('button')].find(b=>b.innerText.trim().startsWith('스마트 메시')&&b.getBoundingClientRect().width<200)?.click(); await new Promise(r=>setTimeout(r,1500));
[...document.querySelectorAll('button')].find(b=>b.innerHTML.includes('i-tripo:multi-view')).click(); await new Promise(r=>setTimeout(r,1500));
const out={n,set:[]}; for(const [lab,key] of [['앞','front'],['왼쪽','right'],['오른쪽','left'],['뒷면','back']]){ out.set.push(await setF(lab,key)); await new Promise(r=>setTimeout(r,2000)); } return out; }`);
localStorage.setItem('hhGoFn', `async ()=>{ await new Promise(r=>setTimeout(r,4000)); const P=()=>document.querySelector('#__nuxt').__vue_app__.config.globalProperties.$pinia.state.value; const st=P()['workspace-generate-store']; const cnt4=[...document.querySelectorAll('button')].some(b=>b.innerText.trim()==='4'&&b.getAttribute('data-state')==='on'); const before=P()['feature-user'].payment.wallet.total_credit;
const imgs=(st.multiViewImages||[]).filter(Boolean).length; const ok= location.pathname==='/ko/workspace/generate' && st.tab==='low_poly' && imgs===4 && cnt4 && !Object.values(st.multiViewUploading).some(x=>x);
if(ok) [...document.querySelectorAll('button')].find(b=>/생성/.test(b.innerText)&&/100/.test(b.innerText)&&!b.disabled).click();
await new Promise(r=>setTimeout(r,6000)); return {ok,imgs,before,after:P()['feature-user'].payment.wallet.total_credit,url:location.pathname}; }`);
localStorage.setItem('hhPbrFn', `async (id)=>{ await new Promise(r=>setTimeout(r,7000)); const P=()=>document.querySelector('#__nuxt').__vue_app__.config.globalProperties.$pinia.state.value; const L=P()['feature-workspace'].current.latest; const before=P()['feature-user'].payment.wallet.total_credit; const b=[...document.querySelectorAll('button')].find(b=>/PBR 생성/.test(b.innerText)&&/5/.test(b.innerText)&&!b.disabled);
const ok=location.pathname.includes(id) && L?.id?.startsWith(id) && /tripo_texture_/.test(L?.model_url||'') && !!b; if(ok) b.click(); await new Promise(r=>setTimeout(r,6000)); return {id, ok, src:(L?.model_url||'').split('?')[0].split('/').pop().slice(0,24), before, after:P()['feature-user'].payment.wallet.total_credit}; }`);
// --- 10/13 additions ---
// Smart Mesh tab button: skip the "스마트 메시 P2.0" banner button.
localStorage.setItem('hhSetFn', localStorage.getItem('hhSetFn').replace("[...document.querySelectorAll('button')].find(b=>b.innerText.trim().startsWith('스마트 메시')&&b.getBoundingClientRect().width<200)?.click();", "[...document.querySelectorAll('button')].find(b=>(b.textContent||'').includes('스마트 메시')&&!(b.textContent||'').includes('P2.0')&&b.getBoundingClientRect().width>0&&b.getBoundingClientRect().width<200)?.click();"));
// Prep = set 4 views + refill empty slots (no spend). Then call hhGoFn separately (45 s tool limit).
localStorage.setItem('hhPrepFn', `async (n,bname,idxName)=>{ const set=await (eval(localStorage.getItem('hhSetFn')))(n,bname,idxName); const IDX=JSON.parse(localStorage.getItem(idxName)); const bundle=await (await (await caches.open('hh')).match(bname)).blob(); const map={'앞':'front','왼쪽':'right','오른쪽':'left','뒷면':'back'}; const fixes=[];
for(let t=0;t<3;t++){ await new Promise(r=>setTimeout(r,6000)); const empt=[...document.querySelectorAll('input[type=file]')].map(e=>[e,(e.parentElement?.innerText||'').trim()]).filter(([e,l])=>map[l]); if(!empt.length) break; for(const [inp,l] of empt){ const key=map[l]; const [o,s]=IDX[n+'_'+key]; const f=new File([bundle.slice(o,o+s,'image/png')],n+'_'+key+'_ns.png',{type:'image/png'}); const dt=new DataTransfer(); dt.items.add(f); inp.files=dt.files; inp.dispatchEvent(new Event('input',{bubbles:true})); inp.dispatchEvent(new Event('change',{bubbles:true})); fixes.push(l); await new Promise(r=>setTimeout(r,2500)); } }
const st=document.querySelector('#__nuxt').__vue_app__.config.globalProperties.$pinia.state.value['workspace-generate-store']; return {n,fixes,imgs:(st.multiViewImages||[]).filter(Boolean).length,tab:st.tab}; }`);
// Texture queue: localStorage hhTexQ=[{k:id8,full:uuid,key:'<name>_front',b:bundleNo}], hhTexI=index. Each call textures the current item, then moves the page to the next one.
localStorage.setItem('hhTexDo', `async ()=>{ const q=JSON.parse(localStorage.getItem('hhTexQ')); const i=+localStorage.getItem('hhTexI'); const it=q[i]; if(!it) return 'done'; if(!location.pathname.includes(it.full)){ location.href='/ko/workspace/texture/'+it.full; return 'nav '+i+' '+it.key; } await new Promise(r=>setTimeout(r,5000)); const r=await (eval(localStorage.getItem('hhTexFn')))(it.k,it.key,'/hh-bundle'+it.b,'hhIdx'+it.b); if(r.ok) localStorage.setItem('hhTexI',String(i+1)); r.i=i; r.key=it.key; const nx=q[i+1]; if(r.ok&&nx) setTimeout(()=>{location.href='/ko/workspace/texture/'+nx.full},300); return r; }`);
// Timer-free sleep (setTimeout is throttled when the pane is hidden). Run eval(localStorage.getItem('hhSleepDef')) at the start of every call.
localStorage.setItem('hhSleepDef', `window.__hhSleep=(ms)=>new Promise(res=>{const end=Date.now()+ms; const ch=new MessageChannel(); ch.port1.onmessage=()=>{ if(Date.now()>=end){ch.port1.close(); res();} else fetch('data:,').then(()=>ch.port2.postMessage(0)); }; ch.port2.postMessage(0);});`);
for(const k of ['hhTexFn','hhSetFn','hhGoFn','hhPbrFn','hhPrepFn','hhTexDo']) localStorage.setItem(k, localStorage.getItem(k).replace(/new Promise\(r=>setTimeout\(r,(\d+)\)\)/g,'window.__hhSleep($1)'));
// NOTE: the Tripo page only runs while this session's browser pane is visible on screen.
'hh helpers installed'
