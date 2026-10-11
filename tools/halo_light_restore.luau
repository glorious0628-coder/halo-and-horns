if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local L = game:GetService("Lighting")
local raw = L:GetAttribute("ImgDevSimSaved")
if not raw then return "nothing saved" end
local saved = game:GetService("HttpService"):JSONDecode(raw)
for k, v in saved.props do
	L[k] = type(v) == "table" and Color3.new(v[1], v[2], v[3]) or v
end
for _, e in L:GetChildren() do
	if e:IsA("PostEffect") then
		if string.find(e.Name, "^ImgDev") then
			e:Destroy()
		elseif saved.fx[e.Name] ~= nil then
			e.Enabled = saved.fx[e.Name]
		end
	end
end
L:SetAttribute("ImgDevSimSaved", nil)
local fx = {}
for _, e in L:GetChildren() do if e:IsA("PostEffect") then table.insert(fx, e.Name .. "=" .. tostring(e.Enabled)) end end
return string.format("restored B %.2f Spec %.2f Diff %.2f Clock %.2f Exp %.2f Lat %.1f fx %s", L.Brightness,
	L.EnvironmentSpecularScale, L.EnvironmentDiffuseScale, L.ClockTime, L.ExposureCompensation, L.GeographicLatitude,
	table.concat(fx, ","))
