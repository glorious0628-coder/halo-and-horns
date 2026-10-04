task.wait(7)
local p=game:GetService("Players").LocalPlayer
local report=p.PlayerScripts:FindFirstChild("CameraFollowQADeath")
local raw=report.Value
report:Destroy()
return raw
