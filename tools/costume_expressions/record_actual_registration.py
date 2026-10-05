# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Record a completed rigid expression registration from actual QA evidence.

Offline only. This does not upload, call Studio, edit game source, promote rigs,
or change the local-production manifests. The resulting record is an audited
snapshot of a root-owned import/engine validation, not a fresh Studio query.
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def demand(condition, message):
    if not condition:
        raise ValueError(message)


def qa_rows(path):
    rows = load(path)
    demand(isinstance(rows, list) and rows, 'Actual QA rows required: ' + str(path))
    demand(all(r.get('error') is False for r in rows), 'Actual QA has errors: ' + str(path))
    return {label: [r for r in rows if r['label'] == label]
            for label in {r['label'] for r in rows}}


def decoded(rows, label):
    demand(label in rows, 'Missing actual QA: ' + label)
    demand(len(rows[label]) == 1, 'Ambiguous required QA label: ' + label)
    return json.loads(rows[label][0]['text'])


def expression(rows, label, state, textures, with_costume=None):
    row = decoded(rows, label)
    demand(row.get('expression') == state and row.get('ready') is True,
           'State/ready failed: ' + label)
    demand(row.get('face', row.get('texture')) == textures[state],
           'Texture differs: ' + label)
    if with_costume:
        demand(row.get('costume') == with_costume and row.get('status') == 'Active',
               'Costume differs: ' + label)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['local-manifest', 'graft-plan', 'actual-graft', 'promotion-result',
                 'live-qa', 'talk-qa', 'lifecycle', 'instance-preload']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--registration-source', type=Path,
                        default=ROOT / 'src/ReplicatedStorage/Shared/ExpressionAssets.luau')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    demand(not args.output.exists(), 'Refuse silent registration-record replacement')
    manifest = load(args.local_manifest)
    plan = load(args.graft_plan)
    graft = load(args.actual_graft)
    promotion = load(args.promotion_result)
    avatar = manifest['avatar']
    demand(re.fullmatch(r'Costume_[A-Za-z]+', avatar), 'Unexpected avatar identifier')
    head = ROOT / manifest['head_asset']
    demand(sha(head) == manifest['head_sha256'] == plan['head_sha256'] == graft['head_sha256'],
           'Local head and imported head evidence differ')
    demand(plan['avatar'] == avatar and plan['offline_exact_uv_proof'] is True,
           'Missing offline exact UV proof')
    validation = load(args.local_manifest.with_name('validation.json'))
    demand(validation.get('validated') is True and validation['head_sha256'] == sha(head),
           'Local validated Head SHA changed')
    records = {r['state']: r for r in manifest['records']}
    demand(set(records) == {'Neutral', 'SoftSmile', 'Serious'}, 'Three approved states required')
    for row in records.values():
        demand(sha(ROOT / row['png']) == row['sha256'], 'Current expression PNG changed')
    textures = plan['textures']
    demand(graft['textures'] == textures and graft['preserved_neck_c0_c1'] is True,
           'Actual graft textures or preserved Neck differ')
    face_id = plan['imports']['FaceExpression']['mesh_id']
    head_id = plan['imports']['HeadBase']['mesh_id']
    demand(graft['face_mesh_id'] == promotion['face'] == face_id and
           graft['head_mesh_id'] == promotion['head'] == head_id,
           'Actual promotion mesh IDs differ')
    destination = 'ServerStorage.CostumeRigs.' + avatar
    demand(promotion.get('validated') is True and promotion['destination'] == destination,
           'Actual Ready promotion has not passed')
    demand(promotion.get('archived', '').startswith('ServerStorage.CostumeRigArchive.'),
           'Old Ready archive evidence required')

    source = args.registration_source.read_text(encoding='utf-8')
    blocks = re.findall(r'\b' + re.escape(avatar) + r'\s*=\s*\{([^{}]*)\}', source)
    demand(len(blocks) == 1, 'Actual source registration must be unique')
    registered = dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', blocks[0]))
    demand(all(registered.get(s) == textures[s] for s in textures) and
           registered.get('MeshName') == 'FaceExpression', 'Actual source registration differs')

    live = qa_rows(args.live_qa)
    for label, state in [('neutral', 'Neutral'), ('after_attack', 'Serious'),
                         ('attack_expiry', 'Neutral'), ('after_hurt', 'Serious')]:
        expression(live, label, state, textures, avatar)
    talk = qa_rows(args.talk_qa)
    for label, state in [('talk', 'SoftSmile'), ('hurt_priority', 'Serious'),
                         ('resume_talk', 'SoftSmile'), ('neutral_expired', 'Neutral')]:
        expression(talk, label, state, textures)
    life = qa_rows(args.lifecycle)
    off = decoded(life, 'off_state')
    demand(off.get('applied') is False and off.get('enabled') is False and
           off.get('status') == 'Avatar' and decoded(life, 'off_face').get('face') is False,
           'OFF personal-avatar/expression cleanup did not pass')
    for state_label, face_label in [('on_state', 'on_face'), ('respawn', 'respawn_face')]:
        on = decoded(life, state_label)
        demand(on.get('id') == avatar and on.get('applied') is True and
               on.get('enabled') is True and on.get('status') == 'Active',
               'ON/respawn actual costume failed')
        expression(life, face_label, 'Neutral', textures)

    preload = load(args.instance_preload)
    demand(preload.get('isError') is False, 'Instance preload execution failed')
    preload_rows = json.loads(next(c['text'] for c in preload['content'] if c['type'] == 'text'))
    for state in ['Serious', 'SoftSmile']:
        matching = [r for r in preload_rows if r.get('texture') == textures[state]]
        demand({r['id'] for r in matching if r.get('status') == 'Success'} >=
               {face_id, textures[state]}, 'Actual instance preload failed: ' + state)

    evidence = {}
    for name in ['local_manifest', 'graft_plan', 'actual_graft', 'promotion_result',
                 'live_qa', 'talk_qa', 'lifecycle', 'instance_preload', 'registration_source']:
        path = getattr(args, name).resolve()
        evidence[name] = {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}
    result = {'schema': 1, 'avatar': avatar, 'pipeline': 'rigid_head_expression',
              'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
              'head_asset': manifest['head_asset'], 'head_sha256': sha(head),
              'face_mesh_id': face_id, 'head_mesh_id': head_id, 'textures': textures,
              'texture_png_sha256': {s: r['sha256'] for s, r in records.items()},
              'ready_destination': destination, 'old_ready_archive': promotion['archived'],
              'roblox_uploaded': True, 'source_registered': True, 'runtime_validated': True,
              'qa': {'attack_hurt_expiry': True, 'talk_hurt_priority_expiry': True,
                     'off_personal_avatar_cleanup': True, 'on_respawn_neutral': True,
                     'actual_instance_preload': True}, 'evidence': evidence,
              'scope': 'Actual recorded root-owned QA snapshot; this tool does not query current Studio.',
              'studio_called': False, 'source_edited': False, 'local_manifests_edited': False}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'avatar': avatar, 'output': str(args.output), 'runtime_validated': True,
                      'studio_called': False, 'source_edited': False}))


if __name__ == '__main__':
    main()
