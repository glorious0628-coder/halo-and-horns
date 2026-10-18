"""A23-219 Tool tab press-through (dev1-craft-tool) in MY test Studio (STUDIO_ID = PhoneTest_1015), fresh Play.
The test Studio runs a TEST-ONLY Config (never committed): Crafting on, tool steps +1..+3 at 50% / craft Lv 1 (a fail and a
success in a few presses), the Mixing Kit +0 bless chance 100% and AS1 at craft Lv 1 (a blessed scroll at once).
Every server change goes through the game's own DebugCommand (Scene / Item / stats): the MCP context has its own module copies.
7a no materials -> NeedMats line; 7b materials, gold 0 -> NeedGold line; 7c gold -> [Upgrade] presses until a fail and a
success (CraftToolResult line, +N); 7e an alchemist crafts AS1 -> the Blessed Scroll line under the result + bag Enh70B.
Usage: STUDIO_ID=... py craft7.py"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, shot, scene, start_play, pick, stop_play, close, GAME, click, debug  # noqa: E402
from press1017b import TOOL_STATE, FIND_UPGRADE, OPEN_TOOL  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-17", "craft_tool")
os.makedirs(OUT, exist_ok=True)
ARTISAN = {"NeutralFaction": True, "Gathering": True, "Crafting": True, "Tonics": True, "Research": True, "Gear": True}
CH1 = ["M1_1", "M1_2", "M1_3", "M1_4"]
STATS = ('local p = game.Players.LocalPlayer return string.format("bank=%s carried=%s copper=?", '
         'tostring(p:GetAttribute("BankGold")), tostring(p:GetAttribute("CarriedGold")))')
RESULT = ('local r, b = "", "" for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do '
          'if d:IsA("TextLabel") and d.Name == "Result" and d.Parent and d.Parent.Name ~= "Tool" then r = d.Text '
          'elseif d:IsA("TextLabel") and d.Name == "Bless" then b = d.Text end end return "Result=" .. r .. " | Bless=" .. b')


def open_tool(c):
    close(c)
    time.sleep(0.5)
    log("  open:", lua(c, OPEN_TOOL, "Server"))
    time.sleep(1.5)


def main():
    c = Client()
    c.start()
    start_play(c)
    log("pick:", pick(c, "Halo", "Warrior"))
    try:
        log("7", scene(c, {"Features": ARTISAN, "Faction": "Neutral", "Class": "Warrior", "Level": 8, "Tutorial": "Done",
                           "Done": CH1, "At": "Bench:Smith"}))
        time.sleep(3)
        close(c)
        log("  loot reset:", debug(c, "LootReset", 1))
        log("  gold 0:", debug(c, "CarriedGold", 0), debug(c, "BankGold", 0), lua(c, STATS, "Client"))
        open_tool(c)
        log("  7a no mats:", lua(c, TOOL_STATE, "Client"))
        shot(c, os.path.join(OUT, "7a_need_mats.png"))
        log("  ", debug(c, "Item", "CopperOre:40"), debug(c, "Item", "Jelly:40"))
        time.sleep(1.5)
        log("  7b mats, gold 0:", lua(c, TOOL_STATE, "Client"), lua(c, STATS, "Client"))
        shot(c, os.path.join(OUT, "7b_need_gold.png"))
        log("  ", debug(c, "Gold", 2000))
        time.sleep(1.5)
        log("  7c ready:", lua(c, TOOL_STATE, "Client"), lua(c, STATS, "Client"))
        seen = set()
        for i in range(10):
            up = lua(c, FIND_UPGRADE, "Client")
            if up == "none":
                log("  no [Upgrade]")
                break
            click(c, up)
            time.sleep(0.15)
            pop = os.path.join(OUT, f"7c_press{i + 1}_t015.png")
            shot(c, pop)
            time.sleep(1.3)
            st = lua(c, TOOL_STATE, "Client")
            log(f"  7c press {i + 1}:", st, lua(c, STATS, "Client"))
            kind = "same" if "Result=Not this time" in st else "up" if "Result=" in st else "none"
            if kind not in seen:
                shot(c, os.path.join(OUT, f"7c_{kind}.png"))
            seen.add(kind)
            if "same" in seen and "up" in seen:
                break
        log("  7c seen:", sorted(seen))
        close(c)
        # 7e the Blessed Scroll (test Config: Mixing Kit +0 = 100%, AS1 at craft Lv 1)
        log("7e", scene(c, {"Features": ARTISAN, "Faction": "Neutral", "Class": "Mage", "Level": 8, "Tutorial": "Done",
                            "Done": CH1, "Items": {"Herb": 40, "CopperOre": 30, "SlimeCore": 20}, "Gold": 5000, "At": "Bench:Alch"}))
        time.sleep(3)
        close(c)
        log("  start AS1:", lua(c, 'game.ReplicatedStorage.Remotes.CraftStart:FireServer("AS1") return "sent"', "Client"))
        time.sleep(2.5)
        skip = lua(c, 'for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d:IsA("GuiButton") and d.Name == "Skip" and d.Visible then return d:GetFullName() end end return "none"', "Client")
        log("  skip:", skip)
        if skip != "none":
            log("  ", click(c, skip))
            time.sleep(0.7)
            log("  7e result:", lua(c, RESULT, "Client"))
            shot(c, os.path.join(OUT, "7e_blessed.png"))
            time.sleep(1.6)
            log("  7e +2.3 s:", lua(c, RESULT, "Client"), "| ring open:",
                lua(c, 'for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d.Name == "CraftRing" then return "yes" end end return "no"', "Client"))
            time.sleep(1.2)
            log("  7e +3.5 s ring open:",
                lua(c, 'for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d.Name == "CraftRing" then return "yes" end end return "no"', "Client"))
        log("  bag:", debug(c, "DataDump", "Items")[:300])
    finally:
        save_log(os.path.join(OUT, "log.txt"))
        stop_play(c)


if __name__ == "__main__":
    main()
