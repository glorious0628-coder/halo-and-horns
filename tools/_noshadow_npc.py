"""No-shadow redraw driver for PEOPLE (이미지 생성 2, SPEC A23-150). One image at a time via tools/codex_image.py.
Usage: py tools/_noshadow_npc.py <NPC_Name> [...]   (names from docs/review/noshadow_redo_2026-10-12.md, section 2)
Front first (ref1 = old approved front), then back/left/right (ref1 = old that view for camera direction, ref2 = new front).
Output art/out/s2/noshadow/npc/<Name>_<view>_ns.png ; skips existing; exit 3 = ChatGPT usage out."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _noshadow_redo as R  # noqa: E402

OUT = os.path.join(R.ROOT, "art/out/s2/noshadow/npc")
RULES = ("Modest kid-friendly clothing that fully covers the torso, shoulders and arms as in the design; skirts knee-length or longer with tights or leggings; only the face and hands are bare. "
         "Friendly simple face, clean skin with NO freckles, NO marks, NO paint and NO patterns on the face. A small thin floating gold halo ring above the head. ")
LIGHT = ("Keep the 3D look: real volume, rounded edges, soft gentle form shading so every shape reads as 3D, smooth glossy toy plastic like ref1. "
         "Lighting: soft, even studio light from all around (like a bright light box). NO cast shadows, NO shadow on the ground or floor, NO contact shadows under the hat, hair, arms, "
         "skirt, cape or boots, NO dark gap between the legs, NO dark shadowed side, NO dark crevices, no strong glare on metal. Colours stay bright and true to the design. "
         "Plain light grey background, no floor. No text, no letters, no symbols, no extra objects, no light rays. Square image.")
FRONT = ("ref1 is an approved character design for a kid-friendly Roblox game. Redraw the SAME character exactly as a 3D-rendered blocky toy figure like ref1: same face shape, eyes, smile, hair, "
         "clothes, colours, accessories and held items, chunky rounded limbs, C-shaped hands, same proportions. Straight-on FRONT view at mid-height, relaxed A-pose, full body from halo to boots, "
         "centered with a margin. If ref1 is slightly angled, turn it to a straight front view. " + RULES + LIGHT)
VIEW = {"back": "the BACK (we see the back of the head and the back of the clothes, no face visible)",
        "left": "the character's LEFT side in exact profile (the character faces the RIGHT edge of the image)",
        "right": "the character's RIGHT side in exact profile (the character faces the LEFT edge of the image)"}
OTHER = ("ref1 is an older approved view of this character that shows the camera direction; ref2 is the character's new front view. Draw the SAME character exactly as in ref2 "
         "(same face, hair, clothes, colours, accessories, halo, proportions) as a 3D-rendered blocky toy figure, seen straight-on from %s, the same camera direction as ref1, at mid-height, "
         "relaxed standing pose, full body, centered, the same size and distance as ref2. " + RULES + LIGHT)
OTHER_NOREF = ("ref1 is the new front view of a character for a kid-friendly Roblox game. Draw the SAME character exactly (same face, hair, clothes, colours, accessories, halo, proportions) "
               "as a 3D-rendered blocky toy figure seen straight-on from %s at mid-height, relaxed standing pose, full body, centered, the same size and distance as ref1. " + RULES + LIGHT)


def old_view(front_path, name, view):
    d = os.path.dirname(front_path)
    for c in ("%s_%s_HQ_src.png" % (name, view), "%s_%s_src.png" % (name, view), "%s_%s_HQ.png" % (name, view)):
        p = os.path.join(d, c)
        if os.path.exists(p):
            return p
    return None


def main():
    table = R.rows()
    for name in sys.argv[1:]:
        old = table.get(name)
        if not old:
            print("not in doc:", name)
            continue
        oldp = os.path.join(R.ROOT, old)
        front = os.path.join(OUT, "%s_front_ns.png" % name)
        if not os.path.exists(front):
            rc = R.run(FRONT, [oldp], front)
            print(name, "front rc", rc, flush=True)
            if rc:
                return rc
        for v in ("back", "left", "right"):
            out = os.path.join(OUT, "%s_%s_ns.png" % (name, v))
            if os.path.exists(out):
                continue
            ov = old_view(oldp, name, v)
            rc = R.run(OTHER % VIEW[v], [ov, front], out) if ov else R.run(OTHER_NOREF % VIEW[v], [front], out)
            print(name, v, "rc", rc, "ref", os.path.basename(ov) if ov else "-", flush=True)
            if rc:
                return rc
    return 0


if __name__ == "__main__":
    sys.exit(main())
