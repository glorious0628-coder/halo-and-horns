"""Monster Codex screen (SPEC A23-153; 게임성 개발 1, 2026-10-13; design docs/design/codex_cards_2026-10-12.md, server
contract docs/design/codex_cards_contract_2026-10-13.md), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and CodexUI.luau (tools/fixtures/codex_ui_offline.luau) on doubles:
- the card (CodexUI.View): a card not met = "???", a black silhouette, no story / drops; a met one = its name, its stage
  (Card / Silver / Gold Holo by the kills even when the saved stage is lower), "Silver at 100" / "Gold Holo at 1,000" /
  "Top stage!", the story line in my side's voice (no side = Neutral), its zone, its materials only, the first day or
  "Before the Codex"; bosses step 1 / 10 / 30 and never have a Gold Foil card; the Gold Foil card only once a golden one
  was beaten; all 11 kinds read on every side;
- pages / count / tilt / moments: the meadow page 2 of 4, 2/11 (an unknown kind is no card), the tilt kept in the unit
  circle, Card / Golden reveal - Silver / Holo evolve - Page / Glow popup, the waiting queue keeps the newest 8;
- the window (Panels "Codex", fixed body, its width, the title Config.Codex.Text.Name): opening asks CodexOpen once (a
  second open at once does not), 3 zone tabs (the open one gold), the page's slots (SlotEmpty for a card not met), the
  count "1/11 cards", the big card in colour with the IconMonSlime picture when no model is there, the Card rim and no
  sheen; a tab shows its page; a click turns a met card (never an unknown one), the back = my side's line, [Flip] back;
  the mouse on the right edge tilts it right (the top bar inset counted), it eases there with a small roll, leaving
  flattens it, [Auto tilt] sways it; a CodexUp with the window open redraws the card (Silver, sheen on) and the line is a
  reward toast; closing disconnects the motion and input;
- moments (window closed): none before my data or while the tutorial holds banners, then the card in the middle with
  the server's line, a new card from its silhouette into colour, a page done = the reward popup (the queue waits for it),
  Gold Holo starts at Silver and sways into Gold Holo, a click ends it early, reduced motion shows the new look at once.
최종 검수 10/13 review: the QuestDone chime rings on a card moment, the reward popup and the open window's toast
(the server toast is off); the layout follows the body (CodexUI.Layout: a full window 230 x 310 card / 168 slots / 197
tabs; at 404 / 360 / 330 / 300 du high the buttons and both slot rows stay inside, the card keeps its shape) and the
body's changes (a 720p body at UIScale 0.8, a phone sideways at 0.75); the zone names fit a 197 tab at a 720p floor;
a flip, the foil, a choice and a fresh snapshot keep the slots (no new 3D views), a card just met remakes only its
slot; the window title carries my count.
Static: Config.Codex.ServerToast false and Config.Codex.Screen's words ASCII English; the HUD tile Codex (Window "Codex",
its name TXT.TileCodex); ClientMain loads CodexUI once, after Panels; the remotes are Net names; no ray words and the
round RewardSparkle only; no hard-coded player words in CodexUI (Text = only from Config / the server); the copy of a
monster drops scripts / effects / name tags / rig brains and is anchored. Mutations: each must be caught.

Usage: py tools/test_codex_ui.py
Report: docs/art/verification_2026-10-13/offline_codex_ui_2026-10-13.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CODEX": SPS / "CodexUI.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "HUD": SPS / "HUD.luau", "MAIN": SPS / "ClientMain.client.luau", "NET": ROOT / "src/ReplicatedStorage/Shared/Net.luau"}
FIXTURE = ROOT / "tools/fixtures/codex_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_codex_ui_2026-10-13.json"


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + s + "]" + eq + "]"


def block(src: str, start: str) -> str:
    a = src.find(start)
    if a < 0:
        return ""
    depth, i = 0, a
    while i < len(src):
        ch = src[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return src[a:i + 1]
        i += 1
    return src[a:]


def static(src: dict) -> list[tuple[str, bool]]:
    cx, cfg, hud, main, net = src["CODEX"], src["CONFIG"], src["HUD"], src["MAIN"], src["NET"]
    screen = block(cfg, "Config.Codex.Screen = {")
    order = re.search(r"local ORDER = \{([^}]*)\}", main)
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    code = "\n".join(line for line in cx.splitlines() if not line.lstrip().startswith("--"))
    strip = block(cx, "Strip = {")
    return [
        ("Config.Codex.ServerToast = false (the lines come from the screen)", re.search(r"\n\tServerToast = false,", cfg) is not None),
        ("Config.Codex.Screen's words are plain English (ASCII)", screen != "" and all(ord(c) < 128 for c in
                                                                                        block(screen, "Text = {"))),
        ("the HUD tile Codex opens the window 'Codex' (named TXT.TileCodex)",
         '{ Id = "Codex", Icon = "IconMonSlime", Window = "Codex", Keep = 7 },' in hud
         and 'TileCodex = "Codex"' in hud and "Codex = TXT.TileCodex" in hud),
        ("ClientMain loads CodexUI once, after Panels", names.count("CodexUI") == 1 and "Panels" in names
         and names.index("Panels") < names.index("CodexUI")),
        ("the remotes are Net names (CodexOpen / Codex / CodexUp)", all(f'"{n}"' in net for n in ("CodexOpen", "Codex", "CodexUp"))
         and 'Net.Get("CodexOpen")' in cx and 'Net.Get("Codex")' in cx and 'Net.Get("CodexUp")' in cx),
        ("no rays: no ray / burst words, the round RewardSparkle only", re.search(r"(?i)\bray|burst|sunburst", code) is None
         and '"RewardSparkle"' in cx),
        ("no hard-coded player words: every Text = comes from tx() / Config / the server / a model's name",
         all(re.search(r'Text\s*=\s*"[A-Za-z]', line) is None for line in code.splitlines())),
        ("the copied monster loses scripts, sounds, effects, name tags / HP bars, rig brains", all(f'"{c}"' in strip for c in
         ("LuaSourceContainer", "Sound", "ParticleEmitter", "BillboardGui", "Highlight", "Humanoid", "Animator"))),
        ("the copied monster stands still (anchored, no collisions / touches / queries)",
         "\t\t\td.Anchored = true\n\t\t\td.CanCollide = false\n\t\t\td.CanTouch = false\n\t\t\td.CanQuery = false\n" in cx),
        ("a card not met = a black silhouette (ViewportFrame ImageColor3)",
         "c.ViewFrame.ImageColor3 = v.Known and L.Lit or L.Silhouette" in cx and "Silhouette = Color3.new(0, 0, 0)" in cx),
        ("the window and the moments work on approved parts (PanelCard, SlotEmpty / SlotCommon, Chip, BtnSecondary)",
         all(f'"{p}"' in cx for p in ("PanelCard", "SlotEmpty", "SlotCommon", "Chip", "BtnSecondary", "IconGoldenMon"))),
        ("the models come from the server's folder (Config.Codex.ModelFolder, contract §6-1) before a live copy",
         'ReplicatedStorage:FindFirstChild(tostring(codex().ModelFolder or "CodexModels"))' in cx
         and 'ModelFolder = "CodexModels"' in cfg
         and cx.index("codex().ModelFolder") < cx.index("if not src then src = MODEL.Live(kind) end")),
        ("the back's lines are whole (each as tall as its wrapped words, never a fixed box) and a long slot name ends in ...",
         "AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false, TextWrapped = true," in cx
         and "TextTruncate = Enum.TextTruncate.AtEnd" in cx),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal CODEX_SOURCE = " + lua_str(src["CODEX"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "codex_ui.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=180)
    out = proc.stdout + proc.stderr
    m = re.search(r"CODEX_UI_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


MUTATIONS = [
    ("CODEX", "the saved stage trusted over the kills", "if e and type(Config.CodexStage) == \"function\" then stage = math.max(stage, Config.CodexStage(kind, kills)) end",
     ""),
    ("CODEX", "a boss gets a Gold Foil card", "local canGold = type(Config.CodexCanGold) ~= \"function\" or Config.CodexCanGold(kind)",
     "local canGold = true"),
    ("CODEX", "the foil shown without a golden kill", "local hasFoil = known and canGold and e ~= nil and int(e.Golden) >= 1",
     "local hasFoil = known and canGold"),
    ("CODEX", "the back always in the Halo voice", 'local side = (faction == "Halo" or faction == "Horns") and faction or "Neutral"',
     'local side = "Halo"'),
    ("CODEX", "scrolls and potions in the drops", 'if type(item) == "table" and item.Kind == "Material" and not seen[id] then',
     'if type(item) == "table" and not seen[id] then'),
    ("CODEX", "an unknown card shows its name", 'v.Name = known and tostring(def.Name or kind) or tx("Unknown")',
     "v.Name = tostring(def.Name or kind)"),
    ("CODEX", "no silhouette", "c.ViewFrame.ImageColor3 = v.Known and L.Lit or L.Silhouette", "c.ViewFrame.ImageColor3 = L.Lit"),
    ("CODEX", "the queue never trimmed", "while #queue > math.max(1, max) do table.remove(queue, 1) end", ""),
    ("CODEX", "the tilt leaves the circle", "if m > 1 then x, y = x / m, y / m end", ""),
    ("CODEX", "CodexOpen on every open", "if os.clock() - S.OpenAt < L.OpenGap then return end", ""),
    ("CODEX", "an unknown card turns over", "\tif not (VIEW.Big.View and VIEW.Big.View.Known) then return end\n", ""),
    # 최종 검수 10/13 review: the chime, the layout for the body, slots kept, the count in the title
    ("CODEX", "a card moment without its chime", "\tchime()\n\tlocal hold = ", "\tlocal hold = "),
    ("CODEX", "the open window's toast without its chime", "\t\tcall(\"Toast\", tostring(payload.Text or \"\"), \"reward\")\n\t\tchime()\n",
     "\t\tcall(\"Toast\", tostring(payload.Text or \"\"), \"reward\")\n"),
    ("CODEX", "the card not fitted to the body (buttons cut on a phone)",
     "local cardH = math.clamp(math.min(math.floor(room - L.Gap - L.ButtonH), byWidth), L.MinCardH, L.MaxCardH)",
     "local cardH = L.CardH"),
    ("CODEX", "the card never grows (the window's lower half empty)",
     "local cardH = math.clamp(math.min(math.floor(room - L.Gap - L.ButtonH), byWidth), L.MinCardH, L.MaxCardH)",
     "local cardH = math.clamp(math.min(math.floor(room - L.Gap - L.ButtonH), byWidth), L.MinCardH, L.CardH)"),
    ("CODEX", "the slots never grow", "math.clamp(math.floor((room - L.Gap) / 2), L.MinSlotH, L.MaxSlotH)",
     "math.clamp(math.floor((room - L.Gap) / 2), L.MinSlotH, 168)"),
    ("CODEX", "the card wider than its column", "local byWidth = math.floor(rightW * L.CardH / L.CardW)", "local byWidth = 9999"),
    ("CODEX", "the old narrow tabs", "TabH = 40, TabW = 220,", "TabH = 40, TabW = 132,"),
    ("CODEX", "the slot says the short name", "\ts.Name.Text = v.Name\n", "\ts.Name.Text = v.Short\n"),
    ("CODEX", "a hidden window takes the moments as toasts", "\t\tif not p.Visible then return false end\n", ""),
    ("CODEX", "the back's lines in fixed boxes (cut)", "AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false, TextWrapped = true,",
     "AutomaticSize = Enum.AutomaticSize.None, TextScaled = true, TextWrapped = true,"),
    ("CODEX", "the body's changes not followed", "\ttable.insert(VIEW.Conns, parent:GetPropertyChangedSignal(\"AbsoluteSize\"):Connect(relayout))\n", ""),
    ("CODEX", "the UIScale ignored", "\t\tif u and u.Scale > 0 then s *= u.Scale end\n", ""),
    ("CODEX", "slots built again on every draw", "\tif VIEW.SlotsPage ~= page.Index then", "\tif true then"),
    ("CODEX", "a card just met keeps its empty slot", "\t\t\tif not s or s.Known ~= v.Known then", "\t\t\tif not s then"),
    ("CODEX", "the title without my count", "\treturn string.format(\"%s · %s\", type(name) == \"string\" and name or \"\", tx(\"Count\", owned, total))",
     "\treturn type(name) == \"string\" and name or \"\""),
    ("CODEX", "the top bar inset ignored", "if ok and typeof(inset) == \"Vector2\" then pos += inset end", ""),
    ("CODEX", "the motion left running after closing", "local function cleanup()\n\tdisconnect()\n", "local function cleanup()\n"),
    ("CODEX", "moments over the tutorial", "\treturn hold ~= true\n", "\treturn true\n"),
    ("CODEX", "moments before my data", '\tif not LocalPlayer or LocalPlayer:GetAttribute("DataLoaded") ~= true then return false end\n', ""),
    ("CODEX", "a new card shown in colour at once", '\tif payload.Event == "Card" then\n\t\tbefore = CodexUI.View(kind, nil, faction(), false)\n',
     '\tif payload.Event == "Card" then\n\t\tbefore = after\n'),
    ("CODEX", "the evolve never swaps", "\t\t\t\t\tCARD.Set(c, after)\n", ""),
    ("CODEX", "no line under the moment card", 'Text = tostring(payload.Text or ""), AnchorPoint', 'Text = "", AnchorPoint'),
    ("CODEX", "window open: the line lost", '\t\tpcall(drawWindow)\n\t\tcall("Toast", tostring(payload.Text or ""), "reward")\n',
     "\t\tpcall(drawWindow)\n"),
    ("CODEX", "the popup does not hold the queue", "\t\twhile frame.Parent do task.wait(0.25) end\n", ""),
    ("CODEX", "a click cannot end the moment", "if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then finish() end",
     "if false then finish() end"),
    ("CODEX", "the window never registered", "\tS.Ready = panels.Register(L.Window, {", "\tS.Ready = false and panels.Register(L.Window, {"),
    ("CONFIG", "the server's toast back on", "\tServerToast = false,", "\tServerToast = true,"),
    ("HUD", "no Codex tile", '\t\t{ Id = "Codex", Icon = "IconMonSlime", Window = "Codex", Keep = 7 },\n', ""),
    ("MAIN", "CodexUI never loaded", '"KingDiary", "CodexUI", ', '"KingDiary", '),
    ("CODEX", "the server's model folder ignored", 'ReplicatedStorage:FindFirstChild(tostring(codex().ModelFolder or "CodexModels"))',
     'ReplicatedStorage:FindFirstChild("Models")'),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
