import math
import unittest

from constraints import PRIMARY, RigError, bone_regions, face_region, region_weights, upload_batches


def parents():
    result = {"Hips": None, "Spine": "Hips", "Spine1": "Spine", "Spine2": "Spine1", "Neck": "Spine2", "Head": "Neck"}
    for side in ("Left", "Right"):
        result.update({side + "Shoulder": "Spine2", side + "Arm": side + "Shoulder",
                       side + "ForeArm": side + "Arm", side + "Hand": side + "ForeArm",
                       side + "HandThumb1": side + "Hand", side + "UpLeg": "Hips",
                       side + "Leg": side + "UpLeg", side + "Foot": side + "Leg",
                       side + "ToeBase": side + "Foot"})
    result["LeftEye"] = "Head"
    return result


class StrictRigConstraints(unittest.TestCase):
    def test_real_ancestry_maps_fingers_and_eyes(self):
        source = parents()
        prefixed = {"mixamorig:" + key: "mixamorig:" + value if value else None for key, value in source.items()}
        mapping, primary = bone_regions(prefixed)
        self.assertEqual(mapping["mixamorig:LeftHandThumb1"], "LeftHand")
        self.assertEqual(mapping["mixamorig:LeftEye"], "Head")
        self.assertEqual(len(primary), 15)

    def test_missing_hand_is_refused(self):
        source = parents()
        del source["LeftHand"]
        with self.assertRaises(RigError):
            bone_regions(source)

    def test_wrong_knee_hierarchy_is_refused(self):
        source = parents()
        source["RightFoot"] = "Hips"
        with self.assertRaises(RigError):
            bone_regions(source)

    def test_no_skin_names_are_refused(self):
        with self.assertRaises(RigError):
            bone_regions({})

    def test_unweighted_unknown_and_nan_are_refused(self):
        mapping, _ = bone_regions(parents())
        for weights in ([], [("Prop", 1.0)], [("Hips", math.nan)]):
            with self.subTest(weights=weights), self.assertRaises(RigError):
                region_weights(weights, mapping)

    def test_exact_adjacent_ties_choose_the_parent(self):
        part, _ = face_region([{"LeftHand": 0.5, "LeftLowerArm": 0.5}] * 3)
        self.assertEqual(part, "LeftLowerArm")

    def test_non_adjacent_exact_ties_are_refused(self):
        with self.assertRaises(RigError):
            face_region([{"LeftHand": 0.5, "RightFoot": 0.5}] * 3)

    def test_explicit_non_adjacent_policy_uses_actual_proximal_tied_part(self):
        part, _ = face_region([{"LeftUpperLeg": 1 / 3, "LeftLowerLeg": 1 / 3, "RightLowerArm": 1 / 3}] * 3, "parent-depth")
        self.assertEqual(part, "LeftUpperLeg")

    def test_normal_blended_skin_uses_actual_maximum_weight(self):
        part, confidence = face_region([{"Head": 0.34, "UpperTorso": 0.33, "LowerTorso": 0.33}] * 3)
        self.assertEqual(part, "Head")
        self.assertAlmostEqual(confidence, 0.34)

    def test_cycles_are_refused_even_when_all_joint_ancestors_exist(self):
        source = parents()
        source["Hips"] = "Head"
        with self.assertRaises(RigError):
            bone_regions(source)

    def test_clear_weights_choose_the_real_body_region(self):
        part, confidence = face_region([{"Head": 0.9, "UpperTorso": 0.1}] * 3)
        self.assertEqual(part, "Head")
        self.assertAlmostEqual(confidence, 0.9)

    def test_upload_budget_counts_model_mesh_and_shared_images(self):
        parts = list(PRIMARY)
        roles = {part: {("BodyTex", "ColorMap")} for part in parts}
        batches = upload_batches(parts, roles)
        self.assertEqual([len(batch["parts"]) for batch in batches], [8, 7])
        self.assertEqual([part for batch in batches for part in batch["parts"]], parts)
        self.assertTrue(all(batch["estimated_assets"] <= 10 for batch in batches))

    def test_pbr_maps_are_counted_separately(self):
        parts = list(PRIMARY)
        maps = {("Color", "ColorMap"), ("Normal", "NormalMap"), ("ORM", "MetalnessMap"), ("ORM", "RoughnessMap")}
        batches = upload_batches(parts, {part: maps for part in parts})
        self.assertEqual([len(batch["parts"]) for batch in batches], [5, 5, 5])
        self.assertTrue(all(batch["estimated_assets"] == 10 for batch in batches))


if __name__ == "__main__":
    unittest.main()
