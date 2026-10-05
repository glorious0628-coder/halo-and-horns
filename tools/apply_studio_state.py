"""Re-apply the Studio-only state that lives outside src/ (run after opening the cloud place in Studio, Edit mode).

  py tools/apply_studio_state.py          # apply (idempotent)

Why: the private published place (81671223175574) opened from the cloud may not contain changes made in an earlier
Studio session (File > Save to File only writes build/GoodEvil.rbxlx). This script makes that state reproducible:
  1. ServerStorage.CustomModels: rigged Tripo monsters (Goblin, GoblinBrute, Skeleton, SkeletonKnight) inserted from
     the user's own inventory Model assets (bulk-import uploads, 41 bones each). The Skeleton GLB faces +X (others +Z),
     so its PrimaryPart.PivotOffset gets +90 degrees around Y. Old static models move to ServerStorage.MonsterModelArchive.
  2. ServerStorage Costume* folders are deleted (A23-5 chibi costume removal).
  3. The anvil sign reads "대장간 · 장인 길드" (tools/preview_map.lua).
Safe to run repeatedly: a model that is already rigged is left alone. Studio must be in Edit mode.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402

RIGGED = {  # inventory Model asset id -> CustomModels name (creator: the user's new account)
    "133553279214842": "Goblin",
    "115363822910954": "GoblinBrute",
    "107657905498432": "Skeleton",
    "122157877645648": "SkeletonKnight",
}

PREP = '''local SS=game:GetService("ServerStorage")
local f=SS:FindFirstChild("ImportCheck") if f then f:Destroy() end
f=Instance.new("Folder") f.Name="ImportCheck" f.Parent=SS
local need={}
for id,kind in game:GetService("HttpService"):JSONDecode(%s) do
	local m=SS.CustomModels:FindFirstChild(kind)
	local bones=0
	if m then for _,d in m:GetDescendants() do if d:IsA("Bone") then bones+=1 end end end
	if bones<10 then table.insert(need,id) end
end
return game:GetService("HttpService"):JSONEncode(need)'''

SWAP = '''local SS=game:GetService("ServerStorage")
local CM=SS:FindFirstChild("CustomModels")
local AR=SS:FindFirstChild("MonsterModelArchive") or Instance.new("Folder")
AR.Name="MonsterModelArchive" AR.Parent=SS
local IC=SS:FindFirstChild("ImportCheck")
local out={}
for id,kind in game:GetService("HttpService"):JSONDecode(%s) do
	local h=IC and IC:FindFirstChild("S_"..id)
	local scene=h and (h:FindFirstChild("Scene") or h)
	if scene and scene:IsA("Model") then
		local old=CM:FindFirstChild(kind)
		if old then
			local nm=kind.."_static"
			local i=1
			while AR:FindFirstChild(nm) do i+=1 nm=kind.."_static"..i end
			old.Name=nm old.Parent=AR
		end
		local bones=0
		for _,d in scene:GetDescendants() do if d:IsA("Bone") then d.Transform=CFrame.identity bones+=1 end end
		pcall(scene.ScaleTo,scene,1)
		scene:SetAttribute("Rigged","Tripo spec 2026-10-06 (MonsterMotion clips "..kind.."_*)")
		if kind=="Skeleton" and scene.PrimaryPart then
			scene.PrimaryPart.PivotOffset=CFrame.Angles(0,math.rad(90),0)
			scene:SetAttribute("FrontFix","PrimaryPart.PivotOffset +90 Y (GLB faces +X, others +Z)")
		end
		scene.Name=kind
		scene.Parent=CM
		table.insert(out,kind.."="..bones)
	end
end
if IC then IC:Destroy() end
local removed=0
for _,c in SS:GetChildren() do if string.sub(c.Name,1,7)=="Costume" then c:Destroy() removed+=1 end end
local sign="no anvil"
local lm=workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Landmarks")
local anvil=lm and lm:FindFirstChild("ArtisanGuild") and lm.ArtisanGuild:FindFirstChild("Anvil")
local bb=anvil and anvil:FindFirstChildWhichIsA("BillboardGui")
local lbl=bb and bb:FindFirstChildWhichIsA("TextLabel")
if lbl then lbl.Text="대장간 · 장인 길드" sign=lbl.Text end
return "swapped "..table.concat(out,",").." | costume folders removed "..removed.." | sign "..sign'''


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def main():
    c = Client()
    try:
        c.start()
        state = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in state:
            sys.exit("Studio must be in Edit mode: " + state[:200])
        payload = json.dumps(json.dumps(RIGGED))
        need = json.loads(text_of(c.call("execute_luau", {"code": PREP % payload, "datamodel_type": "Edit"})) or "[]")
        for asset_id in need:
            r = c.call("insert_asset", {"assetId": asset_id, "assetName": "S_" + asset_id, "assetType": "Model",
                                        "parentPath": "game.ServerStorage.ImportCheck"})
            print("insert", asset_id, RIGGED[asset_id], "error" if r.get("isError") else "ok")
        todo = {k: v for k, v in RIGGED.items() if k in need}
        print(text_of(c.call("execute_luau", {"code": SWAP % json.dumps(json.dumps(todo)), "datamodel_type": "Edit"})))
    finally:
        c.close()


if __name__ == "__main__":
    main()
