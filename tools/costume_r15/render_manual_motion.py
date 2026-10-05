# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Offline rigid R15 candidate poses; never an engine gameplay pass.

blender --background --factory-startup --python-exit-code 2 --python
tools/costume_r15/render_manual_motion.py -- JOINTS.json NEW_BUILD_DIRECTORY
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from constraints import JOINTS, RigError


ROOT = Path(__file__).resolve().parents[2]
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def transforms(plan, rotations):
    result = {"HumanoidRootPart": Matrix.Identity(4)}
    for joint in plan["joints"]:
        rotation = Matrix.Identity(4)
        for axis, angle in rotations.get(joint["part1"], []):
            rotation = rotation @ Matrix.Rotation(angle, 4, axis)
        position = Vector(joint["joint_position"])
        result[joint["part1"]] = result[joint["part0"]] @ Matrix.Translation(position) @ rotation @ Matrix.Translation(-position)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    plan_path, output = args.plan.resolve(), args.output.resolve()
    if ROOT / "build" not in output.parents or output.exists():
        raise RigError("Motion QA requires a new directory inside build/")
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    if plan.get("rig_origin") != "inferred_manual_candidate" or plan.get("original_bones_claimed") is not False or plan.get("rig_ready_for_game") is not False:
        raise RigError("Only explicit unregistered inferred candidates can use this QA")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = []
    by_name = {part["name"]: part["part"] for part in plan["meshes"]}
    for batch in plan["batches"]:
        path = plan_path.parent / batch["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != batch["sha256"]:
            raise RigError("An exported original surface batch changed")
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        for obj in set(bpy.context.scene.objects) - before:
            if obj.type != "MESH":
                continue
            name = obj.name.removesuffix("Mesh")
            if name not in by_name:
                raise RigError("Imported rigid part cannot be identified")
            imported.append((obj, by_name[name], obj.matrix_world.copy()))
    if len(imported) != len(plan["meshes"]):
        raise RigError("Candidate geometry coverage changed")
    points = [obj.matrix_world @ vertex.co for obj, _, _ in imported for vertex in obj.data.vertices]
    low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    center = (low + high) * .5
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (.83, .83, .83)
    camera_data = bpy.data.cameras.new("CandidatePoseCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(high - low) * 1.35
    camera = bpy.data.objects.new("CandidatePoseCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    output.mkdir(parents=True)
    poses = {
        "rest": {},
        "walk_left": {"LeftUpperLeg": [("X", .35)], "RightUpperLeg": [("X", -.35)], "RightLowerLeg": [("X", .45)],
                      "LeftUpperArm": [("X", -.25)], "RightUpperArm": [("X", .25)]},
        "walk_right": {"LeftUpperLeg": [("X", -.35)], "RightUpperLeg": [("X", .35)], "LeftLowerLeg": [("X", .45)],
                       "LeftUpperArm": [("X", .25)], "RightUpperArm": [("X", -.25)]},
        "arm_bend": {"LeftUpperArm": [("X", -.6), ("Z", -.25)], "RightUpperArm": [("X", -.6), ("Z", .25)],
                     "LeftLowerArm": [("X", -.8)], "RightLowerArm": [("X", -.8)]},
        "attack_stress": {"UpperTorso": [("Y", .16)], "LeftUpperArm": [("X", -.8)], "RightUpperArm": [("X", -1.0)],
                          "RightLowerArm": [("X", -.8)], "LeftUpperLeg": [("X", -.15)], "RightUpperLeg": [("X", .15)]},
        "head_turn": {"Head": [("Y", .4)]},
    }
    metrics = {}
    for label, rotations in poses.items():
        pose = transforms(plan, rotations)
        for obj, part, rest in imported:
            obj.matrix_world = TO_BLENDER @ pose[part] @ TO_BLENDER.inverted() @ rest
        bpy.context.view_layer.update()
        joint_error = 0.0
        for joint in plan["joints"]:
            position = Vector(joint["joint_position"])
            joint_error = max(joint_error, (pose[joint["part0"]] @ position - pose[joint["part1"]] @ position).length)
        if joint_error > 1e-5:
            raise RigError("Rigid candidate pose detached an actual inferred joint")
        metrics[label] = {"maximum_parent_child_joint_error": joint_error, "rotations_radians": rotations}
        for direction, ray in (("front", Vector((0, 1, 0))), ("side", Vector((1, 0, 0)))):
            camera.location = center + ray * 20
            camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(output / (label + "_" + direction + ".png"))
            bpy.ops.render.render(write_still=True)
    (output / "motion_qa.json").write_text(json.dumps({"schema": 1, "plan": str(plan_path),
        "rig_origin": "inferred_manual_candidate", "original_bones_claimed": False,
        "rig_ready_for_game": False, "studio_motion_validated": False, "game_attack_timing_validated": False,
        "original_mesh_uv_material_untouched": True, "poses": metrics,
        "limitations": ["Offline rigid poses expose seams, hair/coat ownership and joint placement; they do not prove gameplay or exact class attack motion."]}, indent=2) + "\n", encoding="utf-8")
    print("[manual candidate] rendered 12 pose QA images: " + str(output))


if __name__ == "__main__":
    main()
