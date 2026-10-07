"""
촬영용 아바타 3안 (촬영 편집, 2026-10-07, 사용자 "아바타 시안 짜봐, 너의 재량에 맡길게" — 검수 전달).
FilmSet 테스트 Play 캐릭터에만 HumanoidDescription을 입힌다(사용자 진짜 Roblox 아바타·계정은 안 건드림).
재료 = Roblox가 만든 무료(가격 0) 카탈로그 아이템만(tools/devlog_avatar_catalog.py로 찾음). 로고·브랜드·유명 캐릭터 없음.

  FILM_OK=1 py tools/devlog_avatar.py photos      -> 3안 앞·옆·게임 화면 사진 + 시트 (검수 "전달함, 시작" 뒤에만)
  py tools/devlog_avatar.py sheet                 -> 사진으로 시트만 다시 만들기
  py tools/devlog_avatar.py lua <A|B|C>           -> 그 안을 입히는 서버 Luau 출력(촬영 스크립트가 씀)
"""

import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "devlog", "avatar")
SKIN = (234, 184, 146)   # one skin tone for all three looks

LOOKS = {
    "A": {"title": "A · Halo (white · gold · sky)", "faction": "Halo",
          "classic": {"Shirt": (382537702, "Teal Shirt")},
          "layered": [("Jacket", 7192546798, "Collared Leather Jacket - White", 6),
                      ("Pants", 7192681239, "Textured Leather Pants - White", 2),
                      ("LeftShoe", 9482987287, "Sneakers - White (L)", 1), ("RightShoe", 9482991343, "Sneakers - White (R)", 1)],
          "rigid": [("Hair", 376526888, "Straight Blonde Hair")]},
    "B": {"title": "B · Horns (black · red)", "faction": "Horns",
          "classic": {"Pants": (382537569, "Black Jeans")},
          "layered": [("TShirt", 7178740556, "Baseball Long Sleeve - Red", 3),
                      ("Jacket", 7192553841, "Zip Hoodie - Black", 6),
                      ("LeftShoe", 9483690316, "Canvas Shoes - Gray (L)", 1), ("RightShoe", 9483697460, "Canvas Shoes - Gray (R)", 1)],
          "rigid": [("Hair", 376527350, "Black Ponytail")]},
    "C": {"title": "C · Adventurer (teal · brown · bag)", "faction": "Neutral",
          "classic": {},
          "layered": [("Jacket", 8648389231, "Zip Hoodie - Teal", 6),
                      ("Pants", 6984740059, "Cargo Pants - Brown", 2),
                      ("LeftShoe", 9481782649, "Canvas Shoes - White (L)", 1), ("RightShoe", 9481786623, "Canvas Shoes - White (R)", 1)],
          "rigid": [("Hair", 63690008, "Pal Hair"), ("Back", 98752422639730, "Dog Backpack")]},
}


def lua_for(key):
    lk = LOOKS[key]
    acc = []
    for typ, aid, _, order in lk["layered"]:
        acc.append("{AccessoryType=Enum.AccessoryType.%s, AssetId=%d, IsLayered=true, Order=%d}" % (typ, aid, order))
    for typ, aid, _ in lk["rigid"]:
        acc.append("{AccessoryType=Enum.AccessoryType.%s, AssetId=%d, IsLayered=false}" % (typ, aid))
    classic = "".join("d.%s = %d; " % (k, v[0]) for k, v in lk["classic"].items())
    c = "Color3.fromRGB(%d,%d,%d)" % SKIN
    return r"""
local p = game:GetService('Players'):GetPlayers()[1]
if not p then return 'no player' end
local d = Instance.new('HumanoidDescription')
d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = %s, %s, %s, %s, %s, %s
d.BodyTypeScale, d.ProportionScale, d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = 0, 0, 1, 1, 1, 1
%s
d:SetAccessories({%s}, true)
local ok, err = pcall(p.LoadCharacterWithHumanoidDescriptionAsync, p, d)
return 'look %s: ' .. tostring(ok) .. ' ' .. tostring(err)
""" % (c, c, c, c, c, c, classic, ", ".join(acc), key)


SPOT = (14.0, 3.2, -30.0)     # Crossroads plaza (safe zone), the character faces +Z


def photos():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import devlog_film as D
    os.makedirs(OUT, exist_ok=True)
    x, y, z = SPOT
    f = D.Film()
    try:
        print(f.call("start_stop_play", {"is_start": True}), flush=True)
        time.sleep(14)
        print(f.hide_korean(), flush=True)
        f.lua(r"""
local pg = game.Players.LocalPlayer:WaitForChild('PlayerGui')
task.spawn(function() local t = os.clock() while os.clock() - t < 600 do
  local mg = pg:FindFirstChild('MainGui'); local m = mg and mg:FindFirstChild('PanelsModal')
  if m and m.Visible then m.Visible = false end
  local fp = mg and mg:FindFirstChild('FactionPicker'); if fp and fp.Visible then fp.Visible = false end
  task.wait(0.1) end end)
return 'modal hidden'""", "Client")
        for k, v in (("Class", "Warrior"), ("ClassChosen", True), ("Level", 30), ("PlaytimeSeconds", 1500), ("WeaponTier", 6)):
            f.debug(k, v)
        for key in ("A", "B", "C"):
            print(f.debug("Faction", LOOKS[key]["faction"]), flush=True)
            time.sleep(4)
            print(f.lua(lua_for(key)), flush=True)
            time.sleep(5)
            f.teleport((x, y + 2, z), (x, y + 2, z + 10))
            time.sleep(2.5)
            f.hud(False)
            for view, cam in (("front", (x, y + 2.6, z + 9)), ("side", (x + 9, y + 2.6, z))):
                f.lua(r"""
local RS = game:GetService('RunService'); local cam = workspace.CurrentCamera
_G.__filmTok = (_G.__filmTok or 0) + 1; local tok = _G.__filmTok; local name = 'HHC_Film' .. tok
RS:BindToRenderStep(name, Enum.RenderPriority.Last.Value, function()
  if _G.__filmTok ~= tok then pcall(RS.UnbindFromRenderStep, RS, name); return end
  cam.CameraType = Enum.CameraType.Scriptable
  cam.FieldOfView = 40
  cam.CFrame = CFrame.lookAt(Vector3.new(%f, %f, %f), Vector3.new(%f, %f, %f))
end)
return 'cam'""" % (cam[0], cam[1], cam[2], x, y + 1.6, z), "Client")
                time.sleep(1.2)
                D.grab_viewport(os.path.join(OUT, "%s_%s.png" % (key, view)))
            f.lua("_G.__filmTok = (_G.__filmTok or 0) + 1; local c = workspace.CurrentCamera; c.FieldOfView = 70; "
                  "c.CameraType = Enum.CameraType.Custom; return 'reset'", "Client")
            f.hud(True)
            f.teleport((x, y + 2, z + 6), (x, y + 2, z - 10))
            time.sleep(2.0)
            D.grab_viewport(os.path.join(OUT, "%s_game.png" % key))
            print("look", key, "done", flush=True)
    finally:
        try:
            f.lua("_G.__filmTok = (_G.__filmTok or 0) + 1; local c = workspace.CurrentCamera; c.FieldOfView = 70; "
                  "c.CameraType = Enum.CameraType.Custom; return 'reset'", "Client")
        except Exception:
            pass
        print(f.call("start_stop_play", {"is_start": False}), flush=True)
        f.close()
        D.minimize_film()
    sheet()


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    fb = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 30)
    fs = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 20)
    pw, ph = 420, 560          # front / side crops (portrait)
    gw, gh = 760, 428          # game screen
    rowh = ph + 200
    W = pw * 2 + gw + 80
    c = Image.new("RGB", (W, rowh * 3 + 20), (24, 26, 36))
    d = ImageDraw.Draw(c)
    for r, key in enumerate(("A", "B", "C")):
        y0 = 10 + r * rowh
        lk = LOOKS[key]
        d.text((20, y0 + 6), lk["title"], font=fb, fill=(255, 224, 120))
        x = 20
        for view in ("front", "side"):
            p = os.path.join(OUT, "%s_%s.png" % (key, view))
            if os.path.exists(p):
                im = Image.open(p).convert("RGB")
                cw = im.height * pw // ph          # centre crop to portrait
                im = im.crop(((im.width - cw) // 2, 0, (im.width + cw) // 2, im.height)).resize((pw, ph), Image.LANCZOS)
                c.paste(im, (x, y0 + 48))
            d.text((x + 8, y0 + 54), view, font=fs, fill=(255, 255, 255))
            x += pw + 10
        p = os.path.join(OUT, "%s_game.png" % key)
        if os.path.exists(p):
            im = Image.open(p).convert("RGB").resize((gw, gh), Image.LANCZOS)
            c.paste(im, (x + 10, y0 + 48))
        d.text((x + 18, y0 + 54), "in game (HUD on)", font=fs, fill=(255, 255, 255))
        items = ["%s: %s (%d)" % (k, v[1], v[0]) for k, v in lk["classic"].items()]
        items += ["%s (%d)" % (n, a) for _, a, n, _ in lk["layered"]] + ["%s (%d)" % (n, a) for _, a, n in lk["rigid"]]
        ty = y0 + 48 + gh + 14
        for k in range(0, len(items), 2):
            d.text((x + 10, ty), "  ·  ".join(items[k:k + 2]), font=fs, fill=(210, 214, 230))
            ty += 26
        d.text((x + 10, ty + 4), "all: Roblox-made, price 0 · skin RGB%s · blocky R15" % (SKIN,), font=fs, fill=(150, 156, 180))
    out = os.path.join(OUT, "avatar_looks_sheet.png")
    c.save(out)
    print(out)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "photos":
        photos()
    elif cmd == "sheet":
        sheet()
    elif cmd == "lua":
        print(lua_for(sys.argv[2]))
    else:
        sys.exit(__doc__)
