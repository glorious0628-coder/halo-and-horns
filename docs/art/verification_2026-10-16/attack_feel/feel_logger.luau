-- client: records basic-attack moments into workspace.HH_FeelLog (one line per event: "<os.clock> <kind> <detail>")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local me = Players.LocalPlayer
local log = workspace:FindFirstChild("HH_FeelLog")
if log then log:Destroy() end
log = Instance.new("StringValue")
log.Name = "HH_FeelLog"
log.Value = ""
log.Parent = workspace
local lines = {}
local function add(kind, detail)
	table.insert(lines, string.format("%.4f %s %s", os.clock(), kind, tostring(detail or "")))
	log.Value = table.concat(lines, "\n")
end
local conns = {}
local function on(sig, fn) table.insert(conns, sig:Connect(fn)) end
on(UIS.InputBegan, function(input)
	if input.KeyCode == Enum.KeyCode.F then add("press", "F") end
end)
local cam = workspace.CurrentCamera
local function watchFx(folder)
	on(folder.ChildAdded, function(c) add("fx", c.Name) end)
	on(folder.DescendantAdded, function(d)
		if d:IsA("TextLabel") and d.Name == "Text" then
			on(d:GetPropertyChangedSignal("Text"), function() if d.Text ~= "" then add("num", d.Text) end end)
		end
	end)
	for _, d in folder:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Text" then
			on(d:GetPropertyChangedSignal("Text"), function() if d.Text ~= "" then add("num", d.Text) end end)
		end
	end
end
local fx = cam:FindFirstChild("LocalFx")
if fx then watchFx(fx) else on(cam.ChildAdded, function(c) if c.Name == "LocalFx" then watchFx(c) end end) end
local function watchChar(char)
	local hum = char:WaitForChild("Humanoid", 5)
	local seen = {}
	local rs = char:FindFirstChild("RightShoulder", true)
	local last = rs and rs:IsA("Motor6D") and (rs.C0 * rs.Transform) or nil
	-- Fx Feel writes the procedural pose in PreSimulation (after the Animator): read it after that (PostSimulation)
	on(game:GetService("RunService").PostSimulation, function()
		if hum then
			local now = {}
			for _, tr in hum:GetPlayingAnimationTracks() do
				now[tr] = true
				if not seen[tr] then add("anim", (tr.Animation and tr.Animation.AnimationId or "?") .. " " .. tr.Name) end
			end
			seen = now
		end
		if rs and rs.Parent and last then
			local t = rs.C0 * rs.Transform
			local _, ang = (last:Inverse() * t):ToAxisAngle()
			if math.deg(ang) > 4 then add("arm", string.format("%.0f", math.deg(ang))) end
			last = t
		end
	end)
end
if me.Character then watchChar(me.Character) end
local monsters = workspace:WaitForChild("Monsters", 5)
local function watchMonster(m)
	if not m:IsA("Model") then return end
	on(m:GetAttributeChangedSignal("HurtSeq"), function() add("hurt", m:GetAttribute("MonsterKind")) end)
	on(m.ChildAdded, function(c) if c.Name == "CalmSoft" then add("calm", m:GetAttribute("MonsterKind")) end end)
	local root = m.PrimaryPart
	if root then on(root:GetPropertyChangedSignal("Anchored"), function() if root.Anchored then add("beaten", m:GetAttribute("MonsterKind")) end end) end
end
if monsters then
	for _, m in monsters:GetChildren() do watchMonster(m) end
	on(monsters.ChildAdded, watchMonster)
end
on(me:GetAttributeChangedSignal("XP"), function() add("xp", me:GetAttribute("XP")) end)
-- the whoosh Fx.PlaySound("Swing") plays (SoundService.Fx_Swing): on my press (predicted) or on the server's Fx
local SS = game:GetService("SoundService")
local function watchSound(snd)
	if snd:IsA("Sound") and snd.Name == "Fx_Swing" then on(snd.Played, function() add("whoosh", "") end) end
end
for _, d in SS:GetChildren() do watchSound(d) end
on(SS.ChildAdded, watchSound)
on(me:GetAttributeChangedSignal("HHDbgSwing"), function() add("swing", me:GetAttribute("HHDbgSwing")) end)
add("start", me:GetAttribute("Class"))
return "logger on " .. #conns
