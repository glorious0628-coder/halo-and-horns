local p=game:GetService("Players").LocalPlayer
local Net=require(game.ReplicatedStorage.Shared.Net)
local c=p.Character local h=c:FindFirstChildOfClass("Humanoid") local r=c.HumanoidRootPart
local out={before={kills=p:GetAttribute("TotalKills"),xp=p:GetAttribute("XP"),level=p:GetAttribute("Level"),gold=p:GetAttribute("BankGold"),carried=p:GetAttribute("CarriedGold"),tutorial=p:GetAttribute("TutorialStep")},samples={}}
local ok,err=pcall(function()
 for i=1,35 do
  if p.Character~=c or h.Health<=0 or p:GetAttribute("TotalKills")>=5 then break end
  local nearest,distance=nil,math.huge
  for _,m in workspace.Monsters:GetChildren() do
   local part=m.PrimaryPart
   if part and m:GetAttribute("MonsterKind")=="Slime" then local d=(part.Position-r.Position).Magnitude if d<distance then nearest=part distance=d end end
  end
  if nearest then
   if distance>5 then h:MoveTo(nearest.Position) else h:MoveTo(r.Position) end
   if distance<12 then Net.Get("Swing"):FireServer() end
  end
  task.wait(1.1)
  table.insert(out.samples,{second=i*1.1,hp=h.Health,kills=p:GetAttribute("TotalKills"),charge=p:GetAttribute("Charge"),subjectMatches=workspace.CurrentCamera.CameraSubject==h,nearestDistance=distance})
 end
end)
h:MoveTo(r.Position)
out.after={kills=p:GetAttribute("TotalKills"),xp=p:GetAttribute("XP"),level=p:GetAttribute("Level"),gold=p:GetAttribute("BankGold"),carried=p:GetAttribute("CarriedGold"),tutorial=p:GetAttribute("TutorialStep"),health=h.Health}
out.ok=ok out.error=err
return game:GetService("HttpService"):JSONEncode(out)
