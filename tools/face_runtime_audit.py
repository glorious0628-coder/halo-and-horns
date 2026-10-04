"""Read-only assets and reversible Play-only probes, via Studio MCP (no desktop input)."""
import argparse
import base64
import hashlib
import json
import re
from pathlib import Path
import sys

from studio_mcp import Client

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/art/verification_2026-10-04/face_runtime_audit'
TEMP = ROOT / 'build/face_sharp_runtime_20261004'


def run(label, code, model='Client'):
    OUT.mkdir(parents=True, exist_ok=True)
    TEMP.mkdir(parents=True, exist_ok=True)
    payload = {'datamodel_type': model, 'code': code}
    (OUT / f'{label}_request.json').write_text(json.dumps(payload, indent=2), encoding='utf-8')
    c = Client()
    try:
        c.start()
        result = c.call('execute_luau', payload)
    finally:
        c.close()
    (TEMP / f'{label}_response.json').write_text(json.dumps(result), encoding='utf-8')
    if result.get('isError'):
        (OUT / f'{label}_error.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        raise RuntimeError(result)
    raw = ''.join(p.get('text', '') for p in result.get('content', []))
    try:
        data = json.loads(raw)
    except ValueError:
        data = {'message': raw}
    if isinstance(data, dict) and 'base64' in data:
        binary = base64.b64decode(data.pop('base64'))
        if data.get('encoding') == 'rgba':
            from PIL import Image
            Image.frombytes('RGBA', tuple(data['size']), binary).save(OUT / f'{label}.png')
        else:
            (OUT / f'{label}.png').write_bytes(binary)
        data['image_file'] = f'{label}.png'
        data['image_sha256'] = hashlib.sha256((OUT / f'{label}.png').read_bytes()).hexdigest()
    # Account thumbnails are relevant only as a fallback, never as a user identity in evidence.
    data = json.loads(re.sub(r'(rbxthumb://type=AvatarHeadShot&id=)\d+', r'\1LOCAL_USER', json.dumps(data)))
    (OUT / f'{label}.json').write_text(json.dumps(data, indent=2), encoding='utf-8')
    print(json.dumps(data, ensure_ascii=False)[:7000])
    return data


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('label')
    parser.add_argument('lua_file')
    parser.add_argument('--model', default='Client', choices=['Client', 'Edit', 'Server'])
    args = parser.parse_args()
    run(args.label, Path(args.lua_file).read_text(encoding='utf-8'), args.model)
