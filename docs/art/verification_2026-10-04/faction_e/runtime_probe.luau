-- Run in Studio MCP Client. Read-only runtime evidence, viewport units are logical pixels.
local p = game.Players.LocalPlayer
local gui = p.PlayerGui:FindFirstChild("MainGui")
local root = gui and gui:FindFirstChild("FactionPicker")
local function xy(v) return {v.X, v.Y} end
local out = {viewport=xy(workspace.CurrentCamera.ViewportSize), locale=p.LocaleId,
    faction=p:GetAttribute("Faction"), class=p:GetAttribute("Class"),
    visible=root and root.Visible, cards={}, panels={}, worldEnabled=0,
    subjectMatches=workspace.CurrentCamera.CameraSubject==p.Character:FindFirstChildOfClass("Humanoid")}
if root then
    out.root={position=xy(root.AbsolutePosition),size=xy(root.AbsoluteSize),attrs=root:GetAttributes()}
    local page=root:FindFirstChild("FactionEContent",true)
    if page and page:IsA("ScrollingFrame") then
        out.page={size=xy(page.AbsoluteSize),canvas=xy(page.AbsoluteCanvasSize),position=xy(page.CanvasPosition)}
    end
    local row=root:FindFirstChild("Cards",true)
    if row then
        out.scroll={enabled=row.ScrollingEnabled,direction=tostring(row.ScrollingDirection),
            size=xy(row.AbsoluteSize),canvas=xy(row.AbsoluteCanvasSize),position=xy(row.CanvasPosition)}
        for _,id in {"Halo","Horns","Neutral"} do
            local card=row:FindFirstChild("Card_"..id)
            if card then
                local body=card.Body local art=body:FindFirstChild("FactionEArt")
                local b=body:FindFirstChild("ChooseButtonE")
                table.insert(out.cards,{id=id,position=xy(card.AbsolutePosition-root.AbsolutePosition),
                    size=xy(card.AbsoluteSize),mode=body:GetAttribute("FactionERenderMode"),
                    loaded=art and art.IsLoaded,image=art and art.Image,scaleType=art and tostring(art.ScaleType),attrs=art and art:GetAttributes(),
                    button={size=xy(b.AbsoluteSize),position=xy(b.AbsolutePosition-root.AbsolutePosition),visible=b.Visible}})
            end
        end
    end
    for _,name in {"Title","Premise","Footer"} do
        local a=root:FindFirstChild("FactionE"..name,true)
        if a then table.insert(out.panels,{name=name,image=a.Image,scaleType=tostring(a.ScaleType),attrs=a:GetAttributes(),loaded=a.IsLoaded,
            size=xy(a.AbsoluteSize),position=xy(a.AbsolutePosition-root.AbsolutePosition)}) end
    end
end
for _,v in workspace:GetDescendants() do
    if (v:IsA("BillboardGui") or v:IsA("SurfaceGui")) and v.Enabled then out.worldEnabled+=1 end
end
pcall(function()out.coreChat=game.StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat)end)
out.chat={}
for _,v in game.TextChatService:GetChildren() do
    pcall(function()out.chat[v.ClassName]=v.Enabled end)
end
return game.HttpService:JSONEncode(out)
