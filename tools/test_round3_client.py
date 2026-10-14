"""Round 3 'first 10 minutes' client pieces in HUD.luau (docs/design/ideas_first10_2026-10-07.md §3-4, game dev 1):
#1 line 2 after the pinned row = the waiting story -> a claim -> the S0 shard story (until auto combat is unlocked) ->
the first daily, in both the phone header line and the two quest lines; the PC list has no daily header before the
first mission is accepted (step 0); a seconds row's ProgressUnit follows the target ('5/10 s', dev2 2c5e84e).
#3 one tap on the phone quest block whose line 1 is the step-0 pinned row ('Tap here: first quest from Hallie') opens
the guide (L.PinnedTap) instead of the list.
#2 the guide's first window (Panels BUILDERS.Welcome): [I'm In!] is the one wide button (half the row), Next / Later a
quarter each; short phone screens (height < 520) keep a 64 px guide face instead of none.
A23-74 weapon first (dev2 dev2-weapon): TutorialStep Forge (3) beams to the anvil in the Crossroads, to the Crossroads
from elsewhere (by the step, never BlacksmithVisited; 빛 마을 점검 #16: the anvil from every walk zone); a tap of the Forge
row brings the guide back and pops the quest marker (#20); the bag's empty weapons line says the weapon comes with the first quest.
Static source checks (HUD.luau is too large for an offline run of refreshQuests); each check names the exact code.
Report: docs/art/verification_2026-10-07/offline_round3_client_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
CFG_TXT = (Path(__file__).resolve().parents[1] / "src/ReplicatedStorage/Shared/Config.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")  # the moved words (Config.ClientText)
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
PANELS = ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_round3_client_2026-10-07.json"


def block(src: str, head: str) -> str:
    i = src.find(head)
    if i < 0:
        return ""
    j = src.find("\nend\n", i)
    return src[i:j + 4] if j > 0 else ""


def main():
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    tap = block(hud, "function L.QuestBlockTap()")
    refresh = hud[hud.find("refreshQuests = function()"):]
    refresh = refresh[:refresh.find("\nend\n") + 4] if refresh else ""
    nums = block(hud, "local function questNums(e)")
    guides = block(hud, "local function refreshGuides()")
    pinned = block(hud, "function L.PinnedTap(e, r)")
    forge_branch = guides[guides.find("\tif forge then"):guides.find("\telseif L.NeedsMeadowGuide(step)")]
    panels = PANELS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    welcome = panels[panels.find("BUILDERS.Welcome = function(parent)"):]
    welcome = welcome[:welcome.find("\nBUILDERS.") if "\nBUILDERS." in welcome else len(welcome)]
    vitals = (ROOT / "src/StarterPlayer/StarterPlayerScripts/VitalsUI.luau").read_text(encoding="utf-8-sig")
    mapb = (ROOT / "src/ServerScriptService/MapBuilder.luau").read_text(encoding="utf-8-sig")
    checks = [
        ("#3 the step-0 pinned line opens the guide in one tap (before the claim / list paths)",
         "if e and e.Pinned and e.TutorialStep == 0 and L.PinnedTap then" in tap
         and tap.find("e.TutorialStep == 0") < tap.find("e.Progress >= e.Target")),
        ("#1 S0 is looked up only until auto combat is unlocked",
         'if attr("AutoCombatUnlocked", false) ~= true then' in refresh and 'e.Story and e.Story.Id == "S0"' in refresh),
        ("#1 phone header line 2: story -> claim -> S0 -> daily", "second = callIndex or firstClaim or s0 or firstDaily" in refresh),
        # A23-81 (2026-10-08): up to Config.QuestTabs.HudLines lines; after line 1 the same order (story, claim, S0, daily)
        ("#1 quest lines 2+: story -> claim -> S0 -> daily (A23-81 order)",
         "L.QuestLineOrder(entries, shown, { callIndex, second, firstClaim, s0, firstDaily })" in refresh),
        ("#1 PC: no daily header at step 0",
         "ui.questHeader.Visible = not (entries[1] and entries[1].Pinned and entries[1].TutorialStep == 0)" in refresh),
        ("ProgressUnit kept from the server row (<= 3 letters)",
         re.search(r"ProgressUnit = \(type\(e\.ProgressUnit\) == \"string\" and #e\.ProgressUnit > 0 and #e\.ProgressUnit <= 3\)", hud)
         is not None),
        ("ProgressUnit follows the target: '5/10 s'", 'if e.ProgressUnit then t = t .. " " .. e.ProgressUnit end' in nums),
        ("#2 / 검수 10/09: [I'm In!] is the one big button, first in the row (user 10/13: no longer the whole card wide -"
         " WELCOME.AcceptW of the card, 0.45)",
         "nextButton = makeButton(actions, T.WelcomeAccept, PALETTE.Free, UDim2.new(WELCOME.AcceptW, 0, 0, 60)" in welcome
         and "nextButton.LayoutOrder = 1" in welcome),
        ("user 10/13: [I'm In!] is under half the card wide", re.search(r"AcceptW = 0\.(\d+) \}", panels) is not None
         and float("0." + re.search(r"AcceptW = 0\.(\d+) \}", panels)[1]) <= 0.5),
        ("user 10/13 ('글씨 가운데'): a window title sits in the middle of the whole ribbon (centred words, the right end as"
         " wide as the icon disc, a least width for the words)",
         "TextXAlignment = Enum.TextXAlignment.Center,\n\t\tLayoutOrder = 2," in panels
         and 'UIKit.Create("Frame", { Name = "End", Size = UDim2.new(0, disc0, 1, 0)' in panels
         and "MinSize = Vector2.new(math.max(0, FRAME.TitleMinW - 2 * disc0), 0)" in panels
         and "local capW = math.max(40, maxW - 2 * math.floor(th * FRAME.Disc))" in panels),
        ("검수 10/09: a small ▶ (64 du) for the next page, no 'Later' (the window's X closes)",
         "readMore = makeButton(actions, T.WelcomeMore, PALETTE.Button, UDim2.new(0, 64, 0, 60)" in welcome
         and "readMore.LayoutOrder = 2" in welcome and ('WelcomeMore = "▶",' in panels
         or 'WelcomeMore = "▶",' in (PANELS.parents[2] / "ReplicatedStorage/Shared/Config.luau").read_text(encoding="utf-8-sig"))
         and "WelcomeLater" not in panels and "later" not in welcome),
        ("#2 short screens keep a 64 px face", "local face = short and 64 or 170" in welcome
         and "Size = UDim2.fromOffset(face, face)" in welcome and "portraitRow.Visible = not short" not in welcome),
        ("UI round 2 #8: weapons of 100+ gold buy on a second press within 3 s",
         "ConfirmAt = 100, ConfirmSeconds = 3," in panels
         and "if info and (tonumber(info.Price) or 0) >= WSHOP.ConfirmAt and os.clock() >= (ui.ArmedUntil or 0) then" in panels
         and "ui.Buy.Text = UserInputService.TouchEnabled and WSHOP.AgainTouch or WSHOP.AgainMouse" in panels
         and 'AgainTouch = "Tap again to buy"' in panels),
        ("UI round 2 #3: the forge window from afar lists the weapons and shows [Show me the way]",
         "details.Visible = access == nil or far" in panels and "wayRow.Visible = far" in panels
         and "function WSHOP.ShowWay()" in panels and 'pcall(qt.Travel, "Crossroads", zone)' in panels),
        ("UI round 2 #3: no potions -> [Buy] shows the way to the merchant",
         'if count <= 0 and label == "Buy" then WAY.Show() end' in vitals and "pcall(hud.ShowGuide, target, WAY.Label)" in vitals),
        ("#10 story choices: kind / sneaky art buttons with the wing / horns glyph, the old button without the art",
         "function STORY.ChoiceButton(parent, side, text, size, onClick)" in panels
         and 'local art = side == "Good" and "BtnKind" or "BtnSneaky"' in panels
         and 'local glyph = side == "Good" and "GlyphKindWing" or "GlyphSneakyHorns"' in panels
         and 'buttons[1] = STORY.ChoiceButton(actions, "Good", left,' in panels
         and 'buttons[2] = STORY.ChoiceButton(actions, "Evil", right,' in panels
         and "if not btn or disabledButtons[btn] then return end" in panels),
        ("A23-74 weapon first: the Forge step's beam goes to the anvil in the Crossroads (the Crossroads from elsewhere), "
         "decided by the step, never by BlacksmithVisited",
         'L.ForgeStep = (type(TUT.Steps) == "table" and tonumber(TUT.Steps.Forge)) or 3' in hud
         and hud.find("L.ForgeStep = ") < hud.find("local function refreshGuides()")
         and "\tlocal forge = step == L.ForgeStep\n" in guides
         and '\t\tif guide.Tag == "forge" and (not forge or guide.From ~= select(2, L.ForgeTarget(zone))) then\n\t\t\tHUD.ClearGuide()\n' in guides
         and 'local target, from = L.ForgeTarget(zone)' in forge_branch
         and 'if showGuide(target, TXT.ForgeGuide, "forge", nil) and guide then guide.From = from end' in forge_branch
         and 'L.ForgeWalk = { Crossroads = true, HaloTown = true, HornsTown = true, Outskirts = true }' in hud
         and 'local anvil = L.ForgeWalk[zone] and L.BlacksmithTarget() or nil' in hud
         and 0 < guides.find("\tif forge then") < guides.find("\telseif L.NeedsMeadowGuide(step)")
         and "BlacksmithVisited" not in forge_branch
         and 'ForgeGuide = "First weapon",' in CFG_TXT),
        ("빛 마을 점검 #20: tapping the Forge row brings the guide back and pops the quest marker (no RequestTutorial)",
         "\telseif step == L.ForgeStep then\n" in pinned
         and "\t\tHUD.ClearGuide()\n\t\trefreshGuides()\n\t\tlocal qm = C and C.QuestMarker\n"
             "\t\tif type(qm) == \"table\" and type(qm.Pulse) == \"function\" then pcall(qm.Pulse) end\n" in pinned
         and "RequestTutorial" not in pinned[pinned.find("elseif step == L.ForgeStep then"):pinned.find("elseif step == 1 or step == 2 then")]
         and pinned.find("if step == 0 then") < pinned.find("elseif step == L.ForgeStep then")
         < pinned.find("elseif step == 1 or step == 2 then")),
        ("A23-74: the bag's empty weapons line promises the weapon right after the first quest",
         'NoWeapons = "Bare hands for now. Accept the Guide\'s first quest and Otto gives you your first weapon.",' in panels),
        ("E11: MapBuilder puts a BoardPrompt (attribute Board) on each job board's spot, off while the board is off",
         "local function ensureJobBoards(ctx, folder)" in mapb and 'prompt.Name = "BoardPrompt"' in mapb
         and 'prompt:SetAttribute("Board", tostring(id))' in mapb and "prompt.Enabled = B.Enabled == true" in mapb
         and "ensureJobBoards(ctx, folders.Landmarks)" in mapb),
    ]
    for name, good in checks:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = all(g for _, g in checks)
    report = {"status": "passed" if passed else "failed", "static": [{"check": n, "ok": g} for n, g in checks],
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (HUD, PANELS)},
              "studioCalls": 0, "contract": __doc__.split("Static")[0].strip(),
              "limitations": "Static only; the phone tap and the line order are a Studio check (fresh save, phone)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']}")


if __name__ == "__main__":
    main()
