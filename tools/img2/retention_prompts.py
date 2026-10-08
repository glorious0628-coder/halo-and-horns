"""A23-77 attendance board + A23-79 small art (weekly box, claimed stamp, day-count ribbon, King Diary, candy jar,
friend invite, 'Saved!' marker): Medium candidate prompts A / B -> art/prompts/<tag>.txt + Firefly queue
build/montex/ret_queue.js (window.__q_ret, run with __s2_runMed).

  py tools/img2/retention_prompts.py
"""
import json

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
STYLE = ("Glossy 3D-rendered toy-like game icon, chunky rounded shapes with soft bevels, soft glossy toy plastic with "
         "polished gold accents, bright kid-friendly colors, soft light from the top left, thick even dark navy outline "
         "around the whole silhouette with a crisp hard edge, one single solid object, nothing floating around it, simple "
         "bold silhouette that reads at 32 pixels, centered filling 80 percent of a square, {view}. Isolated on a plain flat "
         "medium gray background with a wide empty margin, clean shadowless backdrop. No letters, no numbers, no light rays.")
TQ = "slight three-quarter front view"
FV = "straight front view"

ITEMS = {
    "IconWeeklyBox_A": (TQ, "Game inventory icon of a special weekly reward gift box: one chunky square gift box with a lid, "
                            "the box split down the middle into two colors, the left half pearly white with gold trim and the "
                            "right half deep plum purple with red trim, a fat glossy gold bow on top, a small gold halo ring charm on the left loop of the bow and a small pair of red horn "
                            "charms on the right loop."),
    "IconWeeklyBox_B": (TQ, "Game inventory icon of a special weekly reward gift box: one chunky square royal blue gift box "
                            "with a lid, gold corner caps, a wide gold ribbon band and a fat glossy gold bow on top, a glossy "
                            "gold broken crown piece emblem with one purple gem fixed on the front of the box."),
    "StampClaimed_A": (FV, "Game UI stamp mark meaning the reward is already collected: one round glossy green seal badge "
                           "with a smooth wavy scalloped rim and a thick bold white check mark in the middle, the whole "
                           "badge tilted a little like a stamp pressed on paper, smooth surfaces without lines or pleats."),
    "StampClaimed_B": (FV, "Game UI stamp mark meaning the reward is already collected: one round stamp made of a thick "
                           "glossy green ring with a bold chunky white check mark inside it, the check mark breaking out "
                           "past the ring at the top right, the whole stamp tilted a little."),
    "RibbonDays_A": (FV, "Game UI milestone award: one round glossy gold award medallion with a smooth wavy scalloped rim "
                         "and a large flat blank cream-colored center disc left empty, two short deep red ribbon tails "
                         "hanging below, smooth surfaces without pleats or lines."),
    "RibbonDays_B": (FV, "Game UI milestone award banner: one horizontal glossy gold ribbon banner with folded swallowtail "
                         "ends curling back, a large flat blank cream-colored middle area left empty, a small gold star on "
                         "top of the middle."),
    "IconKingDiary_A": (TQ, "Game inventory icon of the Pumpkin King's diary: one chunky closed storybook with a glossy "
                            "orange hardcover and a dark green spine, a round orange pumpkin ornament with a green stem and "
                            "a curly leaf on the front cover, the pumpkin smooth with no face, a small gold crown on top of "
                            "the pumpkin ornament, gold corner caps, a purple ribbon bookmark hanging out of the pages."),
    "IconKingDiary_B": (TQ, "Game inventory icon of the Pumpkin King's diary: one chunky thick journal with a deep purple "
                            "cover, orange corner caps and a gold clasp, a small smooth round orange pumpkin charm with a "
                            "green stem on the clasp, no face on the pumpkin, a tiny gold crown above it on the cover, cream "
                            "pages visible at the side."),
    "IconCandyJar_A": (TQ, "Game inventory icon of a candy jar: one round clear glass jar with a glossy gold screw lid, "
                           "filled to the top with colorful wrapped candies in orange, purple and lime green, a small orange "
                           "ribbon bow tied around the neck of the jar, plain candies without faces."),
    "IconCandyJar_B": (TQ, "Game inventory icon of a candy jar: one chunky clear glass jar shaped like a round pumpkin, a "
                           "green stem knob on its lid, filled with colorful striped wrapped candies in orange, purple and "
                           "green, a soft shine on the glass, no face on the jar or the candies."),
    "IconInviteFriend_A": (TQ, "Game UI icon for inviting a friend: one chunky closed envelope in cream white with a pink "
                               "heart-shaped seal in the middle, a round sticker of a small gold halo with tiny white wings "
                               "on the upper left corner and a round sticker of small red horns on the lower right corner."),
    "IconInviteFriend_B": (TQ, "Game UI icon for inviting a friend: one chunky open envelope in sky blue with a blank cream "
                               "card sticking out of it, a small red heart on the card, a round sticker with a gold halo on "
                               "the left of the envelope and a round sticker with small red horns on the right."),
    "IconSaved_A": (FV, "Game UI icon meaning the progress is saved: one small glossy green bookmark ribbon tab with a "
                        "V-notched bottom end and a bold white check mark on it."),
    "IconSaved_B": (FV, "Game UI icon meaning the progress is saved: one small checkpoint flag, a glossy green pennant "
                        "flag with a bold white check mark on a short gold pole with a round gold knob, standing on a "
                        "small round grass-topped base."),
}

q = []
for tag, (view, body) in ITEMS.items():
    t = body + " " + STYLE.format(view=view)
    assert len(t) < 1000, (tag, len(t))
    with open(ROOT + "art/prompts/" + tag + ".txt", "w", encoding="utf-8", newline="\n") as f:
        f.write(t + "\n")
    q.append({"tag": tag, "a": "정사각형 (1:1)", "t": t})
    print(tag, len(t))
with open(ROOT + "build/montex/ret_queue.js", "w", encoding="utf-8", newline="\n") as f:
    f.write("window.__q_ret=" + json.dumps(q, ensure_ascii=False) + ";\n")
print(len(q), "items")
