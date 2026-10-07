local src=game.ServerStorage.CustomModels.PetBabySlime
local old=workspace:FindFirstChild('FilmPet'); if old then old:Destroy() end
local m=src:Clone(); m.Name='FilmPet'
for _,d in m:GetDescendants() do if d:IsA('BasePart') then d.Anchored=true; d.CanCollide=false end; if d:IsA('Script') or d:IsA('LocalScript') then d:Destroy() end end
local size=m:GetExtentsSize()
local hit=workspace:Raycast(Vector3.new(300,100,-40),Vector3.new(0,-200,0))
local gy=hit and hit.Position.Y or 0
m:PivotTo(CFrame.new(300, gy+size.Y/2, -40)*CFrame.Angles(0,math.rad(200),0))
m.Parent=workspace
return 'size '..tostring(size)..' ground '..gy..' pivot '..tostring(m:GetPivot().Position)
