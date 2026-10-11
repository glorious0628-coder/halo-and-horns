"""5 more icons (10/12, 디자인 검수): PetTreat + 4 tonic bottles (one shared bottle shape). Medium candidates x2 each (0 credits).
Writes art/prompts/Icon<Name>.txt + build/img2_icons_bag2/queue.json (ref = approved IconJelly, filled by caller). Run: py tools/_icons_bag2_prompts.py"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
HEAD = "Use the attached image only as a style reference (outline thickness, glossy look, size). Game inventory item icon of "
STYLE = (" Glossy 3D-rendered toy-like game icon, chunky rounded shapes with soft bevels, soft glossy toy plastic, bright saturated kid-friendly colors, soft light from the top left, "
         "thick even dark navy outline around the whole silhouette with a crisp hard edge, no glow or light rays, one single solid object with nothing floating around it, "
         "centered filling 70 percent of a square with a wide margin, three-quarter front view. Isolated on a plain flat medium gray background, soft even light, clean shadowless backdrop. Wordless, blank unmarked surfaces, no face.")
BOTTLE = "one round fat glass flask with a short thick neck and a wide rim, a round cork-style stopper shaped as {cap}, the liquid inside is {liq} with a soft glossy highlight, the glass is clear with a thick dark navy outline. "
I = {
 "PetTreat": ["pet treats: a small cream-colored paper bag tied with a red ribbon bow, with two bone-shaped brown cookies and one star-shaped biscuit sticking out of the top, warm brown and cream colors.",
              "pet treats: a small pile of three bone-shaped golden-brown dog cookies and one star-shaped biscuit, with a little cream cloth bag tied with a ribbon beside them, warm brown and cream colors."],
 "MightTonic": [BOTTLE.format(cap="a small round wooden stopper with a tiny orange flame-drop on top", liq="bright red-orange") + "Strength tonic.",
                BOTTLE.format(cap="a small round wooden stopper carrying a little teardrop-shaped red flame", liq="warm orange-red") + "Strength tonic."],
 "GuardTonic": [BOTTLE.format(cap="a small round steel stopper shaped like a tiny shield", liq="bright sky blue") + "Defense tonic.",
                BOTTLE.format(cap="a small round silver stopper with a tiny shield-shaped top", liq="deep cobalt blue") + "Defense tonic."],
 "LuckyTonic": [BOTTLE.format(cap="a small round stopper topped with a four-leaf clover", liq="bright lime green") + "Luck tonic.",
                BOTTLE.format(cap="a small round stopper shaped like a green four-leaf clover", liq="fresh emerald green") + "Luck tonic."],
 "WisdomTonic": [BOTTLE.format(cap="a small round stopper topped with a gold star", liq="glossy violet purple") + "Wisdom tonic.",
                 BOTTLE.format(cap="a small round stopper shaped like a gold five-point star", liq="soft lavender purple") + "Wisdom tonic."],
}
def main():
    q = []
    for k, ds in I.items():
        for n, d in enumerate(ds, 1):
            body = HEAD + d + STYLE
            assert len(body) < 1000, (k, n, len(body))
            (ROOT / "art/prompts" / f"Icon{k}_m{n}.txt").write_text("[reference: approved IconJelly (style only), Medium]\n" + body + "\n", encoding="utf-8")
            q.append({"key": f"Icon{k}_m{n}", "ref": "IconJelly", "prompt": body, "quality": "medium"})
    out = ROOT / "build/img2_icons_bag2"; out.mkdir(parents=True, exist_ok=True)
    (out / "queue.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(q), max(len(i["prompt"]) for i in q))
if __name__ == "__main__":
    main()
