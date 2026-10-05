# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Lossless skin copying and exact proxy frame checks; no engine/API calls."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

from constraints import PRIMARY, RigError
from glb_io import image_bytes, read_glb
from preserve_skin import ROOT, node_matrices, prepare, similarity
from restore_material_regions import primitives


class PreservedSkinTests(unittest.TestCase):
    def test_similarity_retains_orientation_and_real_scale(self):
        source = np.array([[0, 0, 0], [1, 0, 0], [0, 2, 0], [0, 0, 3]], float)
        rotation = np.diag([-1., 1., -1.])
        target = source @ rotation.T * 5.5 + [2, -3, 4]
        matrix, error, scale = similarity(source, target)
        self.assertLess(error, 1e-12)
        self.assertAlmostEqual(scale, 5.5)
        self.assertTrue(np.allclose(matrix[:3, :3], rotation * 5.5))
        reflected = source * [-1, 1, 1]
        with self.assertRaises(RigError):
            similarity(source, reflected)

    def test_node_trs_parent_and_cycle_validation(self):
        gltf = {"nodes": [{"translation": [2, 0, 0], "rotation": [0, 0, 2**-.5, 2**-.5], "children": [1]},
                           {"translation": [1, 0, 0]}]}
        _, _, world = node_matrices(gltf)
        self.assertTrue(np.allclose(world[1][:3, 3], [2, 1, 0]))
        gltf["nodes"][1]["children"] = [0]
        with self.assertRaises(RigError):
            node_matrices(gltf)

    def test_actual_pilot_keeps_original_binary_skin_and_scene_nodes(self):
        plan = ROOT / "build/costume_r15/Costume_HaloArcherM/joints.json"
        if not plan.exists():
            self.skipTest("Existing actual pilot preparation is not present")
        original_plan = json.loads(plan.read_text(encoding="utf-8"))
        source = Path(original_plan["source"])
        before = source.read_bytes()
        gltf, binary, _ = read_glb(source)
        with tempfile.TemporaryDirectory(prefix="skin_preserve_test_", dir=ROOT / "build") as directory:
            output = Path(directory) / "skin.glb"
            report = prepare(plan, output)
            copied, copied_binary, _ = read_glb(output)
            self.assertEqual(binary, copied_binary)
            self.assertEqual(source.read_bytes(), before)
            for key in ("accessors", "bufferViews", "buffers", "skins", "materials", "textures", "images"):
                self.assertEqual(gltf[key], copied[key])
            for old, new in zip(gltf["meshes"], copied["meshes"]):
                self.assertEqual(old["primitives"], new["primitives"])
            for old, new in zip(gltf["nodes"], copied["nodes"]):
                first, second = copy.deepcopy(old), copy.deepcopy(new)
                first.pop("name", None)
                second.pop("name", None)
                self.assertEqual(first, second)
            self.assertEqual(report["principal_r15_bones"], 15)
            self.assertEqual({row["name"] for row in report["bones"] if row["principal"]}, set(PRIMARY))
            self.assertEqual(report["source_skin_bones"], len(gltf["skins"][0]["joints"]))
            self.assertEqual({row["name"] for row in report["meshes"]}, {"CostumeSkinHead", "CostumeSkinBody"})
            self.assertLessEqual(report["estimated_assets"], 10)
            self.assertFalse(report["rig_ready_for_game"])
            self.assertFalse(report["studio_motion_validated"])
            self.assertEqual(report["source_sha256"], hashlib.sha256(before).hexdigest())
            with self.assertRaises(RigError):
                prepare(plan, output)

    def test_wrong_source_hash_does_not_produce_output(self):
        plan = ROOT / "build/costume_r15/Costume_HaloArcherM/joints.json"
        if not plan.exists():
            self.skipTest("Existing actual pilot preparation is not present")
        with tempfile.TemporaryDirectory(prefix="skin_guard_test_", dir=ROOT / "build") as directory:
            bad = json.loads(plan.read_text(encoding="utf-8"))
            bad["source_sha256"] = "0" * 64
            plan_copy, output = Path(directory) / "plan.json", Path(directory) / "skin.glb"
            plan_copy.write_text(json.dumps(bad), encoding="utf-8")
            with self.assertRaises(RigError):
                prepare(plan_copy, output)
            self.assertFalse(output.exists())

    def test_restored_three_package_original_primitives_and_only_active_pngs(self):
        folders = ("Costume_HaloWarriorF_material_front_fixed", "Costume_HaloMageM_material_front_fixed",
                   "Costume_HaloMageF_material_front_face_fixed")
        if any(not (ROOT / "build/costume_r15" / folder / "joints.json").exists() for folder in folders):
            self.skipTest("The three actual material-recovered source plans are not present")
        with tempfile.TemporaryDirectory(prefix="skin_material_test_", dir=ROOT / "build") as directory:
            for folder in folders:
                plan = ROOT / "build/costume_r15" / folder / "joints.json"
                meta = json.loads(plan.read_text(encoding="utf-8"))
                old, binary, before = read_glb(meta["source"])
                report = prepare(plan, Path(directory) / (folder + ".glb"), True, True)
                new, new_binary, _ = read_glb(report["output"])
                self.assertEqual(binary, new_binary)
                self.assertEqual(Path(meta["source"]).read_bytes(), before)
                for key in ("accessors", "bufferViews", "buffers", "skins"):
                    self.assertEqual(old[key], new[key])
                self.assertEqual(len(new["meshes"]), 2)
                self.assertEqual(len(new["materials"]), 2)
                self.assertEqual(len(new["textures"]), 2)
                self.assertEqual(len(new["images"]), 2)
                self.assertEqual(report["estimated_assets"], 5)
                check = copy.deepcopy(new)
                check["nodes"][-1].pop("matrix")
                old_rows, new_rows = primitives(old, binary, True), primitives(check, new_binary, True)
                self.assertEqual(len(old_rows), len(new_rows))
                for first, second in zip(old_rows, new_rows):
                    self.assertEqual(first["values"], second["values"])
                    self.assertEqual(first["triangles"], second["triangles"])
                    old_material = old["materials"][first["definition"]["material"]]
                    new_material = new["materials"][second["definition"]["material"]]
                    self.assertEqual(old_material["name"], new_material["name"])
                    oi = old["textures"][old_material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
                    ni = new["textures"][new_material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
                    self.assertEqual(image_bytes(old, binary, old["images"][oi]), image_bytes(new, new_binary, new["images"][ni]))


if __name__ == "__main__":
    unittest.main()
