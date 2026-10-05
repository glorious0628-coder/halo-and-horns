# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Upload two reviewed expression textures with an outcome ledger and bounded local server."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import datetime
import hashlib
import json
import re
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    parser.add_argument('--tag', default='')
    args=parser.parse_args()
    assert args.name.startswith('Costume_') and args.name.replace('_','').isalnum()
    assert not args.tag or re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,40}',args.tag)
    root=Path(__file__).resolve().parents[2]
    folder=root/'build/costume_skin_expression_imports'/(args.name+('_'+args.tag if args.tag else ''))
    p=folder/'texture_upload_ledger.json'
    d=json.loads(p.read_text(encoding='utf-8'))
    imported=json.loads((folder/'importer_ledger.json').read_text(encoding='utf-8'))
    assert imported['stage']=='Complete' and imported['model']==args.name
    assert imported.get('batch_tag', '')==args.tag
    assert d['stage']=='Prepared' and d['root_reviewed'] and d['whole_batch_maximum_assets']<=10
    assert d['states']==['Serious','SoftSmile'] and d['maximum_assets']==2
    data={}
    for state in d['states']:
        source=(root/d['files'][state]).resolve()
        assert source.is_relative_to(root/'art') and not source.is_relative_to(root/'art/out/v1')
        raw=source.read_bytes()
        assert hashlib.sha256(raw).hexdigest()==d['source_sha256'][state]
        data['/'+state+'.png']=raw
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            raw=data.get(self.path)
            if raw is None:self.send_error(404);return
            self.send_response(200);self.send_header('Content-Type','image/png')
            self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
        def log_message(self,*unused):pass
    server=ThreadingHTTPServer(('127.0.0.1',8766),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    c=Client()
    try:
        c.start()
        d.update(stage='Submitting',submitted_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
        p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        r=c.call('upload_image',{'imagePaths':['http://127.0.0.1:8766/'+s+'.png' for s in d['states']]})
        d['actual']=r
        d['stage']='Unknown' if r.get('isError') else 'Complete'
        d['completed_at']=datetime.datetime.now(datetime.timezone.utc).isoformat()
        p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        for block in r.get('content',[]):
            if block.get('type')=='text':print(block['text'],flush=True)
        if r.get('isError'):raise RuntimeError('Recorded unknown upload result; do not resubmit')
    finally:
        c.close();server.shutdown();server.server_close();thread.join(timeout=2)

if __name__=='__main__':main()
