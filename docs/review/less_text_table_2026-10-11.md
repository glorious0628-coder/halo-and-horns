# 설명 글 줄이기 표 (A23-130, 2026-10-11)

> 사용자(10/11 저녁, 플레이 중): "너무 설명해주는 게 많은 거 같애 없애라고 했었는데 계속 있네" (교차로 황금 거위 사진: 위 막대 + 그 아래 "My points" 줄 + 가운데 큰 띠 + "Thank you! Here, take this potion." 말풍선이 한 화면에).
> 기준(A23-99 + A23-130): **남김** = 보상, 위험·실패, 한 번만 나오는 안전 사실(PvP 안전 카드, New skill!·Stronger!, 첫 주문서 안내 한 번), 퀘스트 줄 + 마름모 + 거리. 그 밖에 설명만 하는 글, 화면이 이미 보여 주는 것을 다시 말하는 글, 다음에 할 일을 말해 주는 글, 이야기 꾸밈 글은 **끔**. 꼭 필요한 게 남으면 **짧게**. 한 화면에 설명 글은 둘 이상 겹치지 않게.

- 만든 사람: 게임성 개발 1. §1 화면(클라이언트) = 직접 코드를 읽고 판정·적용. §2 서버 = API 에이전트(Sonnet, 읽기 전용, 2조각 약 $2.35)가 정적으로 읽은 초안. **서버 줄은 개발 2 몫**(고치는 사람 = 게임성 개발 2, 최종 판정 = 검수).
- 적용 브랜치: `fix/lesstext` (① 99dbd39f 거위 아래 줄·보상 대사 + 이번 커밋 화면 쪽). 끄기는 되도록 `Config.Nudges` 키로(다시 켜기 쉬움).
- 확인한 것: 코드 읽기 + 오프라인 시험. 실제 플레이 확인은 아직 없음(메인 반영 1 사진 필요).

## 0. 이번에 끈 것·짧게 한 것 (화면 쪽, 검수 보고용)
| 무엇 | 전 | 후 | 어떻게 |
|---|---|---|---|
| 거위 행사 막대 아래 줄 | "My points 0 · Knights, fill the gauge!" / 줄다리기 "My hits 3 · Hit the goose to rescue it!" | 안 보임(막대·0/20·제목·인원만) | `Config.Nudges.GooseSub = false` (99dbd39f) |
| 선택 뒤 NPC 대사(도시락·숲 다리 등불) | "Thank you! Here, take this potion." 등 4줄 | 없음, 보상 토스트만("+HP Potion", "+25 gold") | Config Reply 삭제 + 서버 2줄(보상 있는 선택은 lean/saved 줄 안 보냄) (99dbd39f) |
| 공격 버튼 위 말풍선 | 첫 임무 중 몬스터 옆에서 5초 가만히 있으면 "Click to hit!" / "Tap to hit!" | 안 나옴(공격 버튼이 이미 화면에 있음) | `Config.Nudges.AttackHint = false` (FirstSteps) |
| 무기 상인 작별 토스트 | 상점 닫을 때 4초 "Nothing you like? Take your time!" 등 5종 | 안 나옴 | `Config.Nudges.ShopFarewell = false` (Panels) |
| 선택 카드 설명 줄 | "Left: Honor +1 · Right: Honor -1 (not very angel-like)", "Left: Infamy -1 (too nice) · …", 장인 "The Artisan Guild just saves your pick, with no good or evil points.", 0점 "No points here. Your shard just leans to the light or the dark." | "Left: Honor +%d · Right: Honor -%d", "Left: Infamy -%d · Right: Infamy +%d", "No good or evil points.", "No points." (점수 숫자는 남김 = 보상·벌점) | Config.StoryQuests.Text, Panels STORY.Text |
| 퀘스트 줄의 대화 대기 줄 | "A shard is talking to you — tap to see" / "Someone wants to talk — tap to see" | "Your shard is talking" / "Someone wants to talk" | Panels STORY.Text |
| 원한 자루 칩 | "Grudge Sack 1.2K · 30s (shrinks only in PvP zones)" | "Grudge Sack 1.2K · 30s" | EventHUD TXT.Sack |
| 내가 괴수일 때 | "You are a Kaiju! Last 2:00 to become a legend" | "You're the Kaiju! Last 2:00" | EventHUD TXT.KaijuSelf |
| 대장간 버튼을 멀리서 눌렀을 때 | "Go to the Crossroads and find the Forge anvil." / "Walk to the Forge anvil and press its button." | "The Forge is in the Crossroads." / "Walk to the Forge anvil." | HUD L.Smith |
| 첫 PvP 구역 안전 카드 | 카드 3장 연달아 | 1장 2줄: "Other players can fight you here!" / "Knocked out? You can lose pocket gold. Towns keep it safe." | FirstSteps PVP.Text + PauseCard Tip 2줄 (검수 10/11) |
| "Saved! / Next time" 카드 | 장 끝·일일 3개 끝·전쟁 끝 | 장 끝만(일일·전쟁 카드 안 띄움, 알림 동의 순간은 그대로) | PauseCard `T.PauseWhy` (검수 10/11) |

## 1. 화면(클라이언트) 표
| # | 어디 (파일·키) | 언제 | 문구 | 판정 | 이유 / 한 것 |
|---|---|---|---|---|---|
| 1 | EventHUD updateGoose `ui.TugSub` | 거위 행사 내내 | "My points %d · Knights, fill the gauge!" 등 | 끔 | 막대가 이미 보여 줌 → GooseSub=false |
| 2 | EventHUD 거위 막대(제목·0/20·인원) | 거위 행사 | "Team Rescue! 0:45", "0 / 20", "1 together" | 남김 | 사용자 "위 막대만 남긴다" |
| 3 | FirstSteps HINT.Step → HUD.Hint("Attack") | 첫 임무, 몬스터 옆 5초 | "Click to hit!" / "Tap to hit!" | 끔 | 팁. AttackHint=false |
| 4 | SkillBar LEARN.LateHint → HUD.Hint(slot) | 새 스킬 배운 뒤 45초 안 쓰면 한 번 | "Press Q" / "Tap the new button" | 남김 | 스킬 버튼 키 표시가 기본 꺼짐(A23-78) → PC에서 키를 알 유일한 길, 막혔을 때 한 번뿐. 검수가 끄라면 같은 방식 스위치 |
| 5 | SkillBar LEARN banner | 스킬 배울 때 | "New skill! %s" | 남김 | A23-99 |
| 6 | SkillBar LEARN.Tip (키 팁 카드) | 첫 스킬 | 키 바꾸기 카드 | 이미 끔 | Nudges.KeysTip=false |
| 7 | HUD Stronger banner | 첫 무기 | "Stronger!" | 남김 | A23-99 |
| 8 | Fx 레벨 업 Announce | 레벨 업 | 레벨 업 띠(새로 열린 것 함께) | 남김 | 보상 |
| 9 | Fx RareToast | 희귀 드롭 | 희귀 알림 | 남김 | 보상 |
| 10 | Fx ZoneStoryLine | 구역 열림 | 이야기 줄 | 이미 끔 | Nudges.ZoneStoryLine=false |
| 11 | HUD WarIntro | 전쟁 막대 처음 | "Crown War: win points for your side!" | 이미 끔 | Nudges.WarIntro=false |
| 12 | HUD DailiesOpened | 첫 [Claim] 뒤 | "Daily quests are open!" | 이미 끔 | Nudges.DailiesOpened=false |
| 13 | HUD HuntSlimes | 초원 안내 | "Hunt slimes and big slimes for XP." | 이미 끔 | Nudges.HuntSlimes=false |
| 14 | HUD showGuide 라벨·노란 줄 | 안내 목표 | "First weapon" 등 | 이미 끔 | Nudges.GuideLabel/GuideBeam=false |
| 15 | EventHUD SackLore | 첫 원한 자루 화살표 | "Stolen gold carries a grudge …" | 이미 끔 | Nudges.SackLore=false |
| 16 | Announce JoinToast | 첫 진영 고름 | "You joined …!" | 이미 끔(클라) | ChatText.JoinToast=false. 서버 FactionService:384/386/389는 아직 켜짐 → §2 |
| 17 | Panels STORY.Hint (선택 카드) | 선택 카드 | 점수 줄 | 짧게 | 점수(보상·벌점)만 남기고 꾸밈말 뺌 → §0 |
| 18 | Panels STORY.Text.RowShard/RowOther | 대화 대기 퀘스트 줄 | "… — tap to see" | 짧게 | 줄 자체가 눌리는 줄 |
| 19 | Panels WSHOP.Farewell | 상점 닫을 때 | 상인 작별 5종 | 끔 | 꾸밈 대사. ShopFarewell=false |
| 20 | EventHUD TXT.Sack | 원한 자루 들고 있을 때 | "(shrinks only in PvP zones)" | 짧게 | 위험 표시는 남기고 설명 뺌 |
| 21 | EventHUD TXT.KaijuSelf | 내가 괴수 | "… to become a legend" | 짧게 | 위험·목표 시간만 |
| 22 | EventHUD 괴수·사이렌·복수 화살표 칩 | 이벤트 | "Kaiju %s %s", "Revenge: …" | 남김 | 위험 |
| 23 | EventHUD 행운 칩 | 보너스 있을 때만 | "Lucky +%s%%" | 남김 | 보상 |
| 24 | HUD L.Smith Travel/Walk | 대장간 버튼을 멀리서 | 길 안내 2줄 | 짧게 | 내가 누른 것의 답이라 한 줄로 |
| 25 | HUD 상태 칩 | 늘 | "Safe Zone", "PvP Zone", "Sprout Shield", "Sprout Shield ends · PvP in %ds", "In Combat", "Wanted", "Bully penalty: …" | 남김 | 위험·상태 |
| 26 | HUD NoMana | 스킬 MP 모자람 | "Not enough MP." | 남김 | 실패 |
| 27 | HUD TileSoon / LuckTap | 누를 때 | "Coming soon!" / "Rare drops come a bit more often today!" | 남김 | 내가 누른 것의 답 |
| 28 | ShopUI Server/Owned/Soon | 누를 때 | 상점 실패 | 남김 | 실패 |
| 29 | Panels 실패 토스트(무기·물약·오프닝 다시 보기 등) | 누를 때 | "You can replay the opening inside a town." 등 | 남김 | 실패 |
| 30 | Keybinds 토스트 | 설정에서 키 바꿀 때 | 겹침·바꿈·못 씀 | 남김 | 내 행동의 답 |
| 31 | SettingsUI IntroUnsafe | 위험한 곳에서 오프닝 | 실패 | 남김 | 실패 |
| 32 | FirstSteps 이동 줄 | 강제 이동 | "Off to Squishy Meadow!  3" | 남김 | 지금 일어나는 일(3초) |
| 33 | FirstSteps PVP 카드 | 첫 PvP 구역 한 번 | 전: 카드 3장 연달아. 후: 1장 2줄 "Other players can fight you here!" / "Knocked out? You can lose pocket gold. Towns keep it safe." | 짧게(검수 10/11) | A23-99 한 번뿐인 안전 카드 1장. PauseCard Tip이 2줄까지 받음(TipLines=2) |
| 34 | PauseCard Pause / Back | 장 끝 / 6시간 뒤 | "Saved! / Next time: …", "Welcome back! / Next: …" | 일일·전쟁 끝 카드 끔(검수 10/11), 장 끝·Welcome back 남김 | A23-79 사용자 승인 문구라 지우지 않음. `T.PauseWhy = { Chapter = true }`, 안 띄운 일일 카드의 OptIn은 ComeBack으로 그대로 넘김(서버는 안 바꿈) |
| 35 | QuestMarker 마름모·거리, QuestTarget 이름 | 늘 | "%dm", "Forge", "Slime Pond" … | 남김 | A23-99 퀘스트 줄+마름모+거리 |
| 36 | MonsterLabels | 늘 | 몬스터 이름·HP | 남김 | 정보(설명 아님) |
| 37 | QuickSlots BagHint | (안 쓰임) | "Put an item in slot 1, 2 or 3." | 해당 없음 | 코드에서 안 씀 |
| 38 | UIKit 서버 알림 표시(Notify/announce) | 서버가 보낼 때 | §2 | 개발 2 몫 | 큰 가운데 띠 = 종류 없는 NotifyAll |

## 2. 서버 표 (개발 2 몫 — API 에이전트 초안, 검수 판정 전)
- 고칠 사람: 게임성 개발 2(서버). 아래 KEEP/OFF/SHORT는 에이전트 제안이고 개발 1은 손대지 않았음.
- 합계: A부 108곳(남김 55·끔 31·짧게 22, 이미 꺼진 4곳 포함) + B부 118곳(남김 59·끔 21·짧게 38, 꺼진 기능의 dormant 21행 포함) = **226곳, 끔 52·짧게 60 제안**.
- 사용자 사진의 **거위 가운데 큰 띠** = GooseService `Config.Goose.Text.CoopStart`(NotifyAll, 종류 없음 = announce 띠) → A23-130대로 "Golden Goose!" 2초 한 번(개발 2). CoopFull·NeedManual·RivalWait도 B부 표 참고.
- A23-99에서 끈다고 한 "You joined …!"가 서버 FactionService:384/386/389(제단에서 진영 바꿀 때)로는 아직 나감(A부).
- 한 화면에 겹치는 곳(A부 §5): 첫 무기(QuestService:603 대사 + LootService:318 + Stronger!), 일일 마지막 [Claim](QuestService 1154·964·969·1162), 이야기 퀘스트 끝(StoryQuestService 393·394·398·400 최대 4줄), PvP 쓰러짐 한 번(PvPService 744·768·801·827), 선택 한 번(StoryQuestService 1070~1089·1119·1128·1175).
- 주의(A부): StoryQuestService:393의 Finish 줄을 끄면 QuestDone 소리를 보상 줄(:394)로 옮겨야 함.

## 2-A. 서버 A부 (Loot·StoryQuest·PvP·Faction·Quest·Zone)

### 서버 문구 목록 (A부): LootService · StoryQuestService · PvPService · FactionService · QuestService · ZoneService

판정 기준은 `docs/SPEC_ADDENDUM.md` A23-99(:366)와 A23-130(:95-99)입니다. 확인한 것과 추정한 것은 맨 아래에 따로 적었습니다.

표 읽는 법:
- `Text.*` = `Config.Text`, `Loot.Text.*` = `Config.Loot.Text`, `Tut.Text.*` = `Config.Tutorial.Text`, `SQ.Text.*` = `Config.StoryQuests.Text`.
- 맨 위 `Config.Nudges`는 `Config.luau:5285-5314`입니다. `GuideDone`, `EnteredSafe`, `DailyReady`, `WeaponUsableNow`는 모두 `false`라서 해당 줄은 지금 화면에 안 뜹니다.
- Reply 경로만 "(dormant)"로 표시했습니다. 이 여섯 파일에는 Board, Commission, LostFound, AutoIdleRest, DiaryService에 걸린 호출이 없습니다.

#### 1. 호출 지점 표

##### LootService (34곳; `notify` 래퍼 `:47`, `fullNotice` 래퍼 `:52`)

| # | file:line | when | text | Config key | verdict | reason / 새 문구 |
|---|---|---|---|---|---|---|
| 1 | LootService.luau:196 | 재료/주문서 칸이 가득 찰 때. 아이템별 300초에 한 번 | `%s is full (max %d). You can sell it at the Forge.` / `…Use some from your Bag.` | Loot.Text.ItemFull / ItemFullUse | SHORT | 실패는 남기고 뒤 설명만 뺌 → `%s is full (max %d).` |
| 2 | LootService.luau:276 | 이미 가진 무기가 또 나올 때 | `You already have %s → it became %s gold.` | Loot.Text.DuplicateWeapon | KEEP | 골드 보상 |
| 3 | LootService.luau:289 | 전설 무기 잭팟(1/20000). 맨손이면 바로 장착 | `Legendary weapon [%s] equipped! Power %s → %s` / `Legendary weapon [%s]! Equip it from your Bag.` | Loot.Text.JackpotEquip / JackpotSelf | SHORT | 보상은 남기고 "가방에서 장착" 안내만 뺌 → `Legendary weapon [%s]!` |
| 4 | LootService.luau:293 | 레어 이상 무기 드롭 | `%s weapon! You got %s!` | Loot.Text.RareWeapon | KEEP | 아이템 보상 |
| 5 | LootService.luau:298 | 맨손일 때 드롭 무기를 자동 장착한 직후 (293과 한 화면) | `[%s] equipped! Power %s → %s` | Loot.Text.BareEquip | OFF | 293과 같은 순간에 두 줄. 전투력 변화는 "Stronger!" 연출이 이미 보여 줌 |
| 6 | LootService.luau:318 | 첫 무기 선물(M1_1), 맨손일 때. 한 번 | `You got your first weapon, [%s]! Power %s → %s` | Loot.Text.FirstWeapon | SHORT | 보상 한 줄만 → `Got your first weapon, [%s]!` |
| 7 | LootService.luau:321 | 첫 무기 선물, 이미 무기를 샀을 때 | `The Blacksmith also gave you [%s]. Find it in your Bag.` | Loot.Text.FirstWeaponBag | SHORT | 어디 있는지 안내 제거 → `Got [%s]! Check your Bag.` |
| 8 | LootService.luau:332 | 물약이 가득 차 못 받을 때. 종류별 300초 쓰로틀 | `Your potions are full, so you couldn't take the %s.` | Loot.Text.PotionFull | SHORT | 실패 → `%s is full.` |
| 9 | LootService.luau:404 | 첫 슬라임 프린스(BigSlime) 처치, 평생 한 번, 6초. 맨손이면 다른 문구 | `You got a scroll! Enhance your weapon from your Bag. (Your weapon is safe even if it fails)` / `FirstScrollBare` = `…The Blacksmith gives you your first weapon. Then enhance it from your Bag.` | Loot.Text.FirstScroll / FirstScrollBare | KEEP | A23-99: 첫 주문서 안내는 한 번 남김 |
| 10 | LootService.luau:450 | 없는 무기를 강화하려 할 때 | `You don't have that weapon.` | Loot.Text.NotOwned | KEEP | 실패 |
| 11 | LootService.luau:452 | 최대 강화인데 주문서를 쓸 때 | `Already at max enhance (+%d).` | Loot.Text.EnhanceMax | KEEP | 실패 |
| 12 | LootService.luau:453 | 주문서가 없을 때 | `You don't have that item.` | Loot.Text.NoItem | KEEP | 실패 |
| 13 | LootService.luau:466 | 강화 성공할 때마다 | `Enhance success! %s +%d → +%d (attack %d%% → %d%%)` | Loot.Text.EnhanceOk | KEEP | 보상/결과 |
| 14 | LootService.luau:470 | 강화 실패로 +1 내려갈 때 | `Enhance failed… %s +%d → +%d (your weapon is safe)` | Loot.Text.EnhanceFailDown | KEEP | 실패 |
| 15 | LootService.luau:472 | 강화 실패, 단계 유지 | `Enhance failed… but %s stays +%d!` | Loot.Text.EnhanceFailKeep | KEEP | 실패 |
| 16 | LootService.luau:479 | 이전 주문서에서 무기를 안 가졌을 때 | `You don't have that weapon.` | Loot.Text.NotOwned | KEEP | 실패 |
| 17 | LootService.luau:480 | 같은 무기끼리 이전 | `Pick a different weapon.` | Loot.Text.MoveSame | KEEP | 할 수 없음 |
| 18 | LootService.luau:482 | 옮길 강화가 없을 때 | `There is no enhance to move.` | Loot.Text.MoveNothing | KEEP | 할 수 없음 |
| 19 | LootService.luau:484 | 대상이 이미 최대 강화일 때 | `Already at max enhance (+%d).` | Loot.Text.EnhanceMax | KEEP | 실패 |
| 20 | LootService.luau:485 | 이전 주문서가 없을 때 | `You don't have that item.` | Loot.Text.NoItem | KEEP | 실패 |
| 21 | LootService.luau:496 | 이전 성공 | `Transfer success! %s +%d · %s +%d` | Loot.Text.MoveOk | KEEP | 결과 |
| 22 | LootService.luau:498 | 이전 실패 | `Transfer failed… %s stays +%d.` | Loot.Text.MoveFail | KEEP | 실패 |
| 23 | LootService.luau:517 | 전투 중 주문서 사용 | `You can't use scrolls in combat.` | Loot.Text.UseCombat | KEEP | 할 수 없음 |
| 24 | LootService.luau:533 | 없는 무기를 장착하려 할 때 | `You don't have that weapon.` | Loot.Text.NotOwned | KEEP | 실패 |
| 25 | LootService.luau:539 | 레벨이 모자라 장착 불가 | `You can use this weapon from Lv %d.` | Text.EquipNeedLevel | KEEP | 할 수 없음 |
| 26 | LootService.luau:543 | 진영 없이 진영 무기 장착 | `Pick a side first.` | Text.NeedFaction | KEEP | 할 수 없음 |
| 27 | LootService.luau:547 | 쓰러진 상태에서 장착 | `You can't change weapons while knocked out.` | Loot.Text.EquipDead | KEEP | 할 수 없음 |
| 28 | LootService.luau:548 | 전투 중 장착 | `You can't change weapons in combat.` | Loot.Text.EquipCombat | KEEP | 할 수 없음 |
| 29 | LootService.luau:551 | 가방에서 무기를 장착할 때마다 | `%s equipped!` | Loot.Text.Equip | OFF | 방금 한 행동을 되풀이 (장착 모습과 Upgrade 연출이 이미 보임) |
| 30 | LootService.luau:557 | 대장간 멀리서 재료 판매 | `Sell materials near the Forge anvil.` | Loot.Text.SellFar | KEEP | 할 수 없음 |
| 31 | LootService.luau:571 | 팔 재료가 없을 때 | `No materials to sell.` | Loot.Text.SellNothing | KEEP | 실패 피드백 |
| 32 | LootService.luau:576 | 재료 판매 | `Sold %d materials! Gold +%s` | Loot.Text.SellDone | KEEP | 골드 보상 |
| 33 | LootService.luau:599 | 환생/무료 직업 변경으로 레벨이 내려가 무기가 자동 교체될 때 (`quiet`면 없음) | `That weapon needs Lv %d → switched to %s.` | Text.WeaponAutoSwap | SHORT | 이유는 짧게 → `Needs Lv %d. Switched.` |
| 34 | LootService.luau:624 | 레벨업으로 더 센 무기를 쓸 수 있게 될 때. 가드 `Nudges.WeaponUsableNow=false`로 지금 안 뜸 | `You can now use %s! Equip it at the Forge or from your Bag.` | Text.WeaponUsableNow | OFF | 다음에 할 일 안내. 이미 꺼짐, 코드와 키만 정리 |

##### StoryQuestService (21곳; 래퍼 `:79`. def 문구는 Config.StoryQuests.Defs 안)

| # | file:line | when | text | Config key | verdict | reason / 새 문구 |
|---|---|---|---|---|---|---|
| 35 | StoryQuestService.luau:280 | 퀘스트 시작 때마다. 숨김 서브는 제외. def.Start 약 35개 | 예: `Shard: A new move! Try it on a group.` `Collect gold to fix the supply road. Walk into a town and it goes into your vault!` `Bright, the young guard, needs help. Find her in Halo Citadel!` | Defs.<id>.Start (예: Config.luau:2863, 2932, 2965, 3184) | OFF | 스토리 + 다음 할 일 안내. 퀘스트 줄·마름모·거리가 이미 함 |
| 36 | StoryQuestService.luau:284 | 시작 때 첫 단계가 아직 못 이룬 Level 단계일 때 | `Grow to Lv5 to learn your first skill!` | Defs 첫 Step의 Start (Config.luau:2907) | OFF | 퀘스트 줄이 같은 말을 함 |
| 37 | StoryQuestService.luau:391 | 자동전투 퀘스트(S0) 완료. 한 번 | `Auto Battle unlocked! Turn it on or off with {Auto} (phone: the Auto button).` | SQ.Text.Unlocked | SHORT | 한 번뿐인 해금만 남김 → `Auto Battle unlocked!` |
| 38 | StoryQuestService.luau:393 | 퀘스트 완료. def.Finish가 있으면 그 문구가 먼저 나가고 보상 줄은 394로 밀림 (Finish 31개) | Finish 예: `Otto: Clang, clang… done. Cocoa time.\nOtto: That's Crown Shard dust!…` `Goblins stole the dust!` `Who walks this path next?`. 없으면 `%s done! +%s gold · +%s XP` | Defs.<id>.Finish / SQ.Text.Reward·RewardXP·RewardOnlyXP·Done | SHORT | 보상 줄만 보냄 → `%s done! +%s gold` |
| 39 | StoryQuestService.luau:394 | Finish가 있을 때 보상 줄 한 번 더 | `%s done! +%s gold · +%s XP` | SQ.Text.Reward 등 | OFF | 38이 보상 줄만 보내면 중복 |
| 40 | StoryQuestService.luau:398 | 보상 아이템이 있을 때 | `+Enhance Scroll 70%` (Loot.Text.Got / GotN) | Loot.Text.Got·GotN | KEEP | 아이템 보상 |
| 41 | StoryQuestService.luau:400 | 퀘스트 완료 뒤 def.Clue (3개) | 예: `Bright's wristband: gold and purple. Where have you seen one?` | Defs.<id>.Clue (Config.luau:3044, 3206, 3233) | OFF | 로어 |
| 42 | StoryQuestService.luau:408 | 칭호 처음 얻을 때 | `New title: %s!` | SQ.Text.NewTitle | KEEP | 보상 |
| 43 | StoryQuestService.luau:475 | 다음 단계로 넘어갈 때. Step.Start 약 11개 | 예: `Shard: Show me how you fight!` `Something small is crying in the meadow...` `They grab in a line. Break the line!` | Defs.<id>.Steps[n].Start | OFF | 스토리/안내. 퀘스트 줄이 바뀜 |
| 44 | StoryQuestService.luau:483 | `Claim=true` 퀘스트의 마지막 단계 | `%s done! Press [Claim].` | SQ.Text.Claim | OFF | 줄이 이미 [Claim] 표시 |
| 45 | StoryQuestService.luau:527 | Trials 시험 하나 끝날 때 (3개) | 예: `Meeting #47. Topic: Grab more. Result: Meet again.` | Defs.<id>.…Say (Config.luau:3031, 3033, 3035) | OFF | 로어 |
| 46 | StoryQuestService.luau:1070 | 자기 진영에 맞는 선택 점수 | `The shard leans toward the light (Honor +%d)` / `…dark (Infamy +%d)` | SQ.Text.Good / Evil | SHORT | 점수 변화만 → `Honor +%d` / `Infamy +%d` |
| 47 | StoryQuestService.luau:1078 | 반대 진영 선택인데 깎을 점수가 0일 때 | `Hallie: Hmm… not very angel-like! The shard leaned to the dark.` | SQ.Text.OffSideHaloZero·HornsZero + LeanGood·LeanEvil | OFF | 대사. 선택 연출·afterglow가 이미 답함 |
| 48 | StoryQuestService.luau:1083 | 반대 진영 선택으로 점수가 깎일 때 | `Hallie: Hmm… not very angel-like! Honor -%d` | SQ.Text.OffSideHalo / OffSideHorns | SHORT | 손실만 → `Honor -%d` |
| 49 | StoryQuestService.luau:1089 | 위 점수 손실로 계급이 내려갈 때 | `Your rank went down. Do good deeds to get it back!` | SQ.Text.RankDownHalo / RankDownHorns | SHORT | 손실만 → `Rank went down.` |
| 50 | StoryQuestService.luau:1119 | 선택 보상 아이템/골드 | `+HP Potion` / `+25 gold` (join ` · `) | SQ.Text.ChoiceGold + Loot.Text.Got | KEEP | 보상 (A23-130이 남기라 한 것) |
| 51 | StoryQuestService.luau:1128 | 점수 있는 선택이 지난번과 반대 쪽일 때 | `You kept it last time. Now you give. People change. Shards too.` | SQ.Text.ChangedGood / ChangedEvil | OFF | 로어 |
| 52 | StoryQuestService.luau:1140 (dormant) | `pick.Reply` 지연 대사. Config에 `Reply =`가 하나도 없음 | (대사 문자열) | defs의 Reply | OFF | 쓰는 데가 없음. 경로 삭제 |
| 53 | StoryQuestService.luau:1175 | 0점·보상 없는 선택(진영 있는 플레이어) | `Your shard leaned to the light.` / `…dark.` | SQ.Text.LeanGood / LeanEvil | OFF | 선택 연출이 이미 답함 |
| 54 | StoryQuestService.luau:1188 | Neutral 플레이어의 보상 없는 선택 | `Your choice is saved.` | SQ.Text.Recorded | OFF | 설명 |
| 55 | StoryQuestService.luau:1230 | 황금 거위 첫 구출/약탈(평생 한 번) | `Your first Golden Goose rescue! (Honor +%d)` / `…poach! (Infamy +%d)` | SQ.Text.GooseFirstHalo / GooseFirstHorns | SHORT | 점수 보상만 → `Honor +%d` / `Infamy +%d` |

##### PvPService (18곳; 래퍼 `:94`)

| # | file:line | when | text | Config key | verdict | reason / 새 문구 |
|---|---|---|---|---|---|---|
| 56 | PvPService.luau:348 | 별 5개(Most Wanted)가 될 때. NotifyAll 종류 없음 = 가운데 큰 announce 띠 | `%s is now the Most Wanted! Bounty: %s gold` | Text.MostWanted | KEEP | 드문 전 서버 PvP 위험 알림. 현상금은 아래 70·73 줄과 다름 |
| 57 | PvPService.luau:545 | 새싹 보호 끝날 때 한 번, 60초 유예 시작 | `Sprout graduate! You can fight other sides in 60 s` | Text.GraduateStart | KEEP | 한 번뿐인 PvP 안전 사실 |
| 58 | PvPService.luau:744 | PvP에서 졌을 때마다(피해자) | `Get revenge on %s! ATK +25%% for 90 s` | Text.Revenge | SHORT | 버프는 남기고 이름·설명 제거 → `Revenge! ATK +25%` |
| 59 | PvPService.luau:750 | 복수 시간 안에 복수 성공 | `Revenge done!` | Text.RevengeDone | OFF | 방금 한 킬이 이미 보임 |
| 60 | PvPService.luau:761 | 약자 괴롭힘 KO | `Bully KO! No reward, size and ATK -15%% (bully level %d)` | Text.BullyKO | KEEP | 페널티 경고 |
| 61 | PvPService.luau:762 | 괴롭힘 피해자에게 | `A bully knocked you out. You lost nothing!` | Text.BullyVictim | OFF | 안심 설명. 쓰러진 안내는 Death 쪽이 함 |
| 62 | PvPService.luau:768 | 센 상대를 이겼을 때. 점수 줄(827)과 한 화면 | `You beat a stronger foe! Honor, Infamy and war points ×2` | Text.BoldStrong | SHORT | → `Stronger foe! Points ×2` |
| 63 | PvPService.luau:769 | 약한 상대를 이겼을 때 | `A weaker foe: Honor, Infamy and war points are halved.` | Text.BoldWeak | SHORT | → `Weaker foe: points halved.` |
| 64 | PvPService.luau:779 | 3분 안에 같은 사람 또 약탈 | `You just robbed this player. You can't rob them again for 3 minutes.` | Text.PlunderTooSoon | KEEP | 할 수 없음 |
| 65 | PvPService.luau:800 | 약탈당한 피해자 | `%s stole %s gold from you!\nIf a knight catches the thief within 45 s, you get 120%% back.` | Text.Plundered | SHORT | 위험만 → `%s stole %s gold from you!` |
| 66 | PvPService.luau:801 | 약탈한 쪽 | `Put %s gold in your Grudge Sack!\nKeep it: survive 45 s in a PvP zone. (Wanted stars: %d)` | Text.PlunderGain | SHORT | → `+%s gold in Grudge Sack!` |
| 67 | PvPService.luau:814 | 괴롭힘 현상금 수령 | `Got a %s gold bully bounty!` | Text.BullyBountyGain | KEEP | 골드 보상 |
| 68 | PvPService.luau:827 | 깨끗한 Horns를 잡아 명예 얻을 때 | `Honor +%d` | Text.HonorGain | KEEP | 보상 |
| 69 | PvPService.luau:852 | 수배자 KO 현상금 | `Got a %s gold bounty! Honor +%d` | Text.BountyGain | KEEP | 보상 |
| 70 | PvPService.luau:855 | 별 3개 이상 수배자를 잡을 때. NotifyAll 종류 없음 = 가운데 큰 띠 | `[Knights of Light] %s got a %s gold bounty!` / hidden: `%s got a %s gold bounty!` | Text.BountyAnnounce / BountyAnnounceHidden | OFF | 잡은 본인은 69에서 보상을 받음. 남에게는 자랑 방송 |
| 71 | PvPService.luau:969 | 유예 60초 끝날 때 한 번 | `Now you can fight the other sides!` | Text.GraduateEnd | OFF | 57과 중복 |
| 72 | PvPService.luau:1067 | 수배자가 나갈 때 마지막 공격자(Halo)에게 | `Got a %s gold bounty! Honor +%d` | Text.BountyGain | KEEP | 보상 |
| 73 | PvPService.luau:1069 | 위 경우 별 3개 이상. NotifyAll 종류 없음 = 가운데 큰 띠 | `[Knights of Light] %s got a %s gold bounty!` | Text.BountyAnnounce / BountyAnnounceHidden | OFF | 70과 같은 이유 |

##### FactionService (11곳; 래퍼 `:63`)

| # | file:line | when | text | Config key | verdict | reason / 새 문구 |
|---|---|---|---|---|---|---|
| 74 | FactionService.luau:305 | 약한 쪽으로 처음 가입 | `Bonus for joining the smaller side: +%d gold!` | Text.UnderdogSignOn | KEEP | 골드 보상 |
| 75 | FactionService.luau:327 | 제단 전환 시도, 그러나 약탈 자루를 짊어짐 | `You can't do that while carrying a Grudge Sack.` | Text.BlockedSack | KEEP | 할 수 없음 |
| 76 | FactionService.luau:331 | 제단 전환, 카이주 중 | `You can't do that during a Kaiju event.` | Text.BlockedKaiju | KEEP | 할 수 없음 |
| 77 | FactionService.luau:335 | 제단 전환, 수배 별이 있음 | `You need zero Wanted stars to do that.` | Text.BlockedStars | KEEP | 할 수 없음 |
| 78 | FactionService.luau:339 | 제단 전환, 전투 중 | `You can't do that in combat.` | Text.TravelBlockedCombat | KEEP | 할 수 없음 |
| 79 | FactionService.luau:344 | 괴롭힘 레벨이 있는데 Neutral로 | `You can join the Artisan Guild after all your bully levels are gone.` | Text.BlockedBully | KEEP | 할 수 없음 |
| 80 | FactionService.luau:349 | 전환 쿨다운 중 | `You can switch sides again in %s.` | Text.SwitchCooldown | KEEP | 할 수 없음 |
| 81 | FactionService.luau:363 | 티켓 없음 / 구매 저장 중 | `You have no change ticket. Get one at Menu > Ticket Shop.` / `Saving your ticket purchase. Please tap again in a moment.` | Text.NoTicket / TicketSaving | KEEP | 할 수 없음 |
| 82 | FactionService.luau:384 | 티켓으로 진영 전환 | `You joined the %s! (Ticket used, points kept)` | Text.SwitchDoneTicket | OFF | A23-99: "You joined …" 알림 끔. 방금 고른 것을 되풀이 |
| 83 | FactionService.luau:386 | 무료 전환, 점수가 있었을 때 | `You joined the %s! (Price of switching: %s back to 0)` | Text.SwitchDoneFree | SHORT | 잃은 점수만 → `Honor back to 0.` |
| 84 | FactionService.luau:389 | 무료 전환, 점수가 없었을 때 | `You joined the %s!` | `TEXT_SWITCH_DONE_PLAIN` (`FactionService.luau:20`) | OFF | A23-99: "You joined …" 알림 끔 |

##### QuestService (13곳; 래퍼 없이 `Net.Notify` 직접)

| # | file:line | when | text | Config key | verdict | reason / 새 문구 |
|---|---|---|---|---|---|---|
| 85 | QuestService.luau:511 | 첫 미션 수락(단계 진입), 한 번 | `First mission: Free the supply road · 5 slimes! (Reward: 150 gold)` | Tut.Text.QuestStart | OFF | 퀘스트 줄이 같은 말을 함 |
| 86 | QuestService.luau:603 | 대장간에서 첫 무기를 받을 때 (318과 한 화면) | `Otto: Clang, clang… done. Here's your first weapon! The Squishy Meadow is next.` | Tut.Text.ForgeGift | OFF | 대사와 다음 할 일 안내. 아래 318이 보상을 말함 |
| 87 | QuestService.luau:683 | 슬라임 5/5 완료, 한 번 | `Supply road mission done! Press [Claim].` | Tut.Text.QuestReady | OFF | 줄이 이미 완료/[Claim] 표시 |
| 88 | QuestService.luau:707 | 첫 미션 [Claim] 또는 60초 자동 지급(6초). 같은 줄 4종 | `Thanks for guarding the supply road! +%s gold. That buys a new weapon at the Forge!` (AutoClaimed·ClaimedArmed 변형) | Tut.Text.Claimed / AutoClaimed / ClaimedArmed / AutoClaimedArmed | SHORT | 보상만 → `+%s gold` |
| 89 | QuestService.luau:881 | 안내 사슬이 끝나 목표 줄이 사라질 때. 가드 `Nudges.GuideDone=false`로 지금 안 뜸 | `That's all from me! Now hunt and get stronger.` | Tut.Text.GuideDone | OFF | 이미 꺼짐 (A23-99). 코드 정리 |
| 90 | QuestService.luau:964 | 일일 3개 다 깨 보너스 상자 | `3 daily quests done! Bonus chest +%s gold +%s XP` | Text.DailyChest | KEEP | 보상 |
| 91 | QuestService.luau:969 | 상자에서 티켓이 나올 때 (확률) | `A Class Change Ticket came out of the bonus chest!` | Text.DailyChestTicket | KEEP | 아이템 보상 |
| 92 | QuestService.luau:986 | Extra 퀘스트 완료 (튜토리얼 첫 단계 전엔 조용) | `Extra quest done! +%s gold` | Text.QuestDone | KEEP | 보상 |
| 93 | QuestService.luau:990 | 일일 완료. 가드 `Nudges.DailyReady=false`로 지금 안 뜸 | `Daily quest done! Press [Claim].` | Text.DailyReady | OFF | 이미 꺼짐. 줄이 Done!/[Claim] 표시 |
| 94 | QuestService.luau:1116 | 자정에 어제 못 받은 일일 보상 자동 지급 | `Yesterday's unclaimed daily rewards went to your vault. (+%s gold)` | Text.DailyAutoPaid | SHORT | 보상만 → `Daily rewards: +%s gold` |
| 95 | QuestService.luau:1154 | 일일 [Claim] | `Daily reward! +%s gold +%s XP` | Text.DailyClaimed | KEEP | 보상 |
| 96 | QuestService.luau:1162 | 하루 3개 다 받고 2초 뒤, 6초 (보너스 상자 줄 바로 뒤) | `All done for today! You can rest now without missing out. Want more? Enjoy story quests or hunting.` | Text.DailyAllDone | OFF | 격려/안내. 상자 줄과 연달아 두 줄 |
| 97 | QuestService.luau:1207 | 휴가 보너스 수령 | `Vacation bonus! +%s gold +%s XP` | Text.VacationClaimed | KEEP | 보상 |

##### ZoneService (11곳; 래퍼 `:84`, `notifyBounce :264`는 3초 쓰로틀)

| # | file:line | when | text | Config key | verdict | reason / 새 문구 |
|---|---|---|---|---|---|---|
| 98 | ZoneService.luau:301 | 이동 채널 중 맞아서 취소 | `Travel canceled.` | Text.TravelCancelled | KEEP | 실패 |
| 99 | ZoneService.luau:324 | Neutral이 PvP 구역에 들어갈 때. 20초 간격(`PVP_NOTE_GAP`). 새 Neutral 선택은 `Features.NeutralFaction=false`라 기존 저장만 해당 | `PvP zone, but the Artisan Guild can't be attacked.` | Text.EnteredPvPNeutral | OFF | 설명만. 공격도 받지 않음 |
| 100 | ZoneService.luau:326 | PvP 구역에 들어갈 때마다. 20초 간격 | `PvP zone! Watch out for the other sides.` | Text.EnteredPvP | SHORT | 위험은 남기되 반복이라 줄임 → `PvP zone!` |
| 101 | ZoneService.luau:329 | 안전 구역에 들어갈 때마다. 가드 `Nudges.EnteredSafe=false`로 지금 안 뜸 | `Safe zone.` | Text.EnteredSafe | OFF | 이미 꺼짐. 코드 정리 |
| 102 | ZoneService.luau:563 | 마을 물에 8초 이상 있다가 구조될 때. `WaterRescue.Toast=true`라 지금 뜸 | `Splash! Back on dry land.` | Text.WaterRescue (Config.luau:1923) | SHORT | 갑작스러운 이동이라 한 줄은 남김 → `Back on land.` (`Toast=false`로 끄는 것도 가능) |
| 103 | ZoneService.luau:616 | 레벨 모자란 구역에 걸어 들어갈 때. 3초 쓰로틀, 교차로로 튕김 | `You need Lv %d or higher to enter!` | Text.NeedLevel | KEEP | 할 수 없음 |
| 104 | ZoneService.luau:622 | 남의 진영 마을 / 카이주가 마을 진입. 3초 쓰로틀 | `You can't enter the other side's town!` / `A Kaiju can't enter towns!` (`KAIJU_TOWN_FALLBACK`, `ZoneService.luau:39`) | Text.EnemyTown / (`KaijuNoTown` 키는 Config에 없음) | KEEP | 할 수 없음 |
| 105 | ZoneService.luau:755 | 이동 채널 끝에서 조건 불충족 | `Travel canceled.` | Text.TravelCancelled | KEEP | 실패 |
| 106 | ZoneService.luau:794 | 이동 시작 때마다(패드 제외, 메뉴/지도 이동) | `Traveling...` | Text.Traveling | OFF | 이동 바(`TravelingUntil`)가 이미 보임 |
| 107 | ZoneService.luau:820 | 메뉴/지도 이동이 거절될 때 | `You need Lv %d or higher to enter!` / `A Kaiju can't teleport!` / `You can't teleport while carrying a Grudge Sack!` / `With 3 or more Wanted stars, you have to run away on foot!` / `You can't do that in combat.` | Text.NeedLevel / TravelBlockedKaiju·Sack·Stars·Combat | KEEP | 할 수 없음 |
| 108 | ZoneService.luau:859 | 패드를 밟았는데 거절될 때. `PadDebounce` | 107과 같은 문구들 | 위와 같음 | KEEP | 할 수 없음 |

#### 2. OFF 목록 (31곳)

- `LootService.luau:298` Loot.Text.BareEquip
- `LootService.luau:551` Loot.Text.Equip
- `LootService.luau:624` Text.WeaponUsableNow (이미 꺼짐)
- `StoryQuestService.luau:280` Defs.*.Start (def 수준 약 35개)
- `StoryQuestService.luau:284` Defs 첫 Step의 Start
- `StoryQuestService.luau:394` SQ.Text.Reward 등 (38이 보상 줄만 보내면 중복)
- `StoryQuestService.luau:400` Defs.*.Clue (3개)
- `StoryQuestService.luau:475` Defs.*.Steps[n].Start (약 11개)
- `StoryQuestService.luau:483` SQ.Text.Claim
- `StoryQuestService.luau:527` Defs.*.Say (3개)
- `StoryQuestService.luau:1078` SQ.Text.OffSideHaloZero / OffSideHornsZero + LeanGood / LeanEvil
- `StoryQuestService.luau:1128` SQ.Text.ChangedGood / ChangedEvil
- `StoryQuestService.luau:1140` (dormant) Reply 경로 전체
- `StoryQuestService.luau:1175` SQ.Text.LeanGood / LeanEvil
- `StoryQuestService.luau:1188` SQ.Text.Recorded
- `PvPService.luau:750` Text.RevengeDone
- `PvPService.luau:762` Text.BullyVictim
- `PvPService.luau:855` Text.BountyAnnounce / BountyAnnounceHidden (NotifyAll 띠)
- `PvPService.luau:969` Text.GraduateEnd
- `PvPService.luau:1069` Text.BountyAnnounce / BountyAnnounceHidden (NotifyAll 띠)
- `FactionService.luau:384` Text.SwitchDoneTicket
- `FactionService.luau:389` `TEXT_SWITCH_DONE_PLAIN` (`FactionService.luau:20`)
- `QuestService.luau:511` Tut.Text.QuestStart
- `QuestService.luau:603` Tut.Text.ForgeGift
- `QuestService.luau:683` Tut.Text.QuestReady
- `QuestService.luau:881` Tut.Text.GuideDone (이미 꺼짐)
- `QuestService.luau:990` Text.DailyReady (이미 꺼짐)
- `QuestService.luau:1162` Text.DailyAllDone
- `ZoneService.luau:324` Text.EnteredPvPNeutral
- `ZoneService.luau:329` Text.EnteredSafe (이미 꺼짐)
- `ZoneService.luau:794` Text.Traveling

#### 3. SHORT 목록 (22곳)

- `LootService.luau:196` Loot.Text.ItemFull / ItemFullUse → `%s is full (max %d).`
- `LootService.luau:289` Loot.Text.JackpotSelf → `Legendary weapon [%s]!` (JackpotEquip은 그대로)
- `LootService.luau:318` Loot.Text.FirstWeapon → `Got your first weapon, [%s]!`
- `LootService.luau:321` Loot.Text.FirstWeaponBag → `Got [%s]! Check your Bag.`
- `LootService.luau:332` Loot.Text.PotionFull → `%s is full.`
- `LootService.luau:599` Text.WeaponAutoSwap → `Needs Lv %d. Switched.`
- `StoryQuestService.luau:391` SQ.Text.Unlocked → `Auto Battle unlocked!`
- `StoryQuestService.luau:393` def.Finish 제거, 보상 줄만 → `%s done! +%s gold`
- `StoryQuestService.luau:1070` SQ.Text.Good / Evil → `Honor +%d` / `Infamy +%d`
- `StoryQuestService.luau:1083` SQ.Text.OffSideHalo / OffSideHorns → `Honor -%d` / `Infamy -%d`
- `StoryQuestService.luau:1089` SQ.Text.RankDownHalo / RankDownHorns → `Rank went down.`
- `StoryQuestService.luau:1230` SQ.Text.GooseFirstHalo / GooseFirstHorns → `Honor +%d` / `Infamy +%d`
- `PvPService.luau:744` Text.Revenge → `Revenge! ATK +25%`
- `PvPService.luau:768` Text.BoldStrong → `Stronger foe! Points ×2`
- `PvPService.luau:769` Text.BoldWeak → `Weaker foe: points halved.`
- `PvPService.luau:800` Text.Plundered → `%s stole %s gold from you!`
- `PvPService.luau:801` Text.PlunderGain → `+%s gold in Grudge Sack!`
- `FactionService.luau:386` Text.SwitchDoneFree → `Honor back to 0.` / `Infamy back to 0.`
- `QuestService.luau:707` Tut.Text.Claimed / AutoClaimed / ClaimedArmed / AutoClaimedArmed → `+%s gold`
- `QuestService.luau:1116` Text.DailyAutoPaid → `Daily rewards: +%s gold`
- `ZoneService.luau:326` Text.EnteredPvP → `PvP zone!`
- `ZoneService.luau:563` Text.WaterRescue → `Back on land.`

#### 4. 개수

| | 줄 수 | KEEP | OFF | SHORT |
|---|---|---|---|---|
| LootService | 34 | 25 | 3 | 6 |
| StoryQuestService | 21 | 3 | 12 | 6 |
| PvPService | 18 | 8 | 5 | 5 |
| FactionService | 11 | 8 | 2 | 1 |
| QuestService | 13 | 5 | 6 | 2 |
| ZoneService | 11 | 6 | 3 | 2 |
| **합계** | **108** | **55** | **31** | **22** |

- 이미 가드로 꺼져 있는 OFF는 4곳입니다: `LootService.luau:624`, `QuestService.luau:881`, `QuestService.luau:990`, `ZoneService.luau:329`. 실제로 화면에서 새로 사라지는 OFF는 27곳입니다.
- 가운데 큰 announce 띠(NotifyAll, 종류 없음)는 `PvPService.luau:348`, `:855`, `:1069` 세 곳입니다. 이 중 348만 KEEP입니다.
- 108곳은 래퍼가 부르는 호출 수입니다. `LootService.luau:61`, `ZoneService.luau:270`처럼 래퍼 안쪽 한 줄은 따로 세지 않았습니다. 의뢰서의 "약 112"와 차이가 나는 이유는 이 집계 방식 차이로 추정합니다.

#### 5. 한 화면에 설명이 겹치는 곳 (A23-130 "둘 이상 금지")

- **첫 무기 받을 때:** `QuestService.luau:603` 대사, `LootService.luau:318` 또는 `:321`, 그리고 클라이언트의 "Stronger!". 603을 끄면 해결됩니다.
- **레어 드롭을 맨손일 때 받을 때:** `LootService.luau:293`과 `:298`이 연달아 나갑니다.
- **일일 마지막 [Claim]:** `QuestService.luau:1154`, `:964`, `:969`, 2초 뒤 `:1162`가 겹칩니다.
- **스토리 퀘스트 완료:** Finish → 보상 → 아이템 → Clue 순으로 4줄까지 쌓입니다(`StoryQuestService.luau:393`, `:394`, `:398`, `:400`).
- **PvP KO 한 번:** `PvPService.luau:744`, `:768`, `:801`, `:827`이 한꺼번에 나갑니다.
- **스토리 선택 한 번:** `StoryQuestService.luau:1070`~`:1089`, `:1119`, `:1128`, `:1175`가 겹칩니다.

#### 6. 확인한 것 / 추정한 것

**확인한 것** (파일을 직접 읽음):
- 호출 위치(file:line)와 문구 원문.
- `Config.Nudges` 가드 4개가 모두 `false`이고 코드에서 `~= false`로 막고 있음.
- `WaterRescue.Toast = true`(`Config.luau:1923`).
- `Config`에 `Reply =` 항목이 없어서 `StoryQuestService.luau:1140` 경로가 죽어 있음.
- `Features.NeutralFaction = false`(`Config.luau:19`).
- `KaijuNoTown` 키가 Config에 없어서 `ZoneService.luau:39`의 대체 문구가 쓰임.
- `Net.NotifyAll`은 종류를 안 주면 `"announce"`(`Net.luau:139`).

**추정한 것**:
- "한 번만" / "자주"는 코드 흐름으로 판단했고 실제 플레이로 세지 않았습니다.
- Finish, Start, Clue, Say 개수는 `Config.luau`에서 `= "`로 시작하는 줄만 세서 대략입니다(Start 46, Finish 31, Clue 3, Say 3). 여러 줄로 쓴 값은 빠졌을 수 있습니다.
- 클라이언트가 퀘스트 줄·마름모·거리·이동 바·Stronger! 연출을 이미 보여 준다는 전제로 "중복"이라 판정했습니다. 클라이언트 코드는 열어보지 않았습니다.
- 56(`PvPService.luau:348`)과 102(`ZoneService.luau:563`)는 경계선입니다. 56은 KEEP, 102는 SHORT로 두었는데, 더 줄이고 싶으면 56은 SHORT, 102는 `WaterRescue.Toast=false`로 끌 수 있습니다.

**범위 밖이지만 알아둘 것**:
- `LootService.luau:250`, `:291`, `:296`의 `announce(...)`는 `AnnounceService`로 가는 서버 전체 채팅 줄이고 notify가 아니라서 이 표에서 뺐습니다.
- `AnnounceService.luau:155`는 `Net.Notify`를 직접 호출하며 B부 대상입니다.

## 2-B. 서버 B부 (나머지 25개 파일)

### 서버가 화면에 보내는 문구 목록 (B: 25개 파일)

정적 코드 읽기로 만든 표입니다. 실제 플레이로 확인한 것은 없습니다. 판정 기준은 A23-99와 A23-130입니다 (`docs/SPEC_ADDENDUM.md:95-99`, `:364-367`).

**확인한 것**
- 모든 줄 번호는 `Net.Notify`, `Net.NotifyAll`, 지역 래퍼를 직접 읽어 확인했습니다. 래퍼는 `notify`, Shop의 `notifyBad`, Pet의 `notifyLater`, Deeds의 `say`입니다.
- 문구는 `src/ReplicatedStorage/Shared/Config.luau`에서 찾았습니다.
- 꺼진 기능은 설정값으로 확인했습니다.
  - `Board.Enabled=false` (`Config.luau:3881`)
  - `LostFound.Enabled=false` (`:7850`)
  - `Features.Commission=false` (`:7812`)
  - `Combat.AutoIdleRest=false` (`:520`)
  - `Halloween.Enabled=false` (`:2465`)
- `Config.Nudges`는 `GuideDone`, `EnteredSafe`, `DailyReady`, `WeaponUsableNow`가 모두 false입니다 (`:5310-5313`). 이 파일들 안에서 이 가드가 걸린 호출은 없습니다.
- `Config.WaterRescue.Toast`도 이 파일들에는 해당 호출이 없습니다. Zone 쪽(파트 A) 몫입니다.

**추정한 것**
- 판정(KEEP/OFF/SHORT)은 위 규칙을 제가 적용한 것입니다. 최종 결정은 검수 몫입니다.
- "큰 띠"는 `Net.NotifyAll`을 kind 없이 부르면 `"announce"`가 된다는 코드(`Net.luau:138-139`)에서 추정했습니다. 클라이언트 표시 모양은 보지 않았습니다.
- 호출 횟수가 가끔인지 자주인지는 코드 흐름으로 짐작한 것입니다.

**범위 밖이지만 참고**
- `FieldBossService`의 `announce()`와 `AnnounceService.Broadcast`는 `Net.Notify`가 아니라 `Announce` 리모트(채팅/토스트)로 나갑니다. 이 표에 넣지 않았습니다. `Config.Announce.Events`의 `Toast = true`(`Config.luau:5387-5398`)가 켜진 줄은 따로 훑어야 합니다.
- 한 화면에 겹치는 곳이 있습니다.
  - 거위 종료: 내 보상(`GooseService.luau:587`)과 큰 띠 결과(`:673`)가 동시에 나갑니다.
  - 환생: `ProgressionService.luau:486`, `:488/:490`, `:492`가 연달아 나갑니다.
  - 킹 슬라임 처치 카드: `FinisherService.luau:144`, `:148/:151`, `:154`가 연달아 나갑니다.

#### 1. 호출 지점 표

| # | file:line | when | text (English) | Config key | verdict | reason / 새 문구 |
|---|---|---|---|---|---|---|
| **GrudgeService** | | | | | | |
| 1 | GrudgeService.luau:149 | 자루 도둑이 졌거나 환급될 때, 자루당 1회 | You lost the Grudge Sack! | Text.SackLost | KEEP | 잃음(위험) |
| 2 | GrudgeService.luau:309 | 접속 시 우편 환급 | Grudge mail! Your stolen %s gold came back to your vault. | Text.GrudgeMail | SHORT | 환급액만 남김: "Stolen gold back: +%s" |
| 3 | GrudgeService.luau:335 | 도둑이 45초 버텨 지급될 때 | You kept the Grudge Sack! Got %s gold | Text.SackPaid | KEEP | 골드 보상 |
| 4 | GrudgeService.luau:348 | 도둑이 쓰러져 피해자에게 환급 | The thief went down, so your stolen %s gold came back to your vault. | Text.GrudgeReturned | SHORT | 설명 문장: "Stolen gold back: +%s" |
| 5 | GrudgeService.luau:369 | 복수 성공 시 피해자에게 | %s got your Grudge Sack back! %s gold went to your vault! | Text.GrudgeRefund | SHORT | 같은 환급: "Stolen gold back: +%s" |
| 6 | GrudgeService.luau:386 | 복수 대행 보너스(쿨다운 있음) | Avenger bonus +%s gold! | Text.AvengerBonus | KEEP | 골드 보상 |
| 7 | GrudgeService.luau:389 | 복수가 날 때마다 모두에게 NotifyAll, kind "info" | %s took the Grudge Sack back from %s! | Text.GrudgeAvengedAll | OFF | 남 이야기, 전체 방송 |
| 8 | GrudgeService.luau:533 | 유령 잡기 버튼, 최대치 도달 시 | This sack can't be held any longer (max +%d s). | Text.GhostHoldMax | KEEP | 못 한다(실패) |
| 9 | GrudgeService.luau:546 | 유령 잡기 버튼을 누를 때마다 | Your ghost grabbed the thief! Their hold time +%d s (max +%d s) | Text.GhostHoldOk | OFF | 누를 때마다 반복, 버튼·유령 효과가 이미 보여 줌 |
| 10 | GrudgeService.luau:547 | 위와 같음, 도둑에게 | A grudge ghost is holding you! You must survive longer. | Text.GhostHeld | SHORT | 위험은 남김: "Ghost holds you!" |
| **ClassService** | | | | | | |
| 11 | ClassService.luau:88 | 진영 없이 직업 선택 시도 | Pick a side first. | Text.NeedFaction | KEEP | 실패 |
| 12 | ClassService.luau:108 | 같은 직업으로 바꾸기 시도 | You already have that class. | Text.ClassSame | KEEP | 실패 |
| 13 | ClassService.luau:113 | PvP 구역에서 직업 변경 시도 | You can only change class in a safe zone. | Text.ClassNeedSafe | KEEP | 실패 |
| 14 | ClassService.luau:117 | 원한 자루를 든 채 | You can't do that while carrying a Grudge Sack. | Text.BlockedSack | KEEP | 실패 |
| 15 | ClassService.luau:121 | 카이주 이벤트 중 | You can't do that during a Kaiju event. | Text.BlockedKaiju | KEEP | 실패 |
| 16 | ClassService.luau:127 | 전투 중 | You can't do that in combat. | Text.TravelBlockedCombat | KEEP | 실패 |
| 17 | ClassService.luau:138 | 변경권 없음 / 구매 저장 중 | You have no change ticket. Get one at Menu > Ticket Shop. / Saving your ticket purchase. Please tap again in a moment. | Text.NoTicket / TicketSaving | KEEP | 실패 |
| 18 | ClassService.luau:159 | 레벨 낮을 때 무료 변경(Lv5 미만), 변경마다 | You changed your class to %s! (Level kept: under Lv%d) | Text.ClassChangedFreeKeep | SHORT | 방금 한 일을 되말함: "Class: %s (level kept)" |
| 19 | ClassService.luau:161 | 무료(레벨 1로 리셋) / 변경권 사용 | You changed your class to %s! You start again from Lv 1. / …(Ticket used, level kept) | Text.ClassChangedFree / ClassChangedTicket | KEEP | A23-99가 남기라 한 "규칙 알림", 레벨 리셋은 위험 |
| **ShopService** | | | | | | |
| 20 | ShopService.luau:34 | 대장간 멀리서 구매 | Get close to the Forge anvil to buy weapons. | Text.WeaponShopFar | SHORT | 할 일 안내: "Too far from the shop." |
| 21 | ShopService.luau:53 | 안 파는 등급 요청 | The Forge doesn't sell this weapon. | Text.WeaponNotSold | KEEP | 실패 |
| 22 | ShopService.luau:66 | 1등급 무기 구매 시도 | The Blacksmith gives you your first weapon for free. Take the Guide's first quest! | Text.WeaponFromQuest | SHORT | 다음 할 일 안내(퀘스트 줄이 함): "Not sold. Quest reward." |
| 23 | ShopService.luau:75 (notifyBad:23) | 레벨 부족 | You can buy this weapon from Lv %d. / You can use this weapon from Lv %d. | Text.WeaponNeedLevel / EquipNeedLevel | KEEP | 실패 |
| 24 | ShopService.luau:83 (notifyBad) | 진영 없이 진영 무기 | Pick a side first. | Text.NeedFaction | KEEP | 실패 |
| 25 | ShopService.luau:89 | 전투 중 구매 | You can't change weapons in combat. | Loot.Text.EquipCombat | KEEP | 실패 |
| 26 | ShopService.luau:101 (notifyBad) | 골드 부족 | Not enough gold. | Text.NotEnoughGold | KEEP | 실패 |
| 27 | ShopService.luau:112 | 무기 구매/다시 장착마다 | %s equipped! | Text.WeaponBought / Loot.Text.Equip | KEEP | 새 무기(보상). 이미 가진 걸 다시 낄 때(info)는 반복이라 따로 끌 수도 있음 |
| 28 | ShopService.luau:123 | 대장간 멀리서 판매 | Get close to the Forge anvil to sell weapons. | Text.WeaponSellFar | SHORT | "Too far from the shop." |
| 29 | ShopService.luau:154 | 무기 판매 | Sold %s! Gold +%s | Text.WeaponSold | KEEP | 골드 얻음 |
| 30 | ShopService.luau:322 | 물약 상인 멀리서 | Get close to the Potion Seller to buy. | Text.PotionShopFar | SHORT | "Too far from the shop." |
| 31 | ShopService.luau:330 | 물약 보유 한도 | You can hold up to %d of each potion. | Text.PotionStockFull | KEEP | 실패 |
| 32 | ShopService.luau:338 (notifyBad) | 물약 골드 부족 | Not enough gold. | Text.NotEnoughGold | KEEP | 실패 |
| 33 | ShopService.luau:343 | 물약 살 때마다 | Bought %s potion ×%d! | Text.PotionBought | OFF | 방금 한 일 되말함, 상점 창·퀵슬롯 숫자가 보여 줌 |
| **CommissionService** (dormant: Features.Commission=false, `onCommission`이 `FeatureOn` 검사) | | | | | | |
| 34 | CommissionService.luau:90 | (dormant) 멀리서 주문 | Get close to the Forge anvil to buy weapons. | Text.WeaponShopFar | SHORT | "Too far from the shop." |
| 35 | CommissionService.luau:96 | (dormant) 이미 가짐 | You already have this weapon. | Commission.Text.Owned | KEEP | 실패 |
| 36 | CommissionService.luau:101 | (dormant) 레벨 부족 | Otto says: come back at Lv %d! | Commission.Text.NeedLevel | KEEP | 실패 |
| 37 | CommissionService.luau:105 | (dormant) 전투 중 | You can't change weapons in combat. | Loot.Text.EquipCombat | KEEP | 실패 |
| 38 | CommissionService.luau:111 | (dormant) 재료 부족 | Otto needs more materials for this one. | Commission.Text.NeedMaterials | KEEP | 실패 |
| 39 | CommissionService.luau:119 | (dormant) 골드 부족 | Not enough gold. | Text.NotEnoughGold | KEEP | 실패 |
| 40 | CommissionService.luau:136 | (dormant) 제작 완료 | Otto made your %s! | Commission.Text.Done | KEEP | 아이템 보상 |
| **KaijuService** | | | | | | |
| 41 | KaijuService.luau:421 | 카이주 변신 때 NotifyAll 큰 띠, 이벤트당 1회 | Kaiju %s is here! Knights can attack it anywhere! | Story.KaijuStart | SHORT | 규칙 설명 뺌: "Kaiju %s is here!" |
| 42 | KaijuService.luau:455 | 카이주 생존 보상(문구 3종: 일반 / 상한 / 상대 없음) | You survived! Pouch gold ×1.5 = %s gold to your vault! (+ 이 파일 :33-34의 두 문구) | Text.KaijuSurviveReward / TXT_SURVIVE_CAPPED / TXT_SURVIVE_UNCONTESTED | SHORT | 골드는 보상이나 설명이 김: "Survived! +%s gold" |
| 43 | KaijuService.luau:456 | 생존 때 NotifyAll 큰 띠 | The Kaiju %s survived to the end! A Legendary Villain is born! | Story.KaijuSurvived | OFF | 이야기·남의 소식, 큰 띠 |
| 44 | KaijuService.luau:559 | 카이주가 이미 있을 때 대기열에 들어간 호르 플레이어에게 | Another Kaiju is out. You'll transform when it's over! | Text.KaijuQueued | SHORT | 설명 문장: "You're queued as Kaiju." |
| 45 | KaijuService.luau:787 | 처치 보상 | Kaiju hunt reward +%s gold! | Text.KaijuReward | KEEP | 골드 보상 |
| 46 | KaijuService.luau:798 | 처치 때 NotifyAll 큰 띠 | The Knights defeated the Kaiju %s! They share a %s gold reward. | Story.KaijuDefeated | SHORT | 내 보상 줄이 따로 있음: "Kaiju %s defeated!" |
| 47 | KaijuService.luau:801 | 보상 없이 처치 | The Kaiju %s was defeated. | Story.KaijuDefeatedNoReward | SHORT | 위와 같음: "Kaiju %s defeated!" |
| **VitalsService** | | | | | | |
| 48 | VitalsService.luau:34 | MP 부족으로 스킬 실패, 2초 제한 | Not enough MP. Drink an MP potion! (MerchantEnabled=true라 이 문구) | (하드코딩, Config 없음) | SHORT | 실패는 남기고 안내 뺌: "Not enough MP." |
| 49 | VitalsService.luau:64 | 퀘스트 단계에서 가득 찬 채 물약 마시기 | Cheers! The potion stays in your bag. | Text.PotionPractice | OFF | 퀘스트 줄이 안내함 |
| 50 | VitalsService.luau:74 | 카이주로 물약 사용 | You can't use potions as a Kaiju. | (하드코딩) | KEEP | 실패 |
| 51 | VitalsService.luau:85 | 물약 없음 | No potions left. Buy some from the Potion Seller. | (하드코딩) | SHORT | 실패만: "No potions left." |
| 52 | VitalsService.luau:93 | HP 가득 차서 마시기 실패 | HP is full. | (하드코딩) | KEEP | 실패 |
| 53 | VitalsService.luau:102 | MP 가득 차서 마시기 실패 | MP is full. | (하드코딩) | KEEP | 실패 |
| 54 | VitalsService.luau:114 | 물약 마실 때마다 | Used a HP/MP potion! (`"Used a " .. kind .. " potion!"`) | (하드코딩) | OFF | 매번 반복, HP바·퀵슬롯 숫자가 보여 줌 |
| **BoardService** (dormant: Board.Enabled=false) | | | | | | |
| 55 | BoardService.luau:252 | (dormant) 일 끝낼 때 | Job done! +%s gold · +%s XP | Board.Text.Done | KEEP | 보상 |
| 56 | BoardService.luau:258 | (dormant) 일마다 | Your shard leaned to the light. / …to the dark. | Board.Text.LeanKind / LeanSneaky | OFF | 점수 줄과 겹치는 이야기 |
| 57 | BoardService.luau:260 | (dormant) 점수가 오를 때 | Honor +1 / Infamy +1 (`"%s +%d"`) | Board.Text.Score | KEEP | 보상 |
| 58 | BoardService.luau:273 | (dormant) 하루 5번째 일 | 5th job today! +%s | Board.Text.Bonus | KEEP | 아이템 보상 |
| 59 | BoardService.luau:394 | (dormant) 이미 3개 들고 수락 시도 | You carry 3 jobs. Finish one first! | Board.Text.Full | KEEP | 실패 |
| **AttendanceService** (Enabled=true, 하루 1회 수령) | | | | | | |
| 60 | AttendanceService.luau:201 | 수령이 N일 마일스톤에 닿을 때(7/14/28/50/100) | %d days collected! | Attendance.Text.Days | OFF | 아래 칭호·테두리·룩 줄이 실제 보상을 말함. 14일처럼 칭호가 없으면 이 줄이 유일한 줄이니 검수가 판단 |
| 61 | AttendanceService.luau:202 | 28일 | New name frame! | Attendance.Text.NewBorder | KEEP | 보상 |
| 62 | AttendanceService.luau:205 | 칭호 받을 때 | New title: %s! | Attendance.Text.NewTitle | KEEP | 보상 |
| 63 | AttendanceService.luau:213 | 룩 받을 때 | New look: %s! | Attendance.Text.NewLook | KEEP | 보상 |
| 64 | AttendanceService.luau:245 | 매일 수령 | Day %d reward! +N gold · +N XP · +item | Attendance.Text.Claimed | KEEP | 보상 |
| **DiaryService** (dormant: Halloween 전용) | | | | | | |
| 65 | DiaryService.luau:96 | (dormant) 킹 처치 후 쪽 열림 | King Diary: page %d! | Diary.Text.Page | KEEP | 보상 |
| 66 | DiaryService.luau:101 | (dormant) 9쪽 완료 | New title: %s! | Diary.Text.NewTitle | KEEP | 보상 |
| 67 | DiaryService.luau:141 | (dormant) 사탕 단지: 이미 가진 칭호 | You already have it! | Diary.Text.JarOwned | KEEP | 실패 |
| 68 | DiaryService.luau:149 | (dormant) 사탕 부족 | You need %d candy. | Diary.Text.JarNeed | KEEP | 실패 |
| 69 | DiaryService.luau:153 | (dormant) 사탕으로 칭호 교환 | New title: %s! | Diary.Text.NewTitle | KEEP | 보상 |
| **FinisherService** (킹 슬라임/클래터 카드 선택 때 1회) | | | | | | |
| 70 | FinisherService.luau:144 | 선택 후 1줄: `HelpDone/TickleDone` · 아이템 · 골드 · 점수를 " · "로 잇기 | It hops home happy! · +2 Jelly · Honor +1 | Finisher.Cards[kind].Text.HelpDone/TickleDone + Loot.Text.Got(N) + Story.Text.ChoiceGold + Finisher.Text.Score | SHORT | 이야기 문장 뺌: "+2 Jelly · Honor +1" |
| 71 | FinisherService.luau:148 | 반대 진영 선택으로 점수 깎임 | Hallie: Hmm… not very angel-like! Honor -%d (호르는 Magpie 줄) | StoryQuests.Text.OffSideHalo / OffSideHorns | SHORT | 잃음은 남김: "Honor -%d" |
| 72 | FinisherService.luau:151 | 반대 진영, 깎일 점수 0 | Hallie: Hmm… not very angel-like! Your shard leaned to the light. | StoryQuests.Text.OffSideHaloZero / OffSideHornsZero + LeanGood / LeanEvil | OFF | 잃는 것도 얻는 것도 없는 이야기 |
| 73 | FinisherService.luau:154 | 계급이 내려갈 때 | Your rank went down. Do good deeds to get it back! | StoryQuests.Text.RankDownHalo / RankDownHorns | SHORT | 위험은 남기고 안내 뺌: "Rank down!" |
| 74 | FinisherService.luau:156 | 내 진영 선택인데 오늘 점수 소진 | No more points today. Your shard still leans. | Finisher.Text.HintFull | OFF | 설명만 |
| **InviteService** | | | | | | |
| 75 | InviteService.luau:147 | 친구에게 가기: 친구 없음 | Your friend is not on this server. | Invite.Text.NotHere | KEEP | 실패 |
| 76 | InviteService.luau:154 | 상대 마을/멀리 있음 | Your friend is in the other side's town. / Your friend is exploring far away. Try again soon! | Invite.Text.OtherTown / Away | KEEP | 실패 |
| 77 | InviteService.luau:160 | 친구가 PvP 구역, 내 레벨 낮음 | Your friend is in a PvP zone. Come at Lv %d! | Invite.Text.SproutPvP | KEEP | 위험·실패 |
| 78 | InviteService.luau:164 | 같은 구역 | You're already there! | Invite.Text.SameZone | KEEP | 실패 |
| 79 | InviteService.luau:174 | 이동이 거절될 때(ZoneService 이유 문구) | (ZoneService.Travel의 reason 문자열) | Text.* (Zone 쪽) | KEEP | 실패 |
| **GooseService** (kind 없는 NotifyAll = 큰 띠) | | | | | | |
| 80 | GooseService.luau:514 | 이벤트 중 모드가 협동으로 확정될 때, 이벤트당 최대 1회, 큰 띠 | The Golden Goose is in the Crossroads!\nOnly Knights here: Team Rescue. Fill the gauge together! (Horns 변형) | Goose.Text.CoopStart | OFF | 시작 띠가 이미 나감(:548). 위 막대가 같은 말을 함 |
| 81 | GooseService.luau:548 | 거위 시작마다, 큰 띠 | A Golden Goose with a Crown Shard landed in the Crossroads!\nKnights rescue it… / (협동이면 CoopStart) | Story.GooseStart / Goose.Text.CoopStart | SHORT | A23-130이 정한 한 줄: "Golden Goose!" 2초 |
| 82 | GooseService.luau:587 | 보상 지급(자격 있는 사람) | Golden Goose reward! +%s gold +%s XP / Team Rescue reward! +%s gold +%s XP | Text.GooseReward / Goose.Text.CoopReward | KEEP | 골드·XP 보상 |
| 83 | GooseService.luau:592 | 희귀 보상 때 모두에게 NotifyAll, kind "info" | %s got a rare Golden Goose reward! | Text.RareAnnounce | OFF | 남 자랑·전체 방송 |
| 84 | GooseService.luau:601 | 지거나 비길 때마다 | Cheer Star +1 (%d/5): at 5, your next goose reward is rare! | Text.GooseCheer | SHORT | 설명 뺌: "Cheer Star %d/5" |
| 85 | GooseService.luau:658 | 수동 타격 3회 미만이라 보상 없음 | Only players who hit the Golden Goose themselves %d+ times get the reward! (Auto Battle hits don't count) | Goose.Text.NeedManual | SHORT | 실패는 남김: "Hit it yourself for rewards." |
| 86 | GooseService.luau:673 | 거위 끝날 때 큰 띠 | The Knights rescued the Golden Goose! The shard shines with light again. (협동·실패·상대 이탈 변형) | Story.GooseResult[…] / Goose.Text.CoopResult / CoopFail / RivalLeft | OFF | 이야기, 같은 순간 보상 줄(:587)과 겹침 |
| 87 | GooseService.luau:727 | 협동 게이지가 찰 때 큰 띠, 이벤트당 1회, kind "good" | Gauge full! Team Rescue done.\nHit it yourself %d+ times before the end for a reward! | Goose.Text.CoopFull | SHORT | "Gauge full!" |
| 88 | GooseService.luau:809 | 협동 중 상대 진영이 때릴 때, 이벤트당 1회 | This Golden Goose is the Knights' Team Rescue. From the next goose it's a tug-of-war again! | Goose.Text.RivalWait | SHORT | 못 한다는 사실만: "Not your goose this time." |
| **ProgressionService** | | | | | | |
| 89 | ProgressionService.luau:486 | 환생 때 | Rebirth done! Only your level starts over; gold, weapons and items stay. Gold and XP +%d%% forever | Text.RebirthDone | SHORT | 보상만: "Reborn! Gold, XP +%d%%" |
| 90 | ProgressionService.luau:488 | 환생 표식 Fall, kind "announce" 큰 띠 | Fall: the halo cracked and horns grew. (Gold +5%% forever · torn black cape) | Story.Fall | SHORT | 이야기 뺌: "Gold +5%% forever" |
| 91 | ProgressionService.luau:490 | 환생 표식 Redeem, 큰 띠 | Redeem: the horns broke and a cracked halo rose. (XP +5%% forever) | Story.Redeem | SHORT | "XP +5%% forever" |
| 92 | ProgressionService.luau:492 | 환생 때 NotifyAll 큰 띠 | %s was reborn! (Rebirth #%d) | Text.RebirthAnnounce | OFF | 남 소식, 큰 띠 |
| 93 | ProgressionService.luau:554 | 환생 거절 이유 | You need Lv %d to be reborn. / 별 3개 이상 / 자루 / 카이주 / 전투 / 장인 길드 막힘 문구 | Text.RebirthNeed / BlockedStars / BlockedSack / BlockedKaiju / TravelBlockedCombat / BlockedBully | KEEP | 실패 |
| **CombatService** | | | | | | |
| 94 | CombatService.luau:919 | (dormant: AutoIdleRest=false) 자리 비움 → 자동전투 쉼 / 복귀 | You seem away, so Auto Battle is resting. Move and it starts again. / Welcome back! Auto Battle is on again. | Text.AutoRestOn / AutoRestOff | OFF | 설명·환영, 꺼진 기능 |
| 95 | CombatService.luau:943 | (dormant) 쉬기 30초 전 경고 | The shard is sleepy… Take a step? (Auto Battle rests in 30 s) | Text.AutoSleepy | OFF | 설명, 꺼진 기능 |
| 96 | CombatService.luau:1567 | 불량 PvP 벌점으로 자동전투가 꺼질 때 | Unfair PvP penalty: Auto Battle is off. XP and drops are halved too. (무법자 주: Outlaw: Auto Battle is off and XP and drops are halved (until Monday).) | Text.BullyAutoOff / Ranking.Text.OutlawAutoOff | KEEP | 위험(벌) |
| 97 | CombatService.luau:1570 | 벌점이 끝날 때 | Your bully penalty is over! Auto Battle, XP and drops are back. | Text.BullyPenaltyEnd / BullyPenaltyEndNoAuto | SHORT | 보상 회복 말만: "Bully penalty over!" |
| 98 | CombatService.luau:1714 | 벌점 중 자동전투 켜기 시도 | No Auto Battle during a bully penalty. It comes back when your bully levels are gone. | Text.BullyNoAuto / Ranking.Text.OutlawNoAuto | KEEP | 실패(문구는 줄일 수 있음) |
| **PetService** | | | | | | |
| 99 | PetService.luau:144 (`notifyLater`, 호출 :200) | 새 펫을 얻을 때 0.5초 뒤, 1회 | A Baby Slime became your pet! Now your pet fights for you. / A Baby Slime joined you! It hops along behind you. | Tamer.Text.PetGot / PetGrant.Text.Got | SHORT | 설명 뺌: "Baby Slime pet!" |
| 100 | PetService.luau:319 | 길드 사냥꾼이 테이머가 된 옛 저장, 평생 1회 | The hunter is now the Pet Tamer!\nWant another class? Use the free Class Change Ticket you got. (BecameFree 변형) | Tamer.Text.Became / BecameFree | SHORT | 받은 것만: "+1 Class Change Ticket" |
| **WarService** | | | | | | |
| 101 | WarService.luau:366 | 전쟁 라운드 끝(600초마다), 포인트 충족자 | War chest! +%s gold | Text.WarChest | KEEP | 골드 보상 |
| 102 | WarService.luau:399 | 라운드 끝 승자 있을 때 NotifyAll 큰 띠(소리 CrownHalo/Horns) | The Knights of Light won the crown this round! The sky glows gold.\n(Gold and XP +25%% for 10 minutes) | Story.WarWin[Halo/Horns] | SHORT | 이야기 뺌: "Light wins! Gold, XP +25%%" |
| 103 | WarService.luau:401 | 무승부 큰 띠 | Nobody won the crown this round! | Story.WarDraw | OFF | 아무 일도 없었다는 말 |
| **ChoiceCard** | | | | | | |
| 104 | ChoiceCard.luau:194 | 선택 카드 고를 때(예: 꽃 카드) | Kind choice! · +item · +N gold · +N XP · Honor +1 | ChoiceCard.Text.GoodDone / EvilDone + Loot.Text.Got + Story.ChoiceGold + ChoiceCard.Text.XP + ChoiceCard.Text.Score (`o.Done`이 있으면 그 문장) | SHORT | 라벨·이야기 뺌: "+reward · Honor +1" |
| **LostFoundService** (dormant: LostFound.Enabled=false) | | | | | | |
| 105 | LostFoundService.luau:291 | (dormant) 분실물 전달 | Thank you for the %s! Here is a little gift. · +2 HP · +2 MP · scroll | LostFound.Text.GoodDone / FeeDone / TrophyDone | SHORT | NPC 감사 문장 뺌(A23-130 같은 취지): "Reward items only" |
| **MonetizationService** | | | | | | |
| 106 | MonetizationService.luau:57 (호출 :72) | 변경권 구매 후 저장 성공 | You got 1 Class Change Ticket! / …Side Change Ticket! | Text.ClassTicketGot / FactionTicketGot | KEEP | 구매 보상 확인 |
| **DataService** | | | | | | |
| 107 | DataService.luau:421 | 저장 불러오기 재시도 때 1회 | Loading your save… | Text.SaveLoading | KEEP | 기다림·위험 알림(드묾) |
| **JusticeService** | | | | | | |
| 108 | JusticeService.luau:493 | 불량 단계가 5분마다 1칸 내려갈 때 | Your bully level went down (level %d) | Text.BullyDecay | OFF | 주기 반복, 캐릭터 크기·HUD로 보임 |
| **AnnounceService** | | | | | | |
| 109 | AnnounceService.luau:155 | 설정에서 이름 숨김을 바꿀 때 | Announcements and rankings now show your side's name instead of your name. / …show your name. | Announce.Text.NameHidden / NameShown | OFF | 방금 누른 것을 되말함 |
| **FieldBossService** | | | | | | |
| 110 | FieldBossService.luau:276 | 주간 보스 보장 아이템 | +%s / +%s ×%d | Loot.Text.Got / GotN | KEEP | 아이템 보상 |
| **RankingService** | | | | | | |
| 111 | RankingService.luau:479 | 강화 성공 시 장인 명성 | +%d Artisan Fame | Ranking.Text.ArtisanGain | KEEP | 보상 |
| 112 | RankingService.luau:820 | 무법자 주 끝, 1회 | Your outlaw week is over! Auto Battle is back. / …XP and drops are back to normal. | Ranking.Text.OutlawEnd / OutlawEndNoAuto | SHORT | "Outlaw week over!" |
| 113 | RankingService.luau:850 | 지난주 불량 PvP 순위자, 주 1회, 8초 | Last week's Unfair PvP #%d: you are an outlaw this week!\nNo Auto Battle, half XP and drops, double bounty (until Monday). | Ranking.Text.OutlawStart | KEEP | 위험(벌) |
| 114 | RankingService.luau:867 | 지난주 상위 3위, 주 1회, 8초 | Last week's %s #%d! XP and drops +10%% and a title this week (until Monday). / …only while in the %s | Ranking.Text.RewardStart / RewardStartOff | SHORT | 보상은 남김: "Last week #%d! XP, drops +10%%" |
| **Deeds.luau** (`say`:153 → `Net.Notify`; `Deeds.Say`가 Board/ChoiceCard/Finisher에서도 불림) | | | | | | |
| 115 | Deeds.luau:160 | 반대 진영 선택으로 점수 깎임 | Hallie: Hmm… not very angel-like! Honor -%d (호르는 Magpie 줄) | StoryQuests.Text.OffSideHalo / OffSideHorns | SHORT | "Honor -%d" |
| 116 | Deeds.luau:162 | 반대 진영 선택, 깎일 점수 0 | Hallie: Hmm… not very angel-like! Your shard leaned to the light. | StoryQuests.Text.OffSideHaloZero / OffSideHornsZero + LeanGood / LeanEvil | OFF | 이야기 |
| 117 | Deeds.luau:164 | 계급이 내려갈 때 | Your rank went down. Do good deeds to get it back! | StoryQuests.Text.RankDownHalo / RankDownHorns | SHORT | "Rank down!" |
| 118 | Deeds.luau:166 | 내 진영 선택인데 오늘 점수 소진 | Your shard is full for today. Come back tomorrow! | Deeds.Text.Full | OFF | 설명 |

#### 2. OFF 목록

- GrudgeService.luau:389 · Text.GrudgeAvengedAll
- GrudgeService.luau:546 · Text.GhostHoldOk
- ShopService.luau:343 · Text.PotionBought
- KaijuService.luau:456 · Story.KaijuSurvived
- VitalsService.luau:64 · Text.PotionPractice
- VitalsService.luau:114 · (하드코딩 "Used a … potion!" → Config 키 새로 만들거나 호출 삭제)
- BoardService.luau:258 (dormant) · Board.Text.LeanKind / LeanSneaky
- AttendanceService.luau:201 · Attendance.Text.Days
- FinisherService.luau:151 · StoryQuests.Text.OffSideHaloZero / OffSideHornsZero + LeanGood / LeanEvil
- FinisherService.luau:156 · Finisher.Text.HintFull
- GooseService.luau:514 · Goose.Text.CoopStart
- GooseService.luau:592 · Text.RareAnnounce
- GooseService.luau:673 · Story.GooseResult / Goose.Text.CoopResult / CoopFail / RivalLeft
- ProgressionService.luau:492 · Text.RebirthAnnounce
- CombatService.luau:919 (dormant) · Text.AutoRestOn / AutoRestOff
- CombatService.luau:943 (dormant) · Text.AutoSleepy
- WarService.luau:401 · Story.WarDraw
- JusticeService.luau:493 · Text.BullyDecay
- AnnounceService.luau:155 · Announce.Text.NameHidden / NameShown
- Deeds.luau:162 · StoryQuests.Text.OffSide*Zero + Lean*
- Deeds.luau:166 · Deeds.Text.Full

#### 3. SHORT 목록 (새 문구는 영어 6단어 이하)

- GrudgeService.luau:309 · Text.GrudgeMail → "Stolen gold back: +%s"
- GrudgeService.luau:348 · Text.GrudgeReturned → "Stolen gold back: +%s"
- GrudgeService.luau:369 · Text.GrudgeRefund → "Stolen gold back: +%s"
- GrudgeService.luau:547 · Text.GhostHeld → "Ghost holds you!"
- ClassService.luau:159 · Text.ClassChangedFreeKeep → "Class: %s (level kept)"
- ShopService.luau:34 · Text.WeaponShopFar → "Too far from the shop."
- ShopService.luau:66 · Text.WeaponFromQuest → "Not sold. Quest reward."
- ShopService.luau:123 · Text.WeaponSellFar → "Too far from the shop."
- ShopService.luau:322 · Text.PotionShopFar → "Too far from the shop."
- CommissionService.luau:90 (dormant) · Text.WeaponShopFar → "Too far from the shop."
- KaijuService.luau:421 · Story.KaijuStart → "Kaiju %s is here!"
- KaijuService.luau:455 · Text.KaijuSurviveReward, KaijuService.luau:33-34 (두 문구) → "Survived! +%s gold"
- KaijuService.luau:559 · Text.KaijuQueued → "You're queued as Kaiju."
- KaijuService.luau:798 · Story.KaijuDefeated → "Kaiju %s defeated!"
- KaijuService.luau:801 · Story.KaijuDefeatedNoReward → "Kaiju %s defeated!"
- VitalsService.luau:34 · (하드코딩) → "Not enough MP."
- VitalsService.luau:85 · (하드코딩) → "No potions left."
- FinisherService.luau:144 · Cards[kind].Text.HelpDone / TickleDone 줄 빼기 → "+2 Jelly · Honor +1"
- FinisherService.luau:148 · StoryQuests.Text.OffSideHalo / OffSideHorns → "Honor -%d"
- FinisherService.luau:154 · StoryQuests.Text.RankDownHalo / RankDownHorns → "Rank down!"
- GooseService.luau:548 · Story.GooseStart / Goose.Text.CoopStart → "Golden Goose!" (2초 1회, A23-130)
- GooseService.luau:601 · Text.GooseCheer → "Cheer Star %d/5"
- GooseService.luau:658 · Goose.Text.NeedManual → "Hit it yourself for rewards."
- GooseService.luau:727 · Goose.Text.CoopFull → "Gauge full!"
- GooseService.luau:809 · Goose.Text.RivalWait → "Not your goose this time."
- ProgressionService.luau:486 · Text.RebirthDone → "Reborn! Gold, XP +%d%%"
- ProgressionService.luau:488 · Story.Fall → "Gold +5%% forever"
- ProgressionService.luau:490 · Story.Redeem → "XP +5%% forever"
- CombatService.luau:1570 · Text.BullyPenaltyEnd / BullyPenaltyEndNoAuto → "Bully penalty over!"
- PetService.luau:144 · Tamer.Text.PetGot / PetGrant.Text.Got → "Baby Slime pet!"
- PetService.luau:319 · Tamer.Text.Became / BecameFree → "+1 Class Change Ticket"
- WarService.luau:399 · Story.WarWin → "Light wins! Gold, XP +25%%" (호르는 "Horns win! …")
- ChoiceCard.luau:194 · ChoiceCard.Text.GoodDone / EvilDone + `o.Done` 빼기 → "+reward · Honor +1"
- LostFoundService.luau:291 (dormant) · LostFound.Text.GoodDone / FeeDone / TrophyDone 빼기 → "Reward items only"
- RankingService.luau:820 · Ranking.Text.OutlawEnd / OutlawEndNoAuto → "Outlaw week over!"
- RankingService.luau:867 · Ranking.Text.RewardStart / RewardStartOff → "Last week #%d! XP, drops +10%%"
- Deeds.luau:160 · StoryQuests.Text.OffSideHalo / OffSideHorns → "Honor -%d"
- Deeds.luau:164 · StoryQuests.Text.RankDownHalo / RankDownHorns → "Rank down!"

#### 4. 개수

- 표 행: **118**. 처음 안내가 "약 114"였는데, 한 줄이 여러 문구를 내는 호출까지 따로 세어 더 많습니다.
- KEEP **59** / OFF **21** / SHORT **38**.
- 현재 꺼진 기능에 속한 행(dormant)은 행 34-40, 55-59, 65-69, 94-95, 105로 총 21행입니다. 이 중 SHORT 3행, OFF 3행이고 나머지는 KEEP입니다.

#### 5. 판단이 갈릴 수 있는 곳 (검수 확인)

- 행 27(`ShopService.luau:112`): 새 무기 구매는 보상이라 KEEP으로 두었습니다. 이미 가진 무기를 다시 장착할 때 나오는 "equipped!"(info)는 반복이라 따로 끌 수 있습니다.
- 행 60(`AttendanceService.luau:201`): 14일처럼 칭호·테두리가 없는 마일스톤에서는 이 줄이 유일한 줄입니다. OFF로 하면 그 날 알림이 없습니다.
- 행 98과 행 96(`CombatService.luau:1567`, `:1714`): 위험·실패라 KEEP이지만 문구가 깁니다. 짧게 줄이는 것도 가능합니다.
- 행 70, 71, 73, 104, 115, 117은 한 선택에 한 화면에 줄이 2~3개 연달아 나갑니다. SHORT로 줄여도 겹침이 남을 수 있으니, 점수 줄 하나로 합치는 편이 더 낫습니다.

