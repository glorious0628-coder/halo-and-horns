"""Read-only REST reconciliation and local ledgers for the R2 G2 checkpoint."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import shutil

import tripo_api as api

ROOT = Path(__file__).resolve().parents[1]
R2 = ROOT / 'art/models/costume/redraw/r2'


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    records = R2 / 'records'
    records.mkdir(parents=True, exist_ok=True)
    source = ROOT / 'art/out/APose_HaloArcherM_Sharp_D.png'
    expected = '649ce86f007b2762e70bb1fc8d494351520de4f024d1a876c9225b94e6160b0a'
    assert hashlib.sha256(source.read_bytes()).hexdigest() == expected
    balance = api.call('GET', '/account/balance')
    if not (records / 'balance_start.json').exists():
        save(records / 'balance_start.json', {'at_utc': datetime.now(timezone.utc).isoformat(),
                                            'endpoint': 'GET /v3/account/balance', 'response': balance})
    folders = ['generation-c22df695', 'tripo-out/costume-haloarcherm-sharpd-rig-c-a532384f',
               'tripo-out/costume-haloarcherm-sharpd-rig-96aa4858']
    known = json.loads(Path(api.RECORDS).read_text(encoding='utf-8'))
    entries = []
    for folder in folders:
        path = ROOT / 'art/models/costume/redraw' / folder / 'task.json'
        local = json.loads(path.read_text(encoding='utf-8'))
        remote = api.call('GET', '/tasks/' + local['task_id'])
        filtered = {key: remote.get(key) for key in ('task_id', 'type', 'status', 'input',
                                                     'credits_consumed', 'created_at', 'completed_at')}
        save(records / (local['task_id'] + '.json'), filtered)
        entry = {'event': 'historical_R1_reconciled', 'task_id': local['task_id'],
                 'operation': local['type'], 'status': remote.get('status'),
                 'credits': remote.get('credits_consumed'), 'source_record': str(path.relative_to(ROOT)),
                 'reconciled_at_utc': datetime.now(timezone.utc).isoformat()}
        if not any(row.get('event') == entry['event'] and row.get('task_id') == entry['task_id']
                   for values in known.values() if isinstance(values, list) for row in values if isinstance(row, dict)):
            api.record('Costume_HaloArcherM_SharpD_R1', entry)
        entries.append(entry)
    save(records / 'r1_reconciliation.json', {'entries': entries,
         'actual_credits_total': sum(row['credits'] for row in entries),
         'new_paid_requests': 0, 'original_records_preserved': True})
    # Preserve the oddly named predecessor artifact exactly, while correcting its provenance.
    old = ROOT / '--output'
    target = records / 'r1_cli_output.json'
    if old.exists():
        assert old.resolve().parent == ROOT.resolve() and target.resolve().is_relative_to(R2.resolve())
        assert not target.exists()
        digest = hashlib.sha256(old.read_bytes()).hexdigest()
        content = json.loads(old.read_text(encoding='utf-8'))
        shutil.move(str(old), str(target))
        assert hashlib.sha256(target.read_bytes()).hexdigest() == digest
        save(records / 'r1_cli_output_provenance.json', {'old_path': '--output',
             'preserved_path': str(target.relative_to(ROOT)), 'sha256': digest,
             'actual_kind': content.get('kind'),
             'note': 'Despite the requested archive filename, this is HornsMageM mouth-winding metadata, not Tripo R1 CLI output.'})
    old_plan = ROOT / 'docs/art/tripo_sharp_d_plan_2026-10-04.json'
    plan = json.loads(old_plan.read_text(encoding='utf-8'))
    plan['plan_status'] = 'R1_completed_reconciled_at_R2'
    plan['paid_submissions'] = sum(row['credits'] > 0 for row in entries)
    plan['actual_credits_total'] = sum(row['credits'] for row in entries)
    plan['actual_tasks'] = entries
    plan['r2_current_balance'] = balance
    plan['r1_end_balance_inferred'] = plan['balance_at_preflight'] - plan['actual_credits_total']
    plan['r1_end_balance_inferred_is_not_historical_api_snapshot'] = True
    save(old_plan, plan)
    r2_plan_path = ROOT / 'docs/art/tripo_sharp_d_r2_plan_2026-10-04.json'
    initial_plan = {
        'status': 'preparing_G2_free_B0H', 'gates': ['G2', 'G1', 'G3'],
        'prior_work_commits': ['0f7549e', '79ddb8b'], 'source': str(source.relative_to(ROOT)),
        'source_sha256': expected, 'balance_start': balance, 'paid_submissions': 0,
        'paid_credits': 0, 'automatic_paid_retries': 0, 'roblox_uploads': 0,
        'credits': {'image_to_multiview': 10, 'optional_edit_multiview_max': 20,
                    'three_candidates': 180, 'optional_retexture_max': 40, 'selected_rig': 25,
                    'base_total': 215, 'maximum_total': 275, 'B0H_existing_rig_reuse': 0},
        'G2_approval': None, 'G1_approval': None, 'G3_selection': None,
        'paid_transport': 'tools/tripo_api.py REST only; paid POST retries=0',
        'reference_only_previews': True}
    # A rerun may reconcile old tasks but must never erase a gate decision.
    if not r2_plan_path.exists():
        save(r2_plan_path, initial_plan)
    print(json.dumps({'balance': balance, 'R1_actual_credits': sum(row['credits'] for row in entries),
                      'R2_paid_credits': 0}, ensure_ascii=False))


if __name__ == '__main__':
    main()
