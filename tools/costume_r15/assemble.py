"""Generate offline, guarded Edit-mode Luau for a real imported R15 costume.

This command never opens Studio, calls an API, uploads, or promotes a rig.
First generate/run --mode inspect, save its JSON response, then generate
--mode assemble --inspection PATH. The only destination is CostumePendingRigs.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path
import re

from constraints import JOINTS, PRIMARY, RigError
from glb_io import accessor_values, image_bytes, read_glb


ROOT = Path(__file__).resolve().parents[2]
IDENTITY = [1, 0, 0, 0, 1, 0, 0, 0, 1]
TOLERANCE = 0.03


def finite_vector(values, count, label):
    if len(values) != count or any(isinstance(value, bool) or not isinstance(value, (int, float)) or
                                   not math.isfinite(value) for value in values):
        raise RigError(f"Invalid {label}")
    return list(values)


def translation(values, label):
    values = finite_vector(values, 12, label)
    if max(abs(actual - expected) for actual, expected in zip(values[3:], IDENTITY)) > 1e-6:
        raise RigError(f"Only the verified canonical joint axes are supported: {label}")
    return values[:3]


def bounds(points):
    if not points:
        raise RigError("Empty exported mesh")
    for point in points:
        finite_vector(point, 3, "mesh position")
    low = [min(point[axis] for point in points) for axis in range(3)]
    high = [max(point[axis] for point in points) for axis in range(3)]
    size = [high[axis] - low[axis] for axis in range(3)]
    if min(size) < 0.001:
        raise RigError("A mesh is thinner than Roblox's supported Part size; no geometry padding is invented")
    return {"min": low, "max": high, "size": size,
            "offset": [(high[axis] + low[axis]) * 0.5 for axis in range(3)]}


def uniform_ratio(actual, expected, label):
    actual = finite_vector(actual, 3, label)
    if min(actual) <= 0:
        raise RigError(f"Non-positive {label}")
    ratios = [actual[axis] / expected[axis] for axis in range(3)]
    scale = sum(ratios) / 3
    if max(abs(value / scale - 1) for value in ratios) > TOLERANCE:
        raise RigError(f"Nonuniform or axis-swapped imported mesh: {label}")
    return scale


def matvec(matrix, vector):
    return [sum(row[axis] * vector[axis] for axis in range(3)) for row in matrix]


def transpose(matrix):
    return [list(row) for row in zip(*matrix)]


def matmul(first, second):
    return [[sum(first[row][axis] * second[axis][column] for axis in range(3))
             for column in range(3)] for row in range(3)]


def cube_rotations():
    """Proper signed axis permutations; mirrors are refused, no arbitrary fit is guessed."""
    for permutation in itertools.permutations(range(3)):
        parity = (-1) ** sum(permutation[first] > permutation[second]
                             for first in range(3) for second in range(first + 1, 3))
        for signs in itertools.product((-1, 1), repeat=3):
            if parity * math.prod(signs) != 1:
                continue
            yield [[signs[row] if column == permutation[row] else 0 for column in range(3)] for row in range(3)]


def importer_basis(geometries, rows):
    """Recover a verified importer bake from all actual piece centers in one GLB batch.

    Each batch may have a different placement/scale. Actual MeshPart CFrames may
    also carry a common rotation. Recover only one unambiguous proper axis bake
    which accounts for all original centers, mesh dimensions and actual pivots.
    """
    if len(geometries) < 3:
        raise RigError("At least three distinct mesh centers are needed to verify an importer batch")
    first_cf = rows[geometries[0]["name"]]["cframe"]
    actual_rotation = [first_cf[3:6], first_cf[6:9], first_cf[9:12]]
    for geometry in geometries:
        rotation = rows[geometry["name"]]["cframe"][3:]
        if max(abs(first - second) for first, second in zip(rotation, first_cf[3:])) > 1e-4:
            raise RigError("Importer batch has different per-piece rotations; inspect before assembling")
    candidates = []
    for bake in cube_rotations():
        total_rotation = matmul(actual_rotation, bake)
        scales = []
        try:
            for geometry in geometries:
                row = rows[geometry["name"]]
                baked_size = matvec([[abs(value) for value in axis] for axis in bake], geometry["size"])
                scales.append(uniform_ratio(row["size"], baked_size, geometry["name"] + ":Size"))
                if row.get("mesh_size"):
                    uniform_ratio(row["mesh_size"], baked_size, geometry["name"] + ":MeshSize")
            scale = sum(scales) / len(scales)
            if max(abs(value / scale - 1) for value in scales) > TOLERANCE:
                continue
            translations = []
            for geometry in geometries:
                expected = matvec(total_rotation, geometry["center"])
                actual = rows[geometry["name"]]["cframe"][:3]
                translations.append([actual[axis] - scale * expected[axis] for axis in range(3)])
            offset = [sum(row[axis] for row in translations) / len(translations) for axis in range(3)]
            error = max(abs(row[axis] - offset[axis]) for row in translations for axis in range(3))
            if error > max(0.003, scale * 0.003):
                continue
            for geometry, imported_scale in zip(geometries, scales):
                row = rows[geometry["name"]]
                pivot = translation(row["pivot_offset"], geometry["name"] + ":PivotOffset")
                rotated_offset = matvec(bake, geometry["offset"])
                origin_pivot = [-value * imported_scale for value in rotated_offset]
                zero_error = max(abs(value) for value in pivot)
                origin_error = max(abs(value - target) for value, target in zip(pivot, origin_pivot))
                if min(zero_error, origin_error) > max(0.002, imported_scale * 0.002):
                    raise RigError("Unexplained importer PivotOffset")
            candidates.append({"bake": bake, "scale": scale, "offset": offset, "maximum_center_error": error})
        except RigError:
            continue
    if len(candidates) != 1:
        raise RigError(f"Importer rotation is not uniquely verified ({len(candidates)} candidates); inspect before assembling")
    return candidates[0]


def root_placement(origin, size, foot_bottom, target_height, lower_torso_center, policy="source"):
    """Optionally repair only the invisible root reference, never a body mesh/bone.

    Short source legs can put a fixed 2-stud root below the actual sole. The
    explicit repair uses the exported LowerTorso's measured center on Y only;
    every original joint world position and rendered vertex stays unchanged.
    """
    if policy not in ("source", "lower-torso-y"):
        raise RigError("Unknown invisible-root reference policy")
    center = list(origin)
    original_height = origin[1] - size[1] * 0.5 - foot_bottom
    if policy == "lower-torso-y" and original_height <= 0.01:
        center[1] = lower_torso_center[1]
        if center[1] <= origin[1]:
            raise RigError("Actual LowerTorso center cannot repair the root reference")
    height = center[1] - size[1] * 0.5 - foot_bottom
    if not 0.01 < height < target_height:
        raise RigError("Actual foot geometry cannot establish a safe R15 HipHeight")
    return center, height, {"policy": policy, "source_center": list(origin),
                            "assembled_center": center, "source_hip_height": original_height,
                            "actual_foot_bottom": foot_bottom, "visible_geometry_changed": False}


def manifest(path, name, root_reference="source"):
    path = Path(path).resolve()
    metadata = json.loads(path.read_text(encoding="utf-8"))
    if metadata.get("schema") != 1 or metadata.get("dry_run"):
        raise RigError("A completed schema-1 conversion is required")
    if not re.fullmatch(r"Costume_(Halo|Horns|Neutral)(Warrior|Mage|Archer)[MF]", name):
        raise RigError("Not an approved costume template name")
    if metadata.get("rig_ready_for_game") is not False or not metadata.get("requires_studio_animation_validation"):
        raise RigError("Assembly accepts pending conversions only")
    if metadata.get("texture_rebake") or metadata.get("uv_repack") or not metadata.get("original_texture_bytes_preserved"):
        raise RigError("Original UV and image byte preservation is required")
    source = Path(metadata["source"])
    if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != metadata["source_sha256"]:
        raise RigError("Real rig input is missing or changed")
    parts = {part["name"]: part for part in metadata["parts"]}
    if len(parts) != len(metadata["parts"]) or set(parts) != set(PRIMARY):
        raise RigError("Exactly the 15 genuine R15 body regions are required")
    meshes = {mesh["name"]: mesh for mesh in metadata["meshes"]}
    if len(meshes) != len(metadata["meshes"]):
        raise RigError("Duplicate exported mesh name")
    part_meshes = [mesh for part in parts.values() for mesh in part["meshes"]]
    if len(part_meshes) != len(set(part_meshes)) or set(part_meshes) != set(meshes):
        raise RigError("Every material fragment must belong to exactly one real R15 body region")
    for part in parts.values():
        translation(part["CFrame"], part["name"])
        if part["name"] not in part["meshes"] or not meshes[part["name"]]["is_primary"]:
            raise RigError("Each region needs its same-name primary MeshPart")
    geometries = {}
    for batch in metadata["batches"]:
        batch_path = path.parent / batch["file"]
        if batch_path.parent != path.parent or batch.get("estimated_assets", 1000) > 10:
            raise RigError("Invalid local upload batch")
        gltf, binary, content = read_glb(batch_path)
        if hashlib.sha256(content).hexdigest() != batch["sha256"]:
            raise RigError(f"Changed GLB: {batch_path.name}")
        if gltf.get("skins"):
            raise RigError("Only the verified rigid exported pieces can be assembled")
        hashes = {hashlib.sha256(image_bytes(gltf, binary, image)).hexdigest() for image in gltf.get("images", [])}
        if hashes != set(batch["texture_sha256"].values()):
            raise RigError("Exported source texture bytes changed")
        batch_names = set()
        for node in gltf.get("nodes", []):
            if "mesh" not in node:
                continue
            mesh_name = node.get("name")
            if mesh_name not in meshes or mesh_name in geometries:
                raise RigError("Unexpected or duplicate exported mesh")
            if any(key in node for key in ("matrix", "rotation", "scale", "children")):
                raise RigError("Unexpected baked or nested mesh transform")
            origin = finite_vector(node.get("translation", [0, 0, 0]), 3, "mesh origin")
            expected_origin = translation(meshes[mesh_name]["CFrame"], mesh_name)
            if max(abs(first - second) for first, second in zip(origin, expected_origin)) > 1e-5:
                raise RigError("Exported mesh origin disagrees with actual-bone metadata")
            positions, triangles = [], 0
            for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
                if primitive.get("mode", 4) != 4 or "indices" not in primitive:
                    raise RigError("Only verified indexed triangles are supported")
                positions.extend(accessor_values(gltf, binary, primitive["attributes"]["POSITION"]))
                triangles += len(accessor_values(gltf, binary, primitive["indices"])) // 3
            if triangles != meshes[mesh_name]["triangles"]:
                raise RigError("Exported triangle count changed")
            geometry = bounds(positions)
            center = [origin[axis] + geometry["offset"][axis] for axis in range(3)]
            geometries[mesh_name] = dict(geometry, name=mesh_name, part=meshes[mesh_name]["part"],
                                         primary=meshes[mesh_name]["is_primary"], origin=origin, center=center,
                                         batch=batch_path.name, triangles=triangles)
            batch_names.add(mesh_name)
        if batch_names != set(batch["parts"]):
            raise RigError("GLB mesh names disagree with the batch record")
    if set(geometries) != set(meshes):
        raise RigError("A material fragment GLB is missing")
    root = metadata["root"]
    root_origin = translation(root["CFrame"], "HumanoidRootPart")
    root_size = finite_vector(root["Size"], 3, "HumanoidRootPart size")
    if min(root_size) <= 0:
        raise RigError("Invalid root size")
    centers = {part: geometries[part]["center"] for part in parts}
    foot_bottom = min(geometries[foot]["origin"][1] + geometries[foot]["min"][1] for foot in ("LeftFoot", "RightFoot"))
    root_center, hip_height, root_reference_record = root_placement(
        root_origin, root_size, foot_bottom, metadata["target_height_studs"], centers["LowerTorso"], root_reference)
    centers["HumanoidRootPart"] = root_center
    expected_edges = {(joint, parent, child) for joint, parent, child, _ in JOINTS}
    actual_edges = {(joint["name"], joint["part0"], joint["part1"]) for joint in metadata["joints"]}
    if len(metadata["joints"]) != 15 or actual_edges != expected_edges:
        raise RigError("Invalid standard R15 joint graph")
    joints = []
    for joint in metadata["joints"]:
        world = finite_vector(joint["joint_position"], 3, joint["name"])
        for part_key, frame_key in (("part0", "C0"), ("part1", "C1")):
            part = joint[part_key]
            previous_origin = root_origin if part == "HumanoidRootPart" else translation(parts[part]["CFrame"], part)
            previous_offset = translation(joint[frame_key], joint["name"] + ":" + frame_key)
            if max(abs(world[axis] - previous_origin[axis] - previous_offset[axis]) for axis in range(3)) > 1e-5:
                raise RigError("Original joint matrices disagree with actual bone position")
        joints.append({"name": joint["name"], "part0": joint["part0"], "part1": joint["part1"],
                       "world": world, "C0": [world[axis] - centers[joint["part0"]][axis] for axis in range(3)] + IDENTITY,
                       "C1": [world[axis] - centers[joint["part1"]][axis] for axis in range(3)] + IDENTITY})
    return {"schema": 1, "name": name, "source_sha256": metadata["source_sha256"],
            "joints_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "meshes": list(geometries.values()), "joints": joints,
            "root": {"center": root_center, "size": root_size}, "hip_height": hip_height,
            "root_reference": root_reference_record,
            "requires_studio_animation_validation": True, "diagnostics": metadata["weight_diagnostics"]}


def inspection_data(path, expected):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("schema") != 1 or data.get("name") != expected["name"] or data.get("source_sha256") != expected["source_sha256"]:
        raise RigError("Inspection is not for this real source rig")
    rows = {row["name"]: row for row in data["meshes"]}
    if len(rows) != len(data["meshes"]) or set(rows) != {mesh["name"] for mesh in expected["meshes"]}:
        raise RigError("Inspection must include each exact imported mesh once")
    for geometry in expected["meshes"]:
        row = rows[geometry["name"]]
        if not re.fullmatch(r"rbxassetid://[1-9][0-9]*", row.get("mesh_id", "")):
            raise RigError("Every piece needs its actually uploaded Roblox mesh asset ID")
        finite_vector(row["size"], 3, "imported Size")
        cf = finite_vector(row["cframe"], 12, "imported CFrame")
        # Verify the actual rigid transform, without inferring source geometry from placement.
        rotation = [cf[3:6], cf[6:9], cf[9:12]]
        for axis, first in enumerate(rotation):
            for second_axis, second in enumerate(rotation):
                target = 1 if axis == second_axis else 0
                if abs(sum(a * b for a, b in zip(first, second)) - target) > 1e-4:
                    raise RigError("Imported CFrame is not a rigid rotation")
        translation(row["pivot_offset"], geometry["name"] + ":PivotOffset")
    batches = {}
    for geometry in expected["meshes"]:
        batches.setdefault(geometry["batch"], []).append(geometry)
    bases = {"HumanoidRootPart": [[1, 0, 0], [0, 1, 0], [0, 0, 1]]}
    centers = {"HumanoidRootPart": expected["root"]["center"]}
    expected["importer_batches"] = {}
    for batch_name, geometries in batches.items():
        verified = importer_basis(geometries, rows)
        expected["importer_batches"][batch_name] = verified
        bake = verified["bake"]
        inverse_bake = transpose(bake)
        for geometry in geometries:
            geometry["assembled_cframe"] = geometry["center"] + [value for row in inverse_bake for value in row]
            geometry["assembled_size"] = matvec([[abs(value) for value in row] for row in bake], geometry["size"])
            rows[geometry["name"]]["import_baked_rotation"] = bake
            rows[geometry["name"]]["import_scale"] = verified["scale"]
            if geometry["primary"]:
                bases[geometry["part"]] = bake
                centers[geometry["part"]] = geometry["center"]
    for joint in expected["joints"]:
        for part_key, frame_key in (("part0", "C0"), ("part1", "C1")):
            part = joint[part_key]
            delta = [joint["world"][axis] - centers[part][axis] for axis in range(3)]
            joint[frame_key] = matvec(bases[part], delta) + [value for row in bases[part] for value in row]
    return rows


COMMON = r'''
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
if RunService:IsRunning() then error("코스튬 조립은 Edit 모드에서만 실행합니다.") end
local DATA = HttpService:JSONDecode(__MANIFEST__)
local sourceFolder = ServerStorage:FindFirstChild("CostumeImports")
local source = sourceFolder and sourceFolder:FindFirstChild(DATA.name)
if not source then error("CostumeImports에 실제 가져온 모델이 없습니다: " .. DATA.name) end
local expected, imported = {}, {}
for _, geometry in DATA.meshes do expected[geometry.name] = geometry end
for _, descendant in source:GetDescendants() do
    if descendant:IsA("MeshPart") then
        local name = descendant.Name
        if not expected[name] then name = string.gsub(name, "Mesh$", "") end
        if not expected[name] then error("예상하지 못한 MeshPart: " .. descendant:GetFullName()) end
        if imported[name] then error("중복 MeshPart: " .. name) end
        imported[name] = descendant
    end
end
local function vector(v) return { v.X, v.Y, v.Z } end
local function transform(v) return { v:GetComponents() } end
local function appearance(part)
    local maps = {}
    local surface = part:FindFirstChildOfClass("SurfaceAppearance")
    if surface then
        for _, property in { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap" } do
            maps[property] = surface[property]
        end
        maps.AlphaMode = surface.AlphaMode.Name
    end
    return { texture_id = part.TextureID, surface = maps }
end
local function properties(part, expectedName)
    local meshSize
    pcall(function() meshSize = vector(part.MeshSize) end)
    return { name = expectedName, imported_name = part.Name, path = part:GetFullName(), mesh_id = part.MeshId,
             size = vector(part.Size), mesh_size = meshSize, cframe = transform(part.CFrame),
             pivot_offset = transform(part.PivotOffset), appearance = appearance(part) }
end
for _, geometry in DATA.meshes do
    if not imported[geometry.name] then error("아직 가져오지 않은 MeshPart: " .. geometry.name) end
end
'''

INSPECT = r'''
local report = { schema = 1, name = DATA.name, source_sha256 = DATA.source_sha256,
                 meshes = {}, destination = "ServerStorage.CostumePendingRigs", read_only = true }
for _, geometry in DATA.meshes do table.insert(report.meshes, properties(imported[geometry.name], geometry.name)) end
return HttpService:JSONEncode(report)
'''

ASSEMBLE = r'''
local SNAPSHOT = HttpService:JSONDecode(__SNAPSHOT__)
local function sameArray(actual, snapshot, label)
    if #actual ~= #snapshot then error("검사 후 속성 길이가 바뀜: " .. label) end
    for index, value in actual do
        if math.abs(value - snapshot[index]) > 0.0001 then error("검사 후 속성이 바뀜: " .. label) end
    end
end
local function sameAppearance(actual, snapshot, label)
    if actual.texture_id ~= snapshot.texture_id then error("검사 후 TextureID가 바뀜: " .. label) end
    for property, value in actual.surface do
        if snapshot.surface[property] ~= value then error("검사 후 텍스처 맵이 바뀜: " .. label) end
    end
    for property, value in snapshot.surface do
        if actual.surface[property] ~= value then error("검사 후 텍스처 맵이 없어짐: " .. label) end
    end
end
-- Validate all actual imported data before creating or changing anything.
for _, geometry in DATA.meshes do
    local actual, snapshot = properties(imported[geometry.name], geometry.name), SNAPSHOT[geometry.name]
    if not snapshot or actual.mesh_id ~= snapshot.mesh_id then error("검사 후 메시가 바뀜: " .. geometry.name) end
    sameArray(actual.size, snapshot.size, geometry.name .. ".Size")
    sameArray(actual.cframe, snapshot.cframe, geometry.name .. ".CFrame")
    sameArray(actual.pivot_offset, snapshot.pivot_offset, geometry.name .. ".PivotOffset")
    if actual.mesh_size and snapshot.mesh_size then sameArray(actual.mesh_size, snapshot.mesh_size, geometry.name .. ".MeshSize") end
    sameAppearance(actual.appearance, snapshot.appearance, geometry.name)
end
local pending = ServerStorage:FindFirstChild("CostumePendingRigs")
if pending and not pending:IsA("Folder") then error("CostumePendingRigs가 Folder가 아닙니다.") end
if pending and pending:FindFirstChild(DATA.name) then error("기존 검증 대기 리그가 있습니다. 덮어쓰지 않습니다.") end
local model = Instance.new("Model")
model.Name = DATA.name
local ok, result = pcall(function()
    local pieces, parts = {}, {}
    for _, geometry in DATA.meshes do
        local part = imported[geometry.name]:Clone()
        if not part then error("MeshPart 복제 실패: " .. geometry.name) end
        -- Imported controllers/constraints are never trusted. Keep the original surface pixels only.
        for _, child in part:GetDescendants() do
            if child:IsA("LuaSourceContainer") or child:IsA("JointInstance") or child:IsA("Constraint")
                or child:IsA("Attachment") or child:IsA("Bone") then child:Destroy() end
        end
        part.Name = geometry.name
        part.Anchored = false
        part.CanCollide = geometry.primary and (geometry.part == "Head" or geometry.part == "UpperTorso" or geometry.part == "LowerTorso")
        part.CanTouch = false
        part.Massless = true
        -- Roblox MeshPart geometry is centered in Size. The GLB node origin may differ for material fragments.
        -- Set exact original extents and the original geometry center; never use batch placement as a body origin.
        part.Size = Vector3.new(table.unpack(geometry.assembled_size))
        part.CFrame = CFrame.new(table.unpack(geometry.assembled_cframe))
        part.PivotOffset = CFrame.new()
        part:SetAttribute("HHC_SourcePart", geometry.part)
        part:SetAttribute("HHC_SourceMesh", geometry.name)
        part.Parent = model
        sameAppearance(appearance(part), SNAPSHOT[geometry.name].appearance, geometry.name)
        pieces[geometry.name] = part
        if geometry.primary then parts[geometry.part] = part end
    end
    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(table.unpack(DATA.root.size))
    root.CFrame = CFrame.new(table.unpack(DATA.root.center))
    root.Transparency = 1
    root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
    root.Anchored, root.Massless = false, false
    root.RootPriority = 127
    root.Parent = model
    parts.HumanoidRootPart = root
    for _, joint in DATA.joints do
        local motor = Instance.new("Motor6D")
        motor.Name = joint.name
        motor.Part0, motor.Part1 = parts[joint.part0], parts[joint.part1]
        motor.C0, motor.C1 = CFrame.new(table.unpack(joint.C0)), CFrame.new(table.unpack(joint.C1))
        motor.Transform = CFrame.new()
        motor.Parent = parts[joint.part1]
        for _, side in { { joint.part0, joint.C0 }, { joint.part1, joint.C1 } } do
            local attachment = Instance.new("Attachment")
            attachment.Name = joint.name .. "RigAttachment"
            attachment.CFrame = CFrame.new(table.unpack(side[2]))
            attachment.Parent = parts[side[1]]
        end
        local zero = motor.Part0.CFrame * motor.C0
        local one = motor.Part1.CFrame * motor.C1
        if (zero.Position - one.Position).Magnitude > 0.0001 then error("실제 뼈 관절 불일치: " .. joint.name) end
    end
    local extraCount = 0
    for _, geometry in DATA.meshes do
        if not geometry.primary then
            local weld = Instance.new("WeldConstraint")
            weld.Name = "MaterialFragmentWeld"
            weld.Part0, weld.Part1 = parts[geometry.part], pieces[geometry.name]
            weld.Parent = pieces[geometry.name]
            extraCount += 1
        end
    end
    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    humanoid.RigType = Enum.HumanoidRigType.R15
    humanoid.AutomaticScalingEnabled = false
    humanoid.HipHeight = DATA.hip_height
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = true
    humanoid.Parent = model
    local animator = Instance.new("Animator")
    animator.Parent = humanoid
    model.PrimaryPart = root
    model:SetAttribute("HHC_SourceSHA256", DATA.source_sha256)
    model:SetAttribute("HHC_JointsSHA256", DATA.joints_sha256)
    model:SetAttribute("HHC_AnimationValidated", false)
    model:SetAttribute("HHC_PendingAnimationQA", true)
    model:SetAttribute("HHC_OriginalUVPreserved", true)
    model:SetAttribute("HHC_OriginalTextureBytesPreserved", true)
    return { schema = 1, name = DATA.name, mesh_parts = #DATA.meshes, body_parts = 15, motors = #DATA.joints,
             material_welds = extraCount, attachments = #DATA.joints * 2, hip_height = humanoid.HipHeight,
             source_sha256 = DATA.source_sha256, animation_validated = false,
             destination = "ServerStorage.CostumePendingRigs." .. DATA.name }
end)
if not ok then model:Destroy(); error(result) end
if not pending then
    pending = Instance.new("Folder")
    pending.Name = "CostumePendingRigs"
    pending.Parent = ServerStorage
end
model.Parent = pending
return HttpService:JSONEncode(result)
'''


def script(data, mode, snapshot=None):
    encoded = json.dumps(json.dumps(data, ensure_ascii=False, separators=(",", ":")), ensure_ascii=False)
    code = COMMON.replace("__MANIFEST__", encoded)
    if mode == "inspect":
        return code + INSPECT
    if snapshot is None:
        raise RigError("Assembly requires a checked actual import inspection")
    encoded_snapshot = json.dumps(json.dumps(snapshot, ensure_ascii=False, separators=(",", ":")), ensure_ascii=False)
    return code + ASSEMBLE.replace("__SNAPSHOT__", encoded_snapshot)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("joints", type=Path)
    parser.add_argument("--name")
    parser.add_argument("--mode", choices=("inspect", "assemble"), default="inspect")
    parser.add_argument("--inspection", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--root-reference", choices=("source", "lower-torso-y"), default="source",
                        help="Explicitly repair a non-positive HipHeight using the actual LowerTorso center; visible meshes/bones stay unchanged")
    args = parser.parse_args()
    name = args.name or args.joints.resolve().parent.name
    data = manifest(args.joints, name, args.root_reference)
    snapshot = None
    if args.mode == "assemble":
        if not args.inspection:
            raise RigError("First run the read-only inspection and pass its saved JSON with --inspection")
        snapshot = inspection_data(args.inspection, data)
    output = (args.output or args.joints.resolve().parent / ("inspect_imports.json" if args.mode == "inspect" else "assemble_pending.json")).resolve()
    if ROOT / "build" not in output.parents:
        raise RigError("Generated execution payloads may be written only inside build/")
    output.parent.mkdir(parents=True, exist_ok=True)
    code = script(data, args.mode, snapshot)
    output.with_suffix(".luau").write_text(code, encoding="utf-8", newline="\n")
    output.write_text(json.dumps({"code": code, "datamodel_type": "Edit"}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    output.with_name("assembly_manifest.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"payload": output.relative_to(ROOT).as_posix(), "mode": args.mode,
                      "meshes": len(data["meshes"]), "motors": len(data["joints"]), "hip_height": data["hip_height"],
                      "promotion": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
