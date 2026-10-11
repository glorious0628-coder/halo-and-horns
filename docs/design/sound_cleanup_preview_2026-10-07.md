# 옛 효과음 정리 미리 보기 (2026-10-07, 소리 만들기 — 아직 지우지 않음)
> 기록용(10/07 당시). 지금과 다른 점: 정리는 끝남 — 옛 ogg 30개는 55fe9a11에서 지웠고 `art/sfx/`에는 SwingMage·SwingTamer.ogg 2개만 남음. 아래 목록대로 다시 지울 것 없음. 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

**지우는 때:** 게임성 개발 1이 `sound_wiring_onepass_2026-10-07.md`를 넣고 → `py tools/sfx_wiring_check.py`가 '옛 id 아직 쓰는 것 0' → `sound_play_check_2026-10-07.md` Play 확인(PC + 폰 흉내) 통과한 **뒤에만** 소리 만들기가 지운다. 지금은 목록만.

- `art/sfx/*.ogg` 32개 = 지움 30 + 남김 2
- 남김 2개: SwingMage, SwingTamer — 새 파일이 아직 없어 게임이 계속 씀(asset_ids.json "kept"). 처음 '남길 8개' 중 6개(SwingWarrior·KillPop·ComboMilestone·LevelUp·Tap·WindowOpen)는 7번 묶음에서 새로 만들어 지울 쪽으로 옮김.
- asset_ids.json "old" 30개 = 지울 ogg 30개와 같은 목록

| 옛 파일 | 옛 id (게임에서 뺄 것) | 바꾸는 새 소리 | 할 일 |
|---|---|---|---|
| `AutoOff.ogg` | `rbxassetid://87842131842953` | AutoOff `rbxassetid://128226305896103` | 지움 |
| `AutoOn.ogg` | `rbxassetid://91575528786721` | AutoOn `rbxassetid://90300088723425` | 지움 |
| `ComboCoin.ogg` | `rbxassetid://132118526896477` | ComboCoin `rbxassetid://132925998560879` | 지움 |
| `ComboMilestone.ogg` | `rbxassetid://120183624157841` | ComboMilestone `rbxassetid://73147095978331` | 지움 |
| `Deny.ogg` | `rbxassetid://70560315563605` | Deny `rbxassetid://124536292557880` | 지움 |
| `Devour.ogg` | `rbxassetid://89066730830142` | Devour `rbxassetid://118262766439187` | 지움 |
| `GoldPickup.ogg` | `rbxassetid://74126067367127` | GoldPickup `rbxassetid://119243238199900` | 지움 |
| `GooseHonk.ogg` | `rbxassetid://126013517999832` | GooseHonk `rbxassetid://115693307820380` | 지움 |
| `HitHeavy1.ogg` | `rbxassetid://88230015185148` | HitHeavy `rbxassetid://95463530376920` | 지움 |
| `HitHeavy2.ogg` | `rbxassetid://129011812816837` | HitHeavy `rbxassetid://95463530376920` · HurtBig `rbxassetid://73666772845621` | 지움 |
| `HitSoft1.ogg` | `rbxassetid://132253070570696` | HitSoft `rbxassetid://96440842663562` | 지움 |
| `HitSoft2.ogg` | `rbxassetid://138414840858825` | HitSoft `rbxassetid://96440842663562` | 지움 |
| `KillPop.ogg` | `rbxassetid://76243013610008` | KillPop `rbxassetid://117802423144289` | 지움 |
| `KingBell.ogg` | `rbxassetid://133609264734232` | PumpkinKing `rbxassetid://112500082253148` · GhostKing `rbxassetid://100319357258743` | 지움 |
| `LevelUp.ogg` | `rbxassetid://115723389387503` | LevelUp `rbxassetid://108525821312554` | 지움 |
| `Potion.ogg` | `rbxassetid://139764142335079` | Potion `rbxassetid://133789691162407` | 지움 |
| `Purify.ogg` | `rbxassetid://112385811106575` | Purify `rbxassetid://126260420453106` | 지움 |
| `QuestDone.ogg` | `rbxassetid://125748535247961` | QuestDone `rbxassetid://131457371135343` | 지움 |
| `QuestNew.ogg` | `rbxassetid://113743171009116` | QuestNew `rbxassetid://123199271616228` | 지움 |
| `RankDown.ogg` | `rbxassetid://73142353580905` | RankDown `rbxassetid://81421593114766` | 지움 |
| `ScrollFail.ogg` | `rbxassetid://127201461836075` | ScrollFail `rbxassetid://124525939049830` | 지움 |
| `ScrollSuccess.ogg` | `rbxassetid://75617018211597` | ScrollSuccess `rbxassetid://116061752455414` | 지움 |
| `SkillHalo.ogg` | `rbxassetid://94791750026317` | SkillHalo `rbxassetid://75898672312875` | 지움 |
| `SkillHorns.ogg` | `rbxassetid://98826164651498` | SkillHorns `rbxassetid://110780992455213` | 지움 |
| `SwingArcher.ogg` | `rbxassetid://110195369508891` | SwingArrow `rbxassetid://76900813038959` | 지움 |
| `SwingMage.ogg` | `rbxassetid://136838684864577` | — (새 파일 없음) | **남김** |
| `SwingTamer.ogg` | `rbxassetid://126503879214394` | — (새 파일 없음) | **남김** |
| `SwingWarrior.ogg` | `rbxassetid://100665788892468` | SwingWarrior `rbxassetid://114585478722203` | 지움 |
| `TalkBlip.ogg` | `rbxassetid://72477911054987` | TalkBlip `rbxassetid://94593126133806` | 지움 |
| `Tap.ogg` | `rbxassetid://101266273493121` | Tap `rbxassetid://118436931537673` | 지움 |
| `WindowClose.ogg` | `rbxassetid://96155752903162` | WindowClose `rbxassetid://86085176622331` | 지움 |
| `WindowOpen.ogg` | `rbxassetid://72025655652305` | WindowOpen `rbxassetid://129419018750436` | 지움 |

## 지울 때 같이 할 것

1. `art/sfx/<키>.ogg` 30개 삭제(git에서 지움, push_paths로 올림). 남김 2개는 그대로.
2. `art/sfx/asset_ids.json`의 "old" 블록을 지우거나 "retired"로 이름 바꿈(id 기록은 남김: Creator Hub에는 비공개로 남아 있음, 지우지 않음).
3. `art/sfx/sources.json`을 새 wav 기준으로 다시 씀(키마다 picks_r4.json의 출처·라이선스·sha256). 옛 3차 도구 `tools/sfx_game.py`·`sfx_board.py`가 이 파일을 읽으니 같이 손볼지 검수와 정함.
4. `docs/devlog/sfx_licenses.md`에 '옛 3차 파일 정리' 한 줄.
5. Roblox 쪽 옛 소리 자산은 지우지 않음(비공개라 게임에서 안 쓰면 끝).
