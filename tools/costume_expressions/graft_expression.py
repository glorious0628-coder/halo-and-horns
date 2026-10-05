# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Build an offline, guarded pilot expression graft payload; never call Studio.

Only a clone in CostumePendingExpressions is changed. Actual two-piece importer
dimensions and the nonzero three-axis center delta must uniquely prove one proper
signed-axis bake. Existing primary Head extents/bake must coincide so every Neck
C0/C1, attachment and auxiliary weld can stay unchanged.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/costume_r15'))
from assemble import cube_rotations
from glb_io import accessor_values, read_glb


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def asset(value):
    if not isinstance(value, str) or not re.fullmatch(r'rbxassetid://[1-9][0-9]{0,19}', value):
        raise ValueError('An actually uploaded Roblox asset ID is required')
    return value


def geometry(path):
    doc, binary, _ = read_glb(path)
    result = {}
    for node in doc['nodes']:
        if 'mesh' not in node:
            continue
        if any(k in node for k in ('matrix', 'rotation', 'scale')):
            raise ValueError('Only verified canonical translation nodes are supported')
        mesh = doc['meshes'][node['mesh']]
        points = []
        for primitive in mesh['primitives']:
            pos = np.asarray(accessor_values(doc, binary, primitive['attributes']['POSITION']))
            indices = np.asarray(accessor_values(doc, binary, primitive['indices']), int).reshape(-1)
            points.extend(pos[indices])
        points = np.asarray(points) + node.get('translation', [0, 0, 0])
        center = (points.max(axis=0) + points.min(axis=0)) / 2
        size = points.max(axis=0) - points.min(axis=0)
        if np.min(size) < .001:
            raise ValueError('Degenerate imported mesh; no invented size padding')
        result[node['name']] = {'center': center, 'size': size}
    if set(result) != {'HeadBase', 'FaceExpression'}:
        raise ValueError('Exactly the verified two head meshes are required')
    return result


def solve_importer(expected, rows):
    rotations = [np.asarray(rows[name]['cframe'][3:]).reshape(3, 3) for name in expected]
    if max(np.max(np.abs(r - rotations[0])) for r in rotations) > 1e-5:
        raise ValueError('Importer piece rotations differ')
    rotation = rotations[0]
    if np.max(np.abs(rotation.T @ rotation - np.eye(3))) > 1e-5 or np.linalg.det(rotation) < .999:
        raise ValueError('Actual importer rotation is not proper and orthonormal')
    source_delta = expected['FaceExpression']['center'] - expected['HeadBase']['center']
    if np.min(np.abs(source_delta)) < .001:
        raise ValueError('Two-piece center delta cannot prove all three axis signs')
    matches = []
    for raw in cube_rotations():
        bake = np.asarray(raw, float)
        ratios = []
        valid = True
        for name, shape in expected.items():
            for key in ('size', 'mesh_size'):
                values = np.asarray(rows[name].get(key, []), float)
                if values.shape != (3,) or np.min(values) <= 0:
                    raise ValueError('Actual nondegenerate Size and MeshSize are required')
                ratio = values / (np.abs(bake) @ shape['size'])
                ratios.extend(ratio.tolist())
            pivot = np.asarray(rows[name]['pivot_offset'], float)
            if np.max(np.abs(pivot[:3])) > 1e-5 or np.max(np.abs(pivot[3:] - np.eye(3).flatten())) > 1e-5:
                raise ValueError('Only actually observed zero importer pivots are supported')
        scale = float(np.mean(ratios))
        size_error = float(np.max(np.abs(np.asarray(ratios) / scale - 1)))
        if size_error > 1e-4:
            continue
        offsets = [np.asarray(rows[name]['cframe'][:3]) - scale * rotation @ bake @ shape['center']
                   for name, shape in expected.items()]
        offset = np.mean(offsets, axis=0)
        error = float(max(np.max(np.abs(v - offset)) for v in offsets))
        if error > max(2e-5, scale * 2e-5):
            continue
        matches.append({'bake': bake.tolist(), 'scale': scale, 'offset': offset.tolist(),
                        'maximum_center_error': error, 'maximum_relative_size_error': size_error})
    if len(matches) != 1:
        raise ValueError(f'Proper importer bake is not unique: {len(matches)} candidates')
    return matches[0]


LUA = r'''
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
if game:GetService("RunService"):IsRunning() then error("표정 후보 조립은 Edit 모드에서 실행합니다.") end
local DATA = HttpService:JSONDecode(__DATA__)
local function vector(v) return {v.X, v.Y, v.Z} end
local function same(a, b, label)
    if #a ~= #b then error("검증 배열 길이 불일치: " .. label) end
    for i, value in a do
        if math.abs(value - b[i]) > 0.0001 then error("검증 속성 변경: " .. label) end
    end
end
local readyFolder = ServerStorage:FindFirstChild("CostumeRigs")
local ready = readyFolder and readyFolder:FindFirstChild(DATA.avatar)
if not ready or not ready:IsA("Model") then error("기존 게임용 코스튬이 없습니다.") end
if ready:GetAttribute("HHC_SourceSHA256") ~= DATA.original_source_sha256 then error("기존 리그 원본 SHA가 다릅니다.") end
local importsFolder = ServerStorage:FindFirstChild("CostumeExpressionImports")
local source = importsFolder and importsFolder:FindFirstChild(DATA.avatar)
if not source then error("실제 표정 임포트 모델이 없습니다.") end
local pieces = {}
for _, part in source:GetDescendants() do
    if part:IsA("MeshPart") then
        local role
        for name, row in DATA.imports do if part.MeshId == row.mesh_id then role = name end end
        if not role or pieces[role] then error("표정 임포트 메시 ID가 누락되거나 중복됐습니다.") end
        local row = DATA.imports[role]
        if part.TextureID ~= row.texture_id then error("검사 후 TextureID 변경: " .. role) end
        if part:FindFirstChildOfClass("SurfaceAppearance") then error("TextureID 전환 대상에 SurfaceAppearance가 있습니다.") end
        same(vector(part.Size), row.size, role .. ".Size")
        same(vector(part.MeshSize), row.mesh_size, role .. ".MeshSize")
        same({part.CFrame:GetComponents()}, row.cframe, role .. ".CFrame")
        same({part.PivotOffset:GetComponents()}, row.pivot_offset, role .. ".PivotOffset")
        pieces[role] = part
    end
end
if not pieces.HeadBase or not pieces.FaceExpression then error("실제 표정 두 메시가 없습니다.") end
local pending = ServerStorage:FindFirstChild("CostumePendingExpressions")
if pending and (not pending:IsA("Folder") or pending:FindFirstChild(DATA.avatar)) then error("기존 표정 후보는 덮어쓰지 않습니다.") end
local oldReadyHead = ready:FindFirstChild("Head")
if not oldReadyHead or not oldReadyHead:IsA("MeshPart") or oldReadyHead.MeshId ~= DATA.old_head.mesh_id then error("기존 Head 메시가 다릅니다.") end
same(vector(oldReadyHead.Size), DATA.old_head.assembled_size, "Ready.Head.Size")
local oldNeck
local originalCounts = {meshes = 0, motors = 0}
for _, item in ready:GetDescendants() do
    if item:IsA("MeshPart") then originalCounts.meshes += 1 end
    if item:IsA("Motor6D") then
        originalCounts.motors += 1
        if item.Name == "Neck" and item.Part1 == oldReadyHead then
            if oldNeck then error("기존 Neck이 중복됐습니다.") end
            oldNeck = item
        end
    end
end
if originalCounts.meshes ~= DATA.original_mesh_count or originalCounts.motors ~= 15 or not oldNeck then error("기존 R15 구조가 다릅니다.") end
same({oldNeck.C0:GetComponents()}, DATA.old_neck.C0, "Neck.C0")
same({oldNeck.C1:GetComponents()}, DATA.old_neck.C1, "Neck.C1")
local model = ready:Clone()
if not model then error("원본 코스튬 복제 실패") end
local ok, result = pcall(function()
    local oldHead = model:FindFirstChild("Head")
    local head = pieces.HeadBase:Clone()
    local face = pieces.FaceExpression:Clone()
    for _, part in {head, face} do
        for _, child in part:GetDescendants() do
            if child:IsA("LuaSourceContainer") or child:IsA("JointInstance") or child:IsA("Constraint")
                or child:IsA("Attachment") or child:IsA("Bone") then child:Destroy() end
        end
        part.Anchored, part.CanTouch, part.Massless = false, false, true
        part.PivotOffset = CFrame.new()
    end
    head.Name = "Head"
    head.Size = oldHead.Size
    head.CFrame = oldHead.CFrame
    head.CanCollide, head.CanQuery = oldHead.CanCollide, oldHead.CanQuery
    head.CollisionGroup, head.RootPriority = oldHead.CollisionGroup, oldHead.RootPriority
    head:SetAttribute("HHC_SourcePart", "Head")
    head:SetAttribute("HHC_SourceMesh", "HeadBase")
    head.Parent = model
    face.Name = "FaceExpression"
    face.Size = Vector3.new(table.unpack(DATA.face_size))
    face.CFrame = oldHead.CFrame * CFrame.new(table.unpack(DATA.face_relative_cframe))
    face.CanCollide, face.CanQuery = false, false
    face.TextureID = DATA.textures.Neutral
    face:SetAttribute("HHC_SourcePart", "Head")
    face:SetAttribute("HHC_SourceMesh", "FaceExpression")
    face:SetAttribute("HHC_SourceHeadSHA256", DATA.head_sha256)
    face:SetAttribute("HHC_ExpressionMeshValidated", true)
    face.Parent = model
    -- Original attachments and auxiliary children keep their exact local frames.
    for _, child in oldHead:GetChildren() do
        if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") then
            child:Destroy()
        else child.Parent = head end
    end
    for _, joint in model:GetDescendants() do
        if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
            if joint.Part0 == oldHead then joint.Part0 = head end
            if joint.Part1 == oldHead then joint.Part1 = head end
        end
    end
    oldHead:Destroy()
    local weld = Instance.new("WeldConstraint")
    weld.Name, weld.Part0, weld.Part1 = "ExpressionFaceWeld", head, face
    weld.Parent = face
    local motors = 0
    for _, motor in model:GetDescendants() do
        if motor:IsA("Motor6D") then
            motors += 1
            if motor.Name == "Neck" then
                same({motor.C0:GetComponents()}, DATA.old_neck.C0, "Preserved Neck.C0")
                same({motor.C1:GetComponents()}, DATA.old_neck.C1, "Preserved Neck.C1")
                if motor.Part1 ~= head then error("새 Head Neck 연결 실패") end
            end
            local zero, one = motor.Part0.CFrame * motor.C0, motor.Part1.CFrame * motor.C1
            if (zero.Position - one.Position).Magnitude > 0.0001 then error("기존 관절 경계가 바뀌었습니다.") end
        end
    end
    if motors ~= 15 then error("기존 15관절 보존 실패") end
    same({head.CFrame:GetComponents()}, {oldReadyHead.CFrame:GetComponents()}, "Preserved Head.CFrame")
    model:SetAttribute("HHC_SourceHeadSHA256", DATA.head_sha256)
    model:SetAttribute("HHC_ExpressionMeshValidated", true)
    model:SetAttribute("HHC_ExpressionRuntimeValidated", false)
    model:SetAttribute("HHC_PendingExpressionQA", true)
    model:SetAttribute("ExpressionReady", false)
    if not pending then
        pending = Instance.new("Folder")
        pending.Name, pending.Parent = "CostumePendingExpressions", ServerStorage
    end
    model.Parent = pending
    return {schema = 1, destination = model:GetFullName(), ready = false, runtime_validated = false,
        original_ready_unchanged = true, preserved_neck_c0_c1 = true, mesh_parts = originalCounts.meshes + 1,
        motors = motors, head_sha256 = DATA.head_sha256, face_mesh_id = face.MeshId, head_mesh_id = head.MeshId,
        face_size = vector(face.Size), head_size = vector(head.Size), textures = DATA.textures}
end)
if not ok then model:Destroy(); error(result) end
return HttpService:JSONEncode(result)
'''


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--actual-imports', type=Path, required=True)
    p.add_argument('--texture-ledger', type=Path, required=True)
    p.add_argument('--assembly-manifest', type=Path, required=True)
    p.add_argument('--original-imports', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists() or a.output.with_suffix('.luau').exists():
        raise ValueError('Refuse to overwrite an existing payload; use a versioned output')
    subprocess.run([sys.executable, str(Path(__file__).with_name('validate_expression_assets.py')),
                    str(a.manifest)], check=True, capture_output=True, text=True)
    manifest = json.loads(a.manifest.read_text(encoding='utf-8'))
    head_path = ROOT / manifest['head_asset']
    report = json.loads(head_path.with_suffix('.json').read_text(encoding='utf-8'))
    imported = json.loads(a.actual_imports.read_text(encoding='utf-8'))
    if imported['source_sha256'] != sha(head_path) or imported['name'] != manifest['avatar']:
        raise ValueError('Actual import does not identify this exact validated Head GLB')
    if report.get('body_reimport_required') or report.get('body_parts_reimport_required'):
        raise ValueError('This graft cannot skip a required corrected body reimport')
    rows = {row['name']: row for row in imported['meshes']}
    if set(rows) != {'FaceExpression', 'HeadBase'} or len(imported['meshes']) != 2:
        raise ValueError('Exactly two actual imported meshes must be inspected')
    for row in rows.values():
        asset(row['mesh_id']); asset(row['texture_id'])
    if len({row['mesh_id'] for row in rows.values()}) != 2:
        raise ValueError('Actual mesh asset IDs must be distinct')
    expected = geometry(head_path)
    fit = solve_importer(expected, rows)
    assembly = json.loads(a.assembly_manifest.read_text(encoding='utf-8'))
    originals = json.loads(a.original_imports.read_text(encoding='utf-8'))
    if assembly['name'] != manifest['avatar'] or assembly['source_sha256'] != report['source_rig_sha256']:
        raise ValueError('Existing Ready assembly is from another source')
    if originals['source_sha256'] != assembly['source_sha256']:
        raise ValueError('Original actual imports do not match the assembly')
    original_head = next(m for m in assembly['meshes'] if m['name'] == 'Head' and m['primary'])
    old_rotation = np.asarray(original_head['assembled_cframe'][3:]).reshape(3, 3)
    bake = np.asarray(fit['bake'])
    if np.max(np.abs(old_rotation - bake.T)) > 1e-6:
        raise ValueError('New importer bake would require changing the preserved Neck axes')
    anchor = np.asarray(original_head['assembled_cframe'][:3])
    center_error = float(np.max(np.abs(expected['HeadBase']['center'] - anchor)))
    size_error = float(np.max(np.abs(np.asarray(original_head['size']) - expected['HeadBase']['size'])))
    if center_error > 1e-5 or size_error > 1e-5:
        raise ValueError('HeadBase bounds do not preserve the original primary Head anchor')
    face_relative = old_rotation.T @ (expected['FaceExpression']['center'] - anchor)
    relative_rotation = old_rotation.T @ bake.T
    face_size = np.abs(bake) @ expected['FaceExpression']['size']
    ledger = json.loads(a.texture_ledger.read_text(encoding='utf-8'))
    if ledger['stage'] != 'Complete' or ledger['actual'].get('isError'):
        raise ValueError('Actual expression texture upload has not completed')
    texture_result = json.loads(next(c['text'] for c in ledger['actual']['content'] if c['type'] == 'text'))
    textures = {'Neutral': rows['FaceExpression']['texture_id']}
    records = {r['state']: r for r in manifest['records']}
    for state in ('Serious', 'SoftSmile'):
        if ledger['source_sha256'][state] != records[state]['sha256']:
            raise ValueError('Uploaded texture provenance differs: ' + state)
        matches = [value for key, value in texture_result.items() if key.endswith('/' + state + '.png')]
        if len(matches) != 1:
            raise ValueError('Actual texture upload result is ambiguous')
        textures[state] = asset(matches[0])
    old_mesh = next(row for row in originals['meshes'] if row['name'] == 'Head')
    old_neck = next(row for row in assembly['joints'] if row['name'] == 'Neck')
    data = {'schema': 1, 'avatar': manifest['avatar'], 'head_sha256': sha(head_path),
            'original_source_sha256': assembly['source_sha256'], 'imports': rows,
            'importer_fit': fit, 'old_head': {'mesh_id': asset(old_mesh['mesh_id']),
                                            'assembled_size': original_head['assembled_size']},
            'old_neck': old_neck, 'face_size': face_size.tolist(),
            'face_relative_cframe': face_relative.tolist() + relative_rotation.flatten().tolist(),
            'original_mesh_count': len(assembly['meshes']), 'textures': textures,
            'verified_head_center_error': center_error, 'verified_head_size_error': size_error,
            'offline_exact_uv_proof': True, 'ready': False, 'runtime_validated': False,
            'destination': 'ServerStorage.CostumePendingExpressions.' + manifest['avatar'],
            'original_ready_mutated': False, 'source_config_mutated': False,
            'recommended_expression_asset': dict(textures, MeshName='FaceExpression')}
    payload = LUA.replace('__DATA__', json.dumps(json.dumps(data, separators=(',', ':'), ensure_ascii=False)))
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps({'code': payload, 'datamodel_type': 'Edit'}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    a.output.with_suffix('.luau').write_text(payload, encoding='utf-8')
    a.output.with_suffix('.plan.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'output': str(a.output), 'importer_fit': fit, 'center_error': center_error,
                      'size_error': size_error, 'ready': False, 'studio_called': False}))


if __name__ == '__main__':
    main()
