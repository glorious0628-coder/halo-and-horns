"""
검수가 고른 효과음을 게임용 이름으로 내놓기 (소리 만들기, 2026-10-07).
  py tools/sfx_final.py      art/sfx/cand/<후보>.wav를 바이트 그대로 art/sfx/<키>.wav로 복사하고 art/sfx/picks_r4.json에
                             sha256·출처·라이선스·볼륨·바꾸는 옛 파일·업로드 상태를 적는다(sound_spec §4: 고른 파일은 바이트 그대로 + sha256).
업로드(Creator Hub, wav)는 아직: 올리면 art/sfx/asset_ids.json "ids"와 sources.json을 갱신하고, 개발 1이 Config.Audio에 연결한 뒤
옛 art/sfx/*.ogg를 지운다(그림 규칙과 같이: 바뀐 것이 게임에 들어가기 전에는 옛 파일을 지우지 않음).
"""

import hashlib
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "art", "sfx")
CAND = os.path.join(SFX, "cand")
REPORT = os.path.join(ROOT, "build", "sfx_firefly", "r4b", "r4b.json")
ASSETS = os.path.join(ROOT, "build", "sfx_firefly", "raw_assets.json")
SPEC = os.path.join(ROOT, "tools", "sfx_spec.json")

# 검수 고름 (2026-10-07): 1번 묶음 = efc2604 장면 렌더 뒤 확정, 2·3번 묶음 = a5d9555 추천 그대로 확정,
# 4번 묶음 = 8efda17 추천 그대로 확정(새 계정 세션), 5번 묶음 SkillLearn = e351187 추천 sA 확정,
# 6번 묶음 Loot = 추천 sA 확정(검수 2026-10-07: 주문서·무기만, 무기는 0.92배)
PICKS = [
    # key, candidate, batch, replaces (old Config.Audio.Files keys / art/sfx files)
    ("SwingArrow", "SwingArrow_SwingArcher-2-4", 1, "SwingArcher (now silent); the code plays it twice"),
    ("SwingMageHalo", "SwingMageHalo_SwingMage-3-4", 1, "SwingMage (Halo side)"),
    ("SwingMageHorns", "SwingMageHorns_1-1", 1, "SwingMage (Horns side)"),
    ("HitHeavy", "HitHeavy_3-2", 1, "HitHeavy1 / HitHeavy2"),
    ("HitCrit", "HitCrit_sB3", 1, "new: a layer on top of the material hit (no metal, no body)"),
    ("ComboCoin", "ComboCoin_kA", 1, "ComboCoin"),
    ("HitSoft", "HitSoft_kB", 1, "HitSoft1 / HitSoft2 (check on a phone: -5.1 dB)"),
    ("PowerUp", "PowerUp_1-2", 1, "new (first weapon at the blacksmith, A23-68 #3)"),
    ("Jump", "Jump_2-2", 1, "new (user request)"),
    ("GoldPickup", "GoldPickup_sB", 2, "GoldPickup"),
    ("QuestNew", "QuestNew_sA", 2, "QuestNew"),
    ("QuestDone", "QuestDone_sA", 2, "QuestDone"),
    ("WindowClose", "WindowClose_sA", 2, "WindowClose"),
    ("Deny", "Deny_sA", 2, "Deny"),
    ("RankDown", "RankDown_sA", 2, "RankDown"),
    ("ScrollFail", "ScrollFail_sA", 2, "ScrollFail"),
    ("SkillHalo", "SkillHalo_sA", 2, "SkillHalo"),
    ("SkillHorns", "SkillHorns_sA", 2, "SkillHorns"),
    ("Purify", "Purify_sA", 2, "Purify"),
    ("Purify_b", "Purify_sB", 2, "Purify (second version; sound_spec: two versions take turns)"),
    ("Devour", "Devour_sA", 2, "Devour"),
    ("Potion", "Potion_sA", 2, "Potion"),
    ("AutoOn", "AutoOn_sA", 2, "AutoOn"),
    ("AutoOff", "AutoOff_sA", 2, "AutoOff"),
    ("TalkBlip", "TalkBlip_sB", 2, "TalkBlip (BarkPop plays it at 0.8-1.5x)"),
    ("Equip", "Equip_sA", 2, "new (weapon buy / equip; Upgrade leaves GoldPickup)"),
    ("SkillReady", "SkillReady_sA", 2, "new (now Tap)"),
    ("HurtBig", "HurtBig_sA", 2, "HitHeavy2 (when I am hit hard)"),
    ("PumpkinKing", "PumpkinKing_sA", 3, "KingBell (sound_spec file name: KingPumpkin)"),
    ("GhostKing", "GhostKing_sA", 3, "KingBell (sound_spec file name: KingGhost)"),
    ("GooseArrive", "GooseArrive_sA", 3, "new (GooseActive)"),
    ("GooseHonk", "GooseHonk_sA", 3, "GooseHonk (now two honks)"),
    ("CrownHalo", "CrownHalo_sA", 4, "new (a war round won by Halo)"),
    ("CrownHorns", "CrownHorns_sA", 4, "new (a war round won by Horns)"),
    ("KingDefeat", "KingDefeat_sA", 4, "new (a Halloween king is beaten)"),
    ("WarFinal30", "WarFinal30_sA", 4, "new (30 s before the war round ends)"),
    ("CountTick", "CountTick_sA", 4, "new (3-2-1 before a reveal, played at 1.0 / 1.12 / 1.26x)"),
    ("GooseEnd", "GooseEnd_sA", 4, "new (Fx GooseEnd)"),
    ("KaijuSiren", "KaijuSiren_sA", 4, "new (KaijuPhase Siren, 10 s warning)"),
    ("KaijuStomp", "KaijuStomp_sA", 4, "new (Fx Stomp, positional)"),
    ("ZoneEnterPvP", "ZoneEnterPvP_sA", 4, "new (ZonePvP false -> true)"),
    ("GoldenSpot", "GoldenSpot_sA", 4, "new (a golden monster comes into view; GoldenKill reuses this file)"),
    ("ScrollSuccess", "ScrollSuccess_1-4", 4, "ScrollSuccess"),
    ("Spend", "Spend_sA", 4, "new (potion buy: gold leaves my pocket)"),
    ("RankUp", "RankUp_sA", 4, "new (my side's rank / a new title)"),
    ("KO", "KO_sA", 4, "new (Fx KO, only to me)"),
    ("Respawn", "Respawn_sB", 4, "new (I appear again after a KO)"),
    ("Plunder", "Plunder_sB", 4, "new (my sack is taken; the taker hears GoldPickup)"),
    ("JackpotOther", "JackpotOther_sA", 4, "new (someone else's Jackpot / FirstMax line)"),
    ("SkillLearn", "SkillLearn_sA", 5, "new (A23-71: a skill is learned at Lv5 / 15 / 25; play it about 1.1 s after LevelUp)"),
    ("Loot", "Loot_sA", 6, "new (Fx Loot with a scroll or a weapon; a weapon may play it at 0.92x; materials / potions stay silent)"),
    # batch 7 (검수 picks of eef5072): the six sounds that were still the round-3 files ('kept' in asset_ids.json)
    ("SwingWarrior", "SwingWarrior_sA", 7, "SwingWarrior (round-3 file)"),
    ("KillPop", "KillPop_sA", 7, "KillPop (round-3 drop_002)"),
    ("ComboMilestone", "ComboMilestone_sA", 7, "ComboMilestone (round-3 confirmation_003; sA ends on C8 4.2 kHz, under the spec's 5 kHz)"),
    ("LevelUp", "LevelUp_sA", 7, "LevelUp (round-3 LevelUp_a; now with the phone body 523 + 785 Hz)"),
    ("Tap", "Tap_kA", 7, "Tap (round-3 select_002; game volume 0.46 keeps it +3 LU over TalkBlip)"),
    ("WindowOpen", "WindowOpen_sA", 7, "WindowOpen (round-3 maximize_009; the mirror of the new WindowClose)"),    ("QuestOpen", "QuestOpen_sA", 8, "new (batch 8: the quest window (Q) opens)"),
    ("QuestTab", "QuestTab_sA", 8, "new (batch 8: a quest window tab turns)"),
    ("StampPress", "StampPress_sA", 8, "new (batch 8: the attendance stamp (A23-77))"),
    ("Chest7Open", "Chest7Open_sA", 8, "new (batch 8: the day-7 attendance chest opens)"),
    ("WelcomeBack", "WelcomeBack_sA", 8, "new (batch 8: the Welcome back card (A23-79))"),
    ("DiaryPage", "DiaryPage_sA", 8, "new (batch 8: a King Diary page turns)"),
    ("CandyPlop", "CandyPlop_sA", 8, "new (batch 8: a candy goes into the candy jar)"),
    ("KingHelpHome", "KingHelpHome_sA", 8, "new (batch 8: king slime card [Help it hop home])"),
    ("KingTickleCoins", "KingTickleCoins_sA", 8, "new (batch 8: king slime card [Tickle out its coins])"),
    ("TipDing", "TipDing_sA", 8, "new (batch 8: the Lv5 key-settings tip (A23-81))"),
]

VOLUME = {"Tap": 0.46}  # 검수 2026-10-07: game volume differs from sfx_spec.json (short sound measures 4-5 dB low)

KENNEY = {
    "Chest7Open_sA": ["Interface Sounds switch_002"],  # the Kenney CC0 files inside each picked recipe (tools/sfx_recipes.py / sfx_make.py)
    "Tap_kA": ["Interface Sounds select_002", "click_003"],
    "ComboCoin_kA": ["Impact Sounds impactMetal_light_000"],
    "HitSoft_kB": ["Impact Sounds impactSoft_medium_004"],
    "SkillHorns_sA": ["Impact Sounds impactWood_light_000"],
    "AutoOn_sA": ["Interface Sounds switch_002"],
    "AutoOff_sA": ["Interface Sounds switch_002"],
    "Equip_sA": ["Interface Sounds switch_002"],
    "PumpkinKing_sA": ["Impact Sounds impactBell_heavy_003", "impactWood_medium_002", "impactGlass_light_003"],
    "GhostKing_sA": ["Impact Sounds impactBell_heavy_003", "impactGlass_medium_001"],
    "GooseArrive_sA": ["Impact Sounds footstep_grass_001", "Interface Sounds glass_002"],
    "CrownHalo_sA": ["Impact Sounds impactGlass_medium_000"],
    "CrownHorns_sA": ["Impact Sounds impactWood_medium_002", "impactWood_light_000", "footstep_snow_000"],
    "KingDefeat_sA": ["Impact Sounds impactGlass_light_003", "Interface Sounds confirmation_002"],
    "GooseEnd_sA": ["Impact Sounds footstep_grass_001"],
    "KaijuSiren_sA": ["Impact Sounds impactWood_medium_002", "footstep_snow_000"],
    "KaijuStomp_sA": ["Impact Sounds impactWood_medium_002", "footstep_snow_000"],
    "GoldenSpot_sA": ["Interface Sounds glass_002"],
}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    report = json.load(open(REPORT, encoding="utf-8")) if os.path.exists(REPORT) else {}
    by_cand = {}
    for k, v in report.items():
        if v.get("cand"):
            by_cand[os.path.basename(v["cand"])[:-4]] = v
    assets = json.load(open(ASSETS, encoding="utf-8")) if os.path.exists(ASSETS) else {}
    spec = json.load(open(SPEC, encoding="utf-8"))["keys"]
    out = {"about": "검수 picks of round 4 (2026-10-07): batch 1 confirmed after the scene renders (efc2604), batches 2-3 = the "
                    "소리 만들기 recommendations (a5d9555), batch 4 = the recommendations (8efda17), batch 5 = SkillLearn sA "
                    "(e351187), batch 6 = Loot sA, batch 7 = the six round-3 sounds remade (eef5072; ComboMilestone sA). Files are byte copies of "
                    "art/sfx/cand/<candidate>.wav "
                    "(mono 48 kHz 16-bit, K-weighted loudest 100 ms = -17 LUFS, peak <= -2.5 dBFS).",
           "upload": "batches 1-6 (51 files) are uploaded (ids in asset_ids.json 'ids'); batch 7 (6 files) is in asset_ids.json "
                     "'pending' until it is uploaded (Creator Hub, 'HH SFX <key>', Restricted, no Creator Store) and sent to 게임성 개발 1",
           "picks": {}}
    for key, cand, batch, replaces in PICKS:
        src = os.path.join(CAND, cand + ".wav")
        dst = os.path.join(SFX, key + ".wav")
        shutil.copyfile(src, dst)
        data = open(dst, "rb").read()
        r = by_cand.get(cand, {})
        source = r.get("source", "")
        params = r.get("params", {})
        firefly = "recipe" not in params
        rec = {
            "file": f"art/sfx/{key}.wav", "candidate": f"art/sfx/cand/{cand}.wav", "batch": batch,
            "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data),
            "verdict": r.get("verdict"), "score": r.get("score"), "durMs": r.get("durMs"), "centroidHz": r.get("centroidHz"),
            "phoneDropDb": r.get("phoneDropDb"),
            "volume": VOLUME.get(key, spec.get(key.split("_")[0], {}).get("volume")), "replaces": replaces,
        }
        if firefly:
            clip = source + ".wav"
            rec["made"] = f"Adobe Firefly 'Generate sound effects' clip {clip} cut by tools/sfx_cut.py " + json.dumps(params, ensure_ascii=False)
            rec["fireflyAsset"] = assets.get(clip, {}).get("assetId", "")
            rec["license"] = "Adobe Firefly generation (user's Adobe account; Adobe: commercially safe output); our cut / filter / level" + (
                " + our own thin synthesized 'tsing' layer (tools/sfx_cut.py tsing())" if params.get("tsing") is not None else "")
        else:
            rec["made"] = "our recipe (tools/sfx_recipes.py / sfx_make.py): " + params["recipe"]
            k = KENNEY.get(cand)
            rec["license"] = "our own synthesis" + (" + Kenney CC0 1.0 (" + ", ".join(k) + ")" if k else "")
        out["picks"][key] = rec
        print(f"{key:15s} <- {cand:30s} {rec['verdict']} {rec['durMs']} ms  {rec['license'][:60]}")
    with open(os.path.join(SFX, "picks_r4.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print(len(out["picks"]), "files")


if __name__ == "__main__":
    main()
