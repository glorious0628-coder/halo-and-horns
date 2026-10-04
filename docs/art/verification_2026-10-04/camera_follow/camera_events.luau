local p=game:GetService("Players").LocalPlayer
local h=p.Character:FindFirstChildOfClass("Humanoid")
local cam=workspace.CurrentCamera
local originalType=cam.CameraType
local originalCFrame=cam.CFrame
local dummy=Instance.new("Part") dummy.Name="CameraFollowQATarget" dummy.Anchored=true dummy.Transparency=1 dummy.CanCollide=false dummy.Parent=workspace
local out={}
local ok,err=pcall(function()
 cam.CameraSubject=dummy; task.wait(0.15); out.staleSubjectRepaired=cam.CameraSubject==h
 cam.CameraType=Enum.CameraType.Scriptable; cam.CameraSubject=dummy; cam.CFrame=originalCFrame; task.wait(0.15)
 out.scriptablePreserved=cam.CameraType==Enum.CameraType.Scriptable and cam.CameraSubject==dummy and cam.CFrame==originalCFrame
 cam.CameraType=Enum.CameraType.Custom; task.wait(0.15); out.customReturnRebound=cam.CameraSubject==h
 local replacement=Instance.new("Camera") replacement.Name="CameraFollowQAReplacement" replacement.CameraType=Enum.CameraType.Custom replacement.CFrame=cam.CFrame replacement.Parent=workspace
 workspace.CurrentCamera=replacement; task.wait(0.2); out.newCameraRebound=replacement.CameraSubject==h
 -- Roblox may destroy the previous CurrentCamera on replacement. Keep the new camera in this Play only.
 replacement.Name="Camera"
 local root=p.Character.HumanoidRootPart local startY=root.Position.Y
 h.Jump=true; task.wait(0.2); out.jumpHeight=root.Position.Y-startY; out.jumpSubjectMatches=replacement.CameraSubject==h
 task.wait(0.9); out.landedSubjectMatches=replacement.CameraSubject==h
end)
dummy:Destroy()
local current=workspace.CurrentCamera
current.CameraType=originalType current.CameraSubject=h
out.ok=ok out.error=err
return game:GetService("HttpService"):JSONEncode(out)
