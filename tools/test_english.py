"""A23-48 English only (user 2026-10-06): Config player strings and server-sent text, offline.

Loads the CURRENT Config (with Util, through tools/fixtures/dev2_kit.luau) and scans every ServerScriptService script
with tools/fixtures/english_offline.luau and the installed official Luau CLI: no Hangul in any Config string (also the
ones built with string.format at load) outside Config.UIArt and the language's own name, X / XEn twins hold the same
text, glossary names (docs/design/glossary_en_2026-10-06.md), no Hangul in server code outside the nickname word lists.
No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_english.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_english_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

SERVER = sorted(p for p in SSS.glob("*.luau"))
FILES = {"CONFIG_SOURCE": SHARED / "Config.luau", "UTIL_SOURCE": SHARED / "Util.luau"}
FILES.update({"S_" + p.stem.replace(".", "_").upper(): p for p in SERVER})
C = "CONFIG_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    server = "\n".join(f"=====FILE {FILES[key].name}\n{sources[key]}" for key in FILES if key.startswith("S_"))
    return {"CONFIG_SOURCE": sources[C], "UTIL_SOURCE": sources["UTIL_SOURCE"], "SERVER_TEXT": server}


MUTATIONS = [
    ("a Korean message comes back", C, 'LoadFailed = "We couldn\'t load your save. Please rejoin in a moment.",',
     'LoadFailed = "데이터를 불러오지 못했어요.",'),
    ("the Korean honorific comes back", C, 'Honorific = "", HonorificEn = ""', 'Honorific = "님", HonorificEn = ""'),
    ("a Korean weapon name", C, 'Warrior = { "Twig", "Wooden Sword"', 'Warrior = { "나뭇가지", "Wooden Sword"'),
    ("a Korean line built by string.format", C, '\tLines = {\n\t\tstring.format("KO a player weaker than %d%% of your power"',
     '\tLines = {\n\t\tstring.format("내 전투력의 %d%%보다 약한 상대"'),
    ("a Korean weekly title (built at load)", C,
     'Name = string.format("This week\'s %s #%d", R.Text.TitleNames[board], rank),',
     'Name = string.format("이번 주 %s %d위", R.Text.TitleNames[board], rank),'),
    ("a Korean premise line", C, '\t\t"Now each side says the other did it.",',
     '\t\t"이제 서로 저쪽이 그랬다고 해요.",'),
    ("a Korean travel name", C, '{ Id = "SlimeMeadow", Name = "Squishy Meadow" }', '{ Id = "SlimeMeadow", Name = "말랑 초원" }'),
    ("twins drift apart", C,
     'VisitBlacksmithEn = "Get your first weapon · Crossroads Forge",',
     'VisitBlacksmithEn = "Get your first weapon · the Forge",'),
    ("a faction off the glossary", C, 'Name = "Knights of Light", Short', 'Name = "Light Knights", Short'),
    ("the character window is not 'Hero'", C, 'Label = "Hero", LabelEn = "Hero"', 'Label = "Character", LabelEn = "Character"'),
    ("an artisan class off the glossary", C, 'Neutral = "Pet Tamer", None = "Archer"', 'Neutral = "Tamer", None = "Archer"'),
    ("a Korean potion notice", "S_VITALSSERVICE", 'Net.Notify(player, "HP is full.", "info")',
     'Net.Notify(player, "HP가 가득 찼어요.", "info")'),
    ("a Korean nametag word", "S_CHARACTERVISUALS", 'line2 ..= "  Sprout Shield"', 'line2 ..= "  새싹 보호"'),
    ("a Korean nickname message", "S_NICKNAMESERVICE", 'Active = "Nickname saved.",', 'Active = "닉네임을 저장했어요.",'),
    ("a Korean world sign", "S_MAPBUILDER", 'text.Text = "Wanted Board"', 'text.Text = "현상수배 게시판"'),
    ("a Korean team name", "S_FACTIONSERVICE", 'local NONE_TEAM_NAME = "Choosing a side"', 'local NONE_TEAM_NAME = "진영 고르는 중"'),
    # ⑪ the five names (lines_pack §1)
    ("the Halo guide loses her name", C, 'Name = "Hallie", Title = "Guide of Light",', 'Name = "Guide of Light",'),
    ("no catchphrase line", C, '\t\t\t\t"Finders keepers! HA! You\'re with us now. I\'m Magpie.",\n', ""),
    ("the blacksmith speaker is the role again", C, 'Smith = "Otto", Guild = "Kit"', 'Smith = "Blacksmith", Guild = "Kit"'),
    ("the off-side line without the guide", C, 'OffSideHalo = "Hallie: Hmm… not very angel-like! Honor -%d"',
     'OffSideHalo = "Not very angel-like! Honor -%d"'),
    ("the potion prompt ignores the label", "S_MAPBUILDER", 'tune.PotionMerchantLabel or "Potion Seller"', '"Potion Seller"'),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    config = read(SHARED / "Config.luau")
    check("Korean string" not in config.split("\n", 1)[0], "the Config header no longer says 'Korean string'")
    check("LocaleId" not in config and "SetLanguage" not in config, "no LocaleId / language switching in Config (A23-48)")
    check(len(SERVER) >= 30, "every server script is part of the scan")
    return count, failures


SUITE = Suite(
    mark="ENGLISH",
    fixture=ROOT / "tools/fixtures/english_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_english_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-48: every Config string the game can show (incl. strings built with string.format at load) is "
             "English; exceptions = Config.UIArt (image-dev's block, baked FactionE cards off) and the 'ko' language "
             "option's own name. X / XEn twins hold the same text (Keybinds Auto Label / Button excepted: 게임성 개발 1). "
             "Glossary names for factions, artisan classes, zones, monsters, items, Hero, Power, Baby Slime, the "
             "ranking boards and the game. Every server script's code (comments aside) is free of Hangul except the "
             "nickname policy word lists.",
    limitations="Client modules (StarterPlayerScripts) are not scanned (게임성 개발 1 / 이미지 개발). A string with '--' "
                "inside is scanned only up to it. Wording quality is reviewed by people, not by this test.",
)

if __name__ == "__main__":
    run(SUITE)
