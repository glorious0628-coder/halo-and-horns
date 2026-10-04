local p=game:GetService("Players").LocalPlayer
local Net=require(game.ReplicatedStorage.Shared.Net)
local Config=require(game.ReplicatedStorage.Shared.Config)
local notices={}
local conn=Net.Get("Notify").OnClientEvent:Connect(function(data) table.insert(notices,data.Text) end)
Net.Get("Travel"):FireServer("SlimeMeadow")
task.wait(4)
local ch=p.Character local r=ch.HumanoidRootPart
local monsters={}
for _,m in workspace.Monsters:GetChildren() do
 local part=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
 if part then table.insert(monsters,{name=m.Name,position={part.Position.X,part.Position.Y,part.Position.Z},distance=(part.Position-r.Position).Magnitude,attributes=m:GetAttributes()}) end
end
table.sort(monsters,function(a,b)return a.distance<b.distance end)
while #monsters>3 do table.remove(monsters) end
conn:Disconnect()
return game:GetService("HttpService"):JSONEncode({zone=p:GetAttribute("ZoneId"),tutorialStep=p:GetAttribute("TutorialStep"),subjectMatches=workspace.CurrentCamera.CameraSubject==ch:FindFirstChildOfClass("Humanoid"),position={r.Position.X,r.Position.Y,r.Position.Z},monsters=monsters,notices=notices})
