"""A23-77 / A23-79 picks (검수 2026-10-08) -> High redraw prompts art/prompts/<tag>_HQ.txt + Firefly queue
build/montex/ret_hq_queue.js (window.__q_rethq, run with __s2_runHQ; reference = the picked Medium generation).

  py tools/img2/retention_hq.py <tag>=<presigned url> ...
"""
import json
import sys

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
KEEP = ("Redraw the attached reference image as the same game icon, cleaner, sharper and more polished: keep its exact "
        "silhouette, proportions, outline thickness, colors and every part in the same place and the same size in the frame")
STYLE = ("Glossy 3D-rendered toy-like game icon, chunky rounded shapes with soft bevels, thick even dark navy outline around "
         "the whole silhouette with a crisp hard edge, soft light from the top left, simple bold silhouette that reads at "
         "32 pixels, centered, {view}. Plain flat medium gray background with a wide empty margin, shadowless. "
         "No letters, no numbers, no light rays.")
TQ, FV = "slight three-quarter front view", "front view"
ITEMS = {
    "IconWeeklyBox_A2b": (TQ, ".", "One chunky square gift box split down the middle, the left half pearly white with a gold "
                          "ribbon and the right half deep plum purple with a red ribbon, a fat glossy gold bow on top with a "
                          "small gold halo ring standing on the left loop and a pair of small curved red devil horns "
                          "standing on the right loop."),
    "StampClaimed_A": (FV, ".", "One round glossy green seal badge with a smooth wavy scalloped rim, a thin gold inner ring "
                       "and a thick bold white check mark in the middle."),
    "RibbonDays_A": (FV, ".", "One round glossy gold award medallion with a smooth wavy scalloped rim, a large flat blank "
                     "cream-colored center disc left empty, two short deep red ribbon tails hanging below, smooth surfaces "
                     "without pleats or lines."),
    "IconKingDiary_A": (TQ, ".", "One chunky closed storybook with a glossy orange hardcover, a dark green spine with gold "
                        "bands, a round orange pumpkin ornament with a green stem and a curly leaf on the front cover, the "
                        "pumpkin smooth with no face, a small gold crown above it, gold corner caps and a purple ribbon "
                        "bookmark hanging out of the pages."),
    "IconCandyJar_A": (TQ, ".", "One round clear glass jar with a glossy gold screw lid, filled with colorful wrapped "
                       "candies in orange, purple and lime green, a small orange ribbon bow tied around the neck, plain "
                       "candies without faces."),
    "IconInviteFriend_B": (TQ, ", except the round sticker on the right.",
                           "One open sky blue envelope, a blank cream card with a red heart sticking out, a round sticker "
                           "with a gold halo ring on the left, and on the right a round sticker with a pair of tall "
                           "pointed red devil horns curving upward, plain solid red with no white dots, clearly horns, "
                           "not eyes."),
    "IconSaved_A": (FV, ".", "One small glossy green bookmark ribbon tab with a gold rim, a V-notched bottom end and a bold "
                    "white check mark in the middle."),
}
urls = dict(a.split("=", 1) for a in sys.argv[1:])
q = []
for tag, (view, keep_end, body) in ITEMS.items():
    t = KEEP + keep_end + " " + body + " " + STYLE.format(view=view)
    assert len(t) < 990, (tag, len(t))
    with open(ROOT + "art/prompts/" + tag + "_HQ.txt", "w", encoding="utf-8", newline="\n") as f:
        f.write("[reference: Firefly 참조 이미지 = art/out/s2/ret/" + tag + "_src.png (the picked Medium generation), High]\n" + t + "\n")
    q.append({"tag": tag + "_HQ", "a": "정사각형 (1:1)", "urls": [urls.get(tag, "")], "t": t})
    print(tag, len(t))
with open(ROOT + "build/montex/ret_hq_queue.js", "w", encoding="utf-8", newline="\n") as f:
    f.write("window.__q_rethq=" + json.dumps(q, ensure_ascii=False) + ";\n")
