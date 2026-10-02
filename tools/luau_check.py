"""
src/ 의 모든 Luau 파일을 Roblox Studio의 진짜 컴파일러(loadstring)로 문법 검사한다. 실행은 하지 않는다.

  py tools/luau_check.py                 -> 전체 검사
  py tools/luau_check.py path1 path2 ... -> 지정한 파일만 검사 (src/ 기준 또는 절대 경로)

대상: 이름에 STUDIO_NAME(기본 "GoodEvil")이 들어간 스튜디오 창, Edit 모드여야 함.
종료 코드: 문법 오류가 있으면 1.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402
from build_place import SRC, script_kind, read_source  # noqa: E402
from sync_to_studio import long_string  # noqa: E402

BATCH_CHARS = 60_000


def targets(argv):
    if argv:
        out = []
        for a in argv:
            p = a if os.path.isabs(a) else os.path.join(SRC, a)
            if not os.path.isfile(p):
                p = os.path.abspath(a)
            out.append(p)
        return out
    out = []
    for root, _, files in os.walk(SRC):
        for f in sorted(files):
            if script_kind(f)[1]:
                out.append(os.path.join(root, f))
    return out


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    files = targets(sys.argv[1:])
    if not files:
        print("검사할 파일이 없습니다")
        return
    c = Client()
    errors = 0
    try:
        c.start()
        batch, size = [], 0

        def flush():
            nonlocal batch, size, errors
            if not batch:
                return
            lines = ["local out = {}"]
            for rel, src in batch:
                lines.append(
                    f"do local f, e = loadstring({long_string(src)}, {json.dumps('=' + rel)}) "
                    f"if not f then table.insert(out, e) end end"
                )
            lines.append('return #out == 0 and "OK" or table.concat(out, "\\n")')
            res = c.call("execute_luau", {"code": "\n".join(lines), "datamodel_type": "Edit"})
            text = "".join(p.get("text", "") for p in res.get("content", [])).strip()
            if res.get("isError"):
                print(f"[도구 오류] {text}")
                errors += 1
            elif text != "OK":
                for line in text.splitlines():
                    print(line)
                    errors += 1
            batch, size = [], 0

        for path in files:
            rel = os.path.relpath(path, SRC).replace("\\", "/")
            src = read_source(path)
            if size + len(src) > BATCH_CHARS:
                flush()
            batch.append((rel, src))
            size += len(src)
        flush()
    finally:
        c.close()
    if errors:
        print(f"문법 오류 {errors}개")
        sys.exit(1)
    print(f"문법 OK: {len(files)}개 파일")


if __name__ == "__main__":
    main()
