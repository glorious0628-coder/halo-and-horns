# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Render source and rigid rest meshes in the same measured frame/camera.

Offline Blender only. Does not assert Studio readiness or create new designs.
Two lighting modes show original UV coverage and the small subdivision shading
change separately. Existing output images are never overwritten.
"""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from constraints import RigError, bone_regions


ROOT = Path(__file__).resolve().parents[2]


def canonical_source(plan):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=plan["source"])
    arms = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(arms) != 1:
        raise RigError("A real source armature is required")
    arm = arms[0]
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    _, primary = bone_regions({bone.name: bone.parent.name if bone.parent else None for bone in arm.data.bones})
    positions = {name: arm.matrix_world @ arm.data.bones[bone].head_local for name, bone in primary.items()}
    origin = positions["LowerTorso"]
    right = (positions["RightUpperArm"] - positions["LeftUpperArm"]).normalized()
    up = positions["Head"] - origin
    if plan.get("source_frame_policy") == "gltf-positive-z":
        right, up = Vector((-1, 0, 0)), Vector((0, 0, 1))
    up = (up - right * up.dot(right)).normalized()
    back = right.cross(up).normalized()
    coordinate = Matrix.Diagonal(Vector((plan["uniform_scale"],) * 3 + (1,))) @ Matrix((right, up, back)).to_4x4() @ Matrix.Translation(-origin)
    to_blender = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    source_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and
                     any(mod.type == "ARMATURE" and mod.object == arm for mod in obj.modifiers)]
    copies = []
    for obj in source_meshes:
        copied = obj.copy()
        copied.data = obj.data.copy()
        copied.parent = None
        copied.modifiers.clear()
        copied.matrix_world = to_blender @ coordinate @ obj.matrix_world
        copied.hide_render = False
        bpy.context.scene.collection.objects.link(copied)
        copies.append(copied)
    for obj in list(bpy.context.scene.objects):
        if obj not in copies:
            obj.hide_render = True
    points = [obj.matrix_world @ vertex.co for obj in copies for vertex in obj.data.vertices]
    low = [min(point[axis] for point in points) for axis in range(3)]
    high = [max(point[axis] for point in points) for axis in range(3)]
    return low, high


def render(path, low, high, lighting):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = lighting
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (0.72, 0.72, 0.72)
    data = bpy.data.cameras.new("SurfaceQA_Camera")
    data.type = "ORTHO"
    data.ortho_scale = max(high[0] - low[0], high[2] - low[2]) * 1.12
    camera = bpy.data.objects.new("SurfaceQA_Camera", data)
    scene.collection.objects.link(camera)
    camera.location = ((low[0] + high[0]) / 2, max(10, data.ortho_scale * 2), (low[2] + high[2]) / 2)
    camera.rotation_euler = (math.pi / 2, 0, math.pi)
    scene.camera = camera
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    manifest, output = args.manifest.resolve(), args.output.resolve()
    if ROOT / "build" not in output.parents or output.exists():
        raise RigError("Comparison output must be a new directory inside build/")
    plan = json.loads(manifest.read_text(encoding="utf-8"))
    output.mkdir(parents=True)
    low, high = canonical_source(plan)
    render(output / "source_flat.png", low, high, "FLAT")
    render(output / "source_lit.png", low, high, "STUDIO")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for batch in plan["batches"]:
        bpy.ops.import_scene.gltf(filepath=str(manifest.parent / batch["file"]))
    render(output / "prepared_flat.png", low, high, "FLAT")
    render(output / "prepared_lit.png", low, high, "STUDIO")
    (output / "comparison.json").write_text(json.dumps({"manifest": str(manifest),
        "same_canonical_bone_frame": True, "same_camera_bounds": {"min": low, "max": high},
        "modes": ["FLAT", "STUDIO"], "studio_animation_validated": False}, indent=2) + "\n", encoding="utf-8")
    print("[costume_r15] surface comparison: " + str(output))


if __name__ == "__main__":
    main()
