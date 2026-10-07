"""Map v2 (SPEC A23-53) Studio steps for the open game place, Edit mode only (게임성 개발 1).

  py tools/map_v2_apply.py survey          read-only: what workspace.Map / kit folders hold, terrain cells
  py tools/map_v2_apply.py terrain         tools/preview_map.lua in "terrain" mode (land, water, roads, pass mountains,
                                           zone markers, walls, bridges, PvP borders, gates moved; the rest kept,
                                           replaced old pieces go to ServerStorage.MapV1Backup)
  py tools/map_v2_apply.py move            tools/map_v2_move.lua dry run (lists what would move)
  py tools/map_v2_apply.py move --apply    ... and moves it (towns 10 studs out + castles to the island ends, field decor
                                           to the same share of the v2 land, the Halloween decor to the backup)
  py tools/map_v2_apply.py build           require(ServerScriptService.MapBuilder).Build() in Edit (rebuilds the
                                           Halloween fields at the v2 spots, moves pads / gates / zone markers / walls)

Order for the real place (P2): sync the v2 sources first (Config must already say v2), then terrain -> move (dry, then
--apply) -> build -> photos -> Play checks -> File > Save to File As build/GoodEvil.rbxlx. "full" mode of preview_map
wipes workspace.Map and is never run here. Every step refuses to run unless Studio is in Edit (never stops a Play).
Pick the window with STUDIO_ID=<id prefix> when two Studio windows match (tools/studio_mcp.py).
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from studio_mcp import Client  # noqa: E402

SURVEY = r'''
local out = {}
local function add(s) table.insert(out, s) end
local function fmt(v) return string.format("(%d,%d)", math.floor(v.X + 0.5), math.floor(v.Z + 0.5)) end
local function posOf(inst)
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then local ok, cf = pcall(inst.GetPivot, inst); if ok then return cf.Position end end
	return nil
end
local map = workspace:FindFirstChild("Map")
if map then
	for _, f in map:GetChildren() do
		local names, seen = {}, {}
		for _, k in f:GetChildren() do
			if not seen[k.Name] then
				seen[k.Name] = 0
				table.insert(names, k.Name)
			end
			seen[k.Name] += 1
		end
		local parts = {}
		for i, n in names do
			if i > 40 then table.insert(parts, "..."); break end
			local inst = f:FindFirstChild(n)
			local p = inst and posOf(inst)
			table.insert(parts, n .. (seen[n] > 1 and ("x" .. seen[n]) or "") .. (p and fmt(p) or ""))
		end
		add(f.Name .. " [" .. #f:GetChildren() .. "]: " .. table.concat(parts, ", "))
	end
else
	add("no workspace.Map")
end
for _, c in workspace:GetChildren() do
	if c.Name ~= "Map" and not c:IsA("Terrain") and not c:IsA("Camera") then
		local p = posOf(c)
		add("workspace/" .. c.Name .. " [" .. c.ClassName .. ", " .. #c:GetChildren() .. "]" .. (p and fmt(p) or ""))
	end
end
local ok, cells = pcall(function() return workspace.Terrain:CountCells() end)
add("terrain cells: " .. tostring(ok and cells))
local b = game:GetService("ServerStorage"):FindFirstChild("MapV1Backup")
add("MapV1Backup: " .. tostring(b and #b:GetDescendants() or "none"))
return table.concat(out, "\n")
'''

BUILD = r'''
local mb = require(game:GetService("ServerScriptService"):WaitForChild("MapBuilder"))
local ok, res = pcall(mb.Build)
return ok and "MapBuilder.Build ok" or ("MapBuilder.Build failed: " .. tostring(res))
'''


def text_of(res: dict) -> str:
    return "".join(p.get("text", "") for p in res.get("content", []))


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = sys.argv[1:]
    if not args or args[0] not in ("survey", "terrain", "move", "build"):
        print(__doc__)
        return 2
    step = args[0]
    if step == "terrain":
        code = (ROOT / "tools/preview_map.lua").read_text(encoding="utf-8").replace('"__MODE__"', '"terrain"', 1)
    elif step == "move":
        mode = "apply" if "--apply" in args else "dry"
        code = (ROOT / "tools/map_v2_move.lua").read_text(encoding="utf-8").replace('"__MODE__"', f'"{mode}"', 1)
    elif step == "build":
        code = BUILD
    else:
        code = SURVEY
    c = Client()
    c.start()
    try:
        state = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in state:
            print("Studio is not in Edit mode - nothing done:\n" + state)
            return 1
        res = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
        print(text_of(res))
    finally:
        c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
