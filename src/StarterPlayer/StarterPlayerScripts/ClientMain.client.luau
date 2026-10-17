-- ClientMain.client.luau : the ONLY client entry point.
-- A23-156 (user 10/13, 게임성 개발 2's Config.TestServer): the private test's switch (Z skill on, the goose every 10 min,
-- pass sales on) changes Config here FIRST, before any module reads it - the server calls it in Main.server.luau the same
-- way, so both sides see the same values (no call = the client would keep Z off)
do
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
	if type(Config.ApplyTestServer) == "function" then
		local ok, err = pcall(Config.ApplyTestServer)
		if not ok then warn("[ClientMain] ApplyTestServer failed: " .. tostring(err)) end
	end
end
-- A23-179 (user 10/14: "개발을 영어로 하자고 했지 누가 자동 번역까지 끄래"): Roblox's automatic translation is ON. We
-- write English (A23-48); Roblox translates it for players in other languages (Creator Hub localization). The old
-- game-wide AutoLocalize = false watcher (10/07, 69f1fe45) is gone. Only what must stay as it is turns it off where
-- it is made: player names (nametag line 1, the Tab list, the supporter board), number-only labels (UIKit
-- LightText / artText Number = true, damage numbers, the skill seconds) and what players type (TextBoxes).

local ORDER = { "CameraFollow", "UIKit", "GearSlots", "Settings", "Keybinds", "Fx", "VitalsUI", "HUD", "EventHUD", "DeathScreen", "Panels", "SettingsUI", "ShopUI", "Intro", "FactionPicker", "ClassPicker", "WorldMap", "MonsterMotion", "Announce", "ChatTags", "NameTagPrefs", "Invite", "SupporterBoard", "PauseCard", "ComeBack", "KingDiary", "AttendanceUI", "CodexUI", "ChoiceCardUI", "VillageFundUI", "PetWindow", "SkillBook", "QuestBook", "BagUI", "CharacterUI", "HeroPreview", "GatherView", "CraftView", "CraftWindow", "MarketWindow", "GrudgeGhost", "ZoneLook", "MiniMap", "PlayerListUI", "Party", "BubbleUI", "StickerUI", "MonsterLabels", "PetFollow", "QuestTarget", "QuestMarker", "StoryNpcs", "TownReact", "LightCap", "SignFit", "FirstSteps", "FountainFx", "EggFx", "WeatherFx", "SkillBar", "QuickSlots", "BuffBar", "WeaponPose", "LandShadow", "SkillFx", "Audio" }

local C = {}
for _, name in ORDER do
	C[name] = require(script.Parent:WaitForChild(name))
end
for _, name in ORDER do
	local ok, err = pcall(C[name].Init, C)
	if not ok then
		warn(("[ClientMain] %s.Init failed: %s"):format(name, tostring(err)))
	end
end
for _, name in ORDER do
	local ok, err = pcall(C[name].Start)
	if not ok then
		warn(("[ClientMain] %s.Start failed: %s"):format(name, tostring(err)))
	end
end
print("[ClientMain] client started")
