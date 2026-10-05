# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Exact original surface coverage, source-bone slab and final local outputs."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import hashlib
import json
from pathlib import Path
import unittest

from assemble import manifest
from audit_skin import area_ratio, dominance_patch
from constraints import RigError
from glb_io import image_bytes, read_glb
from surface_partition import UNIT_TRIANGLE, elbow_patches, entire_face_beyond_joint, entire_face_in_elbow_slab, lerp, triangulate


ROOT = Path(__file__).resolve().parents[2]


class OriginalSurfacePartitionTests(unittest.TestCase):
    def test_barycentric_source_position_and_uv_are_affine_not_repacked(self):
        self.assertEqual(lerp((0.5, 0.25, 0.25), [(1, 2, 3), (5, 6, 7), (9, 10, 11)]), (4, 5, 6))
        self.assertEqual(lerp((0.5, 0.5, 0), [(0.2, 0.3), (0.6, 0.7), (0.9, 0.1)]), (0.4, 0.5))

    def test_real_three_bone_tie_is_six_oriented_surface_triangles(self):
        rows = [{"Head": 1}, {"LeftUpperArm": 1}, {"LeftLowerArm": 1}]
        chunks = triangulate([(None, dominance_patch(rows, region)) for region in ("Head", "LeftUpperArm", "LeftLowerArm")])
        self.assertEqual(len(chunks), 6)
        self.assertAlmostEqual(sum(area_ratio(tri) for _, tri in chunks), 1)
        for _, triangle in chunks:
            for bary in triangle:
                self.assertAlmostEqual(sum(bary), 1)
                self.assertGreaterEqual(min(bary), 0)

    def test_elbow_planes_use_original_bone_axis_and_cover_entire_source_face(self):
        points = [(3, 1, 5), (3, 7, 5), (7, 4, 5)]
        elbow, wrist = (1, 2, 5), (1, 6, 5)
        patches = elbow_patches(points, elbow, wrist)
        self.assertAlmostEqual(sum(area_ratio(poly) for _, poly in patches), 1)
        chunks = triangulate(patches)
        self.assertAlmostEqual(sum(area_ratio(tri) for _, tri in chunks), 1)
        for owner, triangle in chunks:
            if owner:
                for bary in triangle:
                    point = lerp(bary, points)
                    self.assertGreaterEqual(point[1], elbow[1] - 1e-9)
                    self.assertLessEqual(point[1], wrist[1] + 1e-9)

    def test_conservative_forearm_recovery_never_cuts_crossing_triangles(self):
        elbow, wrist = (1, 2, 3), (2, 4, 7)
        middle = [(1.1, 2.2, 3.4), (1.5, 3, 5), (1.9, 3.8, 6.6)]
        self.assertTrue(entire_face_in_elbow_slab(middle, elbow, wrist))
        crossing = middle[:-1] + [(2.2, 4.4, 7.8)]
        self.assertFalse(entire_face_in_elbow_slab(crossing, elbow, wrist))
        with self.assertRaises(RigError):
            entire_face_in_elbow_slab(middle, elbow, elbow)
        with self.assertRaises(RigError):
            triangulate([(None, list(reversed(UNIT_TRIANGLE)))])

    def test_foot_recovery_uses_actual_ankle_plane_and_keeps_crossing_faces(self):
        knee, ankle = (1, 4, 2), (1, 2, 2)
        self.assertTrue(entire_face_beyond_joint([(0.8, 1.8, 2), (1.2, 1.7, 2), (1, 1.4, 3)], knee, ankle))
        self.assertFalse(entire_face_beyond_joint([(0.8, 2.2, 2), (1.2, 1.7, 2), (1, 1.4, 3)], knee, ankle))
        with self.assertRaises(RigError):
            entire_face_beyond_joint([(1, 2, 3)] * 3, ankle, ankle)

    def test_three_merged_rig_results_have_safe_actual_bone_based_local_outputs(self):
        for name in ("HaloWarriorF", "HaloMageM", "HaloMageF"):
            with self.subTest(costume=name):
                path = ROOT / ("build/costume_r15/Costume_" + name + "_material_fixed/joints.json")
                if not path.is_file():
                    self.skipTest("Final merged rig conversion is not present")
                plan = json.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(len(plan["parts"]), 15)
                self.assertEqual(len(plan["meshes"]), {"HaloWarriorF": 18, "HaloMageM": 17, "HaloMageF": 19}[name])
                self.assertEqual(len(plan["batches"]), 3)
                assembled = manifest(path, "Costume_" + name)
                self.assertGreater(assembled["hip_height"], 0.01)
                if name == "HaloWarriorF":
                    report = plan["mechanical_surface_partition"]
                    self.assertEqual(report["source_triangles"], 14854)
                    self.assertEqual(report["output_triangles"], 14854)
                    self.assertEqual(report["reassigned_original_faces"], 56)
                    self.assertFalse(report["original_vertices_changed"])
                    self.assertEqual(report["extra_triangles"], 0)
                    self.assertEqual(report["maximum_sampled_normalization_error_degrees"], 0)
                self.assertFalse(plan["rig_ready_for_game"])

    def test_final_horns_outputs_keep_original_images_normals_and_real_joint_graph(self):
        for name, before, after, faces in (("HornsMageM", 14031, 14036, 1), ("HornsMageF", 14446, 14446, 0)):
            with self.subTest(costume=name):
                path = ROOT / ("build/costume_r15/Costume_" + name + "/joints.json")
                if not path.is_file():
                    self.skipTest("Final local mechanical conversion is not present")
                plan = json.loads(path.read_text(encoding="utf-8"))
                source, source_binary, original = read_glb(plan["source"])
                self.assertEqual(hashlib.sha256(original).hexdigest(), plan["source_sha256"])
                source_images = {hashlib.sha256(image_bytes(source, source_binary, image)).hexdigest() for image in source["images"]}
                exported_images = set()
                self.assertEqual(plan["source_triangles"], before)
                self.assertEqual(plan["prepared_triangles"], after)
                report = plan["mechanical_surface_partition"]
                self.assertEqual(report["subdivided_source_faces"], faces)
                self.assertFalse(report["original_vertices_changed"])
                self.assertEqual(report["maximum_coverage_error"], 0)
                if name == "HornsMageF":
                    self.assertEqual(report["reassigned_original_faces"], 415)
                    self.assertEqual(report["maximum_sampled_normalization_error_degrees"], 0)
                for batch in plan["batches"]:
                    self.assertLessEqual(batch["estimated_assets"], 10)
                    gltf, binary, _ = read_glb(path.parent / batch["file"])
                    exported_images.update(hashlib.sha256(image_bytes(gltf, binary, image)).hexdigest() for image in gltf["images"])
                    self.assertTrue(batch["export_validation"]["normals_verified"])
                    self.assertLess(batch["export_validation"]["maximum_normal_export_error"], 1e-4)
                self.assertEqual(exported_images, source_images)
                self.assertTrue(plan["source_corner_normals_preserved"])
                assembled = manifest(path, "Costume_" + name)
                self.assertEqual(len(assembled["joints"]), 15)
                self.assertEqual(len(assembled["meshes"]), 19)
                self.assertGreater(assembled["hip_height"], 0.01)
                self.assertFalse(plan["rig_ready_for_game"])

    def test_projected_head_recovery_moves_only_112_verified_original_faces(self):
        directory = ROOT / "build/costume_r15"
        path = directory / "Costume_HornsArcherM_face_fixed/joints.json"
        before_path = directory / "Costume_HornsArcherM/joints.json"
        if not path.is_file() or not before_path.is_file():
            self.skipTest("Exact projected face recovery is not present")
        plan = json.loads(path.read_text(encoding="utf-8"))
        before = json.loads(before_path.read_text(encoding="utf-8"))
        report = plan["mechanical_surface_partition"]
        self.assertEqual(report["source_triangles"], 14253)
        self.assertEqual(report["output_triangles"], 14253)
        self.assertEqual(report["subdivided_source_faces"], 0)
        self.assertEqual(report["projected_head_faces_restored"], 112)
        self.assertEqual(report["reassigned_original_faces"], 112)
        self.assertFalse(report["original_vertices_changed"])
        self.assertEqual(report["maximum_sampled_normalization_error_degrees"], 0)
        self.assertEqual(plan["source_sha256"], before["source_sha256"])
        self.assertEqual(hashlib.sha256(Path(plan["source"]).read_bytes()).hexdigest(), plan["source_sha256"])
        self.assertEqual(hashlib.sha256(Path(report["projected_head_face_signature_file"]).read_bytes()).hexdigest(),
                         report["projected_head_face_signature_sha256"])
        self.assertEqual(len({(face["object"], face["source_face"]) for face in report["faces"]}), 112)
        for face in report["faces"]:
            self.assertEqual(face["source_owner"], "UpperTorso")
            self.assertEqual(face["reason"], "verified_projected_front_face_uv_geometry_signature")
            self.assertEqual(face["barycentric_triangles"], [{"owner_override": "Head", "corners": [list(corner) for corner in UNIT_TRIANGLE]}])
        counts = {part["name"]: part["triangles"] for part in plan["parts"]}
        old_counts = {part["name"]: part["triangles"] for part in before["parts"]}
        self.assertEqual(counts["Head"], old_counts["Head"] + 112)
        self.assertEqual(counts["UpperTorso"], old_counts["UpperTorso"] - 112)
        for name in counts.keys() - {"Head", "UpperTorso"}:
            self.assertEqual(counts[name], old_counts[name])
        old_frames = {part["name"]: part["CFrame"] for part in before["parts"]}
        for part in plan["parts"]:
            if part["name"] != "UpperTorso":
                self.assertEqual(part["CFrame"], old_frames[part["name"]])
        # Removing a front-face triangle can change the torso's bounding-box
        # center; local C0/C1 must change with it, while real world joints stay.
        self.assertEqual([joint["joint_position"] for joint in plan["joints"]],
                         [joint["joint_position"] for joint in before["joints"]])
        source, source_binary, _ = read_glb(plan["source"])
        source_images = {hashlib.sha256(image_bytes(source, source_binary, item)).hexdigest() for item in source["images"]}
        exported_images = set()
        for batch in plan["batches"]:
            self.assertLessEqual(batch["estimated_assets"], 10)
            gltf, binary, _ = read_glb(path.parent / batch["file"])
            exported_images.update(hashlib.sha256(image_bytes(gltf, binary, item)).hexdigest() for item in gltf["images"])
            self.assertTrue(batch["export_validation"]["normals_verified"])
        self.assertEqual(exported_images, source_images)
        self.assertEqual(len(manifest(path, "Costume_HornsArcherM")["joints"]), 15)
        self.assertFalse(plan["rig_ready_for_game"])

    def test_final_small_face_repairs_preserve_all_source_world_joints(self):
        cases = (("Costume_HornsArcherM", "Costume_HornsArcherM_face_fixed_v2", 115),
                 ("Costume_HornsWarriorM", "Costume_HornsWarriorM_face_fixed", 1),
                 ("Costume_HaloMageF_material_front_fixed", "Costume_HaloMageF_material_front_face_fixed", 3))
        for old_name, new_name, restored in cases:
            with self.subTest(costume=new_name):
                before_path = ROOT / "build/costume_r15" / old_name / "joints.json"
                path = ROOT / "build/costume_r15" / new_name / "joints.json"
                if not path.is_file() or not before_path.is_file():
                    self.skipTest("Final exact small face repair is not present")
                before = json.loads(before_path.read_text(encoding="utf-8"))
                plan = json.loads(path.read_text(encoding="utf-8"))
                report = plan["mechanical_surface_partition"]
                self.assertEqual(plan["source_sha256"], before["source_sha256"])
                self.assertEqual(report["projected_head_faces_restored"], restored)
                self.assertEqual(report["source_triangles"], report["output_triangles"])
                self.assertEqual(report["subdivided_source_faces"], 0)
                self.assertFalse(report["original_vertices_changed"])
                old_counts = {part["name"]: part["triangles"] for part in before["parts"]}
                new_counts = {part["name"]: part["triangles"] for part in plan["parts"]}
                for part in old_counts:
                    delta = restored if part == "Head" else -restored if part == "UpperTorso" else 0
                    self.assertEqual(new_counts[part], old_counts[part] + delta)
                self.assertEqual([joint["joint_position"] for joint in before["joints"]], [joint["joint_position"] for joint in plan["joints"]])
                self.assertFalse(plan["rig_ready_for_game"])


if __name__ == "__main__":
    unittest.main()
