"""Optional in-memory subdivisions of genuine skinned source triangles.

The source disk file is never written. New corners are barycentric samples of
the original plane/UV/normal/skin fields. Elbow recovery is an explicit policy
using the original elbow/wrist bone positions, never a guessed skeleton.
"""
from __future__ import annotations

from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

from audit_skin import area_ratio, clip_polygon, dominance_patch, subdivision_normal_error
from constraints import PRIMARY, RigError, bone_regions, face_region, region_weights
from glb_io import accessor_values, read_glb


UNIT_TRIANGLE = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]


def lerp(barycentric, corners):
    return tuple(sum(barycentric[corner] * corners[corner][axis] for corner in range(3))
                 for axis in range(len(corners[0])))


def elbow_patches(points, elbow, wrist):
    axis = [wrist[i] - elbow[i] for i in range(3)]
    length_squared = sum(value * value for value in axis)
    if not math.isfinite(length_squared) or length_squared < 1e-12:
        raise RigError("Actual elbow/wrist bone axis is degenerate")
    start = [sum((point[i] - elbow[i]) * axis[i] for i in range(3)) / length_squared for point in points]
    end = [1 - value for value in start]
    before = clip_polygon(UNIT_TRIANGLE, [-value for value in start])
    middle = clip_polygon(clip_polygon(UNIT_TRIANGLE, start), end)
    after = clip_polygon(clip_polygon(UNIT_TRIANGLE, start), [-value for value in end])
    polygons = [(None, before), ("LeftLowerArm", middle), (None, after)]
    if abs(sum(area_ratio(polygon) for _, polygon in polygons) - 1) > 1e-9:
        raise RigError("Original elbow-plane surface coverage is incomplete or overlaps")
    return [(owner, polygon) for owner, polygon in polygons if area_ratio(polygon) > 1e-14]


def entire_face_in_elbow_slab(points, elbow, wrist):
    """Select only an existing face completely between the actual bone planes.

    This conservative recovery retains all source triangles and corner normals.
    Triangles crossing either plane keep their old owner; no new surface is made.
    """
    axis = [wrist[i] - elbow[i] for i in range(3)]
    length_squared = sum(value * value for value in axis)
    if not math.isfinite(length_squared) or length_squared < 1e-12:
        raise RigError("Actual elbow/wrist bone axis is degenerate")
    projections = [sum((point[i] - elbow[i]) * axis[i] for i in range(3)) / length_squared for point in points]
    return all(-1e-10 <= value <= 1 + 1e-10 for value in projections)


def entire_face_beyond_joint(points, parent_joint, child_joint):
    """Retain only existing faces on the child side of a real source joint."""
    axis = [child_joint[i] - parent_joint[i] for i in range(3)]
    squared = sum(value * value for value in axis)
    if not math.isfinite(squared) or squared < 1e-12:
        raise RigError("Actual parent/child bone axis is degenerate")
    return all(sum((point[i] - child_joint[i]) * axis[i] for i in range(3)) / squared >= -1e-10
               for point in points)


def triangulate(polygons):
    result = []
    for owner, polygon in polygons:
        for index in range(1, len(polygon) - 1):
            triangle = [polygon[0], polygon[index], polygon[index + 1]]
            signed_ratio = sum(a[1] * b[2] - b[1] * a[2] for a, b in zip(triangle, triangle[1:] + triangle[:1]))
            if signed_ratio < -1e-12:
                raise RigError("Subdivision reversed original triangle winding")
            if signed_ratio > 1e-14:
                result.append((owner, triangle))
    if abs(sum(area_ratio(triangle) for _, triangle in result) - 1) > 1e-9:
        raise RigError("Subdivision changed original triangle surface coverage")
    return result


def prepare(split_ties=False, recover_left_forearm=False, recover_left_foot=False, head_faces=None, source=None):
    """Called after Blender imports a fresh source, before normal conversion."""
    import bpy

    arms = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(arms) != 1:
        raise RigError("Mechanical subdivision requires one real armature")
    arm = arms[0]
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    parents = {bone.name: bone.parent.name if bone.parent else None for bone in arm.data.bones}
    mapping, primary = bone_regions(parents)
    shapes = {bone.custom_shape for bone in arm.pose.bones if bone.custom_shape}
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not
              (obj in shapes and obj.users_collection and all(collection.name == "glTF_not_exported" and
               collection.hide_render and collection.hide_viewport for collection in obj.users_collection))]
    elbow = tuple(arm.matrix_world @ arm.data.bones[primary["LeftLowerArm"]].head_local)
    wrist = tuple(arm.matrix_world @ arm.data.bones[primary["LeftHand"]].head_local)
    knee = tuple(arm.matrix_world @ arm.data.bones[primary["LeftLowerLeg"]].head_local)
    ankle = tuple(arm.matrix_world @ arm.data.bones[primary["LeftFoot"]].head_local)
    torso = tuple(arm.matrix_world @ arm.data.bones[primary["UpperTorso"]].head_local)
    head = tuple(arm.matrix_world @ arm.data.bones[primary["Head"]].head_local)
    source_faces, owners = {}, Counter()
    for obj in meshes:
        if obj.data.shape_keys or len(obj.data.color_attributes):
            raise RigError("Shape keys/vertex colors require a separate preserving subdivision path")
        modifiers = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
        if len(modifiers) != 1 or modifiers[0].object != arm or any(mod.type != "ARMATURE" for mod in obj.modifiers):
            raise RigError("Subdivision requires the unchanged genuine source skin")
        group_names = {group.index: group.name for group in obj.vertex_groups}
        weights = [region_weights([(group_names[group.group], group.weight) for group in vertex.groups], mapping)
                   for vertex in obj.data.vertices]
        records = []
        for face in obj.data.polygons:
            if len(face.vertices) != 3:
                raise RigError("Mechanical subdivision requires original source triangles")
            rows = [weights[index] for index in face.vertices]
            tied = False
            try:
                owner, _ = face_region(rows)
            except RigError:
                if not split_ties:
                    raise
                owner, _ = face_region(rows, "parent-depth")
                tied = True
            owners[owner] += 1
            records.append((face.index, owner, rows, tied))
        source_faces[obj] = records
    head_matches = {}
    if head_faces:
        from mathutils import Matrix, Vector
        config = json.loads(Path(head_faces).read_text(encoding="utf-8"))
        source = Path(source).resolve()
        if Path(config["source_rig"]).resolve() != source or hashlib.sha256(source.read_bytes()).hexdigest() != config["source_rig_sha256"]:
            raise RigError("Projected head-face signatures refer to a different real source")
        fixed = Path(__file__).resolve().parents[2] / "art/models/costume/fixed" / (config["avatar"] + ".glb")
        if not fixed.is_file() or hashlib.sha256(fixed.read_bytes()).hexdigest() != config["source_fixed_sha256"]:
            raise RigError("Projected facial reference changed")
        affine_values = config["fixed_to_rig_affine"]
        if len(affine_values) != 4 or any(len(row) != 4 or not all(math.isfinite(value) for value in row) for row in affine_values):
            raise RigError("Invalid verified source-coordinate map")
        affine = Matrix(affine_values)
        fixed_gltf, fixed_binary, _ = read_glb(fixed)
        fixed_centroids = {}
        for node in fixed_gltf["nodes"]:
            if "mesh" not in node:
                continue
            if any(key in node for key in ("matrix", "rotation", "scale", "children")):
                raise RigError("Unexpected fixed-reference node transform")
            node_offset = node.get("translation", (0, 0, 0))
            for primitive in fixed_gltf["meshes"][node["mesh"]]["primitives"]:
                material = fixed_gltf["materials"][primitive["material"]]
                if not material["name"].startswith("HeadMat"):
                    continue
                points = accessor_values(fixed_gltf, fixed_binary, primitive["attributes"]["POSITION"])
                uv_rows = accessor_values(fixed_gltf, fixed_binary, primitive["attributes"]["TEXCOORD_0"])
                indices = [value[0] for value in accessor_values(fixed_gltf, fixed_binary, primitive["indices"])]
                for start in range(0, len(indices), 3):
                    triangle = indices[start:start + 3]
                    # Blender imports V with one float32 flip. Mirror that
                    # numeric representation without editing either UV field.
                    signature = tuple(sorted((round(uv_rows[i][0], 6), round(struct.unpack("<f", struct.pack("<f", 1 - uv_rows[i][1]))[0], 6)) for i in triangle))
                    world = [Vector((points[i][0] + node_offset[0], -points[i][2] - node_offset[2], points[i][1] + node_offset[1])) for i in triangle]
                    fixed_centroids.setdefault(signature, []).append(sum(world, Vector()) / 3)
        rows = config["expression_front_face_signatures_excluded"]
        if not rows or len(rows) > 1000:
            raise RigError("An explicit small projected facial signature list is required")
        candidates = {}
        for obj, records in source_faces.items():
            for face_index, owner, _, _ in records:
                face = obj.data.polygons[face_index]
                material = obj.data.materials[face.material_index]
                if not material.name.startswith("HeadMat"):
                    continue
                uv = obj.data.uv_layers.active
                signature = tuple(sorted((round(uv.data[loop].uv.x, 6), round(uv.data[loop].uv.y, 6)) for loop in face.loop_indices))
                candidates.setdefault(signature, []).append((obj, face_index, owner))
        used = set()
        for row in rows:
            signature = tuple(sorted(tuple(uv) for uv in row["original_uv_signature"]))
            if signature in used:
                raise RigError("Duplicate projected face UV signature")
            used.add(signature)
            matches = candidates.get(signature, [])
            if len(matches) != 1:
                raise RigError("Projected facial triangle does not match one exact original HeadMat face")
            obj, face_index, owner = matches[0]
            if owner != row["part"] or owner not in ("UpperTorso", "LeftUpperArm", "RightUpperArm"):
                raise RigError("Projected facial source ownership changed")
            points = [obj.matrix_world @ obj.data.vertices[index].co for index in obj.data.polygons[face_index].vertices]
            centroid = sum(points, Vector()) / 3
            fixed_matches = fixed_centroids.get(signature, [])
            if len(fixed_matches) != 1:
                raise RigError("Projected face signature is not one exact original fixed-reference triangle")
            expected = affine @ fixed_matches[0]
            residual = (centroid - expected).length
            head_side = entire_face_beyond_joint(points, torso, head)
            if residual > 1e-5 or not head_side:
                raise RigError(f"A projected facial triangle fails actual geometry/head-joint verification (residual={residual}, head_side={head_side}, face={face_index})")
            head_matches[(obj, face_index)] = "Head"
    if recover_left_forearm and owners["LeftLowerArm"]:
        raise RigError("Elbow recovery is only for a genuinely empty LeftLowerArm region")
    if recover_left_foot and owners["LeftFoot"]:
        raise RigError("Ankle recovery is only for a genuinely empty LeftFoot region")
    overrides, report = {}, {"enabled": True, "split_weight_ties": split_ties,
        "recover_empty_left_forearm": recover_left_forearm, "source_triangles": sum(owners.values()),
        "subdivided_source_faces": 0, "extra_triangles": 0, "original_vertices_changed": False,
        "reassigned_original_faces": 0,
        "projected_head_faces_restored": len(head_matches),
        "projected_head_face_signature_file": str(Path(head_faces).resolve()) if head_faces else None,
        "projected_head_face_signature_sha256": hashlib.sha256(Path(head_faces).read_bytes()).hexdigest() if head_faces else None,
        "forearm_recovery_policy": "Only original weighted arm/hand triangles entirely inside the actual elbow/wrist bone slab; crossing triangles retain their original owner." if recover_left_forearm else None,
        "recover_empty_left_foot": recover_left_foot,
        "foot_recovery_policy": "Only original weighted left-leg triangles entirely on the foot side of the actual knee-to-ankle bone plane; crossing triangles retain their original owner." if recover_left_foot else None,
        "maximum_coverage_error": 0.0, "maximum_sampled_normalization_error_degrees": 0.0,
        "uv_repack": False, "texture_rebake": False, "elbow_world": elbow if recover_left_forearm else None,
        "wrist_world": wrist if recover_left_forearm else None, "faces": []}
    report["knee_world"] = knee if recover_left_foot else None
    report["ankle_world"] = ankle if recover_left_foot else None
    for obj, records in source_faces.items():
        old = obj.data
        group_name_order = [group.name for group in obj.vertex_groups]
        original_positions = [tuple(vertex.co) for vertex in old.vertices]
        original_groups = [{group.group: group.weight for group in vertex.groups} for vertex in old.vertices]
        original_normals = [tuple(normal.vector) for normal in old.corner_normals]
        original_uvs = {layer.name: [tuple(loop.uv) for loop in layer.data] for layer in old.uv_layers}
        positions, weights = list(original_positions), list(original_groups)
        triangles, materials, smooth, normals = [], [], [], []
        uv_values = {name: [] for name in original_uvs}
        override = {}
        changed = False
        for face_index, old_owner, region_rows, tied in records:
            face = old.polygons[face_index]
            vertices = list(face.vertices)
            local_points = [original_positions[i] for i in vertices]
            world_points = [tuple(obj.matrix_world @ old.vertices[i].co) for i in vertices]
            source_normals = [original_normals[i] for i in face.loop_indices]
            source_uv = {name: [values[i] for i in face.loop_indices] for name, values in original_uvs.items()}
            polygons = None
            reassign_original = None
            if tied:
                polygons = [(None, dominance_patch(region_rows, region))
                            for region in sorted(set.union(*(set(row) for row in region_rows)))]
            elif recover_left_forearm and old_owner in ("LeftUpperArm", "LeftHand") and any(
                    row.get("LeftLowerArm", 0) > 1e-8 for row in region_rows):
                if entire_face_in_elbow_slab(world_points, elbow, wrist):
                    reassign_original = "LeftLowerArm"
            elif recover_left_foot and old_owner in ("LeftLowerLeg", "LeftUpperLeg") and any(
                    row.get("LeftFoot", 0) > 1e-8 for row in region_rows):
                if entire_face_beyond_joint(world_points, knee, ankle):
                    reassign_original = "LeftFoot"
            elif (obj, face_index) in head_matches:
                reassign_original = "Head"
            chunks = triangulate(polygons) if polygons else [(reassign_original, UNIT_TRIANGLE)]
            if reassign_original:
                report["reassigned_original_faces"] += 1
                report["faces"].append({"object": obj.name, "source_face": face_index,
                    "reason": {"LeftLowerArm": "entire_original_face_in_actual_elbow_wrist_slab", "LeftFoot": "entire_original_face_on_actual_ankle_foot_side", "Head": "verified_projected_front_face_uv_geometry_signature"}[reassign_original], "source_owner": old_owner,
                    "triangles": 1, "barycentric_triangles": [{"owner_override": reassign_original, "corners": UNIT_TRIANGLE}]})
            if polygons:
                changed = True
                report["subdivided_source_faces"] += 1
                report["extra_triangles"] += len(chunks) - 1
                report["maximum_coverage_error"] = max(report["maximum_coverage_error"],
                    abs(sum(area_ratio(tri) for _, tri in chunks) - 1))
                report["maximum_sampled_normalization_error_degrees"] = max(
                    report["maximum_sampled_normalization_error_degrees"],
                    subdivision_normal_error(source_normals, [poly for _, poly in polygons]))
                report["faces"].append({"object": obj.name, "source_face": face_index, "reason": "weight_tie" if tied else "actual_elbow_wrist_slab",
                                         "source_owner": old_owner, "triangles": len(chunks),
                                         "barycentric_triangles": [{"owner_override": owner, "corners": tri} for owner, tri in chunks]})
            added = {}
            for owner, barycentric in chunks:
                face_vertices = []
                for bary in barycentric:
                    if bary in UNIT_TRIANGLE:
                        index = vertices[UNIT_TRIANGLE.index(bary)]
                    else:
                        key = tuple(round(value, 13) for value in bary)
                        if key not in added:
                            index = len(positions)
                            positions.append(lerp(bary, local_points))
                            group_ids = set.union(*(set(original_groups[i]) for i in vertices))
                            weights.append({group: sum(bary[corner] * original_groups[vertices[corner]].get(group, 0)
                                                      for corner in range(3)) for group in group_ids})
                            added[key] = index
                        index = added[key]
                    face_vertices.append(index)
                    normals.append(lerp(bary, source_normals))
                    for name, corners in source_uv.items():
                        uv_values[name].append(lerp(bary, corners))
                if owner:
                    override[len(triangles)] = owner
                triangles.append(face_vertices)
                materials.append(face.material_index)
                smooth.append(face.use_smooth)
        if not changed:
            if override:
                overrides[obj] = override  # Pure source-face ownership change; mesh data is untouched.
            continue
        new = bpy.data.meshes.new(old.name + "_PreservedSurfaceSplit")
        new.from_pydata(positions, [], triangles)
        new.update()
        for material in old.materials:
            new.materials.append(material)
        for face, material, shading in zip(new.polygons, materials, smooth):
            face.material_index, face.use_smooth = material, shading
        for name, values in uv_values.items():
            layer = new.uv_layers.new(name=name)
            for target, value in zip(layer.data, values):
                target.uv = value
        new.normals_split_custom_set(normals)
        obj.data = new
        obj.vertex_groups.clear()
        for name in group_name_order:
            obj.vertex_groups.new(name=name)
        for index, row in enumerate(weights):
            for group, value in row.items():
                if value > 1e-8:
                    obj.vertex_groups[group].add([index], value, "REPLACE")
        if any(tuple(new.vertices[index].co) != value for index, value in enumerate(original_positions)):
            raise RigError("Mechanical subdivision moved an original vertex")
        overrides[obj] = override
    if recover_left_forearm and not any(overrides.values()):
        raise RigError("Actual elbow/wrist source slab has no recoverable weighted forearm surface")
    if recover_left_foot and not any("LeftFoot" in row.values() for row in overrides.values()):
        raise RigError("Actual ankle source plane has no recoverable weighted foot surface")
    if report["maximum_sampled_normalization_error_degrees"] > 0.1:
        raise RigError("Subdivision shading-field change exceeds the reviewed mechanical tolerance")
    report["output_triangles"] = report["source_triangles"] + report["extra_triangles"]
    return overrides, report
