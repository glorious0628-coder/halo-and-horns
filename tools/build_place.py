"""
src/ 폴더의 Luau 스크립트들을 Roblox Studio에서 바로 열 수 있는 .rbxlx 파일로 묶는다.
(Rojo 없이 쓰는 간단한 빌더. 폴더 구조와 파일 이름 규칙은 Rojo와 같다.)

  *.server.luau  -> Script
  *.client.luau  -> LocalScript
  *.luau         -> ModuleScript
  init.server.luau / init.client.luau / init.luau -> 그 폴더 자체가 해당 스크립트가 됨
  폴더            -> Folder (단, src 바로 아래 폴더 이름은 서비스로 취급)

사용법:
  py tools/build_place.py            -> build/GoodEvil.rbxlx 생성
  py tools/build_place.py out.rbxlx  -> 원하는 경로로 생성
"""

import os
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
DEFAULT_OUT = os.path.join(ROOT, "build", "GoodEvil.rbxlx")

SERVICES = {
    "Workspace", "Lighting", "ReplicatedFirst", "ReplicatedStorage",
    "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack",
    "StarterPlayer", "SoundService", "Teams", "Chat", "TextChatService",
}
# StarterPlayer 아래 특수 컨테이너
SPECIAL_CONTAINERS = {"StarterPlayerScripts", "StarterCharacterScripts"}

SCRIPT_SUFFIXES = [
    (".server.luau", "Script"), (".server.lua", "Script"),
    (".client.luau", "LocalScript"), (".client.lua", "LocalScript"),
    (".luau", "ModuleScript"), (".lua", "ModuleScript"),
]

_ref_counter = 0


def next_ref():
    global _ref_counter
    _ref_counter += 1
    return "RBX%08X" % _ref_counter


def script_kind(filename):
    for suffix, cls in SCRIPT_SUFFIXES:
        if filename.endswith(suffix):
            return filename[: -len(suffix)], cls
    return None, None


def cdata(text):
    # "]]>" 가 소스 안에 있으면 CDATA가 깨지므로 쪼갠다
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def read_source(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        return f.read().replace("\r\n", "\n")


def item_xml(cls, name, source=None, children=(), indent=1):
    pad = "  " * indent
    out = [f'{pad}<Item class="{cls}" referent="{next_ref()}">',
           f"{pad}  <Properties>",
           f'{pad}    <string name="Name">{escape(name)}</string>']
    if source is not None:
        out.append(f'{pad}    <ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    if cls == "Script":
        out.append(f'{pad}    <bool name="Disabled">false</bool>')
    out.append(f"{pad}  </Properties>")
    for child in children:
        out.append(child(indent + 1))
    out.append(f"{pad}</Item>")
    return "\n".join(out)


def build_dir(path, name, cls_override=None):
    """폴더 하나를 Item 생성 함수로 바꾼다."""
    entries = sorted(os.listdir(path))
    init_cls, init_src = None, None
    for e in entries:
        base, cls = script_kind(e)
        if base == "init" and os.path.isfile(os.path.join(path, e)):
            init_cls, init_src = cls, read_source(os.path.join(path, e))

    children = []
    for e in entries:
        full = os.path.join(path, e)
        if os.path.isdir(full):
            children.append(build_dir(full, e, e if e in SPECIAL_CONTAINERS else None))
        else:
            base, cls = script_kind(e)
            if cls is None or base == "init":
                continue
            src = read_source(full)
            children.append(lambda ind, c=cls, b=base, s=src: item_xml(c, b, s, (), ind))

    cls = cls_override or init_cls or "Folder"
    src = init_src if (init_cls and not cls_override) else None
    return lambda ind: item_xml(cls, name, src, children, ind)


def count_scripts(path):
    n = 0
    for _, _, files in os.walk(path):
        n += sum(1 for f in files if script_kind(f)[1])
    return n


def main():
    out_path = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    if not os.path.isdir(SRC):
        sys.exit(f"src 폴더가 없습니다: {SRC}")

    parts = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
             'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">']
    for e in sorted(os.listdir(SRC)):
        full = os.path.join(SRC, e)
        if not os.path.isdir(full):
            continue
        if e not in SERVICES:
            print(f"경고: src/{e} 는 알려진 서비스 이름이 아니라서 건너뜁니다")
            continue
        parts.append(build_dir(full, e, e)(1))
    parts.append("</roblox>")
    xml_text = "\n".join(parts) + "\n"

    ET.fromstring(xml_text.encode("utf-8"))  # 잘못된 XML이면 여기서 예외

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml_text)
    print(f"완료: {out_path}  (스크립트 {count_scripts(SRC)}개)")


if __name__ == "__main__":
    main()
