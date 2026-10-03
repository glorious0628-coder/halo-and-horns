"""설치된 Roblox 기본 R15 RBXM의 Source를 읽어 캡처와 비교한다. 파일/Studio를 바꾸지 않는다."""
import hashlib
import json
import os
import struct
from pathlib import Path


def unpack_lz4(data, expected):
    out = bytearray()
    pos = 0
    while pos < len(data):
        token = data[pos]
        pos += 1
        literal = token >> 4
        if literal == 15:
            while True:
                add = data[pos]
                pos += 1
                literal += add
                if add != 255:
                    break
        out.extend(data[pos:pos + literal])
        pos += literal
        if pos == len(data):
            break
        distance = struct.unpack_from("<H", data, pos)[0]
        pos += 2
        if not 0 < distance <= len(out):
            raise ValueError("LZ4 match offset 오류")
        count = (token & 15) + 4
        if (token & 15) == 15:
            while True:
                add = data[pos]
                pos += 1
                count += add
                if add != 255:
                    break
        for _ in range(count):
            out.append(out[-distance])
        if len(out) > expected:
            raise ValueError("LZ4 길이 제한 초과")
    if len(out) != expected:
        raise ValueError("LZ4 길이 불일치")
    return bytes(out)


root = Path(__file__).resolve().parents[2]
captured = (root / "tools/costume_r15/vendor/RobloxR15Animate.client.luau").read_bytes()
versions = Path(os.environ["LOCALAPPDATA"]) / "Roblox/Versions"
evidence = []
for file in versions.glob("*/content/avatar/scripts/humanoidAnimateR15_DEPRECATED_20260813.rbxm"):
    raw = file.read_bytes()
    if raw[:14] != b"<roblox!\x89\xff\r\n\x1a\n":
        raise ValueError("RBXM 헤더 오류")
    pos = 32
    while pos + 16 <= len(raw):
        kind = raw[pos:pos + 4]
        compressed, expanded, _ = struct.unpack_from("<III", raw, pos + 4)
        payload = raw[pos + 16:pos + 16 + (compressed or expanded)]
        pos += 16 + (compressed or expanded)
        decoded = unpack_lz4(payload, expanded) if compressed else payload
        if kind == b"PROP":
            name_length = struct.unpack_from("<I", decoded, 4)[0]
            name = decoded[8:8 + name_length]
            property_type = decoded[8 + name_length]
            if name == b"Source" and property_type == 1:
                string_length = struct.unpack_from("<I", decoded, 9 + name_length)[0]
                source = decoded[13 + name_length:13 + name_length + string_length]
                if len(source) != string_length:
                    raise ValueError("Source 길이 오류")
                evidence.append({"engine_file": str(file), "engine_file_sha256": hashlib.sha256(raw).hexdigest(),
                                 "source_bytes": len(source), "source_sha256": hashlib.sha256(source).hexdigest(),
                                 "exact_source_match": source == captured})
        if kind.startswith(b"END"):
            break
path = root / "build/roblox_r15_animate_engine_evidence.json"
path.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(evidence, ensure_ascii=False))
