"""The town people's bodies (TownNpcs.luau, built by MapBuilder.Build) (zone_check_halo #22 / #24 / #25 / #26 / #27 / #30 / #34,
검수 2026-10-10; 게임성 개발 3), offline.

Runs the CURRENT TownNpcs module with the CURRENT Config (Config.TownNpcs: Bright, Sir Gleam, four townsfolk, the Halo potion seller
(off until ShopService accepts more than one seller), Otto behind the anvil) on tools/fixtures/dev2_kit.luau with
tools/fixtures/town_npcs_offline.luau and the installed official Luau CLI. Doubles: the Instance tree, Players:
CreateHumanoidModelFromDescription (the real call yields), a workspace ray (the ground height), the CollectionService tags and the
Crossroads anvil. Static checks: MapBuilder calls the module once after the potion seller, the sync list needs nothing, nothing
sold or paid, no Hangul outside comments. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_town_npcs.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev3_town_npcs_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "TOWNNPCS_SOURCE": SSS / "TownNpcs.luau",
}
C, T = "CONFIG_SOURCE", "TOWNNPCS_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- Config
    ("Config: Bright is not a story NPC", C, 'Id = "Bright", Name = "Npc_Bright", Story = "Bright",', 'Id = "Bright", Name = "Npc_Bright",'),
    ("Config: Bright has another NpcId", C, 'Name = "Npc_Bright", Story = "Bright",', 'Name = "Npc_Bright", Story = "Brite",'),
    ("Config: Bright outside the town", C, "At = Vector3.new(18, 0, -452), Look = Vector3.new(0, 0, -420),", "At = Vector3.new(18, 0, -252), Look = Vector3.new(0, 0, -420),"),
    ("Config: the prompt range is 40", C, "\tPromptDistance = 10,", "\tPromptDistance = 40,"),
    ("Config: the seller is switched on", C, 'Label = "Potion Seller", Enabled = false,', 'Label = "Potion Seller",'),
    ("Config: a fifth townsperson", C, '\t\t{ Id = "PotionHalo",', '\t\t{ Id = "Folk5", Name = "Npc_Folk5", Folk = "Folk5", At = Vector3.new(20, 0, -570), Look = Vector3.new(0, 0, -565) },\n\t\t{ Id = "PotionHalo",'),
    ("Config: a duplicate model name", C, 'Id = "Folk2", Name = "Npc_Folk2",', 'Id = "Folk2", Name = "Npc_Folk1",'),
    ("Config: Otto is not behind the anvil", C, 'Anvil = true, Behind = 4,', 'Anvil = true, Behind = -4,'),
    ("Config: off", C, "Config.TownNpcs = {\n\tEnabled = true,", "Config.TownNpcs = {\n\tEnabled = false,"),
    ("Config: the ray is shorter", C, "\tRayTop = 150, -- the ground ray", "\tRayTop = 50, -- the ground ray"),
    # --- TownNpcs
    ("ground: any surface is ground", T, "if typeof(hit.Normal) ~= \"Vector3\" or hit.Normal.Y < 0.7 then return nil end", "if typeof(hit.Normal) ~= \"Vector3\" then return nil end"),
    ("ground: only a flat surface", T, "hit.Normal.Y < 0.7 then return nil end", "hit.Normal.Y < 0.9 then return nil end"),
    ("ground: a miss is the zone's height", T, "if not ok or not hit then return nil end", "if not ok or not hit then return 0 end"),
    ("ground: characters are not excluded", T, "\t\t\tif p.Character then table.insert(list, p.Character) end\n", ""),
    ("ground: the folder is not excluded", T, "\tfor _, inst in ignore or {} do table.insert(list, inst) end\n", ""),
    ("ground: the ray points up", T, "Vector3.new(0, -(top + num(C.RayDepth, 60)), 0)", "Vector3.new(0, (top + num(C.RayDepth, 60)), 0)"),
    ("spot: a NaN spot passes", T, "if typeof(at) ~= \"Vector3\" or not finite(at.X) or not finite(at.Z) or", "if typeof(at) ~= \"Vector3\" or"),
    ("spot: a far spot passes", T, " or math.abs(at.X) > num(C.MaxCoord, 3000) or math.abs(at.Z) > num(C.MaxCoord, 3000) then", " then"),
    ("spot: Otto in front of the anvil", T, "return { X = anvil.Position.X + dx / len * back, Z = anvil.Position.Z + dz / len * back,", "return { X = anvil.Position.X - dx / len * back, Z = anvil.Position.Z - dz / len * back,"),
    ("spot: Otto looks away", T, "LookX = center.X, LookZ = center.Z }", "LookX = anvil.Position.X * 2, LookZ = anvil.Position.Z * 2 }"),
    ("spot: no anvil still builds Otto", T, "\t\tlocal anvil = findAnvil()\n\t\tif not anvil then return nil end\n", "\t\tlocal anvil = findAnvil() or { Position = Vector3.new(30, 0, 30) }\n"),
    ("spot: a part named Anvil anywhere", T, "if anvil and anvil:IsA(\"BasePart\") then return anvil end", "if anvil then return anvil end"),
    ("body: the head colour is the torso's", T, "\tdesc.HeadColor = head\n", "\tdesc.HeadColor = torso\n"),
    ("body: bare arms", T, "\tdesc.LeftArmColor, desc.RightArmColor = torso, torso\n", "\tdesc.LeftArmColor, desc.RightArmColor = head, head\n"),
    ("body: no trousers colour", T, "\tdesc.LeftLegColor, desc.RightLegColor = legs, legs\n", ""),
    ("body: scripts kept", T, "\t\t\tif child:IsA(\"LuaSourceContainer\") then\n\t\t\t\tchild:Destroy()\n\t\t\telseif child:IsA(\"BasePart\") then", "\t\t\tif child:IsA(\"BasePart\") then"),
    ("body: parts not anchored", T, "\t\t\t\tchild.Anchored = true\n", ""),
    ("body: parts collide", T, "child.CanCollide, child.CanTouch, child.CanQuery = false, false, false", "child.CanCollide, child.CanTouch, child.CanQuery = true, true, true"),
    ("body: the humanoid walks", T, "humanoid.WalkSpeed, humanoid.JumpPower, humanoid.AutoRotate = 0, 0, false", "humanoid.WalkSpeed, humanoid.JumpPower, humanoid.AutoRotate = 16, 50, true"),
    ("body: a name plate", T, "humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None", "humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer"),
    ("body: no primary part", T, "\t\tnpc.PrimaryPart = root\n", ""),
    ("body: another rig", T, "Enum.HumanoidRigType.R15)\n\tend)\n\tif not made", "Enum.HumanoidRigType.R6)\n\tend)\n\tif not made"),
    ("place: feet in the ground", T, "local pos = Vector3.new(spot.X, ground + feet, spot.Z)", "local pos = Vector3.new(spot.X, ground, spot.Z)"),
    ("place: feet offset forgotten the wrong way", T, "local feet = pivot.Position.Y - (bounds.Position.Y - size.Y * 0.5)", "local feet = (bounds.Position.Y - size.Y * 0.5) - pivot.Position.Y"),
    ("place: no facing", T, "\t\tnpc:PivotTo(CFrame.lookAt(pos, look))\n", "\t\tnpc:PivotTo(CFrame.new(pos))\n"),
    ("place: looks up or down", T, "local look = Vector3.new(spot.LookX, pos.Y, spot.LookZ)", "local look = Vector3.new(spot.LookX, 0, spot.LookZ)"),
    ("place: the signature is never stored", T, "\tnpc:SetAttribute(\"HHC_TownNpcAt\", string.format(\"%.1f,%.1f\", spot.X, spot.Z))\n", ""),
    ("mark: no NPC tag", T, "\tCollectionService:AddTag(npc, \"NPC\")\n", ""),
    ("mark: a story NPC without the tag", T, "\t\tCollectionService:AddTag(npc, Config.StoryQuests.NpcTag or \"StoryNpc\")\n", ""),
    ("mark: no NpcId", T, "\t\tnpc:SetAttribute(\"NpcId\", entry.Story)\n", ""),
    ("mark: the townsfolk are story NPCs too", T, "\telseif entry.Folk then\n\t\tCollectionService:AddTag(npc, \"TownFolk\")", "\telseif entry.Folk then\n\t\tCollectionService:AddTag(npc, \"StoryNpc\")\n\t\tCollectionService:AddTag(npc, \"TownFolk\")"),
    ("mark: the seller without its tag", T, "\t\tCollectionService:AddTag(npc, \"PotionMerchant\")\n", ""),
    ("mark: the seller without its marker", T, "\t\tnpc:SetAttribute(\"HHC_PotionMerchant\", true)\n", ""),
    ("mark: no ownership", T, "\tnpc:SetAttribute(\"HHC_TownNpc\", entry.Id)\n", ""),
    ("prompt: the wrong key", T, "prompt.KeyboardKeyCode = Enum.KeyCode.G", "prompt.KeyboardKeyCode = Enum.KeyCode.E"),
    ("prompt: a hold", T, "\tprompt.HoldDuration = 0\n\tprompt.RequiresLineOfSight = false\n", "\tprompt.HoldDuration = 1\n\tprompt.RequiresLineOfSight = false\n"),
    ("prompt: needs line of sight", T, "\tprompt.RequiresLineOfSight = false\n", "\tprompt.RequiresLineOfSight = true\n"),
    ("prompt: always on", T, "\tprompt.Enabled = entry.Enabled ~= false\n", "\tprompt.Enabled = true\n"),
    ("prompt: not a conversation", T, "\tprompt:SetAttribute(\"Conversation\", true) -- verified NPC interaction (the same marker as the potion seller)\n", ""),
    ("prompt: no StoryNpcId", T, "\t\tprompt:SetAttribute(\"StoryNpcId\", entry.Story)\n", ""),
    ("prompt: another range", T, "prompt.MaxActivationDistance = num(C.PromptDistance, 10)", "prompt.MaxActivationDistance = 30"),
    ("prompt: the label is the id", T, "prompt.ActionText, prompt.ObjectText = \"Talk\", entry.Label or entry.Story", "prompt.ActionText, prompt.ObjectText = \"Talk\", entry.Story"),
    ("prompt: the seller's name changed", T, "local name = entry.Merchant == true and vitals.PotionMerchantPrompt or \"TalkPrompt\"", "local name = \"TalkPrompt\""),
    ("prompt: the townsfolk talk", T, "\tif entry.Story == nil and entry.Merchant ~= true then\n", "\tif false then\n"),
    ("prompt: a foreign object under the name is kept", T, "\tif prompt and not prompt:IsA(\"ProximityPrompt\") then prompt:Destroy(); prompt = nil end\n", ""),
    ("build: a switched-off entry is built", T, "\tif entry.Enabled == false then return end\n\tlocal spot", "\tlocal spot"),
    ("build: a foreign model is taken over", T, "if existing and (not existing:IsA(\"Model\") or existing:GetAttribute(\"HHC_TownNpc\") ~= entry.Id) then", "if false then"),
    ("build: a rebuilt body", T, "\tif existing then\n\t\t-- repaired and moved", "\tif false then\n\t\t-- repaired and moved"),
    ("build: never moved", T, "if entry.Enabled ~= false and sig and existing:GetAttribute(\"HHC_TownNpcAt\") ~= sig then", "if false then"),
    ("build: always moved", T, "if entry.Enabled ~= false and sig and existing:GetAttribute(\"HHC_TownNpcAt\") ~= sig then", "if entry.Enabled ~= false and sig then"),
    ("build: a built-meanwhile body is added twice", T, "\tif folder:FindFirstChild(entry.Name) then npc:Destroy(); return end -- built meanwhile\n", ""),
    ("build: a failed body stays", T, "\t\tnpc:Destroy()\n\t\tUtil.Warn(TAG, entry.Name .. \" preparation failed: \"", "\t\tUtil.Warn(TAG, entry.Name .. \" preparation failed: \""),
    ("build: no warning for a failed body", T, "\t\tUtil.Warn(TAG, entry.Name .. \" body failed: \" .. tostring(npc))\n", ""),
    ("build: a placed body without ground", T, "\t\tassert(placed, reason)\n", ""),
    ("ensure: pieces not counted", T, "\t\t\tif not existing and entry.Enabled ~= false then ctx.pieces += 1 end\n", ""),
    ("ensure: pieces counted for every entry", T, "\t\t\tif not existing and entry.Enabled ~= false then ctx.pieces += 1 end\n", "\t\t\tctx.pieces += 1\n"),
    ("ensure: built while Build runs", T, "\ttask.spawn(function()\n\t\tfor _, entry in queue do", "\tdo\n\t\tfor _, entry in queue do"),
    ("ensure: a bad row stops the others", T, "\t\t\tlocal ok, err = pcall(buildOne, entry, folder, C, vitals)\n\t\t\tif not ok then Util.Warn(TAG, tostring(entry.Name) .. \": \" .. tostring(err)) end\n", "\t\t\tbuildOne(entry, folder, C, vitals)\n"),
    ("ensure: the switch is ignored", T, "\t\tif C.Enabled ~= true then\n\t\t\t-- switched off", "\t\tif false then\n\t\t\t-- switched off"),
    ("ensure: prompts stay on when switched off", T, "\t\t\t\t\tif d:IsA(\"ProximityPrompt\") then d.Enabled = false end\n", ""),
    ("entries: duplicate ids pass", T, "and not seenId[entry.Id] and not seenName[entry.Name] then", "and not seenName[entry.Name] then"),
    ("entries: duplicate names pass", T, "and not seenId[entry.Id] and not seenName[entry.Name] then", "and not seenId[entry.Id] then"),
    ("entries: a nameless row passes", T, "type(entry.Name) == \"string\" and entry.Name ~= \"\"", "true"),
    ("entries: a non-table row passes", T, "if type(entry) == \"table\" and type(entry.Id) == \"string\"", "if type(entry.Id) == \"string\""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    mb = read(SSS / "MapBuilder.luau")
    code = strip_comments(mb)
    check(code.count("ensureStoryNpcs(ctx, folders.NPCs)") == 1, "MapBuilder.Build calls ensureStoryNpcs once")
    build = code.split("ensurePotionMerchant(ctx, folders.NPCs)", 1)[1].split("\n", 2)
    check("ensureStoryNpcs(ctx, folders.NPCs)" in build[1], "... right after the potion seller")
    helper = function_block(mb, "local function ensureStoryNpcs(")
    check('script.Parent:FindFirstChild("TownNpcs")' in helper and "pcall(" in helper and "Util.Warn(TAG" in helper,
          "the helper finds the sibling module softly and never throws into Build")
    src = strip_comments(read(SSS / "TownNpcs.luau"))
    check(not re.search(r"[가-힣]", src), "TownNpcs: no Hangul outside comments")
    check("MarketplaceService" not in src and "AddBankGold" not in src and "AddStat" not in src and "GrantItem" not in src, "TownNpcs: nothing sold, nothing paid")
    check("task.wait" not in src and ":WaitForChild" not in src, "TownNpcs never waits (Build never yields)")
    check(src.count("CreateHumanoidModelFromDescription") == 1 and "ServerStorage" not in src and "CustomModels" not in src, "the body comes from a HumanoidDescription only (A23-6): no costume rig, no template")
    return count, failures


SUITE = Suite(
    mark="TOWN_NPCS",
    fixture=ROOT / "tools/fixtures/town_npcs_offline.luau",
    world=None,
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev3_town_npcs_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Config.TownNpcs.List: Bright + Sir Gleam (tag StoryNpc, NpcId, 'Talk' prompt with StoryNpcId, G, tap, 10 studs), four "
             "townsfolk (tag TownFolk, no prompt), the Halo potion seller (tag PotionMerchant + the shop prompt, off until ShopService "
             "accepts more than one seller), Otto 4 studs behind the Crossroads anvil (decorative). Temporary default R15 bodies from a "
             "HumanoidDescription (sleeves, trousers), anchored, no collision, no scripts; the height comes from a ground ray (floor-like "
             "hits only, never the NPC folder or a player's character), feet on the ground, facing the Look point; reused / repaired / "
             "moved when they exist, a foreign model under the name is never touched, a missing ground skips only that body; built "
             "after MapBuilder.Build returns.",
    limitations="The real avatar call, the real ray and the Studio tree are doubles. The look of the bodies and the spots on the final "
                "Halo layout are checked by eye in the main Studio (메인 반영 1).",
)

if __name__ == "__main__":
    run(SUITE)
