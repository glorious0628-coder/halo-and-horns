"""Map v2 (SPEC A23-53) Studio steps for the open game place, Edit mode only (게임성 개발 1).

  py tools/map_v2_apply.py survey          read-only: what workspace.Map / kit folders hold, terrain cells
  py tools/map_v2_apply.py terrain         tools/preview_map.lua in "terrain" mode (land, water, roads, pass mountains,
                                           zone markers, walls, bridges, PvP borders, gates moved; the rest kept,
                                           replaced old pieces go to ServerStorage.MapV1Backup)
  py tools/map_v2_apply.py move            tools/map_v2_move.lua dry run (lists what would move)
  py tools/map_v2_apply.py move --apply    ... and moves it (towns 10 studs out + castles to the island ends, field decor
                                           to the same share of the v2 land, the Halloween decor to the backup)
  py tools/map_v2_apply.py settle          after terrain: every piece the mover noted (MapV2Ground) goes back to the same
                                           height over the NEW ground (a tree from a v1 hill comes down, clouds stay up)
  py tools/map_v2_apply.py build           require(ServerScriptService.MapBuilder).Build() in Edit (rebuilds the
                                           Halloween fields at the v2 spots, moves pads / gates / zone markers / walls)
  py tools/map_v2_apply.py kits            tools/worldkit/meadow_kit_swap.luau (검수): Decor.MeadowKit again from the
                                           moved spots, on the new ground

Order for the real place (P2, A23-74): Save to File As build/GoodEvil_before_v2.rbxlx, sync the v2 sources (Config must
already say v2), then survey -> move (dry) -> move --apply (notes the old ground heights) -> terrain -> settle -> build ->
kits -> survey -> photos -> Play checks -> File > Save to File As build/GoodEvil.rbxlx. "full" mode of preview_map
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

SETTLE = r'''
local RAY = RaycastParams.new()
RAY.FilterType = Enum.RaycastFilterType.Include
RAY.FilterDescendantsInstances = { workspace.Terrain }
RAY.IgnoreWater = false
local function posOf(inst)
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then local ok, cf = pcall(inst.GetPivot, inst); if ok then return cf.Position end end
	return nil
end
local function bottomOf(inst)
	if inst:IsA("BasePart") then return inst.Position.Y - inst.Size.Y / 2 end
	if inst:IsA("Model") then local ok, cf, size = pcall(inst.GetBoundingBox, inst); if ok then return cf.Position.Y - size.Y / 2 end end
	return nil
end
local moved, kept, water, big = 0, 0, 0, {}
for _, root in { workspace:FindFirstChild("Map"), game:GetService("ServerStorage"):FindFirstChild("MeadowPrimitiveBackup") } do
	for _, inst in (root and root:GetDescendants() or {}) do
		local off = inst:GetAttribute("MapV2Ground")
		if type(off) == "number" and not inst:GetAttribute("MapV2Settled") then
			local p, b = posOf(inst), bottomOf(inst)
			local hit = p and workspace:Raycast(Vector3.new(p.X, 400, p.Z), Vector3.new(0, -800, 0), RAY)
			if not (hit and b) or hit.Material == Enum.Material.Water then
				water += 1
			else
				local dy = hit.Position.Y + off - b
				if math.abs(dy) > 60 then
					table.insert(big, string.format("%s %.0f", inst:GetFullName(), dy))
				else
					if math.abs(dy) > 0.05 then
						if inst:IsA("BasePart") then inst.CFrame += Vector3.new(0, dy, 0) else inst:PivotTo(inst:GetPivot() + Vector3.new(0, dy, 0)) end
						moved += 1
					else
						kept += 1
					end
					inst:SetAttribute("MapV2Settled", true)
				end
			end
		end
	end
end
return string.format("settle: moved %d, already right %d, over water / no ground %d (kept), too far %d%s", moved, kept, water, #big,
	#big > 0 and (": " .. table.concat(big, "; ", 1, math.min(#big, 8))) or "")
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
    if not args or args[0] not in ("survey", "terrain", "move", "settle", "build", "kits"):
        print(__doc__)
        return 2
    step = args[0]
    if step == "terrain":
        # the code line itself (the file's header comment also says "__MODE__": a plain first-match replace hit the comment)
        code = (ROOT / "tools/preview_map.lua").read_text(encoding="utf-8").replace('local MODE = "__MODE__"',
                                                                                   'local MODE = "terrain"', 1)
    elif step == "move":
        mode = "apply" if "--apply" in args else "dry"
        code = (ROOT / "tools/map_v2_move.lua").read_text(encoding="utf-8").replace('local MODE = "__MODE__"',
                                                                                    f'local MODE = "{mode}"', 1)
    elif step == "settle":
        code = SETTLE
    elif step == "kits":
        code = (ROOT / "tools/worldkit/meadow_kit_swap.luau").read_text(encoding="utf-8")
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
