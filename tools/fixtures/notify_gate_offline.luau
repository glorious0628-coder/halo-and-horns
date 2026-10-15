-- notify_gate_offline.luau : A23-191 (최종 검수 10/15) the server Notify gate in Net.luau. tools/test_notify_gate.py binds
-- NET_SOURCE in front of dev2_kit.luau; this file follows. Only Kind "bad" carries its text; every other kind sends its
-- sound alone (Text "", no Key) or nothing.

local function netWorld()
	local w = { Sent = {} }
	local remote = {}
	function remote:FireClient(p, payload) table.insert(w.Sent, { To = p, Payload = payload }) end
	function remote:FireAllClients(payload) table.insert(w.Sent, { To = "All", Payload = payload }) end
	local remotes = {}
	function remotes:FindFirstChild(name) return name == "Notify" and remote or nil end
	local rs = { Remotes = remotes }
	local run = {}
	function run:IsServer() return true end
	function run:IsStudio() return false end
	local l10n = { Get = function(key) return "EN " .. tostring(key) end,
		Msg = function(m) return "EN " .. tostring(m.Key) end }
	local parent = {}
	function parent:WaitForChild(name) return name == "L10n" and "L10n" or nil end
	local env = nativeEnv()
	env.game = { GetService = function(_, name) return name == "ReplicatedStorage" and rs or (name == "RunService" and run) end }
	env.script = { Parent = parent }
	env.require = function(m) assert(m == "L10n", "unexpected require"); return l10n end
	w.Net = execute("Net", NET_SOURCE, env)
	function w:Last() return self.Sent[#self.Sent] end
	return w
end

runGroup("bad keeps its text", function()
	local w = netWorld()
	w.Net.Notify("P1", "Not enough gold", "bad")
	local s = w:Last()
	check(#w.Sent == 1 and s.To == "P1" and s.Payload.Text == "Not enough gold" and s.Payload.Kind == "bad",
		"Notify bad: sent with its text", show(w.Sent))
	w.Net.Notify("P1", "Too far", "bad", 3, "None")
	check(#w.Sent == 2 and w:Last().Payload.Text == "Too far" and w:Last().Payload.Sound == "None" and w:Last().Payload.Duration == 3,
		"Notify bad with Sound None: still sent with its text (silent)", show(w:Last()))
	w.Net.NotifyAll("Server closing", "bad")
	check(#w.Sent == 3 and w:Last().To == "All" and w:Last().Payload.Text == "Server closing", "NotifyAll bad: sent to all with its text",
		show(w:Last()))
	w.Net.NotifyKey("P2", "SomeKey", { "1" }, "bad")
	check(#w.Sent == 4 and w:Last().Payload.Key == "SomeKey" and w:Last().Payload.Text == "EN SomeKey", "NotifyKey bad: the keyed line",
		show(w:Last()))
end)

runGroup("other kinds: sound only or nothing", function()
	local w = netWorld()
	w.Net.Notify("P1", "Quest done! +50 gold", "reward", nil, "QuestDone")
	local s = w:Last()
	check(#w.Sent == 1 and s.Payload.Text == "" and s.Payload.Kind == "reward" and s.Payload.Sound == "QuestDone",
		"reward + Sound: the sound alone (Text '')", show(w.Sent))
	w.Net.Notify("P1", "Got a weapon", "reward")
	check(#w.Sent == 2 and w:Last().Payload.Text == "" and w:Last().Payload.Sound == nil,
		"reward without Sound: sent with Text '' (the client's kind sound QuestDone)", show(w:Last()))
	w.Net.Notify("P1", "Pet joined", "reward", nil, "None")
	check(#w.Sent == 2, "reward + Sound None: nothing sent", #w.Sent)
	w.Net.Notify("P1", "Welcome back", "info")
	w.Net.Notify("P1", "Nice!", "good")
	w.Net.Notify("P1", "Big news", "announce")
	w.Net.Notify("P1", "Default kind")
	check(#w.Sent == 2, "info / good / announce / no kind without a sound: nothing sent", #w.Sent)
	w.Net.Notify("P1", "", "good", nil, "Spend")
	check(#w.Sent == 3 and w:Last().Payload.Text == "" and w:Last().Payload.Sound == "Spend", "good + Sound: the sound alone",
		show(w:Last()))
	w.Net.Notify("P1", "Scroll failed", "info", nil, "ScrollFail")
	check(#w.Sent == 4 and w:Last().Payload.Text == "" and w:Last().Payload.Kind == "info" and w:Last().Payload.Sound == "ScrollFail",
		"info + Sound: the sound alone, the kind kept", show(w:Last()))
	w.Net.NotifyAll("Kaiju is here!")
	check(#w.Sent == 4, "NotifyAll default (announce) without a sound: nothing sent", #w.Sent)
	w.Net.NotifyAll("Goose!", "announce", 2, "GooseStart")
	check(#w.Sent == 5 and w:Last().To == "All" and w:Last().Payload.Text == "" and w:Last().Payload.Kind == "announce",
		"NotifyAll announce + Sound: the sound alone", show(w:Last()))
	w.Net.NotifyKey("P2", "SomeKey", nil, "reward", nil, "RankUp")
	check(#w.Sent == 6 and w:Last().Payload.Key == nil and w:Last().Payload.Text == "" and w:Last().Payload.Sound == "RankUp",
		"NotifyKey reward + Sound: the sound alone, no Key", show(w:Last()))
	w.Net.NotifyKey("P2", "SomeKey", nil, "info")
	w.Net.NotifyAllKey("SomeKey", nil)
	check(#w.Sent == 6, "NotifyKey info / NotifyAllKey announce without a sound: nothing sent", #w.Sent)
	local texts = {}
	for _, e in w.Sent do if e.Payload.Text ~= "" then table.insert(texts, e.Payload.Text) end end
	check(#texts == 0, "no non-bad line ever carries text", show(texts))
end)

finish()
