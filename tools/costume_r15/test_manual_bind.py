# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Inferred candidates preserve approved originals and never claim original bones."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import struct
import unittest

from constraints import PRIMARY, RigError
from glb_io import image_bytes, read_glb, view_bytes
from manual_bind import face_counter, validate_config
from restore_material_regions import primitives


ROOT = Path(__file__).resolve().parents[2]


class InferredManualBindingTests(unittest.TestCase):
    def test_original_face_uv_normal_material_and_image_bytes_are_exact(self):
        for name in ("HaloArcherF", "HornsArcherF", "NeutralWarriorF", "NeutralArcherM"):
            with self.subTest(costume=name):
                path = ROOT / ("build/manual_partition_candidates/" + name + "/Costume_" + name + "_manual.glb")
                if not path.is_file():
                    self.skipTest("Local inferred candidate is not present")
                candidate, candidate_binary, _ = read_glb(path)
                proof = candidate["extras"]["HHC_ManualBind"]
                original, original_binary, original_bytes = read_glb(proof["source"])
                self.assertEqual(hashlib.sha256(original_bytes).hexdigest(), proof["source_sha256"])
                self.assertTrue(candidate_binary.startswith(original_binary))
                before = primitives(original, original_binary, False)
                after = primitives(candidate, candidate_binary, True)
                for row in after:
                    row["values"].pop("JOINTS_0")
                    row["values"].pop("WEIGHTS_0")
                self.assertEqual(face_counter(before), face_counter(after))
                self.assertFalse(proof["original_bones_claimed"])
                self.assertFalse(proof["rig_ready_for_game"])
                self.assertEqual(proof["rig_origin"], "inferred_manual_candidate")
                self.assertEqual(candidate["materials"], original["materials"])
                for first, second in zip(original["images"], candidate["images"]):
                    self.assertEqual(image_bytes(original, original_binary, first), image_bytes(candidate, candidate_binary, second))

    def test_candidate_inverse_bind_rest_positions_match_actual_landmarks(self):
        path = ROOT / "build/manual_partition_candidates/HaloArcherF/Costume_HaloArcherF_manual.glb"
        if not path.is_file():
            self.skipTest("Local inferred candidate is not present")
        gltf, binary, _ = read_glb(path)
        config = json.loads(Path(gltf["extras"]["HHC_ManualBind"]["landmark_config"]).read_text(encoding="utf-8"))
        parents = {child: index for index, node in enumerate(gltf["nodes"]) for child in node.get("children", [])}
        world = {}
        def position(index):
            if index not in world:
                local = gltf["nodes"][index].get("translation", [0, 0, 0])
                parent = position(parents[index]) if index in parents else [0, 0, 0]
                world[index] = [local[axis] + parent[axis] for axis in range(3)]
            return world[index]
        skin = gltf["skins"][0]
        accessor = gltf["accessors"][skin["inverseBindMatrices"]]
        _, matrices = view_bytes(gltf, binary, accessor["bufferView"])
        self.assertEqual(len(skin["joints"]), 15)
        for ordinal, node in enumerate(skin["joints"]):
            part = gltf["nodes"][node]["extras"]["HHC_ManualPart"]
            self.assertIn(part, PRIMARY)
            actual = position(node)
            for axis in range(3):
                self.assertAlmostEqual(actual[axis], config["landmarks"][part][axis], places=8)
            inverse = struct.unpack_from("<16f", matrices, ordinal * 64)
            self.assertLess(max(abs(actual[axis] + inverse[12 + axis]) for axis in range(3)), 1e-7)

    def test_missing_or_double_face_owner_and_playable_claim_are_rejected(self):
        path = ROOT / "build/manual_partition_audit/HaloArcherF_manual_landmarks.json"
        if not path.is_file():
            self.skipTest("Local inferred landmark evidence is not present")
        config = json.loads(path.read_text(encoding="utf-8"))
        source, binary, _ = read_glb(ROOT / config["source"])
        validate_config(config, source, binary)
        for change in ("missing", "duplicate", "unknown", "ready", "evidence"):
            altered = copy.deepcopy(config)
            if change == "missing": altered["triangle_owners"][0]["owners"].pop()
            elif change == "duplicate": altered["triangle_owners"].append(copy.deepcopy(altered["triangle_owners"][0]))
            elif change == "unknown": altered["triangle_owners"][0]["owners"][0] = "GuessedExtra"
            elif change == "ready": altered["rig_ready_for_game"] = True
            else: altered["landmark_evidence"].pop("Head")
            with self.subTest(change=change), self.assertRaises(RigError):
                validate_config(altered, source, binary)


if __name__ == "__main__":
    unittest.main()
