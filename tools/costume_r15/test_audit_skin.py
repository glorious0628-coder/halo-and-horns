"""Check real weight-field coverage; reject invented or ambiguous ownership."""
from pathlib import Path
import unittest

from audit_skin import ROOT, area_ratio, audit, dominance_patch
from constraints import RigError


class WeightSurfaceTests(unittest.TestCase):
    def test_three_pure_source_bones_partition_one_face_exactly(self):
        rows = [{"Head": 1.0}, {"LeftUpperArm": 1.0}, {"LeftLowerArm": 1.0}]
        ratios = [area_ratio(dominance_patch(rows, owner)) for owner in rows[0] | rows[1] | rows[2]]
        self.assertAlmostEqual(sum(ratios), 1.0)
        for ratio in ratios:
            self.assertAlmostEqual(ratio, 1 / 3)

    def test_an_interior_owner_is_found_even_without_a_dominant_corner(self):
        rows = [{"LeftLowerArm": 0.4, "LeftUpperArm": 0.6},
                {"LeftLowerArm": 0.4, "LeftHand": 0.6},
                {"LeftLowerArm": 0.4, "Head": 0.6}]
        self.assertGreater(area_ratio(dominance_patch(rows, "LeftLowerArm")), 0)

    def test_permanently_subdominant_or_absent_weights_cannot_create_a_limb(self):
        rows = [{"LeftLowerArm": 0.3, "LeftHand": 0.7},
                {"LeftLowerArm": 0.2, "LeftHand": 0.8},
                {"LeftLowerArm": 0.1, "LeftHand": 0.9}]
        self.assertEqual(area_ratio(dominance_patch(rows, "LeftLowerArm")), 0)
        self.assertEqual(dominance_patch(rows, "RightLowerArm"), [])

    def test_equal_whole_face_fields_do_not_receive_duplicate_surface_ownership(self):
        with self.assertRaises(RigError):
            dominance_patch([{"LeftHand": 0.5, "LeftLowerArm": 0.5}] * 3, "LeftLowerArm")

    def test_real_horns_mage_m_only_one_nonadjacent_face_is_tied(self):
        matches = list((ROOT / "art/models/tripo").glob("Costume_HornsMageM_rig_*.glb"))
        if len(matches) != 1:
            self.skipTest("Unique local source is not present")
        before = matches[0].read_bytes()
        result = audit(matches[0])
        self.assertEqual(len(result["nonadjacent_exact_ties"]), 1)
        tie = result["nonadjacent_exact_ties"][0]
        self.assertEqual((tie["node"], tie["face"]), ("Body", 622))
        self.assertAlmostEqual(tie["patch_area_sum"], 1)
        self.assertGreater(tie["subdivision_normalization_error_degrees"], 0)
        self.assertFalse(tie["subdivision_exported"])
        self.assertFalse(result["rig_ready_for_game"])
        self.assertEqual(matches[0].read_bytes(), before)

    def test_real_horns_mage_f_has_zero_forearm_surface_even_inside_faces(self):
        matches = list((ROOT / "art/models/tripo").glob("Costume_HornsMageF_rig_*.glb"))
        if len(matches) != 1:
            self.skipTest("Unique local source is not present")
        result = audit(matches[0])
        self.assertEqual(result["target_weighted_vertices"], 1761)
        self.assertEqual(result["target_touched_faces"], 1325)
        self.assertEqual(result["target_positive_area_patches"], 0)
        self.assertEqual(result["target_unique_vertices"], 0)
        self.assertLess(result["target_best_vertex_dominance_margin"], 0)
        self.assertFalse(result["geometry_or_weights_changed"])


if __name__ == "__main__":
    unittest.main()
