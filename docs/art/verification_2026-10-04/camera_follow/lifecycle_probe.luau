local p=game:GetService("Players").LocalPlayer
local Net=require(game:GetService("ReplicatedStorage").Shared.Net)
local camera=workspace.CurrentCamera
local snapshots={}
local function snap(label)
 local ch=p.Character local h=ch and ch:FindFirstChildOfClass("Humanoid")
 table.insert(snapshots,{label=label,subjectMatches=camera.CameraSubject==h,subject=camera.CameraSubject and camera.CameraSubject:GetFullName(),costume=ch and ch:GetAttribute("HHC_CostumeId") or "OwnerAvatar",health=h and h.Health,cameraType=camera.CameraType.Name})
end
snap("initial_avatar")
if p:GetAttribute("Faction")=="None" or p:GetAttribute("Faction")==nil then Net.Get("ChooseFaction"):FireServer("Halo"); task.wait(1) end
if not p:GetAttribute("ClassChosen") then Net.Get("ChooseClass"):FireServer("Warrior","M"); task.wait(3) end
snap("costume_on")
Net.Get("SetCostume"):FireServer(false,"M"); task.wait(4); snap("costume_off")
Net.Get("SetCostume"):FireServer(true,"M"); task.wait(3); snap("costume_on_again")
return game:GetService("HttpService"):JSONEncode({snapshots=snapshots,faction=p:GetAttribute("Faction"),class=p:GetAttribute("Class"),classChosen=p:GetAttribute("ClassChosen")})
