-- Client engine play-through, no desktop input or server state overrides.
local p=game.Players.LocalPlayer
local Net=require(game.ReplicatedStorage.Shared.Net)
local out={inputMethod="Studio MCP Client / normal game RemoteEvents",notices={}}
local conn=Net.Get("Notify").OnClientEvent:Connect(function(d)table.insert(out.notices,d.Text)end)
local sim=game:GetService("StudioDeviceSimulatorService")
out.deviceReset={pcall(function()sim:SetOrientationAsync(Enum.ScreenOrientation.LandscapeRight) task.wait(.2) sim:StopSimulationAsync() task.wait(.3)end)}
local a,b=Instance.new("BillboardGui"),Instance.new("BillboardGui")
a.Name="_FactionTestEnabled" b.Name="_FactionTestDisabled" b.Enabled=false
a.Parent=workspace b.Parent=workspace task.wait(.5)
out.hiddenTest={a=a.Enabled,b=b.Enabled}
out.before={faction=p:GetAttribute("Faction"),classChosen=p:GetAttribute("ClassChosen")}
Net.Get("ChooseFaction"):FireServer("Halo") task.wait(1)
out.afterFaction={faction=p:GetAttribute("Faction"),pickerVisible=p.PlayerGui.MainGui.FactionPicker.Visible,
    classVisible=p.PlayerGui.MainGui.ClassPicker.Visible,restoredTrue=a.Enabled,restoredFalse=b.Enabled}
pcall(function()out.afterFaction.coreChat=game.StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat)end)
Net.Get("ChooseClass"):FireServer("Warrior","M") task.wait(2)
out.afterClass={class=p:GetAttribute("Class"),classChosen=p:GetAttribute("ClassChosen"),
    classVisible=p.PlayerGui.MainGui.ClassPicker.Visible,
    cameraMatches=workspace.CurrentCamera.CameraSubject==p.Character:FindFirstChildOfClass("Humanoid")}
Net.Get("ChooseFaction"):FireServer("Horns") task.wait(.6)
out.duplicateFactionRejected=p:GetAttribute("Faction")=="Halo"
a:Destroy() b:Destroy() conn:Disconnect()
return game.HttpService:JSONEncode(out)
