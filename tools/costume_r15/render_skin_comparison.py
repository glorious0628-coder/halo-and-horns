"""Compare an original weighted visual with its rigid R15 proxy offline.

Bone matrices are driven by the same proxy world deltas. This verifies actual
Blender Armature deformation against independent LBS; it is not Studio QA.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from constraints import RigError
from render_manual_motion import TO_BLENDER, transforms


ROOT = Path(__file__).resolve().parents[2]
# Blender's imported rest axes may contain tiny non-orthogonal components.
# A pose channel cannot retain shear. Check actual Bone LBS strictly, and keep
# the independently measured target-pose projection below 0.0001 stud as well.
LBS_TOLERANCE = 1e-5
POSE_PROJECTION_TOLERANCE = 1e-4
CHANNEL_SHEAR_TOLERANCE = 1e-4
POSES = {
    "rest": {},
    "walk_left": {"LeftUpperLeg": [("X", .35)], "RightUpperLeg": [("X", -.35)], "RightLowerLeg": [("X", .45)],
                  "LeftUpperArm": [("X", -.25)], "RightUpperArm": [("X", .25)]},
    "walk_right": {"LeftUpperLeg": [("X", -.35)], "RightUpperLeg": [("X", .35)], "LeftLowerLeg": [("X", .45)],
                   "LeftUpperArm": [("X", .25)], "RightUpperArm": [("X", -.25)]},
    "arm_bend": {"LeftUpperArm": [("X", -.6), ("Z", -.25)], "RightUpperArm": [("X", -.6), ("Z", .25)],
                 "LeftLowerArm": [("X", -.8)], "RightLowerArm": [("X", -.8)]},
    "attack_stress": {"UpperTorso": [("Y", .16)], "LeftUpperArm": [("X", -.8)], "RightUpperArm": [("X", -1.)],
                      "RightLowerArm": [("X", -.8)], "LeftUpperLeg": [("X", -.15)], "RightUpperLeg": [("X", .15)]},
    "head_turn": {"Head": [("Y", .4)]},
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("skin_manifest", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--metrics-only", action="store_true", help="Evaluate all six poses without rendering PNGs")
    parser.add_argument("--region-overlay", type=Path, help="Diagnostic magenta overlay for an exact benchmark weight plan")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    manifest_path, output = args.skin_manifest.resolve(), args.output.resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("rig_origin") not in ("preserved_source_skin_proxy_candidate", "corrected_preserved_source_skin_proxy_candidate") or manifest.get("rig_ready_for_game") is not False:
        raise RigError("Only an explicit unregistered preserved source skin is supported")
    plan_path = Path(manifest["proxy_plan"])
    source = Path(manifest["output"])
    if output.exists() or ROOT / "build" not in output.parents:
        raise RigError("A new build/ comparison directory is required")
    for path, expected in ((plan_path, manifest["proxy_plan_sha256"]), (source, manifest["output_sha256"])):
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RigError("Source skin or existing exact proxy plan changed")
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    arms = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(arms) != 1:
        raise RigError("Importer did not retain exactly one actual armature")
    arm = arms[0]
    mapping = {bone["name"]: bone["proxy_part"] for bone in manifest["bones"]}
    if set(arm.data.bones.keys()) != set(mapping):
        raise RigError("Importer renamed or discarded source bones")
    shapes = {bone.custom_shape for bone in arm.pose.bones if bone.custom_shape}
    surfaces = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj not in shapes]
    if len(surfaces) != len(manifest["meshes"]):
        raise RigError("Importer changed the original skin surface count")
    for obj in surfaces:
        mods = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
        if len(mods) != 1 or mods[0].object != arm or mods[0].use_deform_preserve_volume:
            raise RigError("Actual original linear-blend Armature modifier is required")
    bpy.context.view_layer.update()
    arm_world = arm.matrix_world.copy()
    arm_to_game = np.asarray(TO_BLENDER.inverted() @ arm_world, dtype=np.float64)
    game_to_arm = np.linalg.inv(arm_to_game)
    rest_bones = {bone.name: np.asarray(bone.matrix_local, dtype=np.float64) for bone in arm.data.bones}
    if any(bone.inherit_scale != "FULL" or not bone.use_inherit_rotation or not bone.use_local_location
           for bone in arm.data.bones):
        raise RigError("Source Bone inheritance requires a separately reviewed pose solver")
    rest = {obj: obj.matrix_world.copy() for obj in surfaces}
    game_points = {obj: [TO_BLENDER.inverted() @ obj.matrix_world @ vertex.co for vertex in obj.data.vertices] for obj in surfaces}
    influences = {}
    for obj in surfaces:
        names = {group.index: group.name for group in obj.vertex_groups}
        influences[obj] = [[(names[group.group], group.weight) for group in vertex.groups if group.weight > 1e-8]
                           for vertex in obj.data.vertices]
        if any(not groups or abs(sum(weight for _, weight in groups) - 1) > 1e-4 for groups in influences[obj]):
            raise RigError("Importer changed the actual source weights")
    if args.region_overlay:
        selection = json.loads(args.region_overlay.read_text(encoding="utf-8"))
        if selection["source_skin_sha256"] not in (manifest["output_sha256"], manifest.get("original_benchmark_skin_sha256")):
            raise RigError("Diagnostic overlay does not match the exact source benchmark")
        overlay = bpy.data.materials.new("DiagnosticWeightCorrectionRegion")
        overlay.diffuse_color = (1., 0., 1., 1.)
        for obj in surfaces:
            changes = [row for row in selection["changes"] if row["mesh_name"] == obj.name]
            if not changes:
                continue
            tree = cKDTree([row["game_position"] for row in changes])
            distance, _ = tree.query([tuple(point) for point in game_points[obj]])
            slot = len(obj.data.materials)
            obj.data.materials.append(overlay)
            for polygon in obj.data.polygons:
                if sum(distance[vertex] <= 2e-5 for vertex in polygon.vertices) >= 2:
                    polygon.material_index = slot
    bone_error = 0.
    for bone in manifest["bones"]:
        actual = TO_BLENDER.inverted() @ arm_world @ arm.data.bones[bone["name"]].matrix_local
        expected = bone["game_bind_world"]
        position = Vector((expected[12], expected[13], expected[14]))
        bone_error = max(bone_error, (actual.translation - position).length)
    if bone_error > 1e-5:
        raise RigError("Original source bone positions changed during actual Blender import")
    rigid, part_mapping = [], {part["name"]: part["part"] for part in plan["meshes"]}
    for batch in plan["batches"]:
        path = plan_path.parent / batch["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != batch["sha256"]:
            raise RigError("A reference rigid batch changed")
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        for obj in set(bpy.context.scene.objects) - before:
            if obj.type == "MESH":
                name = obj.name.removesuffix("Mesh")
                if name not in part_mapping:
                    raise RigError("Unknown reference rigid surface")
                rigid.append((obj, part_mapping[name], obj.matrix_world.copy()))
    if len(rigid) != len(plan["meshes"]):
        raise RigError("Rigid reference has incomplete original coverage")
    all_points = [point for values in game_points.values() for point in values]
    low = Vector(tuple(min(point[axis] for point in all_points) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in all_points) for axis in range(3)))
    height_error = abs((high - low).y - plan["target_height_studs"])
    if height_error > 1e-5:
        raise RigError("Original skin and proxy have different canonical height")
    center = TO_BLENDER @ ((low + high) * .5)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (.83, .83, .83)
    camera_data = bpy.data.cameras.new("OriginalSkinComparison")
    camera_data.type, camera_data.ortho_scale = "ORTHO", max(high - low) * 1.35
    camera = bpy.data.objects.new("OriginalSkinComparison", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    output.mkdir(parents=True)
    metrics = {}
    for label, rotations in POSES.items():
        pose = transforms(plan, rotations)
        # Keep bind cancellation in float64; Blender pose channels themselves
        # are float32 and are checked independently after evaluation.
        desired_arrays = {name: game_to_arm @ np.asarray(pose[part], dtype=np.float64) @ arm_to_game @ rest_bones[name]
                          for name, part in mapping.items()}
        desired = {name: Matrix(value.tolist()) for name, value in desired_arrays.items()}
        basis_arrays = {}
        for bone in arm.data.bones:
            if bone.parent:
                rest_local = np.linalg.inv(rest_bones[bone.parent.name]) @ rest_bones[bone.name]
                wanted_local = np.linalg.inv(desired_arrays[bone.parent.name]) @ desired_arrays[bone.name]
                basis = np.linalg.inv(rest_local) @ wanted_local
            else:
                basis = np.linalg.inv(rest_bones[bone.name]) @ desired_arrays[bone.name]
            basis_arrays[bone.name] = basis
            arm.pose.bones[bone.name].matrix_basis = Matrix(basis.tolist())
        for obj, part, matrix in rigid:
            obj.matrix_world = TO_BLENDER @ pose[part] @ TO_BLENDER.inverted() @ matrix
        bpy.context.view_layer.update()
        matrix_error = max(max(abs(arm.pose.bones[name].matrix[row][column] - matrix[row][column])
                               for row in range(4) for column in range(4)) for name, matrix in desired.items())
        actual_deltas = {name: Matrix((arm_to_game @ np.asarray(arm.pose.bones[name].matrix, dtype=np.float64)
                                      @ np.linalg.inv(rest_bones[name]) @ game_to_arm).tolist()) for name in mapping}
        channel_error = max(float(np.max(np.abs(np.asarray(arm.pose.bones[name].matrix_basis) - basis_arrays[name])))
                            for name in mapping)
        channel_shear = max(float(np.max(np.abs(np.linalg.svd(value[:3, :3], compute_uv=False) - 1)))
                            for value in basis_arrays.values())
        maximum, target_error = 0., 0.
        for obj in surfaces:
            evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            if len(mesh.vertices) != len(obj.data.vertices):
                raise RigError("Armature modifier changed source topology")
            for index, vertex in enumerate(mesh.vertices):
                expected, intended = Vector((0, 0, 0)), Vector((0, 0, 0))
                point = game_points[obj][index]
                for name, weight in influences[obj][index]:
                    expected += (actual_deltas[name] @ point) * weight
                    intended += (pose[mapping[name]] @ point) * weight
                actual = TO_BLENDER.inverted() @ evaluated.matrix_world @ vertex.co
                maximum = max(maximum, (actual - expected).length)
                target_error = max(target_error, (actual - intended).length)
            evaluated.to_mesh_clear()
        if maximum > LBS_TOLERANCE or target_error > POSE_PROJECTION_TOLERANCE or channel_shear > CHANNEL_SHEAR_TOLERANCE:
            diagnostic = {"pose": label, "lbs_error": maximum, "target_pose_error": target_error,
                "bone_matrix_error": matrix_error,
                "bones": [{"name": name,
                    "desired_matrix_error": float(np.max(np.abs(np.asarray(arm.pose.bones[name].matrix) - desired_arrays[name]))),
                    "basis_channel_error": float(np.max(np.abs(np.asarray(arm.pose.bones[name].matrix_basis) - basis_arrays[name]))),
                    "basis_singular_values": np.linalg.svd(basis_arrays[name][:3, :3], compute_uv=False).tolist(),
                    "rotation_mode": arm.pose.bones[name].rotation_mode,
                    "actual_quaternion": list(arm.pose.bones[name].rotation_quaternion)} for name in mapping]}
            (output / "failed_pose_diagnostic.json").write_text(json.dumps(diagnostic, indent=2) + "\n", encoding="utf-8")
            raise RigError("Actual Armature deformation disagrees with original source LBS: "
                           + json.dumps({"pose": label, "lbs_error": maximum, "target_pose_error": target_error,
                                         "bone_matrix_error": matrix_error, "channel_shear": channel_shear}))
        metrics[label] = {"maximum_actual_armature_lbs_error": maximum,
                          "maximum_target_pose_projection_error": target_error,
                          "maximum_expected_bone_matrix_error": matrix_error,
                          "maximum_pose_channel_projection_error": channel_error,
                          "maximum_pose_channel_singular_value_deviation": channel_shear,
                          "rotations_radians": rotations}
        if args.metrics_only:
            continue
        for variant in ("skin", "rigid"):
            for obj in surfaces:
                obj.hide_render = variant != "skin"
            for obj, _, _ in rigid:
                obj.hide_render = variant != "rigid"
            for direction, ray in (("front", Vector((0, 1, 0))), ("side", Vector((1, 0, 0)))):
                camera.location = center + ray * 20
                camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
                scene.render.filepath = str(output / (label + "_" + variant + "_" + direction + ".png"))
                bpy.ops.render.render(write_still=True)
    report = {"schema": 1, "skin_manifest": str(manifest_path), "proxy_plan": str(plan_path),
        "poses": metrics, "original_source_bone_position_error": bone_error,
        "canonical_height_error": height_error,
        "source_skin_accessor_image_bytes_preserved": manifest.get("original_mesh_skin_accessors_binary_images_materials_preserved", False),
        "original_geometry_uv_normal_image_bytes_preserved": True,
        "original_weights_exact": not bool(manifest.get("weight_correction_plan")),
        "diagnostic_region_overlay": str(args.region_overlay) if args.region_overlay else None,
        "lbs_tolerance_studs": LBS_TOLERANCE, "target_pose_projection_tolerance_studs": POSE_PROJECTION_TOLERANCE,
        "pose_channel_singular_value_tolerance": CHANNEL_SHEAR_TOLERANCE,
        "rig_ready_for_game": False, "studio_motion_validated": False, "api_called": False,
        "limitations": ["Actual Blender Armature and independent LBS agree; the native importer/Bone runtime remains untested.",
            "Pose channels decompose imported rest-frame shear; target-pose projection error is measured separately without editing the source.",
            "Offline shared poses expose source weighting defects; they do not prove exact class attack timing or physics."]}
    (output / "motion_qa.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output), "images": 0 if args.metrics_only else 24, "maximum_actual_armature_lbs_error":
                     max(row["maximum_actual_armature_lbs_error"] for row in metrics.values()), "rig_ready_for_game": False}))


if __name__ == "__main__":
    main()
