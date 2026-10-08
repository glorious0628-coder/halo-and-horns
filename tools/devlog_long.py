"""
개발 일지 롱폼(16:9, 1920×1080, 30fps) — 촬영 편집 세션. tools/devlog_build.py의 줄·내레이션·효과음·자막 엔진을 그대로 쓰고
화면 크기와 판(board) 배치만 가로로 바꾼다.

  py tools/devlog_long.py ep01 [--no-tts]

입력: docs/devlog/<id>_plan.json ({"voice":…, "video": {id, style, lines…, meta}})
출력: build/devlog/<id>/<video id>/ final.mp4 · en.srt · ko.srt · meta.txt · check_sheet.png (git 밖)
"""

import json
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import devlog_build as B  # noqa: E402

# ---------------------------------------------------------------- landscape canvas
B.W, B.H = 1920, 1080
B.BOX_Y, B.BOX_H = 0, 1080
B.SAFE = (80, 60, 1840, 1020)
B.CX = 960
B.VBAND = (0, 1080)
B.NEON_CAP_Y, B.NEON_CAP_SIZE = 950, 88
B.NEON_CHUNK = (16, 3)
B.CHECK = (0.5, 320, 10)          # check sheet: frames per second, tile width, tiles per row
B.TARGET_MB = 95                   # the whole file under ~100 MB (handoff), bitrate from the length
B.CAPX = 960                       # captions on the frame's centre line
B.CAP_MAXW = 1500
B.SAFE_CHECK = False               # the Shorts safe-area check is for the 9:16 shorts only
W, H = B.W, B.H
CX = B.CX


def stage(inner="#4A5BC4", outer="#10122A"):
    c = B.radial(W, H, inner, outer, cy=0.5)
    floor = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(floor).ellipse((CX - 420, 800, CX + 420, 900), fill=(0, 0, 0, 110))
    c.alpha_composite(floor.filter(ImageFilter.GaussianBlur(18)))
    return c


def team_cells():
    """the team cards (one per session, 9 since 2026-10-08) in one centred row"""
    emo = ImageFont.truetype(B.EMOJI_FONT, 109)
    cells = []
    cw, ch, gap = 190, 290, 12  # 9 cards since 2026-10-08
    n = len(B.TEAM_CARDS)
    x0 = CX - (n * cw + (n - 1) * gap) // 2
    for i, (e, word, col) in enumerate(B.TEAM_CARDS):
        x = x0 + i * (cw + gap)
        cell = B.rounded((cw, ch), 34, B.hexrgb("#24306E"), outline=B.hexrgb(col), width=7)
        ic = Image.new("RGBA", (150, 150), (0, 0, 0, 0))
        ImageDraw.Draw(ic).text((10, 8), e, font=emo, embedded_color=True)
        ic = B.contain(ic.crop(ic.getbbox() or (0, 0, 1, 1)), 132, 132)
        cell.alpha_composite(ic, ((cw - ic.width) // 2, 34))
        lab = B.text_img([(word, B.hexrgb(col)[:3])], B.fit_size(word, cw - 24, 52))
        cell.alpha_composite(lab, ((cw - lab.width) // 2, ch - lab.height - 10))
        cells.append((cell, x + cw // 2, 430))
    return cells


GRID6 = [("Slime", "MonsterSlimeCube"), ("Baby Slime", "PetBabySlime"), ("Pumpkin Slime", "MonsterPumpkinSlime"),
         ("Pumpkin King", "MonsterPumpkinKing"), ("Bat Goblin", "MonsterBatGoblin"), ("Little Ghost", "MonsterLittleGhost")]


def grid6_cells():
    """one row, grouped by family with wider gaps between families (A23-45): slimes | pumpkins | goblin | ghost"""
    cells = []
    cw, ch, gap, fam_gap = 262, 340, 14, 54
    groups = [2, 2, 1, 1]
    total = 6 * cw + (6 - len(groups)) * gap + (len(groups) - 1) * fam_gap
    x = CX - total // 2
    k = 0
    for gi, n in enumerate(groups):
        for j in range(n):
            name, fid = GRID6[k]
            cell = B.rounded((cw, ch), 28, (255, 255, 255, 40), outline=(255, 255, 255, 110), width=3)
            m = B.contain(B.load_rgba("art/models/tripo/%s_preview.png" % fid), 230, 230)
            cell.alpha_composite(m, ((cw - m.width) // 2, 14))
            lab = B.text_img([(name, B.WHITE)], B.fit_size(name, cw - 20, 40))
            cell.alpha_composite(lab, ((cw - lab.width) // 2, ch - 70))
            cells.append((cell, x + cw // 2, 430))
            x += cw + (gap if j < n - 1 else fam_gap)
            k += 1
    return cells


FAMILIES = [("GOBLINS", "#7CE07C", ["MonsterBatGoblin"]), ("PUMPKINS", "#FF9A3C", ["MonsterPumpkinSlime", "MonsterPumpkinKing"]),
            ("GHOSTS", "#BFA8FF", ["MonsterGhostMinion", "MonsterLittleGhost", "MonsterGhostKing"])]


def board_families():
    """A23-45: each family in its own box (no mixing)"""
    c = B.radial(W, H, "#3A2A6A", "#120A22")
    bw, bh, gap = 540, 760, 40
    x0 = CX - (3 * bw + 2 * gap) // 2
    for i, (title, col, models) in enumerate(FAMILIES):
        x = x0 + i * (bw + gap)
        c.alpha_composite(B.rounded((bw, bh), 36, (255, 255, 255, 28), outline=B.hexrgb(col), width=8), (x, 60))
        B.paste_center(c, B.text_img([(title, B.hexrgb(col)[:3])], 72), x + bw // 2, 130)
        n = len(models)
        for k, mid in enumerate(models):
            m = B.contain(B.load_rgba("art/models/tripo/%s_preview.png" % mid), 300 if n == 1 else 250, 420 if n == 1 else 300)
            cx = x + bw // 2 if n == 1 else x + 30 + (bw - 60) * (k + 0.5) / n
            cy = 470 if n == 1 else (420 if k % 2 == 0 else 560)
            B.soft_shadow_paste(c, m, (int(cx - m.width / 2), int(cy - m.height / 2)))
    return c


def board_end():
    c = B.radial(W, H, "#FF9A3C", "#3B0F4F", cy=0.42)
    king = B.contain(B.load_rgba("art/models/tripo/MonsterPumpkinKing_preview.png"), 560, 560)
    B.soft_shadow_paste(c, king, (CX - king.width // 2 - 380, 260))
    buddy = B.contain(B.load_rgba("art/models/tripo/MonsterPumpkinSlime_preview.png"), 230, 230)
    B.soft_shadow_paste(c, buddy, (CX - 180, 560))
    B.paste_center(c, B.text_img([("HALO & HORNS", (255, 243, 214))], 120), CX + 330, 330)
    B.paste_center(c, B.text_img([("BETA  OCT 31", B.GOLD)], 110), CX + 330, 480)
    B.paste_center(c, B.text_img([("Subscribe for #2!", B.WHITE)], 70), CX + 330, 620)
    return c


def board_title():
    c = B.radial(W, H, "#2B3A8A", "#0A0D22", cy=0.45)
    king = B.contain(B.load_rgba("art/models/tripo/MonsterPumpkinKing_preview.png"), 420, 420)
    slime = B.contain(B.load_rgba("art/models/tripo/MonsterSlimeCube_preview.png"), 300, 300)
    B.soft_shadow_paste(c, king, (CX - 760, 420))
    B.soft_shadow_paste(c, slime, (CX + 460, 520))
    B.paste_center(c, B.neon_img([("HALO & HORNS", B.NEON["yellow"])], 150), CX, 320)
    B.paste_center(c, B.neon_img([("DEVLOG #1", B.NEON["cyan"])], 110), CX, 500)
    return c


HUD_EN = {"face": "Face", "hp": "HP", "mp": "MP", "lv": "Lv · Power", "xp": "XP", "mini": "Mini map", "quest": "Quests",
          "war": "War meter", "chips": "Chips", "event": "Next event", "note": "Alerts", "atk": "Attack", "q": "Skill Q", "z": "Skill Z",
          "auto": "Auto", "ghost": "Ghost", "pot": "Potions", "pet": "Pet", "bag": "Bag", "map": "World map", "menu": "Menu",
          "m1": "Hero", "m2": "Bag", "m3": "Skills", "m4": "Map", "m5": "Rank", "m6": "Pet", "m7": "Settings", "m8": "Menu"}


def board_hud_ab(shot):
    """the two gray-box HUD plans (docs/design/hud_layout_{A,B}_2026-10-06.json) redrawn with English labels"""
    which = shot.get("which", "A")
    spec = json.load(open(os.path.join(B.ROOT, "docs", "design", "hud_layout_%s_2026-10-06.json" % which), encoding="utf-8"))
    c = B.radial(W, H, "#3A4A78", "#141A2E")
    bw, bh = 1360, 765
    sx, sy, ox, oy = bw / 1280, bh / 720, CX - bw // 2 + 60, 70   # the caption line (y 950) stays below the box
    d = ImageDraw.Draw(c)
    d.rounded_rectangle((ox - 6, oy - 6, ox + bw + 6, oy + bh + 6), 18, fill=(70, 86, 120, 255), outline=(220, 228, 255, 255), width=4)
    cols = {"A": (255, 190, 90), "B": (90, 200, 255)}
    col = cols.get(which, (255, 255, 255))
    for it in spec.get("items", []):
        r = it.get("pc") or {}
        if not r or r.get("w", 0) <= 0:
            continue
        x0, y0 = ox + r["x"] * sx, oy + r["y"] * sy
        x1, y1 = x0 + r["w"] * sx, y0 + r["h"] * sy
        if it.get("shape") == "round":
            d.ellipse((x0, y0, x1, y1), fill=col + (200,), outline=(255, 255, 255, 255), width=3)
        else:
            d.rounded_rectangle((x0, y0, x1, y1), 10, fill=col + (200,), outline=(255, 255, 255, 255), width=3)
        lab = HUD_EN.get(it.get("id", ""), it.get("id", "").title())
        fs = max(14, min(30, int((y1 - y0) * 0.55)))
        f = B.font(fs)
        while fs > 12 and f.getlength(lab) > (x1 - x0) - 8:
            fs -= 2
            f = B.font(fs)
        d.text(((x0 + x1) / 2, (y0 + y1) / 2), lab, font=f, fill=(20, 20, 30, 255), anchor="mm")
    B.paste_center(c, B.neon_img([(which, col)], 170), ox // 2, oy + bh // 2)  # outside the box, left
    return c


def board_guide_ba(shot):
    """the guide window before (no face) and after (the new guide portrait)"""
    c = B.radial(W, H, "#2B3A8A", "#0A0D22")
    for k, lab in enumerate(("BEFORE", "AFTER")):
        x = CX - 760 + k * 820
        c.alpha_composite(B.rounded((700, 640), 30, (24, 28, 44, 255), outline=(240, 200, 90, 255), width=6), (x, 140))
        if k == 0:
            B.paste_center(c, B.neon_img([("?", B.NEON["white"])], 260), x + 350, 440)
        else:
            p = B.contain(B.load_rgba("art/ui/PTR_GuideHalo.png"), 520, 520)
            c.alpha_composite(p, (x + 350 - p.width // 2, 440 - p.height // 2 - 10))
        B.paste_center(c, B.neon_img([(lab, B.NEON["red"] if k == 0 else B.NEON["green"])], 90), x + 350, 110)
    return c


def board_angel_devil():
    c = Image.new("RGBA", (W, H))
    c.alpha_composite(B.gradient(W // 2, H, "#FFF1B8", "#7CC8FF"), (0, 0))
    c.alpha_composite(B.gradient(W // 2, H, "#6A1236", "#1A0614"), (W // 2, 0))
    halo = B.contain(B.load_rgba("art/ui/CLS_HaloWarrior_M.png"), 520, 760)
    horn = B.contain(B.load_rgba("art/ui/CLS_HornsWarrior_F.png"), 520, 760)
    B.soft_shadow_paste(c, halo, (W // 4 - halo.width // 2, 80))
    B.soft_shadow_paste(c, horn, (3 * W // 4 - horn.width // 2, 80))
    return c


def board_classes():
    """the 8 class pictures in one slightly overlapping row, big and centred above the caption line"""
    c = B.radial(W, H, "#3B4BA0", "#120F2A")
    files = ["CLS_HaloWarrior_M", "CLS_HaloMage_F", "CLS_HaloArcher_M", "CLS_HornsWarrior_F", "CLS_HornsMage_M", "CLS_HornsArcher_F",
             "CLS_ArtisanWarrior_M", "CLS_ArtisanMage_F"]
    step, bw, bh = 222, 320, 600
    x0 = CX - (7 * step) // 2
    for k, f in enumerate(files):
        im = B.contain(B.load_rgba("art/ui/%s.png" % f), bw, bh)
        B.soft_shadow_paste(c, im, (x0 + k * step - im.width // 2, 250 + (30 if k % 2 else 0)))
    return c


def board_doodle():
    c = B.radial(W, H, "#F7F1E3", "#D9CDB0", cy=0.45)
    d = ImageDraw.Draw(c)
    rng = random.Random(5)
    ink = (40, 40, 50, 255)

    def wob(pts, w=9):
        d.line([(x + rng.uniform(-6, 6), y + rng.uniform(-6, 6)) for x, y in pts], fill=ink, width=w, joint="curve")

    cx, cy = CX, 520
    d.ellipse((cx - 95, cy - 330, cx + 85, cy - 150), outline=ink, width=9)
    d.ellipse((cx - 50, cy - 270, cx - 30, cy - 250), fill=ink)
    d.ellipse((cx + 15, cy - 265, cx + 33, cy - 247), fill=ink)
    d.arc((cx - 45, cy - 240, cx + 40, cy - 190), 20, 160, fill=ink, width=7)
    wob([(cx, cy - 150), (cx + 8, cy - 40), (cx - 4, cy + 90)])
    wob([(cx + 4, cy - 100), (cx - 120, cy - 30), (cx - 170, cy - 80)])
    wob([(cx + 4, cy - 100), (cx + 110, cy - 150), (cx + 160, cy - 120)])
    wob([(cx - 4, cy + 90), (cx - 90, cy + 230)])
    wob([(cx - 4, cy + 90), (cx + 80, cy + 240), (cx + 120, cy + 236)])
    d.polygon([(cx - 70, cy - 330), (cx - 40, cy - 400), (cx - 10, cy - 330)], outline=ink, width=7)
    return c


def board_picture(img, label):
    c = B.radial(W, H, "#3A3F86", "#11122C")
    p = B.polaroid(B.load_rgba(img), 600, label)
    B.soft_shadow_paste(c, p, (CX - p.width // 2, 40))
    return c


# route the landscape boards through devlog_build's get_board
B.board_stage = lambda *a, **k: stage(*a, **k)
B.team_cells = team_cells
B.grid6_cells = grid6_cells
B.board_end = board_end
B.board_angel_devil = board_angel_devil
B.board_classes = board_classes
B.board_doodle = board_doodle
B.board_picture = board_picture
B.EXTRA_BOARDS = {"title": lambda shot: board_title(), "families": lambda shot: board_families(),
                  "hud_ab": board_hud_ab, "guide_ba": board_guide_ba}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    pid = sys.argv[1]
    plan = json.load(open(os.path.join(B.ROOT, "docs", "devlog", pid + "_plan.json"), encoding="utf-8"))
    out_root = os.path.join(B.ROOT, "build", "devlog", pid)
    B.build_short(plan["video"], plan["voice"], out_root, do_tts="--no-tts" not in sys.argv)


if __name__ == "__main__":
    main()
