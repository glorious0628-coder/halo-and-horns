"""Source fidelity and duplicate-upload guards, entirely offline with a fake MCP client."""
import copy
import io
import json
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from assemble import ROOT, matvec
from constraints import RigError
from editable_upload import load_mesh, preview_data, run_upload, texture_ids

sys.path.insert(0, str(ROOT / "tools"))


class SourceFidelity(unittest.TestCase):
    def setUp(self):
        self.joints = ROOT / "build/costume_r15/Costume_HaloWarriorM/joints.json"
        self.actual = ROOT / "build/costume_batch01_actual.txt"
        self.probe = ROOT / "build/costume_r15/Costume_HaloWarriorM/editable_probe_reference_result.json"
        if not all(path.is_file() for path in (self.joints, self.actual, self.probe)):
            self.skipTest("Local actually imported pilot evidence is absent")

    def test_all_11_remaining_meshes_keep_original_faces_normals_uv_and_world_vertices(self):
        metadata = json.loads(self.joints.read_text())
        meshes = [mesh for batch in metadata["batches"][1:] for mesh in batch["parts"]]
        self.assertEqual(len(meshes), 11)
        for mesh in meshes:
            with self.subTest(mesh=mesh):
                source = load_mesh(self.joints, mesh)
                data = preview_data(self.joints, mesh, self.actual, self.probe)
                self.assertEqual(source["indices"], data["indices"])
                self.assertEqual(source["uvs"], data["uvs"])
                rotation = [data["preview_cframe"][3:6], data["preview_cframe"][6:9], data["preview_cframe"][9:12]]
                for before, native in zip(source["positions"], data["positions"]):
                    restored = matvec(rotation, native)
                    for axis in range(3):
                        self.assertAlmostEqual(restored[axis] + data["geometry"]["center"][axis],
                                               before[axis] + data["geometry"]["origin"][axis], places=7)
                for before, native in zip(source["normals"], data["normals"]):
                    self.assertEqual(before, matvec(rotation, native))
                self.assertLessEqual(data["triangles"], 20000)
                self.assertLessEqual(data["vertices"], 60000)

    def test_uploaded_batch01_texture_id_reuse_matches_embedded_bytes(self):
        mapping, _ = texture_ids(self.joints, self.actual)
        self.assertEqual(len(mapping), 2)
        self.assertEqual(set(mapping.values()), {"rbxassetid://105457578631345", "rbxassetid://108419991991762"})
        for mesh in ("LeftLowerLeg", "RightUpperArm__Material02", "RightFoot"):
            data = preview_data(self.joints, mesh, self.actual, self.probe)
            self.assertEqual(data["texture_id"], mapping[data["texture_sha256"]])

    def test_unverified_probe_or_changed_source_cannot_create_upload_data(self):
        probe = json.loads(self.probe.read_text())
        for field, value in (("verified", False), ("source_sha256", "changed"), ("uv_policy", "unverified"), ("reversed_winding", 1)):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                changed = copy.deepcopy(probe)
                changed[field] = value
                file = Path(directory) / "probe.json"
                file.write_text(json.dumps(changed))
                with self.assertRaises(RigError):
                    preview_data(self.joints, "LeftLowerLeg", self.actual, file)


class LedgerGuards(unittest.TestCase):
    def fake_client(self, ledger, data, response=None, failure=None):
        class FakeClient:
            calls = 0
            def start(self): pass
            def close(self): pass
            def call(self, method, args):
                if method == "list_roblox_studios":
                    value = {"studios": [{"name": "GoodEvil", "id": "fixture-studio"}]}
                elif method == "get_studio_state":
                    return {"content": [{"type": "text", "text": "Current Studio Mode: Edit"}]}
                else:
                    FakeClient.calls += 1
                    # A durable lock is recorded before the single external mutation could happen.
                    assert json.loads(ledger.read_text())["entries"][data["fingerprint"]]["state"] == "Submitting"
                    if failure:
                        raise failure
                    value = response
                return {"content": [{"type": "text", "text": json.dumps(value)}]}
        return FakeClient

    def data(self):
        return {"fingerprint": "fixture-fingerprint", "asset_name": "fixture-name", "name": "Costume_HaloWarriorM",
                "mesh": "LeftLowerLeg", "source_sha256": "fixture-source", "glb_sha256": "fixture-glb",
                "texture_id": "rbxassetid://1"}

    def test_success_is_written_immediately_and_a_second_call_never_uploads(self):
        data = self.data()
        response = {"schema": 1, "mode": "editable_upload", "fingerprint": data["fingerprint"], "state": "Uploaded", "asset_id": 123}
        with tempfile.TemporaryDirectory() as directory:
            ledger = Path(directory) / "ledger.json"
            fake = self.fake_client(ledger, data, response)
            with patch("studio_mcp.Client", fake), patch("sys.stdout", new_callable=io.StringIO):
                run_upload(data, "fixture", ledger)
                run_upload(data, "fixture", ledger)
            self.assertEqual(fake.calls, 1)
            self.assertEqual(json.loads(ledger.read_text())["entries"][data["fingerprint"]]["asset_id"], 123)
            self.assertFalse(ledger.with_name("ledger.json.lock").exists())

    def test_uncertain_response_blocks_any_automatic_retry(self):
        data = self.data()
        with tempfile.TemporaryDirectory() as directory:
            ledger = Path(directory) / "ledger.json"
            fake = self.fake_client(ledger, data, failure=RuntimeError("fixture interrupted response"))
            with patch("studio_mcp.Client", fake), patch("sys.stdout", new_callable=io.StringIO):
                with self.assertRaises(RuntimeError):
                    run_upload(data, "fixture", ledger)
                with self.assertRaises(RigError):
                    run_upload(data, "fixture", ledger)
            self.assertEqual(fake.calls, 1)
            self.assertEqual(json.loads(ledger.read_text())["entries"][data["fingerprint"]]["state"], "Unknown")

    def test_leftover_lock_never_connects_or_uploads(self):
        data = self.data()
        with tempfile.TemporaryDirectory() as directory:
            ledger = Path(directory) / "ledger.json"
            lock = ledger.with_name("ledger.json.lock")
            lock.write_text("fixture earlier process")
            with self.assertRaises(RigError):
                run_upload(data, "fixture", ledger)
            self.assertEqual(lock.read_text(), "fixture earlier process")


if __name__ == "__main__":
    import sys
    sys.path.insert(0, str(ROOT / "tools"))
    unittest.main()
