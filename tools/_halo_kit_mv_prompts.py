"""Halo new-kit props: High front (from Medium front ref) + back/left/right (from the HQ front ref, only the camera turns, A23-122).
Writes art/prompts/HaloKit_<Key>_{front_HQ,back,left,right}.txt and build/img2_halo_kits/mv_queue.json (items w/o ref url; fill ref at run time).
Run: py tools/_halo_kit_mv_prompts.py"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
TAIL = (" Whole object in frame with a wide empty margin, centered. Plain flat medium gray background, shadowless. Same glossy chunky toy-like 3D render, same colors and lighting. "
        "No faces or face-like marks, no people, no animals, no lettering or symbols, no light rays or beams.")
HEAD = "Use the attached image as the exact design reference of this object and only turn the camera around it; keep every shape, proportion, color and detail identical. Draw only this one object as a standalone prop. "
# key -> (what, back, left (camera at the object's left side), right)
P = {
 "FlowerBush": ("a low neat flowering bush, green leaves with pale lavender and white flowers",
   "The same bush seen from directly behind: same dome shape and leaves, flowers placed a little differently.",
   "The same bush seen from its left side: same dome shape and leaves with flowers.",
   "The same bush seen from its right side: same dome shape and leaves with flowers."),
 "GatherBush": ("a low round flowering gathering bush on a cream stone ring base, pink and white flowers, small glowing golden berries",
   "The same bush on its stone ring seen from directly behind: same dome, flowers and golden berries.",
   "The same bush on its stone ring seen from its left side.",
   "The same bush on its stone ring seen from its right side."),
 "WallLamp": ("a wall lamp: a marble wall plate with a gold bracket arm holding a glass lantern",
   "The wall lamp seen from directly behind: the plain flat back of the marble wall plate and the back of the bracket and lantern, no glow.",
   "The wall lamp seen from its left side: the thin plate edge-on, the bracket arm reaching out and the lantern hanging, side profile.",
   "The wall lamp seen from its right side: the thin plate edge-on, the bracket arm reaching out and the lantern hanging, side profile."),
 "Beehive": ("a white wooden beehive: two stacked boxes with a pitched roof with sky-blue tiles and a round entrance hole",
   "The beehive seen from directly behind: the plain back wall of the stacked boxes and the back slope of the tiled roof, no entrance hole.",
   "The beehive seen from its left side: the side of the stacked boxes and the roof slope in profile.",
   "The beehive seen from its right side: the side of the stacked boxes and the roof slope in profile."),
 "Telescope": ("a white and gold telescope on a wooden three-legged tripod, tube pointing up",
   "The telescope seen from directly behind: the eyepiece end of the tube facing the viewer, the tripod legs.",
   "The telescope seen from its left side: the long tube in profile pointing up, the tripod legs.",
   "The telescope seen from its right side: the long tube in profile pointing up, the tripod legs."),
 "Easel": ("a painter's easel with a canvas showing a calm blue sea",
   "The easel seen from directly behind: the plain pale wooden back of the canvas, the easel legs and brace; no painting visible.",
   "The easel seen from its left side: the thin canvas edge-on, the three legs in profile.",
   "The easel seen from its right side: the thin canvas edge-on, the three legs in profile."),
 "BellFrame": ("a small marble bell frame: two white marble posts with gold trim and a crossbeam holding one small gold bell",
   "The bell frame seen from directly behind: the same two posts and crossbeam, the bell hanging in the middle, plain back of the posts.",
   "The bell frame seen from its left side: the narrow post in profile with the bell hanging behind it.",
   "The bell frame seen from its right side: the narrow post in profile with the bell hanging behind it."),
}
def main():
    q = []
    for k, (what, back, left, right) in P.items():
        for view, note in (("back", back), ("left", left), ("right", right)):
            body = HEAD + note + " This is " + what + "." + TAIL
            assert len(body) < 1000, (k, view, len(body))
            (ROOT / "art/prompts" / f"HaloKit_{k}_{view}.txt").write_text(f"[reference: HaloKit_{k}_front_HQ, High]\n{body}\n", encoding="utf-8")
            q.append({"key": f"HaloKit_{k}_{view}", "front": k, "prompt": body, "quality": "high"})
    out = ROOT / "build/img2_halo_kits"; out.mkdir(parents=True, exist_ok=True)
    (out / "mv_queue.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(q), max(len(i["prompt"]) for i in q))
if __name__ == "__main__":
    main()
