"""
글꼴 견본 시트(검수 2026-10-06, 사용자 "로블록스 글씨가 못생겼다"): 연습 Studio(UiSandbox) Play 화면에
Enum.Font 전부 + Font.fromName 주요 가족(Regular / Bold / Heavy) + 지금 게임 글꼴(UIKit FONT.Id)로 같은 문장을 28px·18px로
쓰고 쪽마다 찍은 뒤, 꾸밈 4가지(그대로 / 진한 남색 테두리 2px / 테두리 + 위흰→아래크림 그라데이션 / 1px 그림자)를
밝은·어두운 바탕에 찍어 한 장으로 붙인다. 한글이 글꼴마다 실제로 바뀌는지(대체 글꼴로 같게 나오는지) 보는 것이 목적.
코드·장소 파일은 바꾸지 않는다(Play 중 PlayerGui에 견본 ScreenGui만 잠깐 만든다).

  py tools/font_samples_view.py [--out art/review/font_samples_2026-10-06.png]
STUDIO_NAME은 UiSandbox로 고정(dv.ensure_sandbox가 먼저 확인). 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import base64
import io
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLE = "어느 편에 설래요? 빛의 기사단 123,450골드 Lv10 Halo & Horns"
FAMILIES = ["BuilderSans", "FredokaOne", "LuckiestGuy", "Bangers", "GothamSSm", "Montserrat", "Nunito", "Arimo",
            "ComicNeueAngular", "Roboto", "SourceSansPro", "Oswald"]
GAME_FONT_ID = 12187370747  # UIKit FONT.Id
ROWS = 10

SETUP = r'''
local lp = game.Players.LocalPlayer
for _, g in lp.PlayerGui:GetChildren() do
    if g:IsA("ScreenGui") and g.Name ~= "FontSamples" then g.Enabled = false end
end
local entries = {}
table.insert(entries, { Label = "지금 게임 글꼴 (UIKit FONT 12187370747) Regular", Face = Font.fromId(%d, Enum.FontWeight.Regular) })
table.insert(entries, { Label = "지금 게임 글꼴 Bold", Face = Font.fromId(%d, Enum.FontWeight.Bold) })
table.insert(entries, { Label = "지금 게임 글꼴 ExtraBold", Face = Font.fromId(%d, Enum.FontWeight.ExtraBold) })
for _, fam in HttpService_decode(%s) do
    for _, w in { "Regular", "Bold", "Heavy" } do
        local ok, face = pcall(Font.fromName, fam, Enum.FontWeight[w])
        if ok and face then table.insert(entries, { Label = fam .. " " .. w, Face = face }) end
    end
end
for _, item in Enum.Font:GetEnumItems() do
    if item ~= Enum.Font.Unknown then
        local ok, face = pcall(Font.fromEnum, item)
        if ok and face then table.insert(entries, { Label = "Enum.Font." .. item.Name, Face = face }) end
    end
end
_G.FontSampleEntries = entries
return #entries
'''

PAGE = r'''
local lp = game.Players.LocalPlayer
local old = lp.PlayerGui:FindFirstChild("FontSamples")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.DisplayOrder, gui.ResetOnSpawn = "FontSamples", true, 1000, false
local bg = Instance.new("Frame")
bg.Size, bg.BackgroundColor3, bg.BorderSizePixel, bg.Parent = UDim2.fromScale(1, 1), Color3.fromRGB(24, 26, 36), 0, gui
local entries = _G.FontSampleEntries
local first, rows = %d, %d
for i = first, math.min(#entries, first + rows - 1) do
    local e = entries[i]
    local y = 64 + (i - first) * 65
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency, name.Position, name.Size = 1, UDim2.fromOffset(12, y), UDim2.fromOffset(1256, 14)
    name.Font, name.TextSize, name.TextColor3, name.TextXAlignment = Enum.Font.Arial, 13, Color3.fromRGB(150, 160, 190), Enum.TextXAlignment.Left
    name.Text = i .. ". " .. e.Label
    name.Parent = bg
    for j, size in { 28, 18 } do
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.Position = UDim2.fromOffset(12, y + 14 + (j - 1) * 30)
        t.Size = UDim2.fromOffset(1256, size + 4)
        t.FontFace, t.TextSize, t.TextColor3, t.TextXAlignment = e.Face, size, Color3.new(1, 1, 1), Enum.TextXAlignment.Left
        t.Text = %s
        t.Parent = bg
    end
end
gui.Parent = lp.PlayerGui
return "page " .. first
'''

DECOR = r'''
local lp = game.Players.LocalPlayer
local old = lp.PlayerGui:FindFirstChild("FontSamples")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.DisplayOrder, gui.ResetOnSpawn = "FontSamples", true, 1000, false
local face = Font.fromId(%d, Enum.FontWeight.Bold)
local text = %s
local NAVY = Color3.fromRGB(27, 33, 64)
local kinds = { "1. 그대로", "2. 진한 남색 테두리 2px (UIStroke)", "3. 테두리 + 위 흰색 → 아래 크림 (UIGradient)", "4. 1px 아래 그림자" }
for col, bgc in { Color3.fromRGB(236, 228, 206), Color3.fromRGB(24, 26, 36) } do
    local bg = Instance.new("Frame")
    bg.Position, bg.Size, bg.BackgroundColor3, bg.BorderSizePixel = UDim2.fromScale(0, (col - 1) * 0.5), UDim2.fromScale(1, 0.5), bgc, 0
    bg.Parent = gui
    for k, kind in kinds do
        local y = 40 + (k - 1) * 78
        if col == 1 then y += 24 end
        local cap = Instance.new("TextLabel")
        cap.BackgroundTransparency, cap.Position, cap.Size = 1, UDim2.fromOffset(12, y), UDim2.fromOffset(600, 14)
        cap.Font, cap.TextSize, cap.TextXAlignment = Enum.Font.Arial, 13, Enum.TextXAlignment.Left
        cap.TextColor3 = col == 1 and Color3.fromRGB(90, 80, 60) or Color3.fromRGB(150, 160, 190)
        cap.Text = kind
        cap.Parent = bg
        for j, size in { 28, 18 } do
            local pos = UDim2.fromOffset(12 + (j - 1) * 0, y + 16 + (j - 1) * 34)
            if k == 4 then
                local sh = Instance.new("TextLabel")
                sh.BackgroundTransparency, sh.Position, sh.Size = 1, pos + UDim2.fromOffset(0, 1), UDim2.fromOffset(1256, size + 6)
                sh.FontFace, sh.TextSize, sh.TextXAlignment, sh.TextColor3 = face, size, Enum.TextXAlignment.Left, NAVY
                sh.TextTransparency, sh.Text, sh.Parent = 0.2, text, bg
            end
            local t = Instance.new("TextLabel")
            t.BackgroundTransparency, t.Position, t.Size = 1, pos, UDim2.fromOffset(1256, size + 6)
            t.FontFace, t.TextSize, t.TextXAlignment = face, size, Enum.TextXAlignment.Left
            t.TextColor3 = (k == 1 and col == 1) and NAVY or Color3.new(1, 1, 1)
            t.Text = text
            t.ZIndex = 2
            t.Parent = bg
            if k == 2 or k == 3 then
                local s = Instance.new("UIStroke")
                s.Color, s.Thickness, s.ApplyStrokeMode = NAVY, 2, Enum.ApplyStrokeMode.Contextual
                s.LineJoinMode = Enum.LineJoinMode.Round
                s.Parent = t
            end
            if k == 3 then
                local g = Instance.new("UIGradient")
                g.Rotation = 90
                g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 236, 190))
                g.Parent = t
            end
        end
    end
end
gui.Parent = lp.PlayerGui
return "decor"
'''


def lua_str(s):
    return json.dumps(s, ensure_ascii=False)


def grab(c, cap_id):
    res = c.call("screen_capture", {"capture_id": cap_id})
    for part in res.get("content", []):
        if part.get("type") == "image":
            return base64.b64decode(part["data"])
    return None


def run(c, pages):
    from PIL import Image
    dv.stop_play(c)
    print(dv.luau(c, dv.SET_DEVICE % dv.DEVICES["pc"], "Edit"))
    c.call("start_stop_play", {"is_start": True})
    for _ in range(60):
        time.sleep(0.5)
        if "Client" in dv.state(c):
            break
    time.sleep(6)
    print(dv.luau(c, dv.PICK % "Halo", "Server"))
    time.sleep(4)
    setup = SETUP.replace("HttpService_decode(%s)", "game:GetService(\"HttpService\"):JSONDecode(%s)")
    n = int(dv.luau(c, setup % (GAME_FONT_ID, GAME_FONT_ID, GAME_FONT_ID, lua_str(json.dumps(FAMILIES))), "Client").strip())
    print("entries", n)
    for first in range(1, n + 1, ROWS):
        print(dv.luau(c, PAGE % (first, ROWS, lua_str(SAMPLE)), "Client").strip())
        time.sleep(3.5)  # font assets load on first use
        data = grab(c, f"fonts_{first}")
        if data:
            pages.append(Image.open(io.BytesIO(data)).convert("RGB"))
    print(dv.luau(c, DECOR % (GAME_FONT_ID, lua_str(SAMPLE)), "Client").strip())
    time.sleep(3)
    data = grab(c, "fonts_decor")
    if data:
        pages.append(Image.open(io.BytesIO(data)).convert("RGB"))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    out = os.path.join(ROOT, "art", "review", "font_samples_2026-10-06.png")
    if "--out" in args:
        out = args[args.index("--out") + 1]
    from PIL import Image
    pages = []
    with dv.sandbox() as c:  # sandbox check first; Play stop + device reset at the end, also after an error
        run(c, pages)
    if not pages:
        sys.exit("no captures")
    w = 1280
    scaled = [p.resize((w, int(p.height * w / p.width))) for p in pages]
    sheet = Image.new("RGB", (w, sum(p.height for p in scaled)), (0, 0, 0))
    y = 0
    for p in scaled:
        sheet.paste(p, (0, y))
        y += p.height
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out, optimize=True)
    print(out, sheet.size, len(pages), "pages")


if __name__ == "__main__":
    main()
