"""Check exact source geometry/winding without confusing it with new UVs."""
from pathlib import Path
import unittest

import numpy as np

from compare_static_surface import ROOT, compare, nearest, oriented_counter


class RawStaticSurfaceTests(unittest.TestCase):
    def test_cyclic_start_vertex_is_allowed_reversed_winding_is_not(self):
        first = oriented_counter(np.asarray([[1, 2, 3], [3, 4, 5]]))
        self.assertEqual(first, oriented_counter(np.asarray([[2, 3, 1], [5, 3, 4]])))
        self.assertNotEqual(first, oriented_counter(np.asarray([[1, 3, 2], [3, 4, 5]])))

    def test_nearest_mapping_measures_rounding_instead_of_round_bin_boundary(self):
        reference = np.asarray([[0, 0, 0], [1, 2, 3], [4, 5, 6]], dtype=np.float64)
        source = reference[[2, 0, 1]] + 7.4e-9
        distance, mapping = nearest(source, reference)
        self.assertEqual(list(mapping), [2, 0, 1])
        self.assertLess(float(distance.max()), 1e-7)

    def test_four_rejected_raw_models_are_the_same_selected_oriented_surface(self):
        for name in ("HaloArcherF", "HornsArcherF", "NeutralWarriorF", "NeutralArcherM"):
            with self.subTest(costume=name):
                fixed = ROOT / ("art/models/costume/fixed/Costume_" + name + ".glb")
                raw = ROOT / ("art/models/costume/raw/C2k_" + name + ".glb")
                if not fixed.exists() or not raw.exists():
                    self.skipTest("Local selected original models are not present")
                result = compare(fixed, raw)
                self.assertTrue(result["surface_preserved_within_tolerance"])
                self.assertTrue(result["world_point_mapping_bijective"])
                self.assertTrue(result["oriented_triangle_counters_equal"])
                self.assertLess(result["maximum_world_position_error"], 1e-8)
                self.assertFalse(result["texture_or_uv_equivalence_asserted"])
                self.assertIsNone(result["riggable"])
                self.assertFalse(result["api_called"])


if __name__ == "__main__":
    unittest.main()
