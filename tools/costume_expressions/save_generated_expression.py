# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Copy a builtin GPT output unchanged and record its prompt/source checksum."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('source',type=Path);p.add_argument('avatar');p.add_argument('state',choices=['Neutral','SoftSmile','Serious'])
a=p.parse_args();root=Path(__file__).resolve().parents[2]
if 'generated_images' not in a.source.parts:raise ValueError('Builtin GPT generated_images source required')
folder=root/'art/models/costume/expressions'/a.avatar
output=folder/(a.avatar+'_Expression_'+a.state+'_face.png')
if output.exists():raise ValueError('Refuse silent replacement; use a separate versioned variant')
shutil.copy2(a.source,output)
data=output.read_bytes()
if data[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('PNG source required')
meta={'avatar':a.avatar,'state':a.state,'png':output.relative_to(root).as_posix(),
 'size':list(struct.unpack_from('>II',data,16)),'sha256':hashlib.sha256(data).hexdigest(),
 'builtin_gpt_generated':True,'source':str(a.source.resolve()),
 'prompt':(folder/'prompts'/(a.state+'.txt')).relative_to(root).as_posix(),
 'quality_status':'candidate; actual R15 front/quarter QA pending','roblox_uploaded':False,'runtime_validated':False}
output.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
print(json.dumps(meta))
