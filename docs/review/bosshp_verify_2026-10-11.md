# dev2-bosshp 검증 (검수 워크플로 2026-10-11)

대상: origin/dev2-bosshp 489867d5 + main ef928a95 합친 트리. 시험 10묶음 모두 통과(test_field_boss 220/220·변이 87/87 등). 아래는 리뷰 3관점(로직·밸런스·회귀)이 낸 것과 반박 검증 결과다. **병합 보류 — 확인된 것을 고친 뒤 다시.**

## 리뷰가 낸 것
- [high] Clatter HP 9000 assumes a Lv25 hunter with an un-enhanced T3 weapon; a normal Skeleton Ruins hunter kills him alone in about 20-80 s, and groups take about 35 s or less (src/ReplicatedStorage/Shared/Config.luau:2023)
  - 상황: A Lv25-30 player arrives in Skeleton Ruins (MinLevel 25) from Goblin Woods (Lv10-25). By then they usually hold T4 (MinLevel 12: Goblin drop P .001, Brute drop P .005, or the Lv12 commission when Config.Features.Commission is on) or a T3 with +5 to +8 from scroll drops. Once they farm the ruins they get T5 (MinLevel 20: Skeleton drop or the T5 commission). Under the doc's own model (swing plus Q, 75% uptime, average over 3 classes x 3 sides), solo times against 9000 HP are: T3+5 about 80 s, T4+0 52 s, T4+3 40 s, T5+0 23 s, T5+3 18 s. Only a Lv25 Archer on T3+0 (58.8 DPS, 153 s) is near 2 min. Each hunter's share is capped at 1 against a 75 DPS pace, so stronger players never add more HP: 3 hunters on T4 kill an 18000-HP Clatter in about 35 s, and 5 on T5 kill a 27000-HP one in about 14 s. The doc rejected k=0.15 because a 28 s fight hides the ground circle and the landing attack; these fights are as short or shorter. The old 20000 HP gave 116 s for Lv25 T4+0, which already met the A23-113 target of about 2 min solo.
  - 근거: I re-ran the doc's soloDps model (tools/fixtures/field_boss_offline.luau, same formula: WeaponDamage x class Damage x (1+DamageBonus), SwingImmediate 0.5, crit 10% x2, Q x6 MP20/3 s, MP 100 + 4/s, Mage swing MP 2, GlobalGap 0.5, x0.75) with the current Config. Lv25 T3+0 = 74.6 DPS (matches the doc). T4+0 = 172.9, T4+3 = 225.0, T5+0 = 392.8, T5+3 = 510.8. At Lv30 with T6 it is 944 DPS, about 9.5 s. There is no monster defense: MonsterService.DamageMonster subtracts the amount as is, and ComputeMonsterHit has no defense term. Lv10 to 25 needs 24,185 XP, which is about 600-760 Goblin Woods kills. I estimate P(T4 drop) at about 0.55-0.7, plus about 14-15 Enh70, 3.7 Enh30 and 0.9 Enh10 scrolls (Config.Loot.Tables Goblin/GoblinBrute/SlingshotGoblin) and about 13.8k gold. Calibrating to T4+0 for 2 min means HP of about 20,700, and T3+5 means about 13,400. Config.Weapons: T3 MinLevel 5, T4 MinLevel 12, T5 MinLevel 20.
- [medium] King 2000 averages the free T1 with T2 equally; a typical Lv5-8 hunter on T2 kills it alone in about 90 s, and one on the Lv5 T3 in about 35 s (src/ReplicatedStorage/Shared/Config.luau:2052)
  - 상황: The 150-gold first-mission reward is there so the player can buy T2 (Price 150) right after the gift weapon (AGENTS latest decisions), and the King never targets players below Lv5. So the usual Lv5-8 King hunter holds T2, not a 50/50 mix of T1 and T2. On T2 alone the model gives 22.1 DPS (Warrior 25.7, Mage 23.2, Archer 17.4), so solo is about 90 s (Warrior 78 s, Mage 86 s, Archer 115 s). Only a T1-only player sees about 170 s. A player who buys T3 (sold from Lv5 for 800 gold) does 54-58 DPS and kills the 2000-HP King in about 35 s. The old 2500 gave about 113 s on T2, which was closer to the 2-minute target for the expected weapon. The doc says the old value was 150 s because its average includes T1.
  - 근거: meanDps over Lv5-8, Halo/Horns/Neutral: T1+T2 average 16.9 DPS, 118 s (the doc's number). T2 only: 22.1 DPS, 90 s. T1 only: 11.8 DPS, 170 s. T3 at Lv5 or Lv8: 54.5 or 57.6 DPS, 37 or 35 s. For 120 s on T2, HP would be about 2650. Each player's share is capped at 1 against a pace of 2000/120 = 16.7 DPS, so a T3 helper (3.3x the pace) counts as one hunter, and King fights with such a helper end even sooner. The doc mentions this limit.
- [low] Free-rider gate gets cheaper: 2% of a 9000-HP Clatter is about 180-200 damage, so one Q plus two swings earns the full reward set (src/ServerScriptService/MonsterService.luau:1347)
  - 상황: The reward rate per server does not change, because the next slot is counted from the appearance (FieldBossService.tickOne sets NextAt = now + Interval 1200 inside appear) and the weekly badge banks up to Max 2. What gets cheaper is the gate on each kill. Someone soloing Clatter gets joined by a Lv25 T3 Archer (Halo) who lands one Q (rnd(38x1.48x0.55x6) = 186) and two swings (15 each), 216 damage in total. That player's crowd share is about 216/(75x15) = 0.19, so MaxHP goes to about 9900 and minDamage = 0.02 x 9900 = 198. With 3 hits and 216 damage they are a fully paid contributor: 3900 XP, 3900 gold, War 20 personal, 3 KnightCrest, the 20%/5% Enh30/Enh10 rolls and the weekly CaptainBadge (needed for the T6 commission). Under 20000 HP the gate was 400 damage, which takes two or more Q casts with a 3 s cooldown. Faster solo kills (see finding 1) also make hopping between servers for a due Clatter pay better, because a due slot waits for the first Lv25 player in the zone.
  - 근거: MonsterService.lua:1347 local minDamage = (tonumber(def.RewardMinDamageFrac) or 0) * rec.MaxHP; CaptainClatter RewardMinHits = 3, RewardMinDamageFrac = 0.02, MinorShare = 0.15 (Config.luau:2022). FieldBossService.extraOne pays War 20 / Weekly per paid id. The schedule is set in tickOne: b.NextAt = now + math.max(60, num(c.Interval, 480)) right after appear(), so kill speed does not change how often he spawns.
- [low] The KO1 retry King is not fully untouched: Config.FirstKORetry caps its HP at Config.MonsterTypes.SlimeKing.HP (2500 -> 2000). Pumpkin King is untouched (src/ReplicatedStorage/Shared/Config.luau:7822)
  - 상황: The design doc and the static test say KO1's personal King is separate. The first King uses FirstHP 5000 and is unaffected. The rematch King's HP is clamped to king.HP, so the def change lowers its ceiling by 500. No tested build reaches the cap (729 builds, Lv1-9, T1-3, +0/+3/+5; the strongest, Lv9 Horns Mage T3+5, is about 760 HP). It binds only for the legendary T8 at a high +N: Lv9 Horns Mage T8+10 = round(76x1.16x2.0x1.3x1.15x0.5) = 132 per swing / 1.1 s = 120 DPS x 17 s = 2040, now clamped to 2000 (it was 2040). So the practical effect is nil, but the coupling exists. The static check only greps for SetEventMaxHP in FirstKOService and would not catch it. PumpkinKing (Config.luau:2059, HalloweenService) has no diff, does not call SetEventMaxHP and is not in FieldBosses.Order, so it is untouched.
  - 근거: Config.luau:7821-7822: local king = Config.MonsterTypes[FK.Kind]; local hp = math.clamp(math.floor(R.Seconds * dps + 0.5), R.MinHP, math.max(R.MinHP, king and king.HP or 2500)). FirstKOKing.Retry = { Seconds = 17, HitPct = 0.075, MinHP = 40 }. FirstKOService.retryOf -> Config.FirstKORetry(level, BestUsableWeapon, class, faction, enh); FK.Kind defaults to SlimeKing. git diff HEAD^1 HEAD shows no change to the PumpkinKing row, HalloweenService or FirstKOService.
## 리뷰가 낸 것
- [medium] The crowd count lags for 15 s, so big groups kill the boss much faster than the documented times (src/ServerScriptService/FieldBossService.luau:169)
  - 상황: The King Slime has been up longer than 15 s, which is the usual case after the Appear announcement, and then 10 equal hunters arrive together. Each hunter's share is recent damage divided by (one hunter's pace x the whole span since the baseline snapshot). That span is about 15 s, so a newcomer's share only climbs as t/15. For the first ~1.5 s the count stays at 1 and MaxHP stays at the base value, and over the next 15 s MaxHP trails the real crowd. The group removes about 55% of the boss's HP in the first 15 s, against about 23% at the steady rate. The design doc's table promises 10 = 66 s and says PerHunter 0.5 was picked to keep big fights over a minute. In practice the fight ends in about 39 s, and 5 hunters take about 55 s instead of 72 s. Even when everyone is there at spawn, the count is 1 for the first 2 s (Every), so 10 hunters strip about 17% before the first recount and finish in about 57 s.
  - 근거: pace = b.BaseHP / SoloSeconds * (now - base.At). The base is the oldest snapshot still inside Window (15 s), and a newcomer has 0 damage in it, so share = min(1, recent / pace) ramps linearly over ~15 s. appear() also starts the count at 1 until the first recount at +Every. I reproduced the exact algorithm in Python (Every 2, Tick 0.5, Window 15, rounding to tenths, fraction kept, integer HP): n=2/3/5/10 hunters arriving 30 s after spawn took 84/69/55/39 s, against the doc's 90/80/72/66 s; arriving at spawn took 89/78/68/57 s. Solo stays at 120 s. Possible fixes: count a player's share from their first hit inside the window instead of from the window baseline, or recount right away when a new damager appears. The offline tests pass (test_field_boss 220/220) but check only steady-state numbers.
- [low] The reward damage bar is a share of the crowd-scaled MaxHP at the kill, so weak and late helpers need up to 5.5x more damage (src/ServerScriptService/MonsterService.luau:1347)
  - 상황: killRecord still computes minDamage = RewardMinDamageFrac x rec.MaxHP, and FieldBossService now multiplies rec.MaxHP by up to 5.5 (Max 10 hunters, PerHunter 0.5). In a 10-hunter King Slime fight a low-level helper needs 55 damage to be paid. Before this change it was 12.5 (0.005 x 2500); solo it is now 10. For Captain Clatter the bar goes to 990 in a 10-hunter fight: it was 400 at the old 20000 HP and is 180 solo. Also, each player's damage is counted in absolute HP, while HP keeps being rescaled. So the bar is measured against a MaxHP the group never actually had to wear down: the boss loses HP faster early, while the count is still catching up. A helper who joins late in a big crowd can drop to MinorShare (Clatter) or get nothing (King), where they used to be paid. The brief says contribution rewards stay unchanged.
  - 근거: MonsterService.luau:1347 `local minDamage = (tonumber(def.RewardMinDamageFrac) or 0) * rec.MaxHP` (unchanged), together with FieldBossService CROWD.Tick -> SetEventMaxHP raising rec.MaxHP. The design doc calls this intended ('the 2% of that fight'), so it needs an explicit 검수 OK against the 'rewards unchanged' wording. An alternative is to use b.BaseHP, or the larger of the MaxHP values seen during the fight, as the basis.
- [low] PerHunter 0.5 differs from the spec's kaiju-style +15% per person (src/ReplicatedStorage/Shared/Config.luau:4325)
  - 상황: SPEC A23-113 item 7 says the field boss HP follows nearby people, solo about 2 min, each person adding HP the kaiju way (+15%). The code adds +50% of the base per counted hunter. The design doc argues for this (with 0.15, 10 players kill in 28 s), but the spec text has not been updated or confirmed. The regression check itself found no other side effects: normal monsters, Halloween kings and personal monsters are not touched, because SetEventMaxHP only acts on Event records and only FieldBossService calls it. The FirstKO retry cap now reads 2000 from SlimeKing.HP, which only changes a Lv9, +10 legendary-weapon build (about 2036 -> 2000). The HP bar is the server BillboardGui fill, which follows updateBar. All Crowd keys the code reads exist. luau-compile passes for all 3 files (so the 200-locals limit holds). test_field_boss, test_first_ko_king, test_first_ko, test_finisher, test_king_thud, test_land_shadow, test_monster_level and test_slime_prince all pass.
  - 근거: Config.luau:4325 `Crowd = { PerHunter = 0.5, Max = 10, Radius = 50, Window = 15, Every = 2, SoloSeconds = 120 }` vs SPEC_ADDENDUM.md A23-113 item 7 '1명당 더함 — 괴수 +15% 방식'. docs/design/field_boss_crowd_2026-10-11.md picks k = 0.5. It needs 검수/user sign-off or a SPEC A23 update.
## 리뷰가 낸 것
- [medium] Reward bar uses the final crowd MaxHP, but _dmg stays in raw HP, so early contributors get downgraded (src/ServerScriptService/MonsterService.luau:1347)
  - 상황: Captain Clatter (RewardMinDamageFrac 0.02, MinorShare 0.15). Lv25 player A fights alone for 12 s and deals 895 damage, about 10% of the 9000-HP boss. A then dies or walks off. Nine Lv25s arrive and CROWD.Tick raises the hunter count to 9, so MaxHP becomes 45,000 (the HP fraction is kept). At the kill, minDamage = 0.02 x 45,000 = 900 > 895. A only gets MinorShare: 15% XP/gold, no drops, no finisher card, no war points, and is left out of PaidUserIds, so payExtras gives no Weekly item, Kills or Titles. A would pass at solo HP (180) or under the old fixed 20000 HP (400). The King has no MinorShare, so there it means nothing at all: a new player's 3 hits for 15 dmg pass 0.5% x 2000 = 10 but fail 0.5% x 11000 = 55. The other direction also happens: when hunters die or leave near the end, MaxHP drops and so does the bar for late taggers. The same raw-HP sum skews the FactionDamage defeat line (MonsterService:1374). If Halo solos half the boss (4,500) and a Horns crowd finishes the other half at ~45k scale (~22k), the line shows about Halo 17% / Horns 83%.
  - 근거: SetEventMaxHP (MonsterService:1734) rescales rec.HP and rec.MaxHP but leaves rec._dmg in raw HP. killRecord compares _dmg[p] to RewardMinDamageFrac * rec.MaxHP using the MaxHP from the last recount. The design doc wants '그 싸움의 2%', but damage dealt while MaxHP was low is undercounted. I ran a Python copy of CROWD.Count (2 s ticks, 15 s window, tenths, Max 10, rescale keeping the fraction) for: A alone 0-12 s, then 9 Lv25 at 74.6 DPS. Output: kill at 51.9 s, A dmg 895, final MaxHP 45000, threshold 900.0. Suggested fix: record each hit normalised to the base HP (amount x BaseHP / MaxHP at hit time, in _dmg or a parallel field) and compare that to RewardMinDamageFrac x BaseHP. Use the same normalised value for FactionDamage.
- [low] MaxHP lags damage by ~16 s, so stop/start play and camping the spawn beat steady play (src/ServerScriptService/FieldBossService.luau:169)
  - 상황: Ten equal Lv5-8 hunters (16.9 DPS) on the King Slime. Steady play kills it in 56.0 s. In the exploit, one player keeps hitting while the other nine hit for 16 s and then stop for 16 s (they can farm nearby slimes in the off phase), repeating. That kills it in 47.0 s, 16% faster. A newcomer's share grows only as their damage fills the 15 s window, and a stopped player's share fades the same way. DPS lands at once, so the fight is cheaper when bursts land while MaxHP is still catching up. The doc claims '들락날락으로 이득 보는 길 없음', which is not true. Separately, the first count is at appear + Every (line 308). A crowd waiting at the shrine (NextAt is public in GameState) deals its first 2 s at solo HP: 338 of 2000 = 17%. That is why a steady 10-player fight takes 56 s, not the doc's 66 s. For 10 Lv25s on Clatter it is 1492/9000 = 16.6% at the solo price.
  - 근거: CROWD.Count: share = (damage since the oldest snapshot still in the window) / (BaseHP/SoloSeconds x span), with span about 15-17 s, so a hunter who starts or stops hitting changes the count linearly over ~16 s. My Python copy of the exact Count/MaxHP/SetEventMaxHP logic printed: 'King 10 honest 56.0', 'King 10 cycle on 16 off 16: 47.0', 'King 10 cycle on 8 off 16: 51.0', 'King solo 118.3'. Suggested fix: let the count go up faster than it goes down. For example, share = max(share over the last ~4 s, share over Window), so a new hunter counts by the next tick while leaving still fades slowly. Also take the first count at the first hit, or after 0.5 s, instead of a full Every after spawn.
## 반박 검증: 반박됨
The spec does not set 0.15 for field bosses, so a different PerHunter value does not contradict it. SPEC A23-113 item 7 reads '혼자 약 2분, 1명당 더함 — 괴수 +15% 방식'. That points at the kaiju's method (HP grows additively for each nearby person) and leaves the number open. The A23-113 basis doc says so outright: docs/design/player_reactions_research_2026-10-10.md row 7 says '괴수의 근처 기사 1명당 +15%(GDD 괴수)와 같은 방식이고, 숫자는 개발 2가 시험으로 정한다'. The same row also says 호박 대왕·클래터 대장도 같은 방식. So the per-person factor was handed to 게임성 개발 2 to settle by testing. The base is also different. In GDD §5-3 the kaiju's +15% sits on a raid body of 20x HP ('체력 20배 (+근처 기사 1명당 15% 더)'). The field boss def HP is a one-person, 120 s fight, so copying 0.15 would not give the same feel anyway. The code does exactly what its config and design doc say. FieldBossService.luau:185 computes MaxHP = base x (1 + PerHunter x (hunters - 1)), which is additive per hunter, as the spec's method asks. docs/design/field_boss_crowd_2026-10-11.md records k = 0.5 and why: with 0.15, ten players kill the boss in 28 s, before the landing-shadow circle (item 1) has any time to matter. Since k < 1, every extra hunter still makes the fight faster. The claim also says it found no functional side effects. Under the precedence order this is a delegated tuning number written down in a design doc. It is not a regression or a spec violation, and no code change is required.

고칠 방법: No code change. Optional, for documentation only: 검수 adds one line to SPEC A23-113 item 7 recording the chosen number, e.g. '(숫자: 1명당 혼자 체력의 +50%, 피해 몫으로 셈, 최대 10명 — docs/design/field_boss_crowd_2026-10-11.md)'. If 검수 or the user later wants the literal kaiju number, the whole change is Config.luau:4325 PerHunter = 0.5 -> 0.15, plus updating the 2/3/5/10-hunter timing line in the comment above it (4319-4323).

## 반박 검증: 반박됨
The arithmetic is right, but the impact is not. The gate is now trivially cheap, and it was already trivially cheap at 20000 HP.

What checks out in the merged tree:
- MonsterService.luau:1347 computes minDamage = 0.02 × rec.MaxHP at kill time, and SetEventMaxHP now moves rec.MaxHP.
- Clatter HP went 20000 -> 9000 (Config.luau:2023).
- For a Lv25 T3 Halo Archer, Q = rnd(38×1.48×0.55×6) = 186 and a swing = 15. One Q plus two swings (216 damage) clears a gate of about 180-198 (MaxHP 9000-9900 after the crowd count).
- tickOne sets NextAt from the appearance, so the spawn rate per server does not change.

Why it is not a real new free-ride path:
1. RewardMinHits = 3 was already the binding part of the gate for most players. I simulated the fastest way to meet it (Q at t=0, swings after the 0.5 s gap, next Q at 3 s, no enhance or perks) for Lv20/25 T3, all classes and sides:
   - Old 400 gate: Mage (all sides) and Horns Warrior met it in 3 hits, 1.5-1.6 s. Halo/Neutral Warrior needed 4-5 hits, 2.5-3.0 s. Only Archers needed a second Q at 3.0 s.
   - New 180-198 gate: 1.0-1.6 s for everyone.
   - Lv25 T4 or better: no change at all.
   So a full contributor needed 1.5-3 s of hitting before and 1-1.6 s now. The claim's premise that the old gate "takes two or more Q casts" is true only for Archers. The same 3900 XP + 3900 gold + extras were already available for about 3 s of hits.
2. Keeping the gate as a fraction is the documented design. field_boss_crowd_2026-10-11.md line 14 says the contribution rules stay as they are and the damage share is measured against MaxHP at the kill ("그 싸움의 2%"), so the gate grows with the crowd. The original 2026-10-09 reasoning (kingslime_verify_2026-10-09.md:35) picked 2-3% as a fraction ("같이 때린 사람 ~30명까지 허용"). A23-113 says contribution rewards are unchanged, and that holds.
3. Spawn interval, the weekly badge cap (Max 2) and waiting for a hunter in the zone (hunterHere) are all unchanged. Server-hopping for a due Clatter worked the same way before this change.

Net effect: at most about 2 s saved for one class (Archer) and Halo/Neutral Warriors, inside a gate that already cost about 3 s. That is not a meaningful balance regression.

고칠 방법: Not required. Only if 검수 wants the old absolute bar back (about 400 damage solo), either change works:

(a) Smallest: one number in Config.luau:2022, CaptainClatter RewardMinDamageFrac = 0.045. That is about 405 solo and still grows with the crowd, but it caps eligible contributors at about 22 instead of about 50.

(b) Keep 2% and add a floor in MonsterService.luau:1347:
`local minDamage = math.max((tonumber(def.RewardMinDamageFrac) or 0) * rec.MaxHP, tonumber(def.RewardMinDamage) or 0)`
then add `RewardMinDamage = 400` to CaptainClatter.

## 반박 검증: 확인됨
The claim holds up. Every number reproduces when I run the doc's own solo DPS model (soloDps/meanDps in tools/fixtures/field_boss_offline.luau) on the current merged Config with the offline luau.exe:
- T1+T2 average: 16.9 DPS, 118 s (this is the number the doc uses).
- T2 only: 22.1 DPS, 90 s (Warrior 25.7/78 s, Mage 23.2/86 s, Archer 17.4/115 s).
- T1 only: 11.8 DPS, 170 s.
- T3 at Lv5: 54.5 DPS, 37 s. T3 at Lv8: 57.6 DPS, 35 s.
- The old HP 2500 on T2: 113 s.

Nothing in the real code changes these numbers. There is no level-gap or boss damage reduction, Q unlocks at Lv5 (Weapons[3].MinLevel), and bosses skip players below Halloween.SafeBelowLevel = 5 (MonsterService targetable).

The weighting premise is backed by the code, not just opinion:
- Config.Weapons: T1 Price 0 (the gift), T2 Price 150 MinLevel 1, T3 Price 800 MinLevel 5.
- The M1_1 comment says the blacksmith visit is "the next-weapon moment (the shop opens after the lines; the first mission's 150 gold buy tier 2)".
- quest_chain puts that visit at about minute 4, while Lv5 comes at minutes 10-30. T3 purchase is S5 at Lv5 (bought around 25-30 min, Lv8-9).

So by the time a player reaches the King's Lv5-8 band, the designed flow has already replaced T1. Weighting T1 at 50% is what pulls the doc's figure up to "118 s". For the weapon a player is expected to hold, a solo fight takes 90 s. That is outside the 105-135 s band the doc's own test uses. T3 holders, a weapon sold from Lv5, finish in about 35 s.

Caveat: this is model-only (75% uptime, no enhancement or pets), as the doc says. But the shortfall comes from the weapon-mix assumption, not from the model.

고칠 방법: Calibrate the King to the expected weapon, T2, instead of a T1/T2 mean.

1. src/ReplicatedStorage/Shared/Config.luau, MonsterTypes.SlimeKing: change HP = 2000 to HP = 2600. On T2 at Lv5-8 that gives about 118 s (22.1 DPS). T1 only becomes about 220 s and T3 about 46 s. Update the comment to say "Lv 5-8 hunter with the tier 2 weapon the first mission's 150 gold buys: 22.1 DPS".

2. tools/fixtures/field_boss_offline.luau, 'crowd numbers' group:
   - change meanDps(C, { 5, 6, 7, 8 }, { 1, 2 }) to meanDps(C, { 5, 6, 7, 8 }, { 2 });
   - change the check king == 2000 to king == 2600.
   The other checks still pass with 2600: pace ratio 1.02; 2 hunters 88 s, 3 hunters 78 s, 10 hunters 65 s.

3. tools/test_field_boss.py: replace the mutation "King HP 2500 again" with "King HP 2000 again" (HP = 2600 → HP = 2000). At 2500 a T2 fight is 113 s, which sits inside the band, so that mutation would survive and catch nothing.

4. docs/design/field_boss_crowd_2026-10-11.md: update the King row (T2, 22.1 DPS, 2600, about 118 s) and the crowd times. Note that a T1 helper now counts as about 0.55 of a hunter (pace 21.7 DPS).

## 반박 검증: 확인됨
I checked this against the merged tree (C:/Users/glori/Documents/Roblox/wt_bosshp) and it holds up. MonsterService.SetEventMaxHP (MonsterService.luau:1734) rescales rec.HP and rec.MaxHP but never touches rec._dmg. DamageMonster (:1458) adds raw min(amount, HP) at whatever scale the boss had at that moment. killRecord (:1347) sets minDamage = RewardMinDamageFrac * rec.MaxHP from the last CROWD.Tick, and nothing resets MaxHP before the kill: killRecord runs synchronously inside DamageMonster, and finish() runs later. A player under the bar but with damage > 0 goes to `minors` when the boss has MinorShare (Clatter: 15% XP/gold, no drops, card or war points). They are also left out of rec.PaidUserIds, so FieldBossService.finish/payExtras skips their War, Kills, Titles and Weekly item. The King has MinorShare 0, so a player under its bar gets nothing at all.

I ran a Luau copy of CROWD.Count, MaxHP, SetEventMaxHP and the kill threshold with the offline luau.exe (2 s recount, 15 s window, tenths, Max 10, the HP fraction kept). A is alone at 74.6 DPS for 0-12 s, then 9 players at the same DPS. Result: kill at about 47 s, A's damage 895, final MaxHP 45000, minDamage 900, so A fails. A removed 9.9% of the bar, and even by raw totals A's share is 3.7%, so A clearly did more than '2% of that fight', yet gets downgraded. The doc picks final MaxHP on purpose ('쓰러질 때의 최대 체력 기준'), but its own stated aim ('그 싸움의 2%') and A23-113's 'contribution rewards unchanged' are broken for early hits. It does not need 9 hunters: with 5 (MaxHP 27000), anyone who removed under about 6% of the bar early and then died or left fails. The reverse also happens: when hunters leave, MaxHP and the bar drop, so late taggers pass more easily. FactionDamage (:1371-1376) sums the same raw _dmg, so a side that hit while HP was low is under-counted in the shareOf defeat line. That line is display only; nothing else reads FactionDamage.

고칠 방법: Smallest fix, all in MonsterService.luau: keep a second table holding each hit as a fraction of the bar at the moment it lands. Keep _dmg raw, because CROWD.Count measures recent raw damage against a raw pace; rescaling _dmg inside SetEventMaxHP would inflate snapshot differences and make the hunter count feed itself.

1) In the record constructor (~:1137) add `_share = {},`. Also add it to the two clearing lines: `rec._contributors, rec._hits, rec._dmg, rec._share = {}, {}, {}, {}` (:1302) and `rec._contributors, rec._hits, rec._dmg, rec._share, rec._manualAt = {}, {}, {}, {}, {}` (:1378).

2) DamageMonster (:1458):
```lua
local dealt = math.min(amount, math.max(0, record.HP))
record._dmg[player] = (record._dmg[player] or 0) + dealt
record._share = record._share or {}
record._share[player] = (record._share[player] or 0) + dealt / math.max(1, record.MaxHP)
```

3) killRecord (:1347): replace minDamage with `local minFrac = tonumber(def.RewardMinDamageFrac) or 0`. In the eligibility check use `if ((rec._share or {})[p] or 0) >= minFrac - 1e-9 then`. The minors branch stays `elseif minorShare > 0 and (rec._dmg[p] or 0) > 0`.

4) The FactionDamage loop (:1371-1375): iterate `rec._share or {}` instead of `rec._dmg`, adding `math.max(0, d)`. shareOf only uses the ratio, so percentages stay right.

For bosses whose MaxHP never changes, the result is the same as today: _share = _dmg / MaxHP, compared with Frac in place of Frac x MaxHP.

## 반박 검증: 확인됨
Confirmed in the code. In CROWD.Count (FieldBossService.luau:168-176) every player is measured against the same span: pace = BaseHP/SoloSeconds * (now - base.At). base is snaps[1], the oldest snapshot still covering the 15 s window, so in steady state the span is about 15-17 s. A newcomer has no damage in base.D, so their share is (time since first hit)/span. It climbs over about 16 s, and the sum is clamped to at least 1. The fraction kept by SetEventMaxHP then locks in all the damage done while MaxHP was too low. appear() also holds Hunters at 1 until the first recount at +Every (2 s).

I rebuilt lines 157-200 in Python (Tick 0.5, Every 2, Window 15, sum rounded to tenths and clamped 1..10, integer HP with the fraction kept, overkill left out of the damage totals, equal hunters at BaseHP/120 DPS). Kill times for n = 2/3/5/10 hunters, against the doc's 90/80/72/66 s:
- arriving 30 s after spawn: 84/70/56/39 s
- arriving at spawn: 89/78/68.5/57.5 s
- arriving at +5 s: 84.5/71.5/59.5/48 s
- trickling in 1.5 s apart: 85/72/60/47.5 s

Solo stays at 120 s. These match the claim. The design doc does mention that a newcomer's share ramps over 15 s "so HP grows smoothly". But the same doc promises 10 = 66 s and says PerHunter 0.5 was chosen to keep big fights over a minute so players see the ground circles. The code misses both in the usual case, where people arrive after the Appear announcement (10 hunters finish in about 39-48 s). test_field_boss passes because it checks only the steady-state formula.

Severity is balance, not a crash. It is not a regression against the old fixed HP either: the old 2500 HP King died in about 15 s to 10 hunters.

고칠 방법: Smallest fix is in CROWD.Count, FieldBossService.luau around lines 168-176. Measure each player's pace from the last snapshot before their first hit in the window, not from the shared baseline:

	local base = snaps[1]
	local rate = b.BaseHP / math.max(1, num(c.SoloSeconds, 120))
	local radius, sum = math.max(0, num(c.Radius, 50)), 0
	for p, d in totals do
		local b0 = num(base.D[p])
		local recent = num(d) - b0
		if recent > 0 and p.Parent ~= nil and S.PlayerService.IsReady(p) and Util.IsAlive(p) then
			local r = Util.GetRoot(p)
			if r and Util.FlatDistance(r.Position, pos) <= radius then
				local since = base.At -- a newcomer's pace starts at the last snapshot before its first hit
				for i = 2, #snaps - 1 do
					if num(snaps[i].D[p]) <= b0 then since = snaps[i].At end
				end
				local pace = rate * (now - since)
				sum += (c.ByDamage == false or pace <= 0) and 1 or math.min(1, recent / pace)

A scratch copy with this change compiles with luau-compile. Steady-state hunters are unchanged: since stays base.At for them. Simulated kill times for 2/3/5/10 hunters arriving 30 s in become 89/78/68.5/57.5 s.

To also close the remaining first-recount lag, set Config.FieldBosses.Crowd.Every = 0.5 (equal to Tick). With both changes the times become 90/79.5/71.5/64 s whether the hunters arrive at spawn, at +5 s or at +30 s, and 67.5 s when they trickle in.

One test must follow: the mutation 'pace from the current MaxHP' in tools/test_field_boss.py:147 matches the old line, so retarget it to 'local rate = b.BaseHP / ...' -> 'local rate = b.Rec.MaxHP / ...'. Also add a ramp case to the test, for example 10 hunters arriving 30 s after spawn must take at least 60 s.

## 반박 검증: 확인됨
I re-ran the doc's own soloDps model with the current Config and got the claim's numbers exactly. To do it I wrapped the real test harness, tools/test_field_boss.py, around the current sources and ran it with the offline luau.exe. Solo times against 9000 HP:

- Lv25, average of the 3 classes: T3+0 74.6 DPS = 121 s (the only case near 2 min; the Archer alone is 153 s). T3+5 = 80 s. T4+0 172.9 DPS = 52 s. T4+3 = 40 s. T5+0 392.8 DPS = 23 s. T5+3 = 18 s.
- Lv30 T6: 944 DPS, about 10 s.

Groups: each hunter's share is capped at 1 against a pace of 9000/120 = 75 DPS (`math.min(1, recent / pace)` in FieldBossService CROWD.Count). So 3 hunters on T4 count as 3 and face 18000 HP, which dies in 35 s. 5 hunters on T5 face 27000 HP, which dies in 14 s.

Nothing in the code slows these fights down. MonsterService.DamageMonster subtracts the amount as is. CombatService.ComputeMonsterHit and damageMonster have no defense term and no per-hit or boss damage cap. JusticeService only applies the faction scale, which is about 1.

The T3+0 assumption is the weakest plausible loadout:
- Config.Weapons: T4 MinLevel 12, T5 MinLevel 20.
- Goblin drops T4 at P .001 and GoblinBrute at P .005.
- Lv10 to 25 needs 24,185 XP (I computed this). Quest rewards are only "minutes of hunting", so this is hundreds of Goblin Woods kills, with Enh70 dropping at .015 to .05 per kill.
- Config.Commission.Orders[4] is T4 at Lv12 for 3000 gold + 10 Brute Horn + 20 Goblin Tooth. SPEC A23-86 decision 2 = A schedules commissions before the beta, even though Config.Features.Commission is false today.
- T5 drops from Skeleton (P .0005), Skeleton Knight (.003) and Clatter himself (.03), plus the T5 commission.
- Skeleton Ruins (MinLevel 25) is the highest zone, so every Lv25+ player farms there and fights Clatter, many of them with T5 or T6.

So a typical Clatter fight lasts about 15-80 s solo and 35 s or less for groups. That is the "too short to see the ground circle or landing attack" problem the doc gave for rejecting k = 0.15. The old 20000 HP gives 116 s for Lv25 T4+0, which already met A23-113 ③ (about 2 min solo).

The current test passes (216/216, run without mutations) only because the 'crowd numbers' group calibrates Clatter with meanDps(C, {25}, {3}).

고칠 방법: Calibrate Clatter to the Lv25 T4+0 hunter of the doc's own model and put the HP back to 20000. That gives 20000 / 172.9 = 116 s solo. T3+5 becomes about 179 s and T5+0 about 51 s. The pace becomes 167 DPS, so a T3+0 helper counts as about 0.45 of a hunter.

1. src/ReplicatedStorage/Shared/Config.luau:2023 (CaptainClatter): change `HP = 9000` to `HP = 20000`. Rewrite the comment above it to "HP 20000 = one hunter's fight, about 2 min for a Lv25 hunter with a T4 weapon (Goblin Woods drop / Lv12 commission; swings + Q, 75% uptime: 172.9 DPS averaged over 3 classes x 3 sides)".
2. tools/fixtures/field_boss_offline.luau 'crowd numbers': change `meanDps(C, { 25 }, { 3 })` to `meanDps(C, { 25 }, { 4 })` and `clatter == 9000` to `clatter == 20000`.
3. tools/test_field_boss.py: replace the mutation "Clatter HP 20000 again" with "Clatter HP 9000", which swaps `HP = 20000,` back to `HP = 9000,`.
4. docs/design/field_boss_crowd_2026-10-11.md: update the Clatter table row (Lv25, T4, 172.9 DPS, 20000 HP, about 116 s).

The crowd code itself does not change. One open point needs a design call and is not part of the smallest fix: because Skeleton Ruins is the top zone, Lv30+ T5/T6 hunters will still solo in 20-50 s, since a hunter's share is capped at 1. If that matters, raise the cap in CROWD.Count, for example to `math.min(3, recent / pace)`.

## 반박 검증: 확인됨
The claim holds. I copied CROWD.Count, CROWD.MaxHP, the CROWD.Tick timing and MonsterService.SetEventMaxHP exactly into an offline Luau sim (scratchpad crowd_sim.luau, run with build/luau_cli_0_741/luau.exe) and got the claim's numbers: King solo 118.3 s, 10 steady hunters 56.1 s, 9 of them cycling 16 s on / 16 s off 47.1 s, cycling 8/16 51.1 s. Clatter: 56.9 s steady vs 47.8 s cycling.

Why it works:
- Snapshots are taken every 2 s, and the loop drops snaps[1] only while snaps[2].At <= now - 15, so the baseline is about 16 s old.
- A player's share is recent damage / (BaseHP/120 x span), capped at 1. So a player who starts or stops hitting changes the count linearly over about 16 s.
- Damage applies at once, while MaxHP is rescaled with the HP fraction kept. The kill speed is DPS/MaxHP, and 1/MaxHP is convex, so damage dealt while a group's share is still rising costs less than steady damage.
- With 3 or 5 hunters, cycling does not pay (76.9 vs 82.2 s; 67 vs 69 s). With 10 it saves about 16%. The doc's line '들락날락으로 이득 보는 길 없음' is false.

The spawn-camping part is also true. appear() sets the empty baseline { At = now, D = {} } and CrowdAt = now + Every (line 308), and nothing protects a fresh event boss in DamageMonster or SpawnEvent. NextAt is published in GameState, and the boss waits for a hunter in its zone before it spawns, so a crowd can be standing there when it appears. Its first 2 s land at the solo HP: 10 x 16.9 x 2 / 2000 = 16.9% of the King, and 1492 / 9000 = 16.6% of Clatter. That is why a steady 10-player fight takes 56 s, not the doc's 66 s. With the first count at 0.5 s the sim gives 62.8 s.

Impact: this is a balance and doc-correctness problem, not a crash. The cycling exploit needs about 9 players coordinating. The spawn discount happens to every crowd that is present when the boss appears.

고칠 방법: Smallest fix: let the count rise fast and fall slowly, and take the first count sooner.

(1) Config.FieldBosses.Crowd: add Rise = 4.

(2) In CROWD.Count (FieldBossService.luau around lines 168-177), after `local base = snaps[1]`, add:
```
local quick = base
for i = #snaps - 1, 1, -1 do if snaps[i].At <= now - num(c.Rise, 4) then quick = snaps[i] break end end
local per = b.BaseHP / math.max(1, num(c.SoloSeconds, 120))
local pace, qpace = per * (now - base.At), per * (now - quick.At)
```
Then, inside the loop, replace the share expression with:
```
math.min(1, math.max(recent / pace, qpace > 0 and (num(d) - num(quick.D[p])) / qpace or 0))
```
Keep the existing `(c.ByDamage == false or pace <= 0) and 1 or ...` guard in front of it.

(3) In appear() (line 308), change to `b.CrowdAt = now + 0.5`, so the first count comes about 0.5 s after spawn.

Result with the same sim: no tested pattern (cycles 16/16, 8/16, 4/16, 4/4, 8/8, 2/6, staggered groups, late joins) beats steady play for 3, 5 or 10 hunters on either boss. Steady times become King 78.4 / 70.0 / 62.8 s and Clatter 79.9 / 71.4 / 63.5 s; solo stays 118.3 s. The fix in (2) alone already removes the cycling gain, and (3) removes the spawn discount.

Also correct the '들락날락 이득 없음' line and the 10-player time in docs/design/field_boss_crowd_2026-10-11.md.

## 반박 검증: 확인됨
The claim holds, and I confirmed it by running the code. MonsterService.luau:1347 (`minDamage = RewardMinDamageFrac * rec.MaxHP`) is unchanged. FieldBossService CROWD.Tick -> SetEventMaxHP raises rec.MaxHP up to 5.5x (PerHunter 0.5, Max 10) and keeps only the HP fraction. Meanwhile rec._dmg (MonsterService.luau:1458) keeps counting absolute HP. The static numbers in the claim are right: King bar 10 solo / 55 at 10 hunters (old 12.5), Clatter 180 / 990 (old 400).

The "it's fine because the fight gets longer" defence only works if total damage roughly equals the MaxHP at the kill. It falls apart when MaxHP rises mid-fight, because damage dealt at the small scale counts for a bigger fraction. I ran an exact copy of CROWD.Count/MaxHP/Tick and SetEventMaxHP in the offline luau.exe, with 0.5 s ticks, counts every 2 s and a 15 s window.
- Clatter, 1 Lv25 hunter (74.6 DPS) from spawn, 9 more join at 60 s, one of them a 60-DPS helper: the boss dies at 72.5 s with MaxHP 38700, so the bar is 774. The whole group only dealt 13347, so the bar is 5.8% of the fight, not 2%. The helper fought the entire rest of the fight and dealt 720 (5.4% of all damage) and still gets MinorShare. Under the old 20000 HP he dealt 1260 against a 400 bar and was paid in full.
- King, same timing, a 3-DPS newbie joining at 60 s: new bar 41 against 36 dealt, so nothing is paid (King has no MinorShare). Old: bar 12.5 against 28.5, so paid.

So the rule now misses its own design-doc intent ("2% of that fight") and the brief's "contribution rewards unchanged". With 10 hunters arriving together at spawn the drift is small (bar 2.29% of group damage). It is large whenever the crowd arrives after the start.

Note: tools/test_halloween.py:232 mutates the exact line 1347 text, and tools/fixtures/finisher_offline.luau:230 sets _dmg by hand to far less than MaxHP. So the fix must keep line 1347 as it is and apply only to rescaled bosses. A version that always used the summed damage (or one gated on rec.Event) would break the finisher fixture's MinorShare check.

고칠 방법: Keep the bar at RewardMinDamageFrac of the damage the fight actually took whenever the crowd rule rescaled MaxHP. Two edits in src/ServerScriptService/MonsterService.luau:

1) In MonsterService.SetEventMaxHP, after `rec.MaxHP = maxHP`, add:
	rec._rescaled = true -- A23-113 ⑦: killRecord's damage bar then uses the damage really dealt

2) In killRecord, directly after line 1347 (leave that line unchanged), add:
	if rec._rescaled then -- A23-113 ⑦: MaxHP followed the crowd; the bar = that share of the damage this fight really took
		local dealt = 0
		for _, d in rec._dmg do dealt += math.max(0, tonumber(d) or 0) end
		minDamage = math.min(minDamage, (tonumber(def.RewardMinDamageFrac) or 0) * dealt)
	end

_dmg already excludes overkill and keeps players who left, so `dealt` is the fight's real total. Monsters that were never rescaled are not touched, so the test_halloween mutation and the finisher fixture are unaffected. I re-ran the same simulation with this change: the bar is exactly 2.00% / 0.50% of group damage in every scenario, the Clatter 60-DPS helper and the King 3-DPS newbie are paid again, and a 3-hit free rider still has to clear 2% of the fight. Also update the design-doc line "피해 몫은 쓰러질 때의 최대 체력 기준" to say "그 싸움에서 실제로 넣은 피해 합의 2%" (2% of the damage actually dealt in that fight).
