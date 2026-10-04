local player=game:GetService("Players").LocalPlayer
local character=player.Character
local humanoid=character:FindFirstChildOfClass("Humanoid")
local root=character:FindFirstChild("HumanoidRootPart")
local camera=workspace.CurrentCamera
local start=root.Position
local startFocus=camera.Focus.Position
local function vec(v) return {v.X,v.Y,v.Z} end
local function horizontal(v) return Vector3.new(v.X,0,v.Z) end
local samples={}
local ok,err=pcall(function()
    humanoid:MoveTo(start+Vector3.new(12,0,0))
    for i=1,12 do
        task.wait(0.25)
        table.insert(samples,{t=i*0.25,root=vec(root.Position),focus=vec(camera.Focus.Position),subjectMatches=camera.CameraSubject==humanoid,focusHorizontalError=horizontal(camera.Focus.Position-root.Position).Magnitude})
    end
end)
humanoid:MoveTo(root.Position)
local moved=horizontal(root.Position-start).Magnitude
local followed=horizontal(camera.Focus.Position-startFocus).Magnitude
return game:GetService("HttpService"):JSONEncode({ok=ok,error=err,rootTravelStuds=moved,focusTravelStuds=followed,samples=samples})
