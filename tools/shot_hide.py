"""Hide / show the Halo v2 layout helpers while taking judge photos (이미지 생성 3, 10/13; 최종 검수: photos show only what is
really placed). HIDE moves Workspace.HaloV2.Props.StandIn / .Placeholder to ServerStorage._ShotHide and disables every
enabled BillboardGui (marked ShotHidden); SHOW puts them back. Import HIDE / SHOW (Luau strings) or run
`STUDIO_NAME=WorldKit py tools/shot_hide.py show` to restore after a crash."""
import os
import sys

GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
HIDE = GUARD + '''local SS = game:GetService("ServerStorage")
local H = SS:FindFirstChild("_ShotHide") or Instance.new("Folder"); H.Name = "_ShotHide"; H.Parent = SS
local n = 0
for _, nm in {"StandIn", "Placeholder"} do local f = workspace.HaloV2.Props:FindFirstChild(nm); if f then f.Parent = H; n += 1 end end
local b = 0
for _, d in workspace:GetDescendants() do if d:IsA("BillboardGui") and d.Enabled then d.Enabled = false; d:SetAttribute("ShotHidden", true); b += 1 end end
return "hidden folders " .. n .. " billboards " .. b'''
SHOW = GUARD + '''local SS = game:GetService("ServerStorage")
local H = SS:FindFirstChild("_ShotHide")
local n = 0
if H then for _, f in H:GetChildren() do f.Parent = workspace.HaloV2.Props; n += 1 end; H:Destroy() end
local b = 0
for _, d in workspace:GetDescendants() do if d:IsA("BillboardGui") and d:GetAttribute("ShotHidden") then d.Enabled = true; d:SetAttribute("ShotHidden", nil); b += 1 end end
return "shown folders " .. n .. " billboards " .. b'''
if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from studio_mcp import Client
    c = Client()
    c.start()
    r = c.call("execute_luau", {"code": SHOW if sys.argv[1] == "show" else HIDE, "datamodel_type": "Edit"})
    print("".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text"))
