# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Offline GLB -> EditableMesh payloads with source geometry/texture verification.

The default command generates a read-only, zero-upload reference probe. No
Studio connection, upload, API call, texture bake or original-file edit occurs.
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
from datetime import datetime, timezone

from assemble import IDENTITY, ROOT, manifest, matvec
from constraints import RigError
from glb_io import accessor_values, image_bytes, read_glb


def load_mesh(joints, mesh_name):
    verified = manifest(joints, Path(joints).resolve().parent.name)
    geometry = next((item for item in verified["meshes"] if item["name"] == mesh_name), None)
    if geometry is None:
        raise RigError("Unknown original exported mesh")
    path = Path(joints).resolve().parent / geometry["batch"]
    gltf, binary, content = read_glb(path)
    nodes = [node for node in gltf["nodes"] if node.get("name") == mesh_name and "mesh" in node]
    if len(nodes) != 1:
        raise RigError("Exactly one source mesh node is required")
    primitives = gltf["meshes"][nodes[0]["mesh"]]["primitives"]
    if len(primitives) != 1:
        raise RigError("Each exported material fragment needs exactly one primitive")
    primitive = primitives[0]
    if primitive.get("mode", 4) != 4 or primitive.get("targets"):
        raise RigError("Only the original rigid triangles are supported")
    attributes = primitive["attributes"]
    if set(attributes) != {"POSITION", "NORMAL", "TEXCOORD_0"}:
        raise RigError("Unexpected/missing source vertex attributes; no attributes are discarded")
    positions = [list(value) for value in accessor_values(gltf, binary, attributes["POSITION"])]
    normals = [list(value) for value in accessor_values(gltf, binary, attributes["NORMAL"])]
    uvs = [list(value) for value in accessor_values(gltf, binary, attributes["TEXCOORD_0"])]
    indices = [value[0] for value in accessor_values(gltf, binary, primitive["indices"])]
    if not positions or len(positions) != len(normals) or len(positions) != len(uvs):
        raise RigError("Mismatched source vertex attributes")
    if len(positions) > 60000 or not indices or len(indices) % 3 or len(indices) // 3 > 20000:
        raise RigError("Source exceeds EditableMesh limits; no simplification is performed")
    if min(indices) < 0 or max(indices) >= len(positions):
        raise RigError("Invalid original triangle indices")
    if any(not math.isfinite(value) for values in positions + normals + uvs for value in values):
        raise RigError("Non-finite original vertex attributes")
    material = gltf["materials"][primitive["material"]]
    pbr = material.get("pbrMetallicRoughness", {})
    texture = pbr.get("baseColorTexture", {})
    if texture.get("texCoord", 0) != 0 or texture.get("extensions") or "index" not in texture:
        raise RigError("Only the verified original UV0 color texture is supported")
    if any(key in material for key in ("normalTexture", "occlusionTexture", "emissiveTexture")) or "metallicRoughnessTexture" in pbr:
        raise RigError("Additional original texture maps need their own verified IDs")
    image = gltf["images"][gltf["textures"][texture["index"]]["source"]]
    return {"schema": 1, "name": verified["name"], "mesh": mesh_name,
            "source_sha256": verified["source_sha256"], "glb_sha256": hashlib.sha256(content).hexdigest(),
            "geometry": geometry, "positions": positions, "normals": normals, "uvs": uvs, "indices": indices,
            "texture_sha256": hashlib.sha256(image_bytes(gltf, binary, image)).hexdigest(),
            "double_sided": material.get("doubleSided", False), "vertices": len(positions), "triangles": len(indices) // 3}


def texture_ids(joints, actual_path):
    """Match each actual Batch01 image ID to its original embedded image SHA256."""
    metadata = json.loads(Path(joints).read_text(encoding="utf-8"))
    batch = metadata["batches"][0]
    actual = json.loads(Path(actual_path).read_text(encoding="utf-8"))
    rows = {row["Name"].removesuffix("Mesh"): row for row in actual}
    result = {}
    for mesh_name in batch["parts"]:
        data = load_mesh(joints, mesh_name)
        if mesh_name not in rows:
            raise RigError("Missing actually imported Batch01 texture evidence")
        texture_id = rows[mesh_name].get("TextureID", "")
        if not texture_id.startswith("rbxassetid://") or not texture_id[13:].isdigit():
            raise RigError("Missing actual newly uploaded texture ID")
        previous = result.get(data["texture_sha256"])
        if previous and previous != texture_id:
            raise RigError("Same original image maps to different actual texture IDs")
        result[data["texture_sha256"]] = texture_id
    return result, rows


def encoded(data):
    return json.dumps(json.dumps(data, separators=(",", ":"), ensure_ascii=False), ensure_ascii=False)


def verified_policy(path, data):
    probe = json.loads(Path(path).read_text(encoding="utf-8"))
    if probe.get("schema") != 1 or probe.get("mode") != "reference_probe" or not probe.get("verified"):
        raise RigError("An actually verified zero-upload reference probe is required")
    if probe.get("source_sha256") != data["source_sha256"] or probe.get("name") != data["name"]:
        raise RigError("The actual reference probe belongs to a different original costume")
    if probe.get("uv_policy") not in ("raw", "flip_v") or probe.get("uploads") != 0:
        raise RigError("Original UV mapping is not verified")
    if probe.get("same_winding") != probe.get("source_triangles") or probe.get("reversed_winding") != 0:
        raise RigError("Original triangle winding is not verified; do not change source faces")
    return probe["uv_policy"]


def preview_data(joints, mesh_name, actual_path, probe_path):
    data = load_mesh(joints, mesh_name)
    textures, _ = texture_ids(joints, actual_path)
    if data["texture_sha256"] not in textures:
        raise RigError("No verified already-uploaded ID for the exact source image bytes")
    data["texture_id"] = textures[data["texture_sha256"]]
    data["uv_policy"] = verified_policy(probe_path, data)
    # Retain the empirically verified native importer Y180 bake. Its inverse in
    # the part CFrame restores the exact original GLB world-space appearance.
    bake = [[-1, 0, 0], [0, 1, 0], [0, 0, -1]]
    data["native_bake"] = bake
    data["positions"] = [matvec(bake, [point[axis] - data["geometry"]["offset"][axis] for axis in range(3)]) for point in data["positions"]]
    data["normals"] = [matvec(bake, normal) for normal in data["normals"]]
    data["preview_cframe"] = data["geometry"]["center"] + [value for row in bake for value in row]
    if data["uv_policy"] == "flip_v":
        data["uvs"] = [[uv[0], 1 - uv[1]] for uv in data["uvs"]]
    fingerprint_data = {key: data[key] for key in ("source_sha256", "glb_sha256", "mesh", "positions", "normals", "uvs", "indices", "texture_sha256", "texture_id", "uv_policy")}
    data["fingerprint"] = hashlib.sha256(json.dumps(fingerprint_data, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    data["asset_name"] = "HHC_" + data["name"] + "_" + data["mesh"] + "_" + data["fingerprint"][:12]
    return data


def verify_preview(path, data):
    preview = json.loads(Path(path).read_text(encoding="utf-8"))
    if not preview.get("verified") or preview.get("mode") != "editable_preview" or preview.get("uploads") != 0:
        raise RigError("An actual, zero-upload numerical preview is required")
    for field in ("name", "mesh", "source_sha256", "glb_sha256", "fingerprint", "texture_id", "texture_sha256", "uv_policy", "vertices", "triangles"):
        if preview.get(field) != data[field]:
            raise RigError("Preview differs from the original payload: " + field)
    return preview


PROBE = r'''
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
if RunService:IsRunning() then error("원본 비교는 Edit 모드에서 실행합니다.") end
local DATA = HttpService:JSONDecode(__DATA__)
local editable
local success, report = pcall(function()
    editable = AssetService:CreateEditableMeshAsync(Content.fromUri(DATA.reference_mesh_id))
    if not editable then error("원본 EditableMesh를 만들지 못했습니다.") end
    local center = editable:GetCenter()
    local function key(position)
        return string.format("%d,%d,%d", math.round(position.X * 10000), math.round(position.Y * 10000), math.round(position.Z * 10000))
    end
    local function vec(values) return Vector3.new(table.unpack(values)) end
    local function bake(value) return Vector3.new(-value.X, value.Y, -value.Z) end
    local function faceKey(corners)
        local keys = { key(corners[1]), key(corners[2]), key(corners[3]) }
        table.sort(keys)
        return table.concat(keys, "/")
    end
    local expectedFaces = {}
    for index = 1, #DATA.indices, 3 do
        local corners, entries = {}, {}
        for offset = 0, 2 do
            local vertex = DATA.indices[index + offset] + 1
            local position = bake(vec(DATA.positions[vertex]) - vec(DATA.geometry.offset))
            table.insert(corners, position)
            table.insert(entries, { position = position, normal = bake(vec(DATA.normals[vertex])), uv = DATA.uvs[vertex] })
        end
        local identifier = faceKey(corners)
        expectedFaces[identifier] = expectedFaces[identifier] or {}
        table.insert(expectedFaces[identifier], entries)
    end
    local actualFaces = editable:GetFaces()
    local missing, matched, rawError, flipError, normalError, positionError = 0, 0, 0, 0, 0, 0
    local sameWinding, reversedWinding = 0, 0
    for _, faceId in actualFaces do
        local vertexIds = editable:GetFaceVertices(faceId)
        if #vertexIds ~= 3 then error("실제 원본이 삼각형이 아닙니다.") end
        local corners = {}
        for _, vertexId in vertexIds do table.insert(corners, editable:GetPosition(vertexId) - center) end
        local candidates = expectedFaces[faceKey(corners)]
        if not candidates then missing += 1; continue end
        local uvIds, normalIds = editable:GetFaceUVs(faceId), editable:GetFaceNormals(faceId)
        local bestRaw, bestFlip, bestPosition, bestNormal, bestOrder = math.huge, math.huge, math.huge, math.huge, nil
        for _, candidate in candidates do
            local candidateRaw, candidateFlip, candidatePosition, candidateNormal, order = 0, 0, 0, 0, {}
            for cornerIndex, position in corners do
                local nearest, distance, nearestIndex = nil, math.huge, nil
                for expectedIndex, expected in candidate do
                    local current = (position - expected.position).Magnitude
                    if current < distance then nearest, distance, nearestIndex = expected, current, expectedIndex end
                end
                table.insert(order, nearestIndex)
                local uv, normal = editable:GetUV(uvIds[cornerIndex]), editable:GetNormal(normalIds[cornerIndex])
                candidatePosition = math.max(candidatePosition, distance)
                candidateNormal = math.max(candidateNormal, (normal - nearest.normal).Magnitude)
                candidateRaw = math.max(candidateRaw, math.abs(uv.X - nearest.uv[1]), math.abs(uv.Y - nearest.uv[2]))
                candidateFlip = math.max(candidateFlip, math.abs(uv.X - nearest.uv[1]), math.abs(uv.Y - (1 - nearest.uv[2])))
            end
            if math.min(candidateRaw, candidateFlip) < math.min(bestRaw, bestFlip) then bestOrder = order end
            bestRaw, bestFlip = math.min(bestRaw, candidateRaw), math.min(bestFlip, candidateFlip)
            bestPosition, bestNormal = math.min(bestPosition, candidatePosition), math.min(bestNormal, candidateNormal)
        end
        if bestOrder then
            if bestOrder[2] == bestOrder[1] % 3 + 1 then sameWinding += 1 else reversedWinding += 1 end
        end
        matched += 1
        rawError, flipError = math.max(rawError, bestRaw), math.max(flipError, bestFlip)
        normalError, positionError = math.max(normalError, bestNormal), math.max(positionError, bestPosition)
    end
    local rawGood, flipGood = rawError <= 0.0002, flipError <= 0.0002
    local policy = rawGood and not flipGood and "raw" or flipGood and not rawGood and "flip_v" or "unverified"
    local size = editable:GetSize()
    local actualVertices = editable:GetVertices()
    return { schema = 1, mode = DATA.probe_mode or "reference_probe", name = DATA.name, mesh = DATA.mesh,
             source_sha256 = DATA.source_sha256, glb_sha256 = DATA.glb_sha256,
             reference_mesh_id = DATA.reference_mesh_id, texture_id = DATA.texture_id,
             source_vertices = DATA.vertices, source_triangles = DATA.triangles,
             actual_vertices = #actualVertices, actual_faces = #actualFaces, matched_faces = matched, missing_faces = missing,
             native_center = { center.X, center.Y, center.Z }, native_size = { size.X, size.Y, size.Z },
             maximum_position_error = positionError, maximum_normal_error = normalError,
             maximum_raw_uv_error = rawError, maximum_flipped_v_error = flipError,
             same_winding = sameWinding, reversed_winding = reversedWinding,
             uv_policy = policy, uploads = 0,
             verified = missing == 0 and matched == DATA.triangles and #actualFaces == DATA.triangles
                        and positionError <= 0.0002 and normalError <= 0.002 and policy ~= "unverified" }
end)
if editable then editable:Destroy() end
if not success then error(report) end
return HttpService:JSONEncode(report)
'''


PREVIEW = r'''
local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
if game:GetService("RunService"):IsRunning() then error("미업로드 미리보기는 Edit 모드에서 실행합니다.") end
local DATA = HttpService:JSONDecode(__DATA__)
local previews = ServerStorage:FindFirstChild("CostumeMeshPreviews")
local folder = previews and previews:FindFirstChild(DATA.name)
local previous = folder and folder:FindFirstChild(DATA.mesh)
if previous and (not previous:IsA("MeshPart") or previous:GetAttribute("HHC_UploadState") ~= "Preview"
    or previous:GetAttribute("HHC_EditableFingerprint") ~= DATA.fingerprint or previous:GetAttribute("HHC_UploadedAssetId") ~= nil) then
    error("업로드 상태/원본이 다른 미리보기가 있습니다. 덮어쓰지 않습니다.")
end
local editable, part
local success, report = pcall(function()
    editable = AssetService:CreateEditableMesh()
    if not editable then error("빈 EditableMesh를 만들지 못했습니다.") end
    local vertices, normals, uvs, faces = {}, {}, {}, {}
    for _, value in DATA.positions do table.insert(vertices, editable:AddVertex(Vector3.new(table.unpack(value)))) end
    for _, value in DATA.normals do table.insert(normals, editable:AddNormal(Vector3.new(table.unpack(value)))) end
    for _, value in DATA.uvs do table.insert(uvs, editable:AddUV(Vector2.new(table.unpack(value)))) end
    for index = 1, #DATA.indices, 3 do
        local a, b, c = DATA.indices[index] + 1, DATA.indices[index + 1] + 1, DATA.indices[index + 2] + 1
        local face = editable:AddTriangle(vertices[a], vertices[b], vertices[c])
        editable:SetFaceUVs(face, { uvs[a], uvs[b], uvs[c] })
        editable:SetFaceNormals(face, { normals[a], normals[b], normals[c] })
        table.insert(faces, face)
    end
    -- Every original vertex, normal, UV and triangle corner is read back before use.
    local positionError, normalError, uvError = 0, 0, 0
    for index, vertexId in vertices do
        positionError = math.max(positionError, (editable:GetPosition(vertexId) - Vector3.new(table.unpack(DATA.positions[index]))).Magnitude)
        normalError = math.max(normalError, (editable:GetNormal(normals[index]) - Vector3.new(table.unpack(DATA.normals[index]))).Magnitude)
        uvError = math.max(uvError, (editable:GetUV(uvs[index]) - Vector2.new(table.unpack(DATA.uvs[index]))).Magnitude)
    end
    for index, faceId in faces do
        local actualVertices, actualUVs, actualNormals = editable:GetFaceVertices(faceId), editable:GetFaceUVs(faceId), editable:GetFaceNormals(faceId)
        for corner = 1, 3 do
            local expectedIndex = DATA.indices[(index - 1) * 3 + corner] + 1
            if actualVertices[corner] ~= vertices[expectedIndex] or actualUVs[corner] ~= uvs[expectedIndex] or actualNormals[corner] ~= normals[expectedIndex] then
                error("원래 면 인덱스/모서리 속성이 바뀌었습니다.")
            end
        end
    end
    local center, size = editable:GetCenter(), editable:GetSize()
    local sizeError = (size - Vector3.new(table.unpack(DATA.geometry.size))).Magnitude
    if center.Magnitude > 0.000002 or sizeError > 0.000002 or positionError > 0.000002 or normalError > 0.000002 or uvError > 0.000002 then
        error("원본 정점/경계/노멀/UV 보존 검사 실패")
    end
    part = AssetService:CreateMeshPartAsync(Content.fromObject(editable), { CollisionFidelity = Enum.CollisionFidelity.Hull })
    part.Name = DATA.mesh
    part.TextureID = DATA.texture_id
    part.DoubleSided = DATA.double_sided
    part.Size = Vector3.new(table.unpack(DATA.geometry.size))
    part.CFrame = CFrame.new(table.unpack(DATA.preview_cframe))
    part.PivotOffset = CFrame.new()
    part.Anchored = true
    part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
    part:SetAttribute("HHC_EditableFingerprint", DATA.fingerprint)
    part:SetAttribute("HHC_SourceSHA256", DATA.source_sha256)
    part:SetAttribute("HHC_SourceGLBSHA256", DATA.glb_sha256)
    part:SetAttribute("HHC_TextureSHA256", DATA.texture_sha256)
    part:SetAttribute("HHC_UVPolicy", DATA.uv_policy)
    part:SetAttribute("HHC_NativeBake", "Y180")
    part:SetAttribute("HHC_OriginalVertices", DATA.vertices)
    part:SetAttribute("HHC_OriginalTriangles", DATA.triangles)
    part:SetAttribute("HHC_EditableFaceIds", HttpService:JSONEncode(faces))
    part:SetAttribute("HHC_EditableVertexIds", HttpService:JSONEncode(vertices))
    part:SetAttribute("HHC_EditableNormalIds", HttpService:JSONEncode(normals))
    part:SetAttribute("HHC_EditableUVIds", HttpService:JSONEncode(uvs))
    part:SetAttribute("HHC_AssetName", DATA.asset_name)
    part:SetAttribute("HHC_UploadState", "Preview")
    if not previews then
        previews = Instance.new("Folder")
        previews.Name = "CostumeMeshPreviews"
        previews.Parent = ServerStorage
    end
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = DATA.name
        folder.Parent = previews
    end
    -- Only this same-source, never-uploaded disposable preview may be replaced, after all checks pass.
    -- Neither actual CostumeImports nor any pending/gameplay rig is touched.
    if previous then previous:Destroy() end
    part.Parent = folder -- Object content holds a strong EditableMesh reference; nothing replicates to clients.
    return { schema = 1, mode = "editable_preview", name = DATA.name, mesh = DATA.mesh,
             source_sha256 = DATA.source_sha256, glb_sha256 = DATA.glb_sha256, fingerprint = DATA.fingerprint,
             path = part:GetFullName(), texture_id = DATA.texture_id, texture_sha256 = DATA.texture_sha256,
             vertices = #editable:GetVertices(), triangles = #editable:GetFaces(), uv_policy = DATA.uv_policy,
             size = { size.X, size.Y, size.Z }, center = { center.X, center.Y, center.Z },
             maximum_position_error = positionError, maximum_normal_error = normalError, maximum_uv_error = uvError,
             maximum_bounds_error = sizeError, uploads = 0, verified = true }
end)
if not success then
    if part then part:Destroy() end
    if editable then editable:Destroy() end
    error(report)
end
return HttpService:JSONEncode(report)
'''


UPLOAD = r'''
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
if game:GetService("RunService"):IsRunning() then error("메시 업로드는 Edit 모드에서 실행합니다.") end
local DATA = HttpService:JSONDecode(__DATA__)
local folder = ServerStorage:FindFirstChild("CostumeMeshPreviews")
folder = folder and folder:FindFirstChild(DATA.name)
local part = folder and folder:FindFirstChild(DATA.mesh)
if not part or not part:IsA("MeshPart") then error("수치 확인을 마친 미업로드 미리보기가 없습니다.") end
if part:GetAttribute("HHC_EditableFingerprint") ~= DATA.fingerprint or part.TextureID ~= DATA.texture_id
    or part:GetAttribute("HHC_SourceSHA256") ~= DATA.source_sha256 or part:GetAttribute("HHC_SourceGLBSHA256") ~= DATA.glb_sha256 then
    error("원본 검사 이후 미리보기/텍스처가 바뀌었습니다.")
end
local function reply(state, id, message)
    return HttpService:JSONEncode({ schema = 1, mode = "editable_upload", name = DATA.name, mesh = DATA.mesh,
        fingerprint = DATA.fingerprint, asset_name = DATA.asset_name, source_sha256 = DATA.source_sha256,
        glb_sha256 = DATA.glb_sha256, texture_id = DATA.texture_id, texture_sha256 = DATA.texture_sha256,
        state = state, asset_id = id, message = message })
end
local state = part:GetAttribute("HHC_UploadState")
if state == "Uploaded" then return reply(state, part:GetAttribute("HHC_UploadedAssetId"), "이미 업로드된 ID를 재사용합니다.") end
if state ~= "Preview" then error("이전 업로드 상태가 불명확합니다. 중복 업로드하지 않습니다: " .. tostring(state)) end
local editable = part.MeshContent.Object
if not editable or not editable:IsA("EditableMesh") then error("검토한 원본 EditableMesh가 없습니다.") end
local actualVertexIds, actualFaceIds = editable:GetVertices(), editable:GetFaces()
if #actualVertexIds ~= DATA.vertices or #actualFaceIds ~= DATA.triangles then error("검사 후 정점/면 수가 바뀌었습니다.") end
local vertexIds = HttpService:JSONDecode(part:GetAttribute("HHC_EditableVertexIds") or "[]")
local normalIds = HttpService:JSONDecode(part:GetAttribute("HHC_EditableNormalIds") or "[]")
local uvIds = HttpService:JSONDecode(part:GetAttribute("HHC_EditableUVIds") or "[]")
if #vertexIds ~= DATA.vertices or #normalIds ~= DATA.vertices or #uvIds ~= DATA.vertices then error("검토한 원래 속성 ID가 없습니다.") end
local faceIds = HttpService:JSONDecode(part:GetAttribute("HHC_EditableFaceIds") or "[]")
local actualFaces = {}
for _, faceId in actualFaceIds do actualFaces[faceId] = true end
if #faceIds ~= DATA.triangles then error("검토한 원래 면 ID가 없습니다.") end
local visited = {}
-- Stable IDs are saved at preview time; GetFaces() iteration order is never assumed.
for index, faceId in faceIds do
    if not actualFaces[faceId] or visited[faceId] then error("검토한 원래 면 ID가 바뀌었습니다.") end
    visited[faceId] = true
    local actualVertices, actualNormals, actualUVs = editable:GetFaceVertices(faceId), editable:GetFaceNormals(faceId), editable:GetFaceUVs(faceId)
    if #actualVertices ~= 3 then error("검사 후 삼각형이 바뀌었습니다.") end
    for corner = 1, 3 do
        local expectedIndex = DATA.indices[(index - 1) * 3 + corner] + 1
        if actualVertices[corner] ~= vertexIds[expectedIndex] or actualNormals[corner] ~= normalIds[expectedIndex] or actualUVs[corner] ~= uvIds[expectedIndex] then
            error("원래 면 모서리의 정점/노멀/UV 참조가 바뀌었습니다.")
        end
        local position = editable:GetPosition(actualVertices[corner])
        local normal, uv = editable:GetNormal(actualNormals[corner]), editable:GetUV(actualUVs[corner])
        if (position - Vector3.new(table.unpack(DATA.positions[expectedIndex]))).Magnitude > 0.000002
            or (normal - Vector3.new(table.unpack(DATA.normals[expectedIndex]))).Magnitude > 0.000002
            or (uv - Vector2.new(table.unpack(DATA.uvs[expectedIndex]))).Magnitude > 0.000002 then
            error("검사 후 원래 면/정점/노멀/UV가 바뀌었습니다.")
        end
    end
end
local creatorId = game:GetService("StudioService"):GetUserId()
if creatorId <= 0 then error("현재 Studio 업로드 계정을 확인하지 못했습니다.") end
part:SetAttribute("HHC_UploadCreatorId", creatorId)
part:SetAttribute("HHC_UploadState", "Submitting") -- Set before the yielding call; unknown attempts remain blocked.
local ok, result, idOrError = pcall(function()
    return game:GetService("AssetService"):CreateAssetAsync(editable, Enum.AssetType.Mesh,
        { Name = DATA.asset_name, CreatorId = creatorId, CreatorType = Enum.AssetCreatorType.User,
          Description = "Original verified costume geometry " .. DATA.source_sha256 })
end)
if not ok then
    part:SetAttribute("HHC_UploadState", "Unknown")
    return reply("Unknown", nil, tostring(result))
end
if result ~= Enum.CreateAssetResult.Success then
    part:SetAttribute("HHC_UploadState", "Failed")
    return reply("Failed", nil, tostring(result) .. ": " .. tostring(idOrError))
end
local assetId = tonumber(idOrError)
if not assetId or assetId <= 0 then
    part:SetAttribute("HHC_UploadState", "Unknown")
    return reply("Unknown", nil, "성공 응답의 메시 ID를 확인하지 못했습니다.")
end
part:SetAttribute("HHC_UploadedAssetId", assetId)
part:SetAttribute("HHC_UploadState", "Uploaded")
-- Return immediately. The caller records the asset ID on disk before any extra yielding operation.
return reply("Uploaded", assetId, nil)
'''


ATTACH = r'''
local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
if game:GetService("RunService"):IsRunning() then error("메시 연결은 Edit 모드에서 실행합니다.") end
local DATA = HttpService:JSONDecode(__DATA__)
local imports = ServerStorage:FindFirstChild("CostumeImports")
local costume = imports and imports:FindFirstChild(DATA.name)
local batchName = string.gsub(DATA.geometry.batch, "batch_(%d+)%.glb", "Batch%1")
local batch = costume and costume:FindFirstChild(batchName)
local previous = batch and batch:FindFirstChild(DATA.mesh)
local assetUri = "rbxassetid://" .. tostring(DATA.asset_id)
if previous then
    if previous:IsA("MeshPart") and previous.MeshId == assetUri and previous:GetAttribute("HHC_EditableFingerprint") == DATA.fingerprint then
        return HttpService:JSONEncode({ schema = 1, mode = "editable_attach", reused = true, name = DATA.name, mesh = DATA.mesh, asset_id = DATA.asset_id, path = previous:GetFullName() })
    end
    error("같은 이름의 다른 import 메시가 있습니다. 덮어쓰지 않습니다.")
end
local part = AssetService:CreateMeshPartAsync(Content.fromAssetId(DATA.asset_id), { CollisionFidelity = Enum.CollisionFidelity.Hull })
local ok, report = pcall(function()
    if (part.MeshSize - Vector3.new(table.unpack(DATA.geometry.size))).Magnitude > 0.0002 then error("업로드 후 메시 경계가 바뀌었습니다.") end
    part.Name = DATA.mesh
    part.TextureID = DATA.texture_id
    part.DoubleSided = DATA.double_sided
    part.Size = Vector3.new(table.unpack(DATA.geometry.size))
    part.CFrame = CFrame.new(table.unpack(DATA.preview_cframe))
    part.PivotOffset = CFrame.new()
    part.Anchored = true
    part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
    part:SetAttribute("HHC_EditableFingerprint", DATA.fingerprint)
    part:SetAttribute("HHC_SourceSHA256", DATA.source_sha256)
    part:SetAttribute("HHC_SourceGLBSHA256", DATA.glb_sha256)
    part:SetAttribute("HHC_TextureSHA256", DATA.texture_sha256)
    part:SetAttribute("HHC_NativeBake", "Y180")
    if not imports then imports = Instance.new("Folder"); imports.Name = "CostumeImports"; imports.Parent = ServerStorage end
    if not costume then costume = Instance.new("Folder"); costume.Name = DATA.name; costume.Parent = imports end
    if not batch then batch = Instance.new("Folder"); batch.Name = batchName; batch.Parent = costume end
    part.Parent = batch
    return { schema = 1, mode = "editable_attach", reused = false, name = DATA.name, mesh = DATA.mesh,
             asset_id = DATA.asset_id, path = part:GetFullName(), mesh_id = part.MeshId, texture_id = part.TextureID,
             size = { part.Size.X, part.Size.Y, part.Size.Z }, cframe = { part.CFrame:GetComponents() }, pivot_offset = { part.PivotOffset:GetComponents() }, uploads = 0 }
end)
if not ok then part:Destroy(); error(report) end
return HttpService:JSONEncode(report)
'''


def save_json(path, value):
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def _run_upload(data, code, ledger_path, studio_id=None):
    """Single explicit call, no retries; disk ledger is locked before network work."""
    from install_animate import reply_json, reply_text
    sys.path.insert(0, str(ROOT / "tools"))
    from studio_mcp import Client
    ledger = json.loads(ledger_path.read_text(encoding="utf-8")) if ledger_path.exists() else {"schema": 1, "entries": {}}
    entry = ledger["entries"].get(data["fingerprint"])
    if entry:
        if entry.get("state") == "Uploaded":
            print(json.dumps(entry, ensure_ascii=False))
            return
        raise RigError("An earlier call is already recorded; no automatic retry: " + entry.get("state", "Unknown"))
    client = Client()
    try:
        client.start()
        studios = reply_json(client.call("list_roblox_studios", {})).get("studios", [])
        matching = [studio for studio in studios if "goodevil" in studio["name"].lower() and (not studio_id or studio["id"] == studio_id)]
        if len(matching) != 1:
            raise RigError("GoodEvil must be unique; specify the current --studio-id if necessary")
        selected = matching[0]["id"]
        state = reply_text(client.call("get_studio_state", {"studio_id": selected}))
        if "Current Studio Mode: Edit" not in state:
            raise RigError("GoodEvil must already be in Edit mode; no Play state was changed")
        entry = {"state": "Submitting", "fingerprint": data["fingerprint"], "asset_name": data["asset_name"],
                 "name": data["name"], "mesh": data["mesh"], "source_sha256": data["source_sha256"],
                 "glb_sha256": data["glb_sha256"], "texture_id": data["texture_id"], "studio_id": selected,
                 "started_at_utc": datetime.now(timezone.utc).isoformat()}
        ledger["entries"][data["fingerprint"]] = entry
        save_json(ledger_path, ledger)
        try:
            result = client.call("execute_luau", {"code": code, "datamodel_type": "Edit", "studio_id": selected})
            report = reply_json(result)
            if report.get("schema") != 1 or report.get("mode") != "editable_upload" or report.get("fingerprint") != data["fingerprint"]:
                raise RigError("Upload response does not match the original request")
            if report.get("state") == "Uploaded" and (type(report.get("asset_id")) not in (int, float) or report["asset_id"] <= 0):
                raise RigError("Upload response has no usable asset ID")
            entry.update(report)
            entry["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
            save_json(ledger_path, ledger)
            print(json.dumps(entry, ensure_ascii=False))
        except Exception as error:
            entry.update(state="Unknown", error=str(error), finished_at_utc=datetime.now(timezone.utc).isoformat())
            save_json(ledger_path, ledger)
            raise
    finally:
        client.close()


def run_upload(data, code, ledger_path, studio_id=None):
    lock = ledger_path.with_name(ledger_path.name + ".lock")
    try:
        descriptor = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    except FileExistsError as error:
        raise RigError("The upload ledger is locked by an earlier operation; inspect before any retry") from error
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as file:
            json.dump({"pid": os.getpid(), "fingerprint": data["fingerprint"]}, file)
        return _run_upload(data, code, ledger_path, studio_id)
    finally:
        lock.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("joints", type=Path)
    parser.add_argument("--mesh", default="LeftLowerArm")
    parser.add_argument("--mode", choices=("probe", "preview", "upload", "attach", "verify"), default="probe")
    parser.add_argument("--probe-result", type=Path)
    parser.add_argument("--preview-result", type=Path)
    parser.add_argument("--ledger", type=Path)
    parser.add_argument("--execute", action="store_true", help="Explicitly execute one upload and save its ledger; never retries")
    parser.add_argument("--studio-id")
    parser.add_argument("--actual-batch01", type=Path, default=ROOT / "build/costume_batch01_actual.txt")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.mode == "probe":
        data = load_mesh(args.joints, args.mesh)
        textures, actual = texture_ids(args.joints, args.actual_batch01)
        if args.mesh not in actual:
            raise RigError("Reference probe must use an already imported original Batch01 mesh")
        data["reference_mesh_id"] = actual[args.mesh]["MeshId"]
        data["texture_id"] = textures[data["texture_sha256"]]
        if not re.fullmatch(r"rbxassetid://[1-9][0-9]*", data["reference_mesh_id"]):
            raise RigError("Reference probe needs the actual already-uploaded mesh ID")
        code = PROBE.replace("__DATA__", encoded(data))
        filename = "editable_probe_reference.json"
    else:
        if args.probe_result is None:
            raise RigError("A verified actual reference probe result is required before preview")
        data = preview_data(args.joints, args.mesh, args.actual_batch01, args.probe_result)
        if args.mode == "preview":
            template = PREVIEW
        elif args.mode == "upload":
            if args.preview_result is None:
                raise RigError("A verified actual zero-upload preview result is required before upload")
            verify_preview(args.preview_result, data)
            template = UPLOAD
        else:
            ledger_path = (args.ledger or args.joints.resolve().parent / "editable_upload_ledger.json").resolve()
            ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
            entry = ledger.get("entries", {}).get(data["fingerprint"])
            if not entry or entry.get("state") != "Uploaded" or not entry.get("asset_id"):
                raise RigError("An actually uploaded asset ID must already be saved in the local ledger")
            data["asset_id"] = entry["asset_id"]
            if args.mode == "verify":
                original = load_mesh(args.joints, args.mesh)
                original["reference_mesh_id"] = "rbxassetid://" + str(int(data["asset_id"]))
                original["texture_id"] = data["texture_id"]
                original["probe_mode"] = "uploaded_mesh_verify"
                data = original
                template = PROBE
            else:
                template = ATTACH
        code = template.replace("__DATA__", encoded(data))
        filename = "editable_" + args.mode + "_" + args.mesh + ".json"
    output = (args.output or args.joints.resolve().parent / filename).resolve()
    if ROOT / "build" not in output.parents:
        raise RigError("Generated payloads may be written only inside build/")
    output.write_text(json.dumps({"datamodel_type": "Edit", "code": code}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    output.with_suffix(".luau").write_text(code, encoding="utf-8")
    if args.execute:
        if args.mode != "upload":
            raise RigError("--execute is allowed only for one explicitly selected upload")
        ledger_path = (args.ledger or args.joints.resolve().parent / "editable_upload_ledger.json").resolve()
        if ROOT / "build" not in ledger_path.parents:
            raise RigError("Upload ledgers must be saved under build/")
        run_upload(data, code, ledger_path, args.studio_id)
        return
    print(json.dumps({"payload": output.relative_to(ROOT).as_posix(), "mesh": args.mesh,
                      "mode": args.mode, "vertices": data["vertices"], "triangles": data["triangles"],
                      "uploads_if_executed": 1 if args.mode == "upload" else 0, "executed": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
