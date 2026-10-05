# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Original triangle/attribute/image preservation and rejection-path tests."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import copy
import json
from pathlib import Path
import tempfile
import unittest

from constraints import RigError
from glb_io import read_glb
from merge_preserved import ROOT, packaging_merge, write_candidate


REJECTED = ("HaloWarriorF", "HaloMageM", "HaloMageF", "HaloArcherF", "HornsArcherF", "NeutralWarriorF", "NeutralArcherM")


class PreservedMergeTests(unittest.TestCase):
    def fixture(self):
        path = ROOT / "art/models/costume/fixed/Costume_HaloWarriorM.glb"
        if not path.is_file():
            self.skipTest("Local fixed source is not present")
        return path, *read_glb(path)

    def test_all_seven_rejected_sources_keep_original_primitive_and_binary_references(self):
        for name in REJECTED:
            with self.subTest(costume=name):
                path = ROOT / ("art/models/costume/fixed/Costume_" + name + ".glb")
                if not path.is_file():
                    self.skipTest("Local rejected source is not present")
                gltf, binary, original = read_glb(path)
                candidate, record = packaging_merge(gltf, binary)
                original_primitives = [primitive for node in gltf["nodes"]
                                       for primitive in gltf["meshes"][node["mesh"]]["primitives"]]
                self.assertEqual(candidate["meshes"][0]["primitives"], original_primitives)
                for key in ("accessors", "bufferViews", "buffers", "images", "materials", "textures", "samplers"):
                    self.assertEqual(candidate.get(key), gltf.get(key))
                self.assertEqual(record["mesh_objects_after"], 1)
                self.assertGreater(record["exact_shared_positions_before"], 0)
                self.assertFalse(record["vertex_weld_performed"])
                self.assertFalse(record["rig_ready_for_game"])
                self.assertIsNone(record["riggable"])
                self.assertEqual(path.read_bytes(), original)

    def test_accepted_control_has_same_two_object_layout_acceptance_is_not_inferred(self):
        _, gltf, binary, _ = self.fixture()
        _, record = packaging_merge(gltf, binary)
        self.assertEqual(record["mesh_objects_before"], 2)
        self.assertEqual(record["primitives"], 2)
        self.assertIsNone(record["riggable"])

    def test_transforms_skin_nested_and_unknown_objects_are_refused(self):
        _, gltf, binary, _ = self.fixture()
        changes = [lambda g: g["nodes"][0].update(translation=[0, 1, 0]),
                   lambda g: g.update(skins=[{"joints": [0]}]),
                   lambda g: g["nodes"][0].update(children=[1]),
                   lambda g: g["nodes"][1].update(name="Unreviewed"),
                   lambda g: g.update(animations=[{}]),
                   lambda g: g["meshes"][0].update(weights=[1]),
                   lambda g: g["meshes"][0]["primitives"][0].update(mode=5)]
        for change in changes:
            candidate = copy.deepcopy(gltf)
            change(candidate)
            with self.assertRaises(RigError):
                packaging_merge(candidate, binary)

    def test_local_candidate_binary_is_identical_and_overwrite_is_refused(self):
        source, original_gltf, original_binary, original_bytes = self.fixture()
        with tempfile.TemporaryDirectory(prefix="test-merge-", dir=ROOT / "build") as directory:
            output = Path(directory) / "new-candidate"
            report = write_candidate(source, output)
            candidate, candidate_binary, _ = read_glb(output / "merged_preserved.glb")
            self.assertEqual(candidate_binary, original_binary)
            self.assertEqual(len(candidate["nodes"]), 1)
            self.assertEqual(json.loads((output / "preservation.json").read_text(encoding="utf-8")), report)
            self.assertEqual(source.read_bytes(), original_bytes)
            with self.assertRaises(RigError):
                write_candidate(source, output)
        with self.assertRaises(RigError):
            write_candidate(source, ROOT / "art/new-disallowed-candidate")


if __name__ == "__main__":
    unittest.main()
