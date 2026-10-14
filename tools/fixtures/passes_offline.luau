-- Offline checks for Passes.luau (SPEC A23-75: the thank-you line right after a purchase). The runner
-- (tools/test_passes.py) prepends PASSES_SOURCE. Roblox is replaced by small doubles: a LocalPlayer with attributes and
-- change signals, MarketplaceService purchase-finished signals fired by hand, UIKit.Toast recorded, os.clock moved by hand.
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end

local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn); return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in self.Fns do fn(...) end end
	return s
end
local CLOCK = { T = 1000 }
local ME = { UserId = 11, Attr = { DataLoaded = true, PassXP2 = false, PassGold2 = false, PassVIP = false, LooksOwned = "" },
	Signals = {} }
function ME:GetAttribute(k) return self.Attr[k] end
function ME:GetAttributeChangedSignal(k)
	self.Signals[k] = self.Signals[k] or signal()
	return self.Signals[k]
end
local function set(k, v)
	ME.Attr[k] = v
	if ME.Signals[k] then ME.Signals[k]:Fire() end
end
local MPS = { PromptGamePassPurchaseFinished = signal(), PromptProductPurchaseFinished = signal() }
local TOASTS = {}
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = ME } end
		if n == "MarketplaceService" then return MPS end
		if n == "ReplicatedStorage" then -- 10/14: the words sit in Config.ClientText.PassesLines
			return { WaitForChild = function() return { WaitForChild = function() return "CONFIG" end } end }
		end
		return {}
	end },
	require = function(m)
		if m == "CONFIG" then
			return { ClientText = { PassesLines = { PassXP2 = "Thank you! 2x XP is on.", PassGold2 = "Thank you! 2x Gold is on.",
				PassVIP = "Thank you! You are a VIP now: crown and chat tag.", Look = "New look unlocked! Pick it in the Shop." } } }
		end
		return nil
	end,
	os = { clock = function() return CLOCK.T end },
}, { __index = getfenv() })
local fn = assert(loadstring(PASSES_SOURCE, "=Passes"))
setfenv(fn, env)
local Passes = fn()
Passes.Init({ UIKit = { Toast = function(text, kind, secs) table.insert(TOASTS, { text, kind, secs }) end } })
Passes.Start()
local function last() return TOASTS[#TOASTS] and TOASTS[#TOASTS][1] end

-- lines
check("every pass has an English line", Passes.LineFor("PassXP2") == "Thank you! 2x XP is on."
	and Passes.LineFor("PassGold2") == "Thank you! 2x Gold is on." and type(Passes.LineFor("PassVIP")) == "string"
	and Passes.LineFor("Nope") == nil)
-- the join-time ownership check (no purchase in this session) never speaks
set("PassVIP", true)
check("a flag turning on without a purchase of mine (the join check) says nothing", #TOASTS == 0, last())
set("PassVIP", false)
-- buy 2x XP
MPS.PromptGamePassPurchaseFinished:Fire(ME, 123, true)
CLOCK.T += 2
set("PassXP2", true)
check("bought 2x XP: the server turns it on -> 'Thank you! 2x XP is on.'", #TOASTS == 1 and last() == "Thank you! 2x XP is on."
	and TOASTS[1][2] == "good", last())
set("PassGold2", true)
check("one purchase, one thank-you (another flag right after stays quiet)", #TOASTS == 1, last())
set("PassGold2", false)
-- a window closed without buying
MPS.PromptGamePassPurchaseFinished:Fire(ME, 124, false)
set("PassGold2", true)
check("a purchase window closed without buying says nothing", #TOASTS == 1, last())
set("PassGold2", false)
-- someone else's purchase
MPS.PromptGamePassPurchaseFinished:Fire({ UserId = 22 }, 124, true)
set("PassGold2", true)
check("another player's purchase says nothing here", #TOASTS == 1, last())
set("PassGold2", false)
-- too late (the window passed)
MPS.PromptGamePassPurchaseFinished:Fire(ME, 124, true)
CLOCK.T += 31
set("PassGold2", true)
check("a flag that turns on 31 s after the purchase stays quiet", #TOASTS == 1, last())
set("PassGold2", false)
-- a look (developer product)
MPS.PromptProductPurchaseFinished:Fire(11, 77, true)
set("LooksOwned", "HaloIce")
check("a bought look -> 'New look unlocked!'", #TOASTS == 2 and last() == "New look unlocked! Pick it in the Shop.", last())
MPS.PromptProductPurchaseFinished:Fire(11, 78, true)
set("LooksOwned", "HaloIce")
check("the same look list again (nothing new) says nothing", #TOASTS == 2, last())
set("LooksOwned", "")
MPS.PromptProductPurchaseFinished:Fire(11, 78, true)
set("LooksOwned", "")
check("a shorter / empty list says nothing", #TOASTS == 2, last())
-- a flag turning OFF right after a purchase (a refund / a test reset) never thanks
MPS.PromptProductPurchaseFinished:Fire(11, 79, true)
set("PassXP2", false)
check("a flag turning off says nothing", #TOASTS == 2, last())
-- VIP
MPS.PromptGamePassPurchaseFinished:Fire(ME, 125, true)
set("PassVIP", true)
check("bought VIP -> its line", #TOASTS == 3 and string.find(last(), "VIP", 1, true) ~= nil, last())

print(("PASSES_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("PASSES_OFFLINE_OK") end
