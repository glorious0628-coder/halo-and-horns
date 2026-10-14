-- revive_offline.luau : 99N G (계획 8) helping a friend up (server: ReviveService), offline.
-- tools/test_revive.py injects (before tools/fixtures/dev2_kit.luau): CONFIG_SOURCE, UTIL_SOURCE, REVIVE_SOURCE, NET_SOURCE,
-- MAIN_SOURCE (the CURRENT src) and PLAYER_GETUP (PlayerService's getUp cut out). ReviveService runs for real on doubles:
-- PlayerService (data rows, IsReady, SetStat, GrantFame, Respawn, CharacterDied / CharacterSpawned / PlayerLeaving),
-- FactionService (the Faction attribute), FirstKOService (w.FirstKO[p]), PvPService (BreakProtection log) and
-- ProximityPromptService (PromptButtonHoldBegan / PromptTriggered fired by the checks).

local function rvWorld(opts)
	opts = opts or {}
	local w = newWorld({ EditConfig = opts.EditConfig })
	w.AllowWarn = opts.AllowWarn
	local Signal = w.Util.Signal
	local data = {}
	w.Data, w.Fame, w.Respawns, w.Breaks, w.FirstKO = data, {}, {}, {}, {}
	local ps = { CharacterDied = Signal.new(), CharacterSpawned = Signal.new(), PlayerLeaving = Signal.new(), PlayerReady = Signal.new() }
	function ps.GetData(p) return data[p] end
	function ps.IsReady(p) return w.Ready[p] == true end
	function ps.SetStat(p, k, v)
		data[p][k] = v
		p:SetAttribute(k, v)
	end
	function ps.GrantFame(p, stat, n, ctx) table.insert(w.Fame, { P = p, Stat = stat, N = n, Revive = ctx and ctx.Revive }) end
	function ps.Respawn(p) table.insert(w.Respawns, p) end
	local reg = {
		PlayerService = ps,
		FactionService = { GetFaction = function(p) return p:GetAttribute("Faction") or "None" end },
		FirstKOService = { GetUp = function(p) return w.FirstKO[p] end },
		PvPService = { BreakProtection = function(p) table.insert(w.Breaks, { P = p, At = w.Clock }) end },
	}
	w.PPS = { PromptTriggered = rbxSignal(w.Warnings), PromptButtonHoldBegan = rbxSignal(w.Warnings) }
	w.Services.ProximityPromptService = w.PPS
	local rv = w:Load("ReviveService", REVIVE_SOURCE)
	reg.ReviveService = rv
	rv.Init(reg)
	rv.Start()
	w.PS, w.Rv, w.Reg = ps, rv, reg
	w.Helped = {}
	rv.Revived:Connect(function(a, b) table.insert(w.Helped, { A = a, B = b }) end)
	-- a body at pos (a model with a Humanoid and a HumanoidRootPart)
	function w:Body(p, pos, hp)
		local model = newInstance("Model", w)
		local hum = newInstance("Humanoid", w)
		hum.Name, hum.Health, hum.MaxHealth = "Humanoid", hp or 100, 100
		hum.Parent = model
		local root = newInstance("Part", w)
		root.Name, root.Position = "HumanoidRootPart", pos
		root.Parent = model
		p.Character = model
		return model, hum, root
	end
	-- a ready player of a side at pos with HP potions
	function w:Join(id, side, pos, potions)
		local p = self:NewPlayer(id, { Faction = side })
		data[p] = { HPPotionCount = potions or 3 }
		self.Ready[p] = true
		self:Body(p, pos or vec(0, 0, 0))
		return p, data[p]
	end
	-- p is knocked out where it stands
	function w:KO(p)
		local hum = p.Character:FindFirstChildOfClass("Humanoid")
		hum.Health = 0
		ps.CharacterDied:Fire(p, p.Character)
		self:Flush()
	end
	function w:Prompt(p)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		return root and root:FindFirstChild(self.Config.Revive.PromptName) or nil
	end
	-- the helper holds the prompt `secs` s, then it triggers
	function w:Hold(helper, prompt, secs)
		self.PPS.PromptButtonHoldBegan:Fire(prompt, helper)
		self:Advance(secs or 3)
		self.PPS.PromptTriggered:Fire(prompt, helper)
		self:Flush()
	end
	-- PlayerService's real spawn order for p: a new body, then CharacterSpawned (the HP / shield after a help)
	function w:Spawn(p, pos)
		local model, hum = self:Body(p, pos or vec(0, 0, 0))
		ps.CharacterSpawned:Fire(p, model, hum, false)
		self:Flush()
		return model, hum
	end
	return w
end

-- PlayerService's getUp, cut out, over a registry
local function playerGetUp(reg)
	local env = { S = reg, loopWarn = function() end, pcall = pcall, type = type }
	local fn = assert(loadstring("local S, loopWarn = S, loopWarn\n" .. PLAYER_GETUP .. "\nreturn getUp", "=PlayerGetUp"))
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end

------------------------------------------------------------------ config + wiring
runGroup("config + wiring", function()
	local w = rvWorld()
	local R = w.Config.Revive
	check(R.Enabled == true and R.Range == 6 and R.Hold == 3 and R.Cooldown == 10 and R.HPPct == 0.3 and R.Shield == 3
		and R.Potion == "HP" and R.Fame == 1 and R.Wait == 10 and R.WaitNear == 40,
		"Config.Revive: 6 studs, hold 3 s, cooldown 10 s, HP 30%, shield 3 s, 1 HP potion, +1 fame; a 10 s wait with a friend within 40",
		show(R))
	local init = string.match(MAIN_SOURCE, "local INIT_ORDER = (%b{})") or ""
	local start = string.match(MAIN_SOURCE, "local START_ORDER = (%b{})") or ""
	local function count(list, name)
		local _, c = string.gsub(list, '"' .. name .. '"', "")
		return c
	end
	local function pos(list, name) return string.find(list, '"' .. name .. '"', 1, true) end
	check(count(init, "ReviveService") == 1 and count(start, "ReviveService") == 1
		and pos(start, "PvPService") < pos(start, "ReviveService") and pos(start, "ReviveService") < pos(start, "PlayerService"),
		"Main: initialized once, started after PvPService and before PlayerService", "")
	local names = string.match(NET_SOURCE, "Net%.Names = (%b{})") or ""
	check(count(names, "ReviveSkip") == 1, "Net.Names has ReviveSkip once", "")
	-- PlayerService's get-up asks FirstKOService first, then ReviveService
	local get = playerGetUp({ FirstKOService = { GetUp = function() return { Delay = 3, Tag = "first" } end },
		ReviveService = { GetUp = function() return { Delay = 10, Tag = "revive" } end } })
	check(get(1).Tag == "first", "PlayerService getUp: the first KO comes first", "")
	local get2 = playerGetUp({ FirstKOService = { GetUp = function() return nil end },
		ReviveService = { GetUp = function() return { Delay = 10, Tag = "revive" } end } })
	check(get2(1).Tag == "revive", "PlayerService getUp: else the revive wait", "")
	local get3 = playerGetUp({})
	check(get3(1) == nil, "PlayerService getUp: no service, nil (the normal RespawnTime)", "")
end)

------------------------------------------------------------------ the KO: a wait and a prompt only with a friend near
runGroup("the wait", function()
	local w = rvWorld()
	local R = w.Config.Revive
	local alone = w:Join(1, "Halo", vec(0, 0, 0))
	local far = w:Join(2, "Halo", vec(60, 0, 0))
	local foe = w:Join(3, "Horns", vec(5, 0, 0))
	w:KO(alone)
	check(w:Prompt(alone) == nil and w.Rv.GetUp(alone) == nil and (alone:GetAttribute("ReviveUntil") or 0) == 0,
		"no friend within 40 (one 60 away, a foe 5 away): no prompt, the usual respawn", "")
	local p = w:Join(4, "Halo", vec(100, 0, 0))
	local f = w:Join(5, "Halo", vec(130, 0, 0))
	w:KO(p)
	local pr = w:Prompt(p)
	check(pr ~= nil and pr.ClassName == "ProximityPrompt" and pr.HoldDuration == 3 and pr.MaxActivationDistance == 6
		and pr.KeyboardKeyCode == "KeyCode.G" and pr.RequiresLineOfSight == false and pr:GetAttribute("Side") == "Halo"
		and pr:GetAttribute("ReviveUserId") == 4 and pr.ActionText == R.Text.Action,
		"a friend 30 away: a G prompt on the body (3 s, 6 studs, Side Halo, the UserId)", show(pr and { pr.HoldDuration, pr.MaxActivationDistance }))
	local g = w.Rv.GetUp(p)
	check(g and g.Delay == 10 and g.CFrame == nil and p:GetAttribute("ReviveUntil") == w.Time + 10,
		"GetUp: wait 10 s (no spot yet); ReviveUntil = now + 10", show(g))
	local fx = nil
	for _, e in w.Fx do if e.Player == p and e.Kind == "ReviveWait" then fx = e end end
	check(fx and fx.Data.Sec == 10, "Fx ReviveWait { Sec = 10 } to the KO'd player", "")
	-- the first KO's own get-up comes first: no revive
	local q = w:Join(6, "Halo", vec(200, 0, 0))
	w:Join(7, "Halo", vec(205, 0, 0))
	w.FirstKO[q] = { Delay = 3 }
	w:KO(q)
	check(w:Prompt(q) == nil and w.Rv.GetUp(q) == nil, "the first KO (FirstKOService holds it): no prompt", "")
	-- the normal respawn after the wait clears it
	w:Spawn(p, vec(0, 0, 0))
	check(w.Rv.GetUp(p) == nil and pr.Destroyed == true and p:GetAttribute("ReviveUntil") == 0, "the respawn after the wait: cleared", "")
	local _ = { far, foe, f }
end)

------------------------------------------------------------------ the help
runGroup("help", function()
	local w = rvWorld()
	local p = w:Join(1, "Halo", vec(0, 0, 0))
	local h, hd = w:Join(2, "Halo", vec(4, 0, 0), 2)
	w:KO(p)
	local pr = w:Prompt(p)
	w:Hold(h, pr, 3)
	check(#w.Respawns == 1 and w.Respawns[1] == p and hd.HPPotionCount == 1 and h:GetAttribute("HPPotionCount") == 1,
		"held 3 s within 6: the KO'd one gets up (Respawn), one HP potion used", show({ #w.Respawns, hd.HPPotionCount }))
	check(#w.Fame == 1 and w.Fame[1].P == h and w.Fame[1].Stat == "Honor" and w.Fame[1].N == 1 and w.Fame[1].Revive == true,
		"the helper: +1 Honor (Halo), ctx Revive", show({ w.Fame[1].Stat, w.Fame[1].N }))
	local g = w.Rv.GetUp(p)
	check(g and g.Delay == 0 and g.CFrame ~= nil and g.CFrame.Args[1].X == 0 and g.CFrame.Args[1].Y == 3,
		"GetUp: now, at the body (3 up)", show(g))
	check(pr.Destroyed == true and p:GetAttribute("ReviveUntil") == 0 and #w.Helped == 1, "the prompt is gone; Revived fired", "")
	local n = w:NoticesFor(h)
	check(n[#n] == "You helped P1 up! +1 Honor" and w:NoticesFor(p)[1] == "P2 helped you up!", "the two lines", show({ n[#n], w:NoticesFor(p)[1] }))
	local _, hum = w:Spawn(p, vec(0, 3, 0))
	check(hum.Health == 30 and w.Rv.GetUp(p) == nil, "the spawn after the help: 30% HP; the record cleared", hum.Health)
	check(#w.Breaks == 0, "the spawn shield stays for now", "")
	w:Advance(3)
	check(#w.Breaks == 1 and w.Breaks[1].P == p, "after 3 s the spawn shield ends (BreakProtection)", #w.Breaks)
	-- a Horn helps a Horn: Infamy (shown as Mischief)
	local x = w:Join(10, "Horns", vec(500, 0, 0))
	local y = w:Join(11, "Horns", vec(503, 0, 0))
	w:KO(x)
	w:Hold(y, w:Prompt(x), 3)
	check(w.Fame[#w.Fame].Stat == "Infamy" and w:NoticesFor(y)[1] == "You helped P10 up! +1 Mischief", "Horns: +1 Infamy (Mischief)", "")
	-- Neutral: no fame, a plain line
	local a = w:Join(20, "Neutral", vec(900, 0, 0))
	local b = w:Join(21, "Neutral", vec(902, 0, 0))
	w:KO(a)
	local fame0 = #w.Fame
	w:Hold(b, w:Prompt(a), 3)
	check(#w.Fame == fame0 and w:NoticesFor(b)[1] == "You helped P20 up!" and w.Respawns[#w.Respawns] == a, "Neutral: helped, no fame", "")
end)

------------------------------------------------------------------ refusals
runGroup("refusals", function()
	local w = rvWorld()
	local p = w:Join(1, "Halo", vec(0, 0, 0))
	local h, hd = w:Join(2, "Halo", vec(4, 0, 0), 1)
	local foe = w:Join(3, "Horns", vec(3, 0, 0))
	w:KO(p)
	local pr = w:Prompt(p)
	-- a quick trigger (no real hold)
	w:Hold(h, pr, 1)
	check(#w.Respawns == 0 and hd.HPPotionCount == 1, "a hold of 1 s: nothing", "")
	w.PPS.PromptTriggered:Fire(pr, h)
	check(#w.Respawns == 0, "a trigger without a hold began: nothing", "")
	-- another side (in PvP too)
	w:Hold(foe, pr, 3)
	check(#w.Respawns == 0 and #w.Fame == 0, "a Horn on a Halo body: refused", "")
	check(w.Rv.Try(foe, p) == "Side", "Try: Side", "")
	-- too far (the prompt's own 6 studs + 2 slack on the server)
	h.Character:FindFirstChild("HumanoidRootPart").Position = vec(9, 0, 0)
	check(w.Rv.Try(h, p) == "Far" and #w.Respawns == 0, "9 studs away: Far", "")
	h.Character:FindFirstChild("HumanoidRootPart").Position = vec(4, 0, 0)
	-- a helper who is down too
	h.Character:FindFirstChildOfClass("Humanoid").Health = 0
	check(w.Rv.Try(h, p) == "Bad", "a helper at 0 HP: refused", "")
	h.Character:FindFirstChildOfClass("Humanoid").Health = 100
	-- no potion
	hd.HPPotionCount = 0
	check(w.Rv.Try(h, p) == "NoPotion" and w:NoticesFor(h)[1] == w.Config.Revive.Text.NoPotion and #w.Respawns == 0,
		"no HP potion: refused with the line", show(w:NoticesFor(h)))
	hd.HPPotionCount = 2
	check(w.Rv.Try(h, h) == "Bad" and w.Rv.Try(h, foe) == "Gone", "myself / someone not down: refused", "")
	-- the wait is over
	w:Advance(11)
	check(w.Rv.Try(h, p) == "Gone", "after the 10 s wait: Gone", "")
	-- the cooldown: two KO'd friends, one helper
	local w2 = rvWorld()
	local a = w2:Join(1, "Halo", vec(0, 0, 0))
	local b = w2:Join(2, "Halo", vec(2, 0, 0))
	local c, cd = w2:Join(3, "Halo", vec(1, 0, 0), 5)
	w2:KO(a)
	w2:KO(b)
	w2:Hold(c, w2:Prompt(a), 3)
	check(#w2.Respawns == 1 and cd.HPPotionCount == 4, "the first help", "")
	w2:Hold(c, w2:Prompt(b), 3)
	check(#w2.Respawns == 1 and cd.HPPotionCount == 4 and string.find(w2:NoticesFor(c)[2] or "", "help again in 7 s", 1, true) ~= nil,
		"3 s later: the 10 s cooldown (7 s left), nothing used", show(w2:NoticesFor(c)))
	local _ = { foe }
end)

------------------------------------------------------------------ skip, leave, a second KO
runGroup("skip + leave", function()
	local w = rvWorld()
	local p = w:Join(1, "Halo", vec(0, 0, 0))
	local h = w:Join(2, "Halo", vec(4, 0, 0))
	w:KO(p)
	local pr = w:Prompt(p)
	w:Advance(1)
	w.Remotes.ReviveSkip.OnServerEvent:Fire(p, "extra")
	check(#w.Respawns == 0, "ReviveSkip with an argument: nothing", "")
	w.Remotes.ReviveSkip.OnServerEvent:Fire(p)
	check(#w.Respawns == 1 and pr.Destroyed == true and w.Rv.GetUp(p) == nil, "ReviveSkip: up in town now, the prompt gone", "")
	w:Hold(h, pr, 3)
	check(#w.Respawns == 1 and #w.Fame == 0, "a hold on the old prompt after the skip: nothing", "")
	w.Remotes.ReviveSkip.OnServerEvent:Fire(h)
	check(#w.Respawns == 1, "ReviveSkip from someone not down: nothing", "")
	-- leaving clears the record
	local q = w:Join(3, "Halo", vec(50, 0, 0))
	w:Join(4, "Halo", vec(52, 0, 0))
	w:KO(q)
	local qp = w:Prompt(q)
	w.PS.PlayerLeaving:Fire(q)
	check(qp.Destroyed == true and w.Rv.GetUp(q) == nil, "the KO'd player leaves: the prompt goes", "")
	-- off: nothing at all
	local off = rvWorld({ EditConfig = function(c) c.Revive.Enabled = false end })
	local o = off:Join(1, "Halo", vec(0, 0, 0))
	off:Join(2, "Halo", vec(3, 0, 0))
	off:KO(o)
	check(off:Prompt(o) == nil and off.Rv.GetUp(o) == nil, "Config.Revive.Enabled = false: no prompt, no wait", "")
end)

finish()
