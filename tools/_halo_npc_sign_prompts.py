"""Writes art/prompts/HaloSign_<Kind>_front.txt (4 shop signs (Bakery, Juice, Flower, Potion; the Toy sign was dropped by 검수 10/10), High) and art/prompts/NPC_Halo<Name>_A.txt (5 Halo town NPC full-body candidates, Medium).
Signs: style ref = HaloProp_Shop_front. NPCs: Bright's ref = PTR_TownBright_HQ_src (the approved anchor); the others take Bright only as the art-style reference.
Run: py tools/_halo_npc_sign_prompts.py  (also build/img2_halo_mv/halo_npc_sign.json)
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "prompts"

SIGN_HEAD = ("Use the attached image only as a style reference. Draw only this one object, as a standalone prop: one hanging shop sign for a town of light, "
             "a round white marble board with a gold rim hanging by two gold chains from a short curved white stone arm with gold bands, ")
SIGN_TAIL = (" The picture is painted large and simple in the middle, no letters, no numbers, no symbols. Three-quarter front view, centered. "
             "White marble with gold trim and pale sky-blue accents, glossy chunky toy-like 3D render with soft rounded bevels, same style, colors and lighting as the attached reference. "
             "No faces, no people. Plain flat medium gray background, wide empty margin, shadowless, whole object in frame. Only soft round glows; no light rays, no beams, no sunburst.")
SIGNS = {
    "Bakery": "the board shows a big golden-brown round loaf of bread with three cut lines and a wheat ear beside it.",
    "Juice": "the board shows a tall glass of orange juice with a straw and a round orange slice on the rim.",
    "Flower": "the board shows one big white flower with a gold center and two green leaves, with a small pale-blue flower beside it.",
    "Potion": "the board shows one round glass potion bottle with a cork stopper filled with bright red liquid, and a small gold star shine beside it.",
}

NPC_HEAD = "Use the attached image for the art style only. "
NPC_TAIL = (" Blocky toy avatar: square cube head, simple flat painted face, chunky rounded limbs, glossy toy plastic, soft even light. "
            "Full-body front view, relaxed A-pose, feet apart, head to feet inside the frame with a wide margin, centered. "
            "Fully covered modest clothing, only face and hands show. Small floating gold halo ring above the head. "
            "Plain flat medium gray background, shadowless. No letters, no symbols, no light rays.")
NPCS = {
    "Bright": "Redraw her full-body: the same cheerful ten-year-old girl knight apprentice as the attached portrait, same face, eyes, freckles, small open happy smile, silver helmet with a sky-blue plume, golden-blond bangs and one long side braid, sky-blue high-collar tabard with a round gold medallion holding a pale blue gem, gold shoulder guards, long white sleeves, white leggings and gold-trimmed sky-blue boots, a short sky-blue tabard skirt over the leggings.",
    "SirGleam": "A tall kind older town guard knight: a broad friendly man with a big gray-white mustache, simple flat face with crinkled smiling eyes, bald head under an open silver helmet with a small sky-blue plume, silver-white plate armor with gold trim over a sky-blue tunic, long sleeves, armored gloves, long white trousers, silver boots, a sheathed plain sword on the belt, a sky-blue cape.",
    "BakerGranny": "A round cheerful grandmother baker: a simple flat face with soft smiling eyes and rosy cheeks, gray hair in a neat bun under a white baker's cap, a long-sleeved pale sky-blue ankle-length dress with a white apron with a gold button row, white sleeves rolled to the wrists, small brown shoes, holding nothing.",
    "FlowerGirl": "A friendly twelve-year-old flower girl: a simple flat face with big round eyes and a gentle smile, long brown hair with a ring of small white flowers, a long-sleeved white high-collar blouse, a knee-length pale-green pinafore dress over long white tights, small brown boots, a small sky-blue satchel on her shoulder.",
    "JuiceMan": "A cheerful middle-aged juice seller: a simple flat face with a round nose and a wide happy smile, short orange-brown hair under a round straw hat with a sky-blue band, a long-sleeved orange tunic with a brown apron, long cream trousers, brown boots.",
}


def main() -> None:
    q = []
    for k, t in SIGNS.items():
        body = SIGN_HEAD + t + SIGN_TAIL
        assert len(body) < 1000, (k, len(body))
        (OUT / f"HaloSign_{k}_front.txt").write_text(f"[reference: HaloProp_Shop_front (style), High]\n{body}\n", encoding="utf-8")
        q.append({"key": f"Sign_{k}", "kind": "sign", "prompt": body})
    for k, t in NPCS.items():
        body = (t + " Same art style, render quality and colors as the attached portrait." + NPC_TAIL) if k == "Bright" else (NPC_HEAD + t + NPC_TAIL)
        assert len(body) < 1000, (k, len(body))
        (OUT / f"NPC_Halo{k}_A.txt").write_text(f"[reference: PTR_TownBright_HQ_src (anchor), Medium]\n{body}\n", encoding="utf-8")
        q.append({"key": f"NPC_{k}", "kind": "npc", "prompt": body})
    (ROOT / "build/img2_halo_mv/halo_npc_sign.json").write_text(json.dumps(q, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(q), "prompts; max", max(len(x["prompt"]) for x in q))


if __name__ == "__main__":
    main()
