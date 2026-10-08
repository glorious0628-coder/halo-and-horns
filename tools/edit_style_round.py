"""Main Studio Edit steps of the 10/08 style round (게임성 개발 1; 검수: style drift #9, watch 3). Edit mode only, no Play.

  py tools/edit_style_round.py gates   -> tools/worldkit/gate_faces_hide.luau (apply), then one Edit photo per gate
  py tools/edit_style_round.py swap    -> snapshot, tools/worldkit/crossroads_3d_swap.luau twice, snapshot after each,
                                          and the differences (crossroads_snapshot.luau): X_SupporterBoard, its
                                          SupporterFace and the MostWantedBoard part must stay as they were
Out: docs/art/verification_2026-10-08/style_round/ (gates/*.png, gates.txt, swap_before.json, swap_after1.json,
swap_after2.json, swap_diff.txt)"""
import base64
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_sound_check as psc  # noqa: E402
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "style_round")
WK = os.path.join(ROOT, "tools", "worldkit")

GATE_SPOTS = r"""
local out = {}
for _, g in workspace.Map.Gates:GetChildren() do
	if g:IsA("Model") then
		local cf, size = g:GetBoundingBox()
		table.insert(out, { Name = g.Name, X = cf.Position.X, Y = cf.Position.Y, Z = cf.Position.Z, H = size.Y })
	end
end
return game:GetService("HttpService"):JSONEncode(out)
"""


def lua(c, code):
    res = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in res.get("content", []))


def read(name):
    with open(os.path.join(WK, name), encoding="utf-8") as f:
        return f.read()


def shot(c, name, cam, look, sub):
    from PIL import Image
    res = c.call("screen_capture", {"capture_id": name, "camera_position": cam, "look_at_position": look})
    for part in res.get("content", []):
        if part.get("type") == "image":
            img = Image.open(io.BytesIO(base64.b64decode(part["data"])))
            os.makedirs(os.path.join(OUT, sub), exist_ok=True)
            img.save(os.path.join(OUT, sub, name + ".png"))
            return f"saved {sub}/{name}.png (white {psc.white_ratio(img):.0%})"
    return "no image for " + name


def gates(c):
    lines = [lua(c, read("gate_faces_hide.luau"))]
    spots = json.loads(lua(c, GATE_SPOTS) or "[]")
    for g in spots:
        # from the crossroads side of the gate (toward the world centre), a little up
        x, y, z, h = g["X"], g["Y"], g["Z"], g["H"]
        d = (x * x + z * z) ** 0.5 or 1
        ux, uz = -x / d, -z / d
        cam = [x + ux * 34, y + h * 0.15 + 6, z + uz * 34]
        lines.append(shot(c, g["Name"], cam, [x, y + h * 0.25, z], "gates"))
    with open(os.path.join(OUT, "gates.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


def diff(a, b):
    out = []
    ka, kb = set(a.get("Children", {})), set(b.get("Children", {}))
    for k in sorted(ka - kb):
        out.append("gone: " + k)
    for k in sorted(kb - ka):
        out.append("new: " + k)
    for k in sorted(ka & kb):
        va, vb = a["Children"][k], b["Children"][k]
        if isinstance(va, list) and isinstance(vb, list):
            if max(abs(p - q) for p, q in zip(va, vb)) > 0.05:
                out.append(f"moved: {k} {va} -> {vb}")
        elif va != vb:
            out.append(f"changed: {k} {va} -> {vb}")
    for key in ("Supporter", "Bounty"):
        if a.get(key) != b.get(key):
            out.append(f"{key} changed: {json.dumps(a.get(key))} -> {json.dumps(b.get(key))}")
    return out


def swap(c):
    snap, swap_src = read("crossroads_snapshot.luau"), read("crossroads_3d_swap.luau")
    os.makedirs(OUT, exist_ok=True)
    before = json.loads(lua(c, snap))
    logs = []
    runs = []
    for i in (1, 2):
        logs.append(f"swap run {i}: " + lua(c, swap_src)[:1500])
        runs.append(json.loads(lua(c, snap)))
    for name, data in (("swap_before", before), ("swap_after1", runs[0]), ("swap_after2", runs[1])):
        with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    d1, d2 = diff(before, runs[0]), diff(runs[0], runs[1])
    lines = logs + ["--- before -> after run 1:"] + (d1 or ["no difference"]) + ["--- run 1 -> run 2:"] + (d2 or ["no difference"])
    keep = runs[1].get("Supporter") and runs[1]["Supporter"].get("Tagged") and runs[1].get("Supporter") == before.get("Supporter")
    bounty = runs[1].get("Bounty") == before.get("Bounty")
    lines.append(f"X_SupporterBoard + SupporterFace kept the same: {bool(keep)}; MostWantedBoard the same: {bool(bounty)}")
    with open(os.path.join(OUT, "swap_diff.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what not in ("gates", "swap"):
        sys.exit(__doc__)
    if what == "gates":
        psc.restore_studio_window()
    c = Client()
    c.start()
    try:
        st = "".join(p.get("text", "") for p in c.call("get_studio_state", {}).get("content", []))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        gates(c) if what == "gates" else swap(c)
    finally:
        c.close()


if __name__ == "__main__":
    main()
