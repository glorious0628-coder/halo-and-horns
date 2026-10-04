local p=game:GetService("Players").LocalPlayer
local Net=require(game.ReplicatedStorage.Shared.Net)
local Config=require(game.ReplicatedStorage.Shared.Config)
local out={notices={}}
local connection=Net.Get("Notify").OnClientEvent:Connect(function(data)table.insert(out.notices,data.Text)end)
local function snap()return {bank=p:GetAttribute("BankGold"),carried=p:GetAttribute("CarriedGold"),weapon=p:GetAttribute("WeaponTier"),tutorial=p:GetAttribute("TutorialStep"),hp=p:GetAttribute("HPPotionCount"),mp=p:GetAttribute("MPPotionCount")}end
out.before=snap()
Net.Get("ClaimQuest"):FireServer("tutorial"); task.wait(0.8); out.firstClaim=snap()
Net.Get("ClaimQuest"):FireServer("tutorial"); task.wait(0.8); out.secondClaim=snap()
Net.Get("UpgradeWeapon"):FireServer(); task.wait(1); out.upgrade=snap()
Net.Get("BuyPotion"):FireServer("HP",1); task.wait(1); out.potionAttempt=snap()
out.merchantEnabled=Config.Vitals.MerchantEnabled
connection:Disconnect()
return game:GetService("HttpService"):JSONEncode(out)
