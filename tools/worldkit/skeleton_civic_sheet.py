"""skeleton_civic_sheet.py (이미지 생성 1, 10/11): contact sheets 'concept 2D | skeleton photos' for the civic skeletons.
usage: py tools/worldkit/skeleton_civic_sheet.py     (reads art/review/world/halo_v2/skeleton/*.jpg, writes <dir>/sheet_<building>.jpg + sheet_all.jpg)"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D = os.path.join(ROOT, os.environ.get("SK_OUT", "art/review/world/halo_v2/skeleton"))
A = os.path.join(ROOT, "art", "out", "s2", "halo")
ROWS = {
    "Gate": (["HaloProp_Gate_front_HQ_src.png", "HaloProp_Gate_left_HQ_src.png"],
             ["Gate_front", "Gate_34", "Gate_side", "Gate_back", "Gate_door_eye", "Gate_inside_eye", "Gate_through", "Gate_crown_close"]),
    "Tower_GateEast": (["HaloProp_Tower_v2_front_HQ_src.png", "HaloProp_Tower_v2_left_HQ_src.png"],
                       ["Tower_GateEast_front", "Tower_GateEast_34", "Tower_GateEast_side", "Tower_GateEast_back", "Tower_GateEast_door_eye", "Tower_GateEast_top"]),
    "Tower_Lookout": (["HaloProp_Tower_v2_front_HQ_src.png", "HaloProp_Tower_v2_back_HQ_src.png"],
                      ["Tower_Lookout_front", "Tower_Lookout_34", "Tower_Lookout_side", "Tower_Lookout_back", "Tower_Lookout_door_eye", "Tower_Lookout_top",
                       "Tower_Lookout_balcony_eye", "Tower_Lookout_balcony_sea"]),
    "Armory": (["HaloProp_Shop_front_HQ_src.png", "roofs/HaloDomeHouse_07_roof_v2.png"],
               ["Armory_front", "Armory_34", "Armory_side", "Armory_back", "Armory_door_eye", "Armory_roof"]),
}
NOTE = {"Armory": "2D 없음: 가게·집 2D로 언어만 참고"}
FONT = ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 16)


def load(path, w):
    if not os.path.exists(path):
        im = Image.new("RGB", (w, int(w * 0.5)), (60, 60, 60))
        ImageDraw.Draw(im).text((10, 10), "missing " + os.path.basename(path), fill=(255, 255, 0), font=FONT)
        return im
    im = Image.open(path).convert("RGB")
    return im.resize((w, int(im.height * w / im.width)))


sheets = []
for bid, (twod, views) in ROWS.items():
    cw, pw = 320, 480
    c = [load(os.path.join(A, t), cw) for t in twod]
    ph = [load(os.path.join(D, v + ".jpg"), pw) for v in views]
    for im, v in zip(ph, views):
        dr = ImageDraw.Draw(im)
        dr.rectangle([0, 0, 260, 22], fill=(0, 0, 0))
        dr.text((4, 2), v, fill=(255, 255, 0), font=ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 14))
    cols = 3
    prow = (len(ph) + cols - 1) // cols
    rh = max((max(p.height for p in ph[i * cols:(i + 1) * cols]) for i in range(prow)))
    H = max(sum(i.height for i in c) + 40, prow * rh)
    sh = Image.new("RGB", (cw + 10 + cols * pw, H), (250, 248, 242))
    y = 0
    for i in c:
        sh.paste(i, (0, y))
        y += i.height
    ImageDraw.Draw(sh).text((6, y + 6), NOTE.get(bid, "콘셉트 2D"), fill=(30, 30, 30), font=FONT)
    for k, p in enumerate(ph):
        sh.paste(p, (cw + 10 + (k % cols) * pw, (k // cols) * rh))
    out = os.path.join(D, "sheet_%s.jpg" % bid)
    sh.save(out, quality=86)
    sheets.append(sh)
    print(out, sh.size)
W = max(s.width for s in sheets)
allsh = Image.new("RGB", (W, sum(s.height for s in sheets)), "white")
y = 0
for s in sheets:
    allsh.paste(s, (0, y))
    y += s.height
allsh = allsh.resize((W // 2, y // 2))
allsh.save(os.path.join(D, "sheet_all.jpg"), quality=84)
print("sheet_all", allsh.size)
