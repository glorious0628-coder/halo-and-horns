# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import struct
from pathlib import Path
import tempfile
import unittest

from constraints import RigError
from glb_io import accessor_values, image_bytes, read_glb, write_glb


class ExportedGlbChecks(unittest.TestCase):
    def test_round_trip_preserves_float_uvs_and_image_bytes(self):
        binary = struct.pack('<4f', 0.125, 0.875, 0.5, 1.0) + b'original-face-image'
        gltf = {'buffers': [{'byteLength': len(binary)}], 'bufferViews': [
            {'buffer': 0, 'byteOffset': 0, 'byteLength': 16},
            {'buffer': 0, 'byteOffset': 16, 'byteLength': 19}],
            'accessors': [{'bufferView': 0, 'componentType': 5126, 'type': 'VEC2', 'count': 2}],
            'images': [{'bufferView': 1, 'mimeType': 'image/png'}]}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.glb'
            write_glb(path, gltf, binary)
            parsed, content, _ = read_glb(path)
            self.assertEqual(accessor_values(parsed, content, 0), [(0.125, 0.875), (0.5, 1.0)])
            self.assertEqual(image_bytes(parsed, content, parsed['images'][0]), b'original-face-image')

    def test_accessor_cannot_read_past_its_buffer_view(self):
        gltf = {'bufferViews': [{'buffer': 0, 'byteLength': 4}],
                'accessors': [{'bufferView': 0, 'componentType': 5126, 'type': 'VEC2', 'count': 1}]}
        with self.assertRaises(RigError):
            accessor_values(gltf, b'\0' * 20, 0)

    def test_external_image_is_refused_without_fetching(self):
        with self.assertRaises(RigError):
            image_bytes({}, b'', {'uri': 'https://example.invalid/face.png'})

    def test_truncated_glb_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'broken.glb'
            path.write_bytes(b'glTF')
            with self.assertRaises(RigError):
                read_glb(path)


if __name__ == '__main__':
    unittest.main()
