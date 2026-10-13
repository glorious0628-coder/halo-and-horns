"""House-chunk 4-view redraw driver (이미지 생성 2). Usage: py tools/_chunk_redo.py <HaloChunk_Id> [...]
Reads art/prompts/house_chunks_queue_2026-10-13.json. Front first (ref = crop), then back/left/right with the new front as ref.
Output art/out/s2/noshadow/chunks/<Id>_<view>_ns.png (+ .txt); skips existing; returns 3 when ChatGPT usage is out."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _noshadow_redo as R

Q = os.path.join(R.ROOT, "art/prompts/house_chunks_queue_2026-10-13.json")
OUT = os.path.join(R.ROOT, "art/out/s2/noshadow/chunks")
ISO = ("Draw ONLY this one piece, isolated and complete, as a standalone 3D-rendered toy-like object (no wall, no neighbouring building parts, no background objects, "
       "no pot or floor unless the piece itself includes it); if it is a flat panel give it a realistic thin thickness. ")
FRONT = ("ref1 is a crop from an approved concept of a kid-friendly Roblox building. It shows: %s. Copy its exact shapes, parts and colours (never its shadows or glow), seen straight-on from the FRONT at mid-height, "
         "perfectly centered, whole piece in frame with a margin. " + ISO + R.LIGHT)
OTHER = ("ref1 is the new front view of a piece of a kid-friendly Roblox building (%s). Draw the SAME piece exactly (same shapes, parts, colours, proportions, materials) as a 3D-rendered toy-like object "
         "seen straight-on from the %s, at mid-height, centered, the SAME camera height, size and distance as ref1. Anything that faces one way (flowers, a lamp) must turn with the piece: seen from the side it shows its side, from behind its back. " + ISO + R.LIGHT)
BACKREF = ("ref1 is the new front view and ref2 an old view of the same piece of a kid-friendly Roblox building (%s), ref2 shows it from the BACK. Draw the SAME piece exactly as ref1 (shapes, parts, colours) "
           "from the BACK like ref2, as a 3D-rendered toy-like object, same camera height, size and distance as ref1. " + ISO + R.LIGHT)
CHUNKY = ("Make the foliage Tripo-friendly: BIG chunky simple leaves, thick short stems, a few big clear clumps with clear boundaries; NO tiny leaves, NO thin wiry vines, NO fine texture. ")
CHUNKY_IDS = ("Ivy", "FlowerBush", "WindowBox", "SunflowerBed", "RoseArch", "RoseTrellis", "Pond", "FlowerBuckets", "RoundTree", "CastleHedge")
SIDES = {"left": "LEFT side (90 degrees to the left of ref1's front)", "right": "RIGHT side (90 degrees to the right of ref1's front)"}


def main():
    items = {i["id"]: i for i in json.load(open(Q, encoding="utf-8"))["items"]}
    for name in sys.argv[1:]:
        it = items[name]
        refs = [os.path.join(R.ROOT, r.get("crop") or r["image"]) for r in it["refs"]]
        has_back = len(it["refs"]) > 1 and "back" in it["refs"][1]["image"]
        draw = it["draw"].split(" 3D note:")[0]
        if any(k in name for k in CHUNKY_IDS):
            draw += ". " + CHUNKY
        if "Hedge" in name:
            draw += "The hedge block is chunky: the green block is about 3 times as long as it is tall, built from only about 8 to 10 BIG round leaf clumps in a row (each clump as tall as the block), clear soft boundaries between clumps, leaf shapes drawn big and simple. "
        if "Trellis" in name:
            draw += "Lattice bars must be THICK and chunky (not thin sticks), big squares. "
        front = os.path.join(OUT, "%s_front_ns.png" % name)
        if not os.path.exists(front):
            rc = R.run(FRONT % draw, [refs[0]], front)
            if rc:
                return rc
        for v in ("back", "left", "right"):
            out = os.path.join(OUT, "%s_%s_ns.png" % (name, v))
            if os.path.exists(out):
                continue
            if v == "back" and has_back:
                rc = R.run(BACKREF % draw, [front, refs[1]], out)
            elif v == "back":
                rc = R.run(OTHER % (draw, "BACK (opposite side to ref1)"), [front], out)
            else:
                rc = R.run(OTHER % (draw, SIDES[v]), [front], out)
            if rc:
                return rc
    return 0


if __name__ == "__main__":
    sys.exit(main())
