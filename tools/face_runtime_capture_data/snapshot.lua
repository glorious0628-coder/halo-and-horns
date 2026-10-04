local H=game:GetService("HttpService")
local P=game.Players.LocalPlayer
local cam=workspace.CurrentCamera
local rows={}
for _,v in P.Character:GetDescendants() do
 if v:IsA("MeshPart") and v.Transparency<1 then
 local s=v:FindFirstChildOfClass("SurfaceAppearance")
 table.insert(rows,{name=v.Name,mesh=v.MeshId,texture=v.TextureID,size={v.Size.X,v.Size.Y,v.Size.Z},color=s and s.ColorMap,normal=s and s.NormalMap,metal=s and s.MetalnessMap,rough=s and s.RoughnessMap}) end
end
local r=settings().Rendering
local data={faction=P:GetAttribute("Faction"),class=P:GetAttribute("Class"),parts=rows,render={QualityLevel=tostring(r.QualityLevel),EditQualityLevel=tostring(r.EditQualityLevel),EnableFRM=r.EnableFRM,GraphicsMode=tostring(r.GraphicsMode)},camera={position={cam.CFrame.X,cam.CFrame.Y,cam.CFrame.Z},focus={cam.Focus.X,cam.Focus.Y,cam.Focus.Z},fov=cam.FieldOfView,viewport={cam.ViewportSize.X,cam.ViewportSize.Y},distance=(cam.CFrame.Position-cam.Focus.Position).Magnitude}}
return H:JSONEncode(data)
