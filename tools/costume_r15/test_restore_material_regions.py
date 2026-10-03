"""Recover lost real material boundaries without changing geometry or skin."""
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import unittest

from constraints import RigError
from glb_io import accessor_values, image_bytes, read_glb
from restore_material_regions import correspondence, oriented_key, primitives, recover


ROOT = Path(__file__).resolve().parents[2]


def corner_counter(gltf, binary, appearance=False):
    result = Counter()
    for row in primitives(gltf, binary, True):
        names = ("POSITION", "NORMAL", "TEXCOORD_0") if appearance else ("POSITION", "JOINTS_0", "WEIGHTS_0")
        for triangle in row["triangles"]:
            result[oriented_key(tuple(tuple((name, row["values"][name][vertex]) for name in names) for vertex in triangle))] += 1
    return result


class OriginalMaterialRecoveryTests(unittest.TestCase):
    def test_oriented_triangle_does_not_allow_a_winding_reversal(self):
        self.assertEqual(oriented_key((1, 2, 3)), oriented_key((2, 3, 1)))
        self.assertNotEqual(oriented_key((1, 2, 3)), oriented_key((1, 3, 2)))

    def test_actual_three_merged_rigs_have_exact_original_uvs_but_lost_head_material(self):
        for name in ("HaloWarriorF", "HaloMageM", "HaloMageF"):
            with self.subTest(costume=name):
                plan_path = ROOT / ("build/costume_r15/Costume_" + name + "/joints.json")
                if not plan_path.is_file():
                    self.skipTest("Actual merged rig is not present")
                plan = json.loads(plan_path.read_text(encoding="utf-8"))
                reference = ROOT / ("art/models/costume/fixed/Costume_" + name + ".glb")
                report = recover(reference, plan["source"])
                self.assertTrue(report["read_only"])
                self.assertFalse(report["api_called"])
                self.assertFalse(report["rig_ready_for_game"])
                self.assertTrue(report["oriented_original_triangles_matched_exactly_once"])
                self.assertLess(report["maximum_shape_mapping_error"], 1e-6)
                self.assertEqual(report["maximum_original_uv_error_before_recovery"], 0)
                self.assertEqual(set(report["source_material_triangle_counts"]), {"BodyMat", "HeadMat"})

    def test_recovered_three_sources_keep_skin_skeleton_original_images_and_source_files(self):
        for name in ("HaloWarriorF", "HaloMageM", "HaloMageF"):
            with self.subTest(costume=name):
                path = ROOT / ("build/costume_r15/restored_material_sources/Costume_" + name + "_rig_material_restored.glb")
                if not path.is_file():
                    self.skipTest("Local recovered material source is not present")
                report = json.loads(path.with_suffix(".recovery.json").read_text(encoding="utf-8"))
                old, old_binary, old_bytes = read_glb(report["rig"])
                new, new_binary, _ = read_glb(path)
                fixed, fixed_binary, fixed_bytes = read_glb(report["reference"])
                self.assertEqual(hashlib.sha256(old_bytes).hexdigest(), report["rig_sha256"])
                self.assertEqual(hashlib.sha256(fixed_bytes).hexdigest(), report["reference_sha256"])
                self.assertTrue(new_binary.startswith(old_binary))
                for key in ("nodes", "skins", "animations"):
                    self.assertEqual(old.get(key), new.get(key))
                self.assertEqual(corner_counter(old, old_binary), corner_counter(new, new_binary))
                self.assertEqual(report["output_primitives"], 2)
                self.assertTrue(report["exact_original_uv_normal_material_corners_verified"])
                self.assertFalse(report["texture_rebake"])
                self.assertFalse(report["uv_repack"])
                for source_image, recovered_image in zip(fixed["images"], new["images"][-len(fixed["images"]):]):
                    self.assertEqual(image_bytes(fixed, fixed_binary, source_image), image_bytes(new, new_binary, recovered_image))
                self.assertEqual({new["materials"][row["definition"]["material"]]["name"] for row in primitives(new, new_binary, True)}, {"HeadMat", "BodyMat"})
                with self.assertRaises(RigError):
                    recover(report["reference"], report["rig"], path)

    def test_unreviewed_source_transform_is_refused(self):
        path = ROOT / "build/costume_r15/Costume_HaloMageF/joints.json"
        if not path.is_file():
            self.skipTest("Actual merged rig is not present")
        plan = json.loads(path.read_text(encoding="utf-8"))
        fixed, fixed_binary, _ = read_glb(ROOT / "art/models/costume/fixed/Costume_HaloMageF.glb")
        rig, rig_binary, _ = read_glb(plan["source"])
        changed = copy.deepcopy(fixed)
        changed["nodes"][0]["translation"] = [1, 0, 0]
        with self.assertRaises(RigError):
            correspondence(changed, fixed_binary, rig, rig_binary)


if __name__ == "__main__":
    unittest.main()
