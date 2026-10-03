"""Small, read-only GLB inspection helpers for validating exported body meshes."""

import json
from pathlib import Path
import struct

from constraints import RigError


def read_glb(path):
    data = Path(path).read_bytes()
    if len(data) < 20:
        raise RigError("Truncated GLB header")
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise RigError("Expected a complete binary glTF 2 file")
    chunks, offset = {}, 12
    while offset < length:
        if offset + 8 > length:
            raise RigError("Truncated GLB chunk header")
        size, kind = struct.unpack_from("<II", data, offset)
        if size % 4 or offset + 8 + size > length or kind in chunks:
            raise RigError("Invalid GLB chunk size or duplicate chunk")
        chunks[kind] = data[offset + 8:offset + 8 + size]
        offset += 8 + size
    if 0x4E4F534A not in chunks:
        raise RigError("Missing GLB JSON chunk")
    gltf = json.loads(chunks[0x4E4F534A].decode("utf-8"))
    binary = chunks.get(0x004E4942, b"")
    buffers = gltf.get("buffers", [])
    if len(buffers) != 1 or "uri" in buffers[0] or not 0 <= buffers[0].get("byteLength", -1) <= len(binary):
        raise RigError("Only one embedded GLB buffer is supported")
    return gltf, binary, data


def write_glb(path, gltf, binary):
    json_bytes = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_bytes += b" " * (-len(json_bytes) % 4)
    binary += b"\0" * (-len(binary) % 4)
    data = struct.pack("<4sII", b"glTF", 2, 28 + len(json_bytes) + len(binary))
    data += struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
    data += struct.pack("<II", len(binary), 0x004E4942) + binary
    Path(path).write_bytes(data)


def view_bytes(gltf, binary, index):
    if not isinstance(index, int) or not 0 <= index < len(gltf.get("bufferViews", [])):
        raise RigError("Invalid buffer-view index")
    view = gltf["bufferViews"][index]
    start, size = view.get("byteOffset", 0), view.get("byteLength", -1)
    if view.get("buffer") != 0 or not isinstance(start, int) or not isinstance(size, int) or start < 0 or size < 0 or start + size > len(binary):
        raise RigError("Out-of-range GLB buffer view")
    return view, binary[start:start + size]


def image_bytes(gltf, binary, image):
    if "bufferView" not in image or "uri" in image:
        raise RigError("Images must be embedded in GLB; external images are not fetched")
    return view_bytes(gltf, binary, image["bufferView"])[1]


def accessor_values(gltf, binary, index):
    if not isinstance(index, int) or not 0 <= index < len(gltf.get("accessors", [])):
        raise RigError("Invalid accessor index")
    accessor = gltf["accessors"][index]
    if accessor.get("sparse") or "bufferView" not in accessor or accessor.get("normalized"):
        raise RigError("Sparse/normalized exported accessors are not supported")
    formats = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
    dimensions = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    if accessor.get("componentType") not in formats or accessor.get("type") not in dimensions:
        raise RigError("Unsupported exported accessor type")
    record = struct.Struct("<" + formats[accessor["componentType"]] * dimensions[accessor["type"]])
    view, content = view_bytes(gltf, binary, accessor["bufferView"])
    start, count = accessor.get("byteOffset", 0), accessor.get("count", -1)
    stride = view.get("byteStride", record.size)
    if not all(isinstance(value, int) for value in (start, count, stride)) or start < 0 or count < 0 or stride < record.size or (count and start + (count - 1) * stride + record.size > len(content)):
        raise RigError("Out-of-range exported accessor")
    return [record.unpack_from(content, start + position * stride) for position in range(count)]
