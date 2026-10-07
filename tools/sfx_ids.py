"""
올린 효과음 id 적기 (소리 만들기, 2026-10-07).
  py tools/sfx_ids.py <키> <숫자 id>
art/sfx/asset_ids.json: "ids" 끝에 키를 더하고 "pending"에서 빼고, 같은 키가 "kept"(아직 쓰는 옛 소리)에 있으면 그 옛 id를
"old"(바뀐 옛 소리, 개발 1 연결 + Play 확인 뒤 정리)로 옮긴다. 글자 바꾸기로만 고쳐서 파일 모양(줄·순서)을 그대로 둔다.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "art", "sfx", "asset_ids.json")


def block(text, header, indent):
    """(start, end) of the lines inside the object that starts with `header` (e.g. '  "ids": {') and closes at `indent` + '}'"""
    s = text.index(header + "\n") + len(header) + 1
    e = text.index("\n" + indent + "}", s - 1)
    return s, e


def remove_line(lines, key):
    i = next(n for n, ln in enumerate(lines) if ln.strip().startswith(f'"{key}":'))
    last = not lines[i].rstrip().endswith(",")
    del lines[i]
    if last and i > 0:
        lines[i - 1] = lines[i - 1].rstrip().rstrip(",")
    return lines


def insert_sorted(lines, key, value, pad):
    keys = [re.match(r'\s*"([^"]+)"', ln).group(1) for ln in lines]
    at = next((n for n, k in enumerate(keys) if k > key), len(lines))
    new = f'{pad}"{key}": "{value}"'
    if at == len(lines):
        lines[-1] = lines[-1].rstrip() + ","
        lines.append(new)
    else:
        lines.insert(at, new + ",")
    return lines


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) != 3 or not sys.argv[2].isdigit():
        raise SystemExit(__doc__)
    key, num = sys.argv[1], sys.argv[2]
    text = open(PATH, encoding="utf-8").read()
    data = json.loads(text)
    if key in data["ids"]:
        raise SystemExit(f"{key} already has an id: {data['ids'][key]}")
    # 1. "ids": append
    s, e = block(text, '  "ids": {', "  ")
    text = text[:e] + f',\n    "{key}": "rbxassetid://{num}"' + text[e:]
    # 2. "pending": drop the key
    pend = [k for k in data.get("pending", []) if k != key]
    text = re.sub(r'  "pending": \[[^\]]*\],', '  "pending": ' + json.dumps(pend, ensure_ascii=False) + ",", text, count=1)
    # 3. "kept" -> "old"
    old_id = data.get("kept", {}).get("ids", {}).get(key)
    if old_id:
        ks = text.index('  "kept": {')
        s, e = block(text[ks:], '    "ids": {', "    ")
        s, e = s + ks, e + ks
        text = text[:s] + "\n".join(remove_line(text[s:e].split("\n"), key)) + text[e:]
        os_ = text.index('  "old": {')
        s, e = block(text[os_:], '    "ids": {', "    ")
        s, e = s + os_, e + os_
        text = text[:s] + "\n".join(insert_sorted(text[s:e].split("\n"), key, old_id, "      ")) + text[e:]
    check = json.loads(text)
    assert check["ids"][key] == f"rbxassetid://{num}" and key not in check.get("pending", [])
    assert key not in check.get("kept", {}).get("ids", {}) and (not old_id or check["old"]["ids"][key] == old_id)
    with open(PATH, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print(f"{key} = rbxassetid://{num}; pending {check['pending']}; old id moved: {old_id or '-'}")


if __name__ == "__main__":
    main()
