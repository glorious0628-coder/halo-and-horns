"""Bag material icons x12 (10/11 night, 디자인 검수): Medium candidates (0 credits), style = approved IconJelly/IconBone.
Writes art/prompts/Icon<Name>.txt and build/img2_icons_bag/queue.json. Run: py tools/_icons_bag_prompts.py"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
HEAD = "Game inventory material icon of "
STYLE = (" Glossy 3D-rendered toy-like game icon, chunky rounded shapes with soft bevels, soft glossy toy plastic, bright saturated kid-friendly colors, soft light from the top left, "
         "thick even dark navy outline around the whole silhouette with a crisp hard edge, no glow or light rays, one single solid object with nothing floating around it, "
         "centered filling 70 percent of a square with a wide margin, three-quarter front view. Isolated on a plain flat medium gray background, soft even light, clean shadowless backdrop. Wordless, blank unmarked surfaces, no face.")
I = {
 "Petal": "a flower petal: one big soft pink flower petal with a gentle curl, glossy, a lighter pink center vein and one tiny dew drop.",
 "CaptainBadge": "a captain's badge: a shiny gold shield-shaped badge with a raised star in the middle, a small red gem under the star and a short dark-blue ribbon tail, rare and fancy.",
 "SeaShell": "a sea shell: one cute spiral seashell in pale peach and pink, glossy ridges, a small pearly opening.",
 "CrystalShard": "a crystal shard: one single tall pointed sky-blue crystal with clean flat facets, a lighter tip and a small base chunk.",
 "MeadowHerb": "a meadow herb: a small bunch of three fresh green leaves tied with a thin string, with one round glowing pale-pink flower bud on top.",
 "CopperOre": "copper ore: one chunky rough rock in orange-brown with bright copper-orange stripes and a few shiny metal flecks.",
 "OakLog": "an oak log: one short thick oak log lying diagonally, warm brown bark with a lighter cut end showing tree rings.",
 "Glowcap": "a glowcap mushroom: one small teal-green mushroom with a round cap and pale spots, a creamy stem, a soft bright cap color.",
 "IronOre": "iron ore: one chunky angular grey rock with sharp flat faces, dark steel-grey with a few bright metal edges.",
 "SilverOre": "silver ore: one smooth rounded nugget of bright shiny silver with soft reflections and a few small bumps.",
 "MoonCrystal": "a moon crystal: one crescent-moon-shaped crystal in soft lilac-purple, glossy facets, a round pale lavender halo shine painted inside the outline.",
 "CrownDust": "crown dust: a small sparkling heap of fine pale-gold dust with a few tiny star sparkles on it, glittery, soft cream and gold.",
}
def main():
    q = []
    for k, d in I.items():
        body = HEAD + d + STYLE
        assert len(body) < 1000, (k, len(body))
        (ROOT / "art/prompts" / f"Icon{k}.txt").write_text(f"[reference: approved IconJelly (style only), Medium]\nUse the attached image only as a style reference (outline, glossy look, size). " + body + "\n", encoding="utf-8")
        q.append({"key": f"Icon{k}", "prompt": "Use the attached image only as a style reference (outline thickness, glossy look, size). " + body, "quality": "medium"})
    out = ROOT / "build/img2_icons_bag"; out.mkdir(parents=True, exist_ok=True)
    (out / "queue.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(q), max(len(i["prompt"]) for i in q))
if __name__ == "__main__":
    main()
