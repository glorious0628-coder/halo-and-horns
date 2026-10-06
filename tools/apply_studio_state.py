"""Re-apply the Studio-only state that lives outside src/ (run after opening the cloud place in Studio, Edit mode).

  py tools/apply_studio_state.py          # apply (idempotent)

Why: the private published place (81671223175574) opened from the cloud may not contain changes made in an earlier
Studio session (File > Save to File only writes build/GoodEvil.rbxlx). This script makes that state reproducible:
  1. ServerStorage.CustomModels: Tripo monsters inserted from the user's own inventory Model assets (bulk-import
     uploads): rigged Goblin, GoblinBrute, Skeleton, SkeletonKnight, BatGoblin (41 bones each) and, since 2026-10-05
     evening, the static cube Slime, PetBabySlime, PumpkinSlime, LittleGhost and PumpkinKing (GPT image 2.5 Sunburst
     concepts). BigSlime = the cube Slime with its body hue-shifted to blue (art/models/tripo/BigSlimeCube_tex_blue.png,
     uploaded as BIG_SLIME_TEXTURE). FRONT_FIX yaws (PrimaryPart.PivotOffset) are applied to every model on every run.
     A replaced model is destroyed (since 2026-10-06; it used to move to ServerStorage.MonsterModelArchive, whose old
     entries' SurfaceAppearance TexturePacks belonged to the old account). Each placed model carries AssetId.
  2. ServerStorage Costume* folders are deleted (A23-5 chibi costume removal), and so is an old
     ServerStorage.MonsterModelArchive (its old-account TexturePacks printed "Failed to fetch TexturePack" and asset
     access warnings on every Play of the cloud place, 2026-10-06).
  3. The anvil sign reads "대장간 · 장인 길드" (tools/preview_map.lua).
  4. The world look: tools/apply_surface_materials.lua (new ground / tree tiles) then tools/apply_world_look.lua (leaf
     and road colours, the Neutral 'B' lighting, A23-36 big-sign removal, props off the pumpkin-field path).
Safe to run repeatedly: a model that is already rigged is left alone. Studio must be in Edit mode.
After a big apply, File > Save to File As build/GoodEvil.rbxlx at once (the cloud place keeps nothing of this).
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
    "83990146086555": "BatGoblin",  # MonsterBatGoblin_Idle.glb (rig + mesh), 2026-10-05
}
STATIC = {  # no bones: the client WOBBLE layer moves them (slimes hop / squash, others bob)
    "133399506433715": "Slime",  # MonsterSlimeCube_raw.glb (replaces the round slime, user 2026-10-05)
    "77411666437725": "PetBabySlime",
    "111244961270470": "PumpkinSlime",
    "77132701345894": "LittleGhost",
    "71855842778142": "PumpkinKing",
    "84018800442559": "GhostMinion",  # A23-45 MonsterGhostMinion_raw.glb (Studio import 2026-10-06, Upload to Roblox)
    "111999674841692": "GhostKing",  # A23-45 MonsterGhostKing_raw.glb (same import)
}
BIG_SLIME_TEXTURE = "rbxassetid://139511730966494"
# GLBs whose front is not the importer's front: PrimaryPart.PivotOffset yaw in degrees. Applied to EVERY model in
# ServerStorage.CustomModels on every run (unlisted = 0), so a re-run always ends in the same state (review C-6).
# Checked in Play 2026-10-06 (camera on the root's LookVector side, then the 4 sides): the Sunburst/Tripo static GLBs and
# the BatGoblin rig face +90 (BatGoblin was 180 = facing sideways; Slime/BigSlime/LittleGhost had no fix = face on the
# side). Goblin, GoblinBrute, SkeletonKnight face front with 0. PetBabySlime is not in the game yet: check it with PET-3.
FRONT_FIX = {"Skeleton": 90, "PumpkinSlime": 90, "PumpkinKing": 90, "BatGoblin": 90,
             "Slime": 90, "BigSlime": 90, "LittleGhost": 90, "GhostMinion": 90, "GhostKing": 90}
MODELS = {**RIGGED, **STATIC}

PREP = '''local SS=game:GetService("ServerStorage")
local f=SS:FindFirstChild("ImportCheck") if f then f:Destroy() end
f=Instance.new("Folder") f.Name="ImportCheck" f.Parent=SS
local need={}
local rigged=game:GetService("HttpService"):JSONDecode(%s)
for id,kind in game:GetService("HttpService"):JSONDecode(%s) do
	local m=SS.CustomModels:FindFirstChild(kind)
	local bones=0
	if m then for _,d in m:GetDescendants() do if d:IsA("Bone") then bones+=1 end end end
	if rigged[id] then
		if bones<10 then table.insert(need,id) end
	elseif not m or tostring(m:GetAttribute("AssetId"))~=id then
		table.insert(need,id)
	end
end
return game:GetService("HttpService"):JSONEncode(need)'''

SWAP = '''local SS=game:GetService("ServerStorage")
local CM=SS:FindFirstChild("CustomModels")
local IC=SS:FindFirstChild("ImportCheck")
local FRONT=game:GetService("HttpService"):JSONDecode(%s)
local out={}
for id,kind in game:GetService("HttpService"):JSONDecode(%s) do
	local h=IC and IC:FindFirstChild("S_"..id)
	local scene=h and (h:FindFirstChild("Scene") or h:FindFirstChildWhichIsA("Model") or h)
	if scene and scene:IsA("Model") then
		local old=CM:FindFirstChild(kind)
		if old then old:Destroy() end -- review 2026-10-06: not archived (old SurfaceAppearance TexturePacks warned)
		local bones=0
		for _,d in scene:GetDescendants() do if d:IsA("Bone") then d.Transform=CFrame.identity bones+=1 end end
		pcall(scene.ScaleTo,scene,1)
		local mp=scene:FindFirstChildWhichIsA("MeshPart",true)
		if not scene.PrimaryPart and mp then scene.PrimaryPart=mp end
		scene:SetAttribute("AssetId",id)
		if bones>0 then scene:SetAttribute("Rigged","Tripo spec 2026-10-06 (MonsterMotion clips "..kind.."_*)") end
		local front=FRONT[kind]
		if front and scene.PrimaryPart then
			scene.PrimaryPart.PivotOffset=CFrame.Angles(0,math.rad(front),0)
			scene:SetAttribute("FrontFix","PrimaryPart.PivotOffset "..front.." Y (the GLB front differs)")
		end
		scene.Name=kind
		scene.Parent=CM
		table.insert(out,kind.."="..bones)
	end
end
if IC then IC:Destroy() end
-- king slime: the cube slime body with the blue texture (rebuilt whenever the slime is new or the texture differs)
local slime=CM:FindFirstChild("Slime")
local big=CM:FindFirstChild("BigSlime")
local bigMesh=big and big:FindFirstChildWhichIsA("MeshPart",true)
if slime and slime:GetAttribute("AssetId") and (not bigMesh or bigMesh.TextureID~=%s) then
	if big then big:Destroy() end
	big=slime:Clone()
	local mp=big:FindFirstChildWhichIsA("MeshPart",true)
	for _,sa in mp:GetChildren() do if sa:IsA("SurfaceAppearance") then sa:Destroy() end end
	mp.TextureID=%s
	big:SetAttribute("AssetId",nil)
	big:SetAttribute("Source","Slime cube, body hue-shifted to blue (art/models/tripo/BigSlimeCube_tex_blue.png)")
	big.Name="BigSlime"
	big.Parent=CM
	table.insert(out,"BigSlime=blue")
end
-- every model, every run (idempotent): front yaw from FRONT (unlisted = 0)
local fronts={}
for _,m in CM:GetChildren() do
	local pp=m:IsA("Model") and m.PrimaryPart
	if pp then
		local front=FRONT[m.Name] or 0
		local want=CFrame.Angles(0,math.rad(front),0)
		if not pp.PivotOffset:FuzzyEq(want,1e-4) then
			pp.PivotOffset=want
			table.insert(fronts,m.Name.."="..front)
		end
		if front~=0 then
			m:SetAttribute("FrontFix","PrimaryPart.PivotOffset "..front.." Y (the GLB front differs)")
		else
			m:SetAttribute("FrontFix",nil)
		end
	end
end
local removed=0
for _,c in SS:GetChildren() do if string.sub(c.Name,1,7)=="Costume" then c:Destroy() removed+=1 end end
local archive=SS:FindFirstChild("MonsterModelArchive")
if archive then archive:Destroy() removed+=1 end
local sign="no anvil"
local lm=workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Landmarks")
local anvil=lm and lm:FindFirstChild("ArtisanGuild") and lm.ArtisanGuild:FindFirstChild("Anvil")
local bb=anvil and anvil:FindFirstChildWhichIsA("BillboardGui")
local lbl=bb and bb:FindFirstChildWhichIsA("TextLabel")
if lbl then lbl.Text="대장간 · 장인 길드" sign=lbl.Text end
return "swapped "..table.concat(out,",").." | front fixed "..table.concat(fronts,",").." | costume folders removed "..removed.." | sign "..sign'''


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def main():
    c = Client()
    try:
        c.start()
        state = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in state:
            sys.exit("Studio must be in Edit mode: " + state[:200])
        prep = PREP % (json.dumps(json.dumps(RIGGED)), json.dumps(json.dumps(MODELS)))
        need = json.loads(text_of(c.call("execute_luau", {"code": prep, "datamodel_type": "Edit"})) or "[]")
        for asset_id in need:
            r = c.call("insert_asset", {"assetId": asset_id, "assetName": "S_" + asset_id, "assetType": "Model",
                                        "parentPath": "game.ServerStorage.ImportCheck"})
            print("insert", asset_id, MODELS[asset_id], "error" if r.get("isError") else "ok")
        todo = {k: v for k, v in MODELS.items() if k in need}
        tex = json.dumps(BIG_SLIME_TEXTURE)
        swap = SWAP % (json.dumps(json.dumps(FRONT_FIX)), json.dumps(json.dumps(todo)), tex, tex)
        print(text_of(c.call("execute_luau", {"code": swap, "datamodel_type": "Edit"})))
        # 4. the world look (A23-29/30 E): ground tiles (image dev's tool, run as is), then leaves / roads / lighting /
        # A23-36 sign removal / pumpkin-path props (tools/apply_world_look.lua). Both are idempotent.
        for lua in ("apply_surface_materials.lua", "apply_world_look.lua"):
            with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), lua), encoding="utf-8") as f:
                res = c.call("execute_luau", {"code": f.read(), "datamodel_type": "Edit"})
            print(lua + ":", ("ERROR " if res.get("isError") else "") + text_of(res)[:400])
        # 5. the crossroads 3D prop kit (A23-33, 52ca1db): models from the user's inventory + contract-safe placement
        import apply_crossroads_kit  # noqa: E402
        apply_crossroads_kit.run(c)
    finally:
        c.close()


if __name__ == "__main__":
    main()
