"""Verify real importer bake recovery and recentered joint frames, without Studio."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from assemble import IDENTITY, RigError, bounds, cube_rotations, importer_basis, inspection_data, manifest, matmul, matvec, transpose


I = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
Y180 = [[-1, 0, 0], [0, 1, 0], [0, 0, -1]]
Z90 = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]


def fixture(bake=Y180, scale=10, rotation=I, source_origin=False):
    geometries, rows = [], {}
    for index, center in enumerate(([1, 2, 3], [-2, 4, -5], [6, 0, 1], [0, -3, 8])):
        geometry = {"name": str(index), "center": center, "size": [index + 1, index + 2, index + 3],
                    "offset": [0.2 * (index + 1), -0.1, 0.3]}
        geometries.append(geometry)
        rotated = matvec(matmul(rotation, bake), center)
        position = [scale * value + shift for value, shift in zip(rotated, [25, 50, -18])]
        dimensions = matvec([[abs(value) for value in row] for row in bake], geometry["size"])
        pivot = [-scale * value for value in matvec(bake, geometry["offset"])] if source_origin else [0, 0, 0]
        rows[geometry["name"]] = {"cframe": position + [value for row in rotation for value in row],
                                  "size": [scale * value for value in dimensions],
                                  "mesh_size": dimensions, "pivot_offset": pivot + IDENTITY}
    return geometries, rows


class ImporterBasisTests(unittest.TestCase):
    def test_rotations_are_24_proper_axes_not_mirrors(self):
        rotations = list(cube_rotations())
        self.assertEqual(len(rotations), 24)
        for rotation in rotations:
            self.assertEqual(matmul(rotation, transpose(rotation)), I)
            first, second, third = rotation
            determinant = sum(first[axis] * (second[(axis + 1) % 3] * third[(axis + 2) % 3] -
                                            second[(axis + 2) % 3] * third[(axis + 1) % 3]) for axis in range(3))
            self.assertEqual(determinant, 1)

    def test_noncentered_material_fragment_keeps_actual_center(self):
        geometry = bounds([[1, 2, 3], [2, 5, 7]])
        self.assertEqual(geometry["offset"], [1.5, 3.5, 5])
        self.assertEqual(geometry["size"], [1, 3, 4])

    def test_actual_y180_bake_and_independent_placement_are_recovered(self):
        geometry, rows = fixture()
        result = importer_basis(geometry, rows)
        self.assertEqual(result["bake"], Y180)
        self.assertAlmostEqual(result["scale"], 10)
        self.assertEqual(result["offset"], [25, 50, -18])

    def test_world_cframe_rotation_is_removed_from_baked_mesh_basis(self):
        geometry, rows = fixture(rotation=Z90)
        self.assertEqual(importer_basis(geometry, rows)["bake"], Y180)

    def test_axis_permutation_and_source_origin_pivots_are_verified(self):
        geometry, rows = fixture(bake=Z90, source_origin=True)
        self.assertEqual(importer_basis(geometry, rows)["bake"], Z90)

    def test_nonuniform_resize_is_refused(self):
        geometry, rows = fixture()
        rows["0"]["size"][0] *= 1.3
        with self.assertRaises(RigError):
            importer_basis(geometry, rows)

    def test_unknown_recentering_or_changed_geometry_is_refused(self):
        for property in ("cframe", "pivot_offset", "mesh_size"):
            with self.subTest(property=property):
                geometry, rows = fixture()
                rows["0"][property][0] += 1
                with self.assertRaises(RigError):
                    importer_basis(geometry, rows)

    def test_mirror_and_ambiguous_axis_fit_are_refused(self):
        geometry, rows = fixture(bake=[[-1, 0, 0], [0, 1, 0], [0, 0, 1]])
        with self.assertRaises(RigError):
            importer_basis(geometry, rows)
        geometry, rows = fixture()
        for item in geometry:
            item["center"], item["size"] = [0, 0, 0], [1, 1, 1]
            rows[item["name"]]["cframe"] = [0, 0, 0] + IDENTITY
            rows[item["name"]]["size"] = [1, 1, 1]
            rows[item["name"]]["mesh_size"] = [1, 1, 1]
        with self.assertRaises(RigError):
            importer_basis(geometry, rows)


class ActualPilotAssemblyTests(unittest.TestCase):
    def test_real_glb_fragments_recenter_without_moving_any_bone_joint(self):
        root = Path(__file__).resolve().parents[2]
        joints = root / "build/costume_r15/Costume_HaloWarriorM/joints.json"
        if not joints.is_file():
            self.skipTest("Local pilot conversion is not present")
        data = manifest(joints, "Costume_HaloWarriorM")
        pristine = copy.deepcopy(data)
        rotations = {"batch_01.glb": Y180, "batch_02.glb": Z90, "batch_03.glb": I}
        rows = []
        for geometry in data["meshes"]:
            bake = rotations[geometry["batch"]]
            center = [value + shift for value, shift in zip(matvec(bake, geometry["center"]), [40, 80, 120])]
            size = matvec([[abs(value) for value in row] for row in bake], geometry["size"])
            rows.append({"name": geometry["name"], "mesh_id": "rbxassetid://100001", "size": size,
                         "mesh_size": size, "cframe": center + IDENTITY, "pivot_offset": [0, 0, 0] + IDENTITY})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "inspection.json"
            path.write_text(json.dumps({"schema": 1, "name": data["name"], "source_sha256": data["source_sha256"], "meshes": rows}), encoding="utf-8")
            inspection_data(path, data)
        pieces = {geometry["name"]: geometry for geometry in data["meshes"]}
        for joint in data["joints"]:
            for part_key, frame_key in (("part0", "C0"), ("part1", "C1")):
                part = joint[part_key]
                cf = data["root"]["center"] + IDENTITY if part == "HumanoidRootPart" else pieces[part]["assembled_cframe"]
                rotation = [cf[3:6], cf[6:9], cf[9:12]]
                offset = matvec(rotation, joint[frame_key][:3])
                for axis in range(3):
                    self.assertAlmostEqual(cf[axis] + offset[axis], joint["world"][axis], places=6)
                local_rotation = [joint[frame_key][3:6], joint[frame_key][6:9], joint[frame_key][9:12]]
                self.assertEqual(matmul(rotation, local_rotation), I)
        self.assertEqual(len(pieces), 18)
        self.assertEqual(len(data["joints"]), 15)
        self.assertAlmostEqual(data["hip_height"], 0.811379075050354)
        for original, assembled in zip(pristine["meshes"], data["meshes"]):
            self.assertEqual(original["center"], assembled["center"])


if __name__ == "__main__":
    unittest.main()
