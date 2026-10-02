"""
src/ 폴더의 스크립트를 열려 있는 Roblox Studio 창에 그대로 밀어 넣는다 (Studio MCP 사용).

  py tools/sync_to_studio.py                    -> 동기화 (플레이 중이면 정지 후)
  py tools/sync_to_studio.py --skip-if-playing  -> 플레이 중이면 아무것도 안 함 (자동 동기화용)

- 대상 창: 이름에 STUDIO_NAME(기본 "GoodEvil")이 들어간 스튜디오
- 내용이 바뀐 스크립트만 지우고 다시 만든다 (스크립트 생성은 MCP multi_edit 도구로만 가능)
- 관리 대상(ServerScriptService, ReplicatedStorage, StarterPlayerScripts, StarterCharacterScripts) 안에서
  src에 없는 스크립트와 빈 폴더는 지운다
- 플레이 중이면 먼저 정지한다
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402
from build_place import SRC, SERVICES, script_kind, read_source  # noqa: E402

ROOTS = [
    ("ServerScriptService",),
    ("ReplicatedStorage",),
    ("StarterPlayer", "StarterPlayerScripts"),
    ("StarterPlayer", "StarterCharacterScripts"),
]


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    # 여는 괄호 바로 뒤 줄바꿈은 Lua가 버리므로 하나 붙여 둔다 (줄 번호 유지)
    return f"[{eq}[\n{text}]{eq}]"


def collect():
    """{ "ServerScriptService.Main": ("Script", source), ... }"""
    items = {}

    def walk(path, parts):
        for e in sorted(os.listdir(path)):
            full = os.path.join(path, e)
            if os.path.isdir(full):
                walk(full, parts + [e])
            else:
                base, cls = script_kind(e)
                if cls is None:
                    continue
                if base == "init":
                    sys.exit(f"init 스크립트는 지원하지 않습니다: {full}")
                items[".".join(parts + [base])] = (cls, read_source(full))

    for svc in sorted(os.listdir(SRC)):
        if svc in SERVICES and os.path.isdir(os.path.join(SRC, svc)):
            walk(os.path.join(SRC, svc), [svc])
    return items


READ_LUA = """
local HttpService = game:GetService("HttpService")
local roots = %s
local function hash(src)
    src = string.gsub(src, string.char(13), "")
    local h = 0
    for i = 1, #src do
        h = (h * 31 + string.byte(src, i)) %% 2147483647
    end
    return #src .. ":" .. h
end
local out = {}
for _, r in ipairs(roots) do
    local node = game:GetService(r[1])
    for i = 2, #r do node = node and node:FindFirstChild(r[i]) end
    if node then
        for _, d in ipairs(node:GetDescendants()) do
            if d:IsA("LuaSourceContainer") then
                local parts = {}
                local n = d
                while n and n ~= game do table.insert(parts, 1, n.Name); n = n.Parent end
                out[table.concat(parts, ".")] = { c = d.ClassName, h = hash(d.Source) }
            end
        end
    end
end
return HttpService:JSONEncode(out)
"""


def src_hash(src):
    b = src.replace("\r", "").encode("utf-8")
    h = 0
    for x in b:
        h = (h * 31 + x) % 2147483647
    return f"{len(b)}:{h}"


DELETE_LUA = """
local paths = %s
local roots = %s
local n = 0
for _, p in ipairs(paths) do
    local node = game
    for name in string.gmatch(p, "[^%%.]+") do
        node = node and node:FindFirstChild(name)
    end
    if node and node ~= game then node:Destroy(); n += 1 end
end
-- 빈 폴더 정리
local function prune(inst)
    for _, ch in ipairs(inst:GetChildren()) do prune(ch) end
    if inst.ClassName == "Folder" and #inst:GetChildren() == 0 then inst:Destroy() end
end
for _, r in ipairs(roots) do
    local node = game:GetService(r[1])
    for i = 2, #r do node = node and node:FindFirstChild(r[i]) end
    if node then for _, ch in ipairs(node:GetChildren()) do prune(ch) end end
end
return "deleted " .. n
"""


def lua_list(values):
    return "{" + ", ".join(json.dumps(v, ensure_ascii=False) for v in values) + "}"


def lua_roots():
    return "{" + ", ".join(lua_list(r) for r in ROOTS) + "}"


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    want = collect()
    c = Client()
    try:
        c.start()
        state = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in state:
            if "--skip-if-playing" in sys.argv:
                print("플레이 중이라 동기화를 건너뜀")
                return
            c.call("start_stop_play", {"is_start": False})

        res = c.call("execute_luau", {"code": READ_LUA % lua_roots(), "datamodel_type": "Edit"})
        if res.get("isError"):
            sys.exit("스튜디오 읽기 실패: " + text_of(res))
        have = json.loads(text_of(res) or "{}")
        if isinstance(have, list):  # 빈 테이블은 [] 로 인코딩된다
            have = {}

        to_delete = [p for p in have if p not in want]
        to_write = []
        for p, (cls, src) in want.items():
            cur = have.get(p)
            if cur and cur["c"] == cls and cur["h"] == src_hash(src):
                continue
            if cur:
                to_delete.append(p)
            to_write.append(p)

        if True:  # 지울 게 없어도 빈 폴더 정리는 한다
            res = c.call("execute_luau", {
                "code": DELETE_LUA % (lua_list(to_delete), lua_roots()),
                "datamodel_type": "Edit",
            })
            if res.get("isError"):
                sys.exit("스튜디오 정리 실패: " + text_of(res))

        for p in to_write:
            cls, src = want[p]
            res = c.call("multi_edit", {
                "file_path": "game." + p,
                "className": cls,
                "datamodel_type": "Edit",
                "edits": [{"old_string": "", "new_string": src if src else "-- empty\n"}],
            })
            if res.get("isError"):
                sys.exit(f"{p} 생성 실패: " + text_of(res))
        removed = [p for p in to_delete if p not in to_write]
        print(f"동기화 완료: 새로 쓴 스크립트 {len(to_write)}개, 지운 스크립트 {len(removed)}개, 그대로 {len(want) - len(to_write)}개")
    finally:
        c.close()


if __name__ == "__main__":
    main()
