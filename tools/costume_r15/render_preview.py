# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Blender-only source/rest/joint-stress previews; no animation-readiness assertion or upload."""

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from constraints import RigError


def frame(values):
    if len(values) != 12 or not all(math.isfinite(value) for value in values):
        raise RigError("Invalid manifest CFrame")
    return Matrix(((values[3], values[4], values[5], values[0]),
                   (values[6], values[7], values[8], values[1]),
                   (values[9], values[10], values[11], values[2]), (0, 0, 0, 1)))


def render(objects, path, front_positive_y):
    points = [obj.matrix_world @ vertex.co for obj in objects for vertex in obj.data.vertices]
    low = [min(point[axis] for point in points) for axis in range(3)]
    high = [max(point[axis] for point in points) for axis in range(3)]
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (0.85, 0.85, 0.85)
    camera_data = bpy.data.cameras.new("QA_Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(high[0] - low[0], high[2] - low[2]) * 1.1
    camera = bpy.data.objects.new("QA_Camera", camera_data)
    scene.collection.objects.link(camera)
    distance = max(10, camera_data.ortho_scale * 2)
    camera.location = ((low[0] + high[0]) / 2, distance if front_positive_y else -distance, (low[2] + high[2]) / 2)
    camera.rotation_euler = (math.pi / 2, 0, math.pi if front_positive_y else 0)
    scene.camera = camera
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.filepath = str(path.resolve())
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--source", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    manifest, output = args.manifest.resolve(), args.output.resolve()
    if ROOT not in output.parents:
        raise RigError("Previews must be saved below the project")
    plan = json.loads(manifest.read_text(encoding="utf-8"))
    targets = [output / "r15_rest.png", output / "r15_joint_stress.png"]
    if args.source:
        targets.append(output / "source_rig.png")
    if any(path.exists() for path in targets):
        raise RigError("A preview already exists; existing files are never overwritten")
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for batch in plan["batches"]:
        bpy.ops.import_scene.gltf(filepath=str((manifest.parent / batch["file"]).resolve()))
    objects = {obj.name: obj for obj in bpy.context.scene.objects if obj.type == "MESH"}
    if set(objects) != {mesh["name"] for mesh in plan["meshes"]}:
        raise RigError("Imported preview meshes differ from the verified manifest")
    render(list(objects.values()), targets[0], True)
    # This is a stated local joint-stress pose, not Roblox's default Animate playback.
    angles = {"LeftShoulder": ("X", 0.55), "RightShoulder": ("X", -0.55),
              "LeftHip": ("X", -0.4), "RightHip": ("X", 0.4),
              "LeftElbow": ("X", 0.35), "RightElbow": ("X", 0.35),
              "LeftKnee": ("X", 0.25), "RightKnee": ("X", 0.25), "Neck": ("Y", 0.3)}
    poses = {"HumanoidRootPart": frame(plan["root"]["CFrame"])}
    remaining = list(plan["joints"])
    while remaining:
        ready = [joint for joint in remaining if joint["part0"] in poses]
        if not ready:
            raise RigError("Cyclic/disconnected joint graph")
        for joint in ready:
            axis, angle = angles.get(joint["name"], ("X", 0))
            poses[joint["part1"]] = poses[joint["part0"]] @ frame(joint["C0"]) @ Matrix.Rotation(angle, 4, axis) @ frame(joint["C1"]).inverted()
            remaining.remove(joint)
    to_blender = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    for mesh in plan["meshes"]:
        objects[mesh["name"]].matrix_world = to_blender @ poses[mesh["part"]] @ to_blender.inverted()
    render(list(objects.values()), targets[1], True)
    if args.source:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(args.source.resolve()))
        actual = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and any(mod.type == "ARMATURE" for mod in obj.modifiers)]
        if not actual:
            raise RigError("Source preview requires a real skin")
        render(actual, targets[2], False)
    (output / "preview.json").write_text(json.dumps({"manifest": str(manifest), "files": [str(path) for path in targets],
        "joint_stress_radians": angles, "default_animate_verified": False}, ensure_ascii=False, indent=2), encoding="utf-8")
    print("[costume_r15] previews: " + str(output), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RigError, ValueError, OSError) as error:
        print("[costume_r15] refused: " + str(error), file=sys.stderr, flush=True)
        sys.exit(2)
