local P=game.Players.LocalPlayer
local R=game:GetService("RunService")
R:UnbindFromRenderStep("FaceSharpAuditCamera")
R:BindToRenderStep("FaceSharpAuditCamera",Enum.RenderPriority.Camera.Value+10,function()
 local c=P.Character;local root=c and c:FindFirstChild("HumanoidRootPart");if not root then return end
 local target=root.Position+Vector3.new(0,2.6,0)
 local cam=workspace.CurrentCamera
 cam.CameraType=Enum.CameraType.Scriptable
 cam.CFrame=CFrame.lookAt(target+root.CFrame.LookVector*12.5,target)
 cam.Focus=CFrame.new(target)
 for _,v in c:GetDescendants() do if v:IsA("BasePart") then v.LocalTransparencyModifier=0 end end
end)
return "frontal12.5"
