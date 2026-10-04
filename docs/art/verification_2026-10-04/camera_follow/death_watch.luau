local p=game:GetService("Players").LocalPlayer
local h=p.Character:FindFirstChildOfClass("Humanoid")
local report=Instance.new("StringValue") report.Name="CameraFollowQADeath" report.Parent=p.PlayerScripts
local out={before=true,beforeSubjectMatches=workspace.CurrentCamera.CameraSubject==h}
report.Value=game:GetService("HttpService"):JSONEncode(out)
h.Died:Once(function()
 out.deadSubjectMatches=workspace.CurrentCamera.CameraSubject==h
 report.Value=game:GetService("HttpService"):JSONEncode(out)
end)
p.CharacterAdded:Once(function(character)
 task.delay(1,function()
  if not report.Parent then return end
  out.characterChanged=character~=h.Parent
  out.respawnSubjectMatches=workspace.CurrentCamera.CameraSubject==character:FindFirstChildOfClass("Humanoid")
  out.respawnCostume=character:GetAttribute("HHC_CostumeId") or "OwnerAvatar"
  report.Value=game:GetService("HttpService"):JSONEncode(out)
 end)
end)
return "death observer ready"
