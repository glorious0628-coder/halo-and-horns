import json,sys
S,tab,gfile=sys.argv[1],sys.argv[2],sys.argv[3]
groups=json.load(open(gfile))
call="await (new Function('return (async()=>{'+localStorage.getItem('__g')+'})()'))()"
init="localStorage.setItem('__g', \"const id=location.pathname.slice(-36); let u=null; for(let i=0;i<60;i++){try{const c=document.querySelector('#__nuxt').__vue_app__.config.globalProperties.$pinia._s.get('feature-workspace').current; if(c.latest&&c.latest.id==id&&c.latest.model_url){u=c.latest.model_url;break;}}catch(e){} await new Promise(r=>setTimeout(r,250));} const o=JSON.parse(localStorage.getItem('__dr_urls')||'{}'); if(u){o[id]=u; localStorage.setItem('__dr_urls',JSON.stringify(o));} return [id.slice(0,8),!!u,Object.keys(o).length];\"); localStorage.removeItem('__dr_urls'); "+call
dump=r"""const o=JSON.parse(localStorage.getItem('__dr_urls')||'{}'); localStorage.removeItem('__dr_urls'); Object.entries(o).map(([k,u])=>{const m=u.match(/tripo-studio\/(\d+)\/([0-9a-f-]{36})\/output_mesh_[0-9a-f-]{36}\.fbx\?.*Policy=([^&]+)&Signature=(.+)$/); const pol=atob(m[3].replace(/-/g,'+').replace(/_/g,'=').replace(/~/g,'/')); return k.slice(0,8)+' '+m[1]+' '+m[2]+' '+pol.match(/EpochTime":(\d+)/)[1]+' '+m[4]}).join(' ;; ')"""
acts=[]; first=True
for g,ids in groups.items():
  for i in ids:
    acts.append({"name":"navigate","input":{"tabId":tab,"url":"https://studio.tripo3d.ai/ko/workspace/generate/"+i}})
    acts.append({"name":"javascript_tool","input":{"tabId":tab,"action":"javascript_exec","text":init if first else call}})
    first=False
acts.append({"name":"javascript_tool","input":{"tabId":tab,"action":"javascript_exec","text":dump}})
for n in range(0,len(acts),24):
  open(f'{S}/bb_{n//24}.json','w').write(json.dumps(acts[n:n+24]))
print(len(acts))
