import json,sys
S,gfile,raw,out=sys.argv[1:5]
g=json.load(open(gfile))
lab={i[:8]:f'{k}_{n+1}_{i[:8]}' for k,ids in g.items() for n,i in enumerate(ids)}
res=[]
for r in open(raw).read().strip().split(' ;; '):
  id8,date,uid,ep,sig=r.split()
  res.append(f'{lab[id8]} {date} {uid} output_mesh_{uid}.fbx {ep} {sig}')
open(out,'w').write('\n'.join(res)+'\n'); print(len(res))
