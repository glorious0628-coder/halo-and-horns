"""The server day and weather (DayCycleService, 게임성 개발 2, SPEC A23-105 2026-10-10), offline.

A23-105: the server turns Lighting.ClockTime once per 24-min day (Day most of it, Dusk / Night / Dawn short; Pace = the
clock's speed, Phases = the published DayPhase names, Dawn from 6:00 when the light is half up) by a small step every Tick
(0.5) s; the Neutral sky's light follows the time of day (Day = Config.Sky.Neutral) and never drops below
Config.DayCycle.Floor; a crown-war sky (WarService Dawn / Eclipse) covers only the LOOK (검수 2026-10-10, the user's choice
(b)): ClockTime keeps turning under it every tick, WarService never tweens or writes the clock while the cycle runs, and
when the war sky ends the look eases over Config.Sky.TweenTime from the war look to the look of the time of day it is
then; one server weather Clear / Rain / Snow (snow only in the KST winter months, then instead of rain); GameState
DayPhase / NightLevel / Weather. DayPhase / NightLevel ALWAYS follow the ClockTime shown, under every sky (검수 2026-10-10
lens review; Config.DayCycle.WarSky is gone): DayPhase = PhaseOf(clock), NightLevel = LookAt(clock).Night (2 decimals) -
a Halo win at 17:30 runs into Dusk and Night with NightLevel rising, a Horns win at noon is Day / 0; the clock shown is
Lighting.ClockTime itself during the switch-off clock ease and whenever the cycle does not own the clock (Enabled false /
Start not done: the fixed afternoon 15.3 = Day / 0, the Eclipse preset 0.5 = Night / 1). The cycle owns the time and the
Neutral look only once its Start ran (before / without it WarService keeps the fixed Neutral afternoon and the preset war
clocks). WarService no longer writes LightingStyle (a place setting, Soft) and its preset war-sky clock tween (cycle off
only) goes forward at most Config.Sky.ClockForwardMax (18) hours (CR-L20 amended; every change between the fixed presets,
the longest Dawn -> Eclipse 17.3 h, still runs forward).
Merge gate: Config.DayCycle.Enabled is false on this branch until the client half lands - ZoneLook C1 (night lift and
NightBright floor scaled by GameState NightLevel, not `sky == "Eclipse"`) and C2 (the haunted hollow's dusk clock without
the 11 h jump at base 6:00). The fixture turns the cycle on for every group that tests it running; the gate group reads
the REAL Config: Enabled true needs C1 (static text checks on ZoneLook) and C2 (ZoneLook's real duskOver over a whole day
of the cycle, every Tick, never more than 0.25 h a step); Enabled false records the current state as findings. The gate
tests itself on patched copies of the pre-C1 / pre-C2 text (they pass, the current text does not).

Runs the CURRENT Config, Util, DayCycleService and WarService on tools/fixtures/dev2_kit.luau +
tools/fixtures/day_cycle_offline.luau with the installed official Luau CLI (Lighting / TweenService / NumberValue / Clouds
/ Color3 / SwitchService / FactionService / PlayerService are doubles; os.time and the server clock are the kit's). Net,
Main and ZoneLook are read as text (GameState defaults, the INIT / START lists, the debug keys, the gate); ZoneLook's
duskOver is evaluated on its own. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of
the sources only.

Usage: py tools/test_day_cycle.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev2_day_cycle_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "NET_SOURCE": SHARED / "Net.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "DAYCYCLE_SOURCE": SSS / "DayCycleService.luau",
    "WAR_SOURCE": SSS / "WarService.luau",
    "ZONELOOK_SOURCE": ROOT / "src/StarterPlayer/StarterPlayerScripts/ZoneLook.luau",
}
C, D, W, N, M = "CONFIG_SOURCE", "DAYCYCLE_SOURCE", "WAR_SOURCE", "NET_SOURCE", "MAIN_SOURCE"


def zonelook_dusk(zl: str) -> str:
    """ZoneLook's own lerp + clockDelta + duskOver and the haunted hollow's Dusk entry, as a chunk returning
    base ClockTime -> the hollow's ClockTime (dusk weight 1). ValueError when ZoneLook's text changed."""
    lerp = re.search(r"^local function lerp\(a, b, t\)[^\n]*$", zl, re.M)
    dusk = re.search(r"Dusk = \{ Clock = ([\d.]+), Fog = rgb\((\d+), (\d+), (\d+)\), FogStart = (\d+), FogEnd = (\d+)", zl)
    if not lerp or not dusk:
        raise ValueError("ZoneLook lerp / HauntedHollow Dusk changed; update the test extractor (tools/test_day_cycle.py).")
    return (
        "local col = ...\n" + lerp.group(0) + "\n"
        + function_block(zl, "local function clockDelta(")
        + function_block(zl, "local function duskOver(")
        + f"local d = {{ Clock = {dusk[1]}, Fog = col({dusk[2]} / 255, {dusk[3]} / 255, {dusk[4]} / 255), "
        + f"FogStart = {dusk[5]}, FogEnd = {dusk[6]} }}\n"
        + "return function(base)\n\treturn duskOver({ ClockTime = base, FogColor = col(0.5, 0.5, 0.5), FogStart = 150, "
        + "FogEnd = 950 }, 1, d).ClockTime\nend\n")


def bindings(sources: dict[str, str]) -> dict[str, str]:
    # ZONELOOK_SOURCE goes in as text (the merge gate's static C1 checks); ZONELOOK_DUSK = its haunted hollow clock (the
    # C2 continuity check). A ZoneLook the extractor no longer understands never aborts the run: ZONELOOK_DUSK is empty,
    # ZONELOOK_DUSK_ERROR says why, and the gate fails clearly only if Config.DayCycle.Enabled is true (else a finding)
    out = dict(sources)
    try:
        out["ZONELOOK_DUSK"], out["ZONELOOK_DUSK_ERROR"] = zonelook_dusk(sources["ZONELOOK_SOURCE"]), ""
    except ValueError as error:
        out["ZONELOOK_DUSK"], out["ZONELOOK_DUSK_ERROR"] = "", str(error)
    return out


MUTATIONS = [
    # the day: length, phases, smooth clock
    ("the day twice as long", C, "{ From = 7, Seconds = 960 }, -- the day", "{ From = 7, Seconds = 2400 }, -- the day"),
    ("night as long as the day", C, "{ From = 19, Seconds = 240 }, -- the night", "{ From = 19, Seconds = 960 }, -- the night"),
    ("night starts at 21", C, '{ Name = "Night", From = 19 },', '{ Name = "Night", From = 21 },'),
    ("Dawn (lamps off) from 5:00 under the full night look", C, '{ Name = "Dawn", From = 6 },', '{ Name = "Dawn", From = 5 },'),
    ("one write a second again (Tick 1)", C, "\tTick = 0.5,\n\tStartClock = 15.3,\n", "\tTick = 1,\n\tStartClock = 15.3,\n"),
    # the merge gate (검수 2026-10-10): the cycle stays off until ZoneLook C1 (night lift by NightLevel) + C2 (hollow dusk
    # without the 6:00 jump) land
    ("Enabled = true without ZoneLook C1/C2", C, "\tEnabled = false,\n\tTick = 0.5,\n", "\tEnabled = true,\n\tTick = 0.5,\n"),
    ("ClockForwardMax 16: Dawn -> Eclipse runs backwards", C, "Config.Sky.ClockForwardMax = 18\n", "Config.Sky.ClockForwardMax = 16\n"),
    ("the cycle owns the light before its Start", D, "\treturn dc().Enabled == true and st.Running == true\n",
     "\treturn dc().Enabled == true\n"),
    ("the clock jumps phase to phase", D, "\t\t\treturn (a + (b - a) * t) % 24\n", "\t\t\treturn a % 24\n"),
    ("phases share one speed (24 h over the first phase's seconds)", D,
     "\t\tif left < secs or i == #list then\n", "\t\tif true then\n"),
    ("PhaseOf / PosOf without the wrap", D,
     "\t\tlocal c = c0\n\t\twhile c < a do\n\t\t\tc += 24\n\t\tend\n\t\tif c < b then return i, c, a, b end",
     "\t\tlocal c = c0\n\t\tif c >= a and c < b then return i, c, a, b end"),
    ("a new server starts at noon", C, "\tStartClock = 15.3,\n", "\tStartClock = 12,\n"),
    ("the day is not Neutral", C, "\t\tDay = {},\n", "\t\tDay = { Brightness = 2.6 },\n"),
    ("looks switch without easing", D, "fromName, toName, s = k.Look, nextKey.Look, t * t * (3 - 2 * t)",
     "fromName, toName, s = k.Look, nextKey.Look, t < 0.5 and 0 or 1"),
    ("every tick rewrites everything", D, "\tif okRead and not differs(cur, value) then return end\n", ""),
    # floors and the night look
    ("no floor", D, "\tfloored(v)\n\tif type(v.FogStart)", "\tif type(v.FogStart)"),
    ("floor too low", C, "\tFloor = { Brightness = 1.2,", "\tFloor = { Brightness = 0.6,"),
    ("a pitch-dark night", C, "OutdoorAmbient = Color3.fromRGB(98, 110, 148),\n\t\t\tExposureCompensation = 0.35,",
     "OutdoorAmbient = Color3.fromRGB(30, 34, 46),\n\t\t\tExposureCompensation = 0.35,"),
    ("no NightLevel", D, '\t\tsetGame("NightLevel", n)\n', ""),
    ("no DayPhase", D, '\t\tsetGame("DayPhase", phase)\n', ""),
    # DayPhase / NightLevel follow the clock shown under every sky (검수 2026-10-10 lens review)
    ("NightLevel is not the look's night share (0 / 1 by the phase)", D,
     "\tpublish(DayCycleService.PhaseOf(c), DayCycleService.LookAt(c).Night)\n",
     "\tpublish(DayCycleService.PhaseOf(c), DayCycleService.PhaseOf(c) == \"Night\" and 1 or 0)\n"),
    ("a war sky publishes a fixed phase (the old WarSky rule, every tick)", D,
     "\tpublishClock(clockEasing and lightingClock(v.ClockTime) or v.ClockTime) -- the clock shown, under every sky\n",
     "\tif st.War then\n\t\tpublish(st.War == \"Eclipse\" and \"Night\" or \"Day\", st.War == \"Eclipse\" and 1 or 0)\n\telse\n"
     "\t\tpublishClock(clockEasing and lightingClock(v.ClockTime) or v.ClockTime)\n\tend\n"),
    ("Cover publishes the war sky's fixed phase", D,
     "\tif not st.War then st.WarSince = Util.Now() end\n\tst.War = sky\n",
     "\tif not st.War then st.WarSince = Util.Now() end\n\tst.War = sky\n"
     "\tpublish(sky == \"Eclipse\" and \"Night\" or \"Day\", sky == \"Eclipse\" and 1 or 0)\n"),
    ("Studio's Clock keeps the old phase under a war sky", D,
     "\tpublishClock(v.ClockTime)\n\tif st.War then return end\n", "\tif st.War then return end\n\tpublishClock(v.ClockTime)\n"),
    ("the switch-off ease publishes the frozen StartClock, not the clock shown", D,
     "\tpublishClock(clockEasing and lightingClock(v.ClockTime) or v.ClockTime) -- the clock shown, under every sky\n",
     "\tpublishClock(v.ClockTime) -- the clock shown, under every sky\n"),
    ("cycle-off Step never publishes", D,
     "\t\tpublishClock(presetClock()) -- e.g. the Eclipse preset 0.5 = Night / 1: its lamps on\n", ""),
    ("cycle-off Step follows the sweeping tween clock (the lamps flicker)", D,
     "\t\tpublishClock(presetClock()) -- e.g. the Eclipse preset 0.5 = Night / 1: its lamps on\n",
     "\t\tpublishClock(lightingClock(startClock()))\n"),
    ("firstLight off-path publishes Day/0 instead of the preset clock", D,
     "\t\tpublishClock(presetClock()) -- the cycle is off: WarService's preset clock\n",
     "\t\tpublish(\"Day\", 0)\n"),
    ("the preset clock ignores the war sky", D, "\tlocal sky = WAR_SKY[warBlessing()] or \"Neutral\"\n\tlocal preset",
     "\tlocal sky = \"Neutral\"\n\tlocal preset"),
    # the war sky covers the look only; the clock keeps turning (검수 2026-10-10, user (b))
    ("WarService writes the preset clock while the cycle owns the time", W,
     "local clockTarget = (cycle == nil) and num(preset.ClockTime) or nil", "local clockTarget = num(preset.ClockTime)"),
    ("WarService holds the war preset clocks again (the old rule)", W,
     "local clockTarget = (cycle == nil) and num(preset.ClockTime) or nil",
     "local clockTarget = (not cycleLook) and num(preset.ClockTime) or nil"),
    ("the cycle stops the clock under a war sky", D,
     "\tif not clockEasing then setProp(Lighting, \"ClockTime\", v.ClockTime) end\n",
     "\tif not clockEasing and not st.War then setProp(Lighting, \"ClockTime\", v.ClockTime) end\n"),
    ("the clock waits for the look's hand-back", D,
     "\tif not clockEasing then setProp(Lighting, \"ClockTime\", v.ClockTime) end\n",
     "\tif not clockEasing and now >= st.LookUntil then setProp(Lighting, \"ClockTime\", v.ClockTime) end\n"),
    ("the cycle writes the look under a war sky", D,
     "\tif st.War or now < st.LookUntil then return end\n", "\tif now < st.LookUntil then return end\n"),
    ("the hand-back eases to the war-start look", D, "\tlocal target = valuesFor(now + seconds)\n",
     "\tlocal target = valuesFor(st.WarSince + seconds)\n"),
    ("the hand-back aims at its start (a step when it ends)", D, "\tlocal target = valuesFor(now + seconds)\n",
     "\tlocal target = valuesFor(now)\n"),
    ("the hand-back tweens the clock again", D, "\t\tst.LookTween = playTween(Lighting, easeInfo(seconds), goal)\n",
     "\t\tgoal.ClockTime = target.ClockTime\n\t\tst.LookTween = playTween(Lighting, easeInfo(seconds), goal)\n"),
    ("WarService never covers the cycle's look", W, "\t\tlocal ok, err = pcall(cycle.Cover, name)\n", "\t\tlocal ok, err = true, nil\n"),
    ("WarService never hands the look back", W,
     "\t\tlocal ok, err = pcall(cycle.Uncover, animate and Config.Sky.TweenTime or 0)\n", "\t\tlocal ok, err = true, nil\n"),
    ("WarService paints Neutral over the cycle", W, "\tif cycleLook then table.clear(goals) end", "\tif false then table.clear(goals) end"),
    ("the war clock spins a whole day (forward only, cycle off)", W,
     "\tif to - from > (num(Config.Sky.ClockForwardMax) or 18) then\n\t\tto -= 24\n\tend\n", ""),
    ("no safety net", D, "\tif sky and st.War ~= sky then\n", "\tif false then\n"),
    ("Cover keeps the hand-back look ease", D,
     "\tif type(sky) ~= \"string\" or sky == \"Neutral\" then return end\n\tcancelLook()\n",
     "\tif type(sky) ~= \"string\" or sky == \"Neutral\" then return end\n"),
    ("the hand-back is a jump", D, "\teaseLook(math.max(0, num(seconds)))\n", "\teaseLook(0)\n"),
    ("steps write the look during the hand-back", D, "\t\tst.LookUntil = now + seconds\n", "\t\tst.LookUntil = 0\n"),
    # the DayCycle switch
    ("the switch is ignored", D, "\tlocal frozen = not switchOn(\"DayCycle\")\n", "\tlocal frozen = false\n"),
    ("the switch-off clock jumps", D, "\t\t\teaseClock(handBackSeconds()) -- off: the clock eases to StartClock\n", ""),
    ("the switch-off clock spins the long way", D, "\tlocal span = ((to - from + 12) % 24) - 12\n",
     "\tlocal span = (to - from) % 24\n"),
    ("the switch-off paints the look over a war sky", D, "\t\t\tif not st.War then easeLook(handBackSeconds()) end",
     "\t\t\teaseLook(handBackSeconds())"),
    ("the cycle writes when the Config turns it off", D, "\tstepWeather(now, dt)\n\tif not DayCycleService.Owns() then\n",
     "\tstepWeather(now, dt)\n\tif false then\n"),
    # the weather
    ("UTC instead of KST", D, "\tlocal offset = math.floor(num(w.UtcOffsetHours, 9) * 3600)\n", "\tlocal offset = 0\n"),
    ("no December", C, "\tSnowMonths = { [12] = true, [1] = true, [2] = true },", "\tSnowMonths = { [1] = true, [2] = true },"),
    ("March is winter", C, "\tSnowMonths = { [12] = true, [1] = true, [2] = true },", "\tSnowMonths = { [12] = true, [1] = true, [2] = true, [3] = true },"),
    ("snow all year", D, "\treturn DayCycleService.IsWinterKST(t) and \"Snow\" or \"Rain\"", "\treturn \"Snow\""),
    ("rain and snow never cross over", D,
     "\tif st.Spell == \"Wet\" then weather = st.Force or DayCycleService.WeatherKindAt(os.time()) end",
     "\tif st.Spell == \"Wet\" then weather = st.Force or st.Weather ~= \"Clear\" and st.Weather or DayCycleService.WeatherKindAt(os.time()) end"),
    ("WinterChance ignored", D, "and num(w.WinterChance, num(w.Chance)) or num(w.Chance)", "and num(w.Chance) or num(w.Chance)"),
    ("rain whenever a spell ends", D, "\t\t\tnewSpell(now, roll < chance and \"Wet\" or \"Clear\")", "\t\t\tnewSpell(now, \"Wet\")"),
    ("showers never end", D, "\t\telse\n\t\t\tnewSpell(now, \"Clear\")\n\t\tend\n", "\t\tend\n"),
    ("rain far too often", C, "\tChance = 0.45,\n", "\tChance = 0.95,\n"),
    ("the wet look jumps", D, "\tlocal step = dt / math.max(1, num(w.BlendSeconds, 20))\n", "\tlocal step = 1\n"),
    ("rain does not touch the light", D, "\t\twetLight(v, kind, clamp01(num(type(wet) == \"table\" and wet[kind] or 0)))\n", ""),
    ("no clouds in rain", D, "\t\tsetProp(clouds(), \"Cover\", goal.Cover)\n", ""),
    ("Weather not published", D, "\t\tsetGame(\"Weather\", weather)\n\tend\n", "\tend\n"),
    ("the weather switch is ignored", D, "\tif w.Enabled ~= true or not switchOn(\"Weather\") then\n", "\tif w.Enabled ~= true then\n"),
    ("a new server may start wet", D, "\tst.SpellEndsAt = now + rangeOf(wc().FirstClear, 450) -- a new server starts clear\n",
     "\tst.SpellEndsAt = now -- a new server starts clear\n"),
    ("one seed for every server", D, "\t\th = (h * 31 + string.byte(id, i)) % 2147483647\n", ""),
    ("Seed ignored", D, "\tif type(s) == \"number\" then return s end\n", ""),
    # debug, Net, Main, WarService style
    ("debug clock does nothing", D, "\tst.Epoch = Util.Now() - DayCycleService.PosOf(h)\n\tif not DayCycleService.Owns()",
     "\tif not DayCycleService.Owns()"),
    ("debug snow follows the season", D, "\tst.Force = kind ~= \"Clear\" and kind or nil\n", "\tst.Force = nil\n"),
    ("no Net defaults", N, '\tDayPhase = "Day", NightLevel = 0, Weather = "Clear",\n', ""),
    ("not in Main START", M, "\t\"DayCycleService\", -- 게임성 개발 2: A23-105 (after WarService,", "\t-- 게임성 개발 2: A23-105 (after WarService,"),
    ("the day debug keys need a ready player", M,
     "\t\tif key == \"Clock\" or key == \"Weather\" or key == \"DayState\" then -- A23-105",
     "\t\tif false then -- A23-105"),
    ("Debug never sets the weather", D, "\tif key == \"Weather\" then return DayCycleService.DebugWeather(value) end\n", ""),
    ("LightingStyle written again", W, "local function bootstrapLighting()\n",
     "local function bootstrapLighting()\n\tpcall(function() Lighting.LightingStyle = Enum.LightingStyle.Realistic end)\n"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    day = read(SSS / "DayCycleService.luau")
    code = strip_comments(day)
    check("task.wait(" in code and re.search(r"(?<![\w.])wait\(", code) is None, "task.wait only")
    check(re.search(r"(?<![\w.])(spawn|delay)\(", code) is None, "task.spawn / task.delay only")
    check("<const>" not in day, "no <const>")
    check("Atmosphere" not in code, "never an Atmosphere (A9-3)")
    check('Instance.new("Atmosphere")' not in code and "SkyboxUp" not in code, "the sky faces stay WarService's")
    for key in ("Keys", "Looks", "Floor", "StartClock", "Tick"):
        check(f"dc().{key}" in code, f"reads Config.DayCycle.{key}")
    # 검수 2026-10-10 lens review: no fixed war-sky phase anywhere (DayPhase / NightLevel follow the clock shown)
    config = read(SHARED / "Config.luau")
    day_cfg = re.search(r"^Config\.DayCycle = \{\n(.*?)^\}\n", config, re.S | re.M)
    check(day_cfg is not None and "WarSky" not in strip_comments(day_cfg.group(1)), "Config.DayCycle has no WarSky entry")
    check("dc().WarSky" not in code and "publishWar" not in code, "DayCycleService reads no WarSky / has no publishWar")
    check(code.count("setGame(\"DayPhase\"") == 1 and code.count("setGame(\"NightLevel\"") == 1
          and len(re.findall(r"(?<![\w.])publish\(", code)) == 2,
          "DayPhase / NightLevel are written in one place (publish, deduped; called only from publishClock)")
    for key in ("Pace", "Phases"):
        check(f'listOf("{key}")' in code, f"reads Config.DayCycle.{key}")
    for key in ("SnowMonths", "UtcOffsetHours", "Chance", "WinterChance", "BlendSeconds", "FirstClear", "Seed"):
        check(f"w.{key}" in code or f"wc().{key}" in code, f"reads Config.Weather.{key}")
    war = strip_comments(read(SSS / "WarService.luau"))
    check("LightingStyle" not in war and "LIGHT_STYLE" not in war, "WarService never writes LightingStyle (place setting)")
    check("Technology" not in war, "WarService never writes Technology (place setting)")
    # 검수 2026-10-10 (user (b)): the cycle never tweens the clock for a war sky; ClockForwardMax is WarService's (cycle off)
    check("ClockForwardMax" not in code and "Config.Sky.ClockForwardMax" in war,
          "ClockForwardMax only in WarService's preset clock tween (the cycle has no war clock tween)")
    for gone in ("Hold", "Resume", "BlendUntil", "clockSpan", "Held"):
        check(re.search(rf"\b{gone}\b", code) is None and re.search(rf"\bcycle\.{gone}\b", war) is None,
              f"the old clock hold is gone ({gone})")
    zl = read(ROOT / "src/StarterPlayer/StarterPlayerScripts/ZoneLook.luau")
    managed = re.search(r"local MANAGED = \{(.*?)\}", zl, re.S)
    names = set(re.findall(r'"(\w+)"', managed.group(1))) if managed else set()
    owned = {"ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "FogColor", "FogStart", "FogEnd"}
    check(owned <= names, "every property the cycle writes is in ZoneLook's MANAGED list (its base follows the server)")
    return count, failures


SUITE = Suite(
    mark="DAYCYCLE",
    fixture=ROOT / "tools/fixtures/day_cycle_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev2_day_cycle_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-105 day: ClockTime turns once per 1440 s (Pace 5-7 120 s, 7-17 960 s, 17-19 120 s, 19-5 240 s), a step "
             "every Tick (0.5 s, <= MaxStepHours 0.025 h, always forward); DayPhase by Phases (Dawn 6-7 = 60 s, Day 7-17 = "
             "960 s, Dusk 17-19 = 120 s, Night 19-6 = 300 s; Dawn only once the light is half up). GameState DayPhase / "
             "NightLevel ALWAYS follow the ClockTime shown, under every sky: DayPhase = PhaseOf(clock), NightLevel = "
             "LookAt(clock).Night (the night share of the time-of-day look, 2 decimals); a war sky never fixes them (Halo "
             "at 17:30 -> Dusk then Night, NightLevel rising; Horns at noon -> Day / 0); the clock shown = Lighting.ClockTime "
             "during the switch-off ease and whenever the cycle does not own the clock (fixed afternoon 15.3 = Day / 0, "
             "Dawn preset 7.2 = PhaseOf(7.2), Eclipse preset 0.5 = Night / 1), published every tick, changes only. "
             "Config.DayCycle.Enabled = false until ZoneLook C1 (night lift by NightLevel) + C2 (hollow dusk without the "
             "6:00 jump) land (the gate group). The cycle owns the time and "
             "the Neutral look only after its Start (WarService keeps Neutral and the preset war clocks before / without "
             "it); the Neutral sky's light by the "
             "time of day (Looks / Keys, Day = Config.Sky.Neutral exactly 8-16) with Floor minimums (rain at night "
             "included); a new server starts at StartClock 15.3. War (검수 2026-10-10, user (b)): WarService Cover(sky) on "
             "Dawn / Eclipse - it tweens the look only, never the clock while the cycle runs -, the cycle keeps writing "
             "ClockTime every tick (forward, <= MaxStepHours; never a look key) under it; Uncover(TweenTime) on Neutral "
             "(one Lighting look tween, no ClockTime, toward ValuesAt of the time it ends - not the war-start look -, no "
             "look writes until it ends, the clock turning meanwhile, no jump after); a missed call is caught by the next "
             "step. Cycle off: WarService's preset clocks, forward <= ClockForwardMax 18 h (Dawn -> Eclipse +17.3 h). "
             "Switch DayCycle off: the clock eases the short way to StartClock (the look with it unless a war sky covers "
             "it). "
             "Weather: Clear / Rain (Snow instead in KST months 12/1/2), FirstClear, Clear, Chance / WinterChance, Rain / "
             "Snow seconds, a shower changes kind at KST midnight, the wet look eases over BlendSeconds (sun, exposure, "
             "fog, clouds). GameState DayPhase / NightLevel / Weather; switches DayCycle / Weather; Studio debug Clock / "
             "Weather / DayState (no player, no save); WarService writes no LightingStyle.",
    limitations="Lighting, TweenService (tweens finish when the test says), Clouds, Color3 and the registry are doubles; "
                "how the night and the rain LOOK (PC and phone photos), how a war sky's look reads with the sun or moon of "
                "any hour (Eclipse at noon, Dawn at midnight), Roblox's own sun / moon position for a ClockTime, "
                "replication timing and the client modules running (ZoneLook's night lift by NightLevel, WeatherFx lamps) "
                "are not here - the gate only reads ZoneLook's text and evaluates its duskOver; main-Studio photos by "
                "메인 반영 1 with DebugCommand Clock / Weather once Enabled is true. With the cycle off, WarService's 3 s "
                "preset clock tween sweeps the sun through the hours in between (e.g. Neutral 15.3 -> Dawn 7.2 forward "
                "through the night) and DayPhase follows that shown clock tick by tick (lamps may come on for ~1-2 s).",
)

if __name__ == "__main__":
    run(SUITE)
