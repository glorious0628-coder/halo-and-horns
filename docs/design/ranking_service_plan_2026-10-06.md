# RankingService 설계 메모 (게임성 개발 2, 2026-10-06)

근거: SPEC A23-22·A23-23·A23-24, `beta_basics_2026-10-05.md` BB10(2026-10-06 변경 메모 3개: 판 4개, 보상·벌칙 계산 확정 235f1ee, 장인 명성), BB37, BB12, BB11. 줄 번호는 main 1614575 기준.
작업 곳: worktree `Game-dev2`(dev2 브랜치). Studio는 만지지 않고 오프라인 러너로만 검사한다.

## 0. 순서
1. BB37 `AnnounceService.PublicName` → 2. BB12 Tab 열 → 3. BB10 RankingService(점수·저장·읽기) → 4. 주간 정산 + 무법자 + 1~3위 보상 → 5. BB14 서버 → 펫 서버.
1~3을 10/12까지 오프라인 통과, 4를 10/12~14, 병합은 덩어리마다 게임성 개발 [8afa46]에게 보낸다.

## 1. 저장 데이터 (DataService.Defaults 추가, Version 3 유지)
```
Rank = { WeekId = 0, Honor = 0, Infamy = 0, Artisan = 0, PvP = 0,   -- 이번 주 판 점수(주간 필드)
         Victims = {},        -- ['U'..victimUserId] = 이번 주 공정 점수를 준 횟수 1..99 (최대 100개, 주간)
         HandScroll = {},     -- [Enh70|Enh30|Enh10] = 직접 사냥으로 얻은 장인 표 수 (주간)
         YieldDay = 0, YieldN = 0, -- 내가 남에게 공정 점수를 준 횟수(오늘, Config.DayIndex)
         HideSynced = false }
RankReward = { WeekId = 0, Board = "", Rank = 0 }   -- A23-22/24 1~3위 보상이 켜지는 주
Outlaw = { WeekId = 0 }                              -- A23-23 무법자가 되는 주
DebugTainted = false                                 -- DebugCommand를 한 번이라도 쓴 저장
```
- `fillDefaults`(DataService.luau:127)가 Rank를 정리한다: Victims 키는 `^U%-?%d+$`, 값은 1..99 정수, 100개 넘으면 잘라냄. HandScroll은 세 id만 0..ItemCap 정수. `Rank.WeekId ~= Config.WeekIndex(os.time())`이면 주간 필드(Honor·Infamy·Artisan·PvP·Victims·HandScroll)를 0/{}로. `YieldDay ~= DayIndex`이면 YieldN=0. RankReward·Outlaw는 모양만 고친다(기간 판정은 WeekId로).
- 시즌 필드(BestPower·BestGrowth)는 만들지 않는다(A23-23).

## 2. Config (파일 끝 한 블록, 다른 부분은 고치지 않음)
```
Config.WeekIndex(t) = floor((t + Daily.TimezoneOffset + 3*86400) / 604800)   -- 월 00:00 KST에 바뀜, 10/05 = 2962
Config.WeekStart(w) = w*604800 - 3*86400 - TimezoneOffset                     -- 그 주 월 00:00 KST의 os.time
Config.Ranking = {
  Season = "PRE", SeasonHistory = { "PRE" },        -- 베타 날 B1로(LAUNCH-OPS)
  Order = { "Honor", "Infamy", "Artisan", "PvP" },
  Boards = { Honor = { Faction = "Halo", Stat = "Honor" }, Infamy = { Faction = "Horns", Stat = "Infamy" },
             Artisan = { Faction = "Neutral" }, PvP = { Penalty = true } },
  WeekCap = { Honor = 150, Infamy = 150, Artisan = 60 },
  TopN = 50, RefreshSeconds = 180, WriteEverySeconds = 120, LoopSeconds = 10, MinBudget = 5, MinReadBudget = 2,
  MinAccountDays = 3, MinPlaySeconds = 1800,
  VictimActiveSeconds = 60, PvPMinVictimAccountDays = 7, PvPMinVictimPlaytime = 10800,
  MaxCreditPerVictimPerWeek = 3, MaxYieldPerVictimPerDay = 5, MaxVictimKeys = 100,
  HandActiveSeconds = 60, HandScrollIds = { "Enh70", "Enh30", "Enh10" },
  RewardTop = 3, RewardMult = 1.10, SettleDelaySeconds = 600, SettleRetrySeconds = 60,
  ExcludeUserIds = {}, NameCacheSeconds = 3600, StudioNames = "Player%d",
  Text = { ... },                                    -- KO/EN 쌍. 무법자 칩·자동 꺼짐·정산 알림·빈 판·탭 안내 2줄·장인 명성 +N
}
Config.TitleDefs.RankHonor1..3 / RankInfamy1..3 / RankArtisan1..3 (Timed = true, 능력치 없음) + TitleOrder 뒤에 추가
Config.RateLimits.RequestRankings = 1
Config.Leaderstats = { Columns = { "Power", "Level", "Rebirths", "Fame" }, Names = { 전투력·레벨·환생·명성 } }
```
- 실제 시즌 = `RunService:IsStudio() or DataService.IsMemoryMode()`이면 "STUDIO", 아니면 Config.Ranking.Season.

## 3. RankingService 함수 (새 서버 모듈, INIT은 AnnounceService 뒤, START는 PlayerService 앞)
| 함수 | 하는 일 |
|---|---|
| `EffectiveSeason()` | "STUDIO" / Season |
| `Credit(player, board, n, why)` | 판 점수 +n. 0 처리: PrivateServerId ~= "", 판 진영 ≠ 현재 진영, WeekCap 도달(Util.Warn 조절), n ≤ 0. 통과하면 data.Rank[board] += n, 속성 `Week<board>` 갱신, dirty 표시 |
| `CreditFame(player, stat, n, ctx)` | PlayerService.GrantFame가 부름. ctx.RankPoints가 있으면 그 값만, ctx.PvP면 ctx.Fair일 때만, 그 밖(이야기·거위 첫 1회)은 n 그대로 Credit |
| `JudgeKO(killer, victim, facts)` | PvP KO 판정(§4). `{ Fair = bool, Unfair = reason?, Exempt = reason? }`. Unfair면 그 자리에서 `Credit(killer,'PvP',1)` |
| `CommitFair(killer, victim)` | 공정 점수를 실제로 줄 때만 카운터 증가: killer.Victims['U'..id] += 1, victim.YieldN += 1 |
| `PvPCreditOK(killer, victim, facts)` | BB10 6조건(+막 부활·반복 KO) 검사만, 거절 이유 반환. Stats.Refused[reason] += 1 |
| `MarkHideChanged(player)` | 숨기기 바뀜 → 그 플레이어의 모든 판 줄을 120초 간격 무시하고 다시 쓰기, 성공하면 HideSynced |
| `RequestRankings` 처리 | §7 원격 |
| `Settle(weekId)` / `DebugSettle()` | §6. DebugCommand 'RankSettle'(STUDIO 시즌만) |
| `RefreshEffects(player)` | 속성 `Outlaw`(bool), `RankReward`(판 id 또는 ""), `RankRewardRank`(0..3)을 지금 주·지금 진영으로 다시 계산 |
| `Stats` | { Reads, Writes, Skipped, Refused = { [reason] = n }, Settles } |

다른 서비스 연결: PlayerReady(정리·효과·숨기기 동기화), PlayerLeaving(즉시 쓰기), FactionService.FactionChanged(옛 판 RemoveAsync + 옛 주간 칸 0, Artisan 기록·HandScroll 지움), LootService.ItemsGranted(장인 표), LootService.Enhanced(장인 점수), 10초 루프(주 바뀜·쓰기), 판별 읽기 루프, 정산 루프.

## 4. 점수가 들어오는 곳 (명성 7곳 + PvP 판 + 장인)
`PlayerService.GrantFame(player, stat, n, ctx)` = `AddStat` + `pcall(RankingService.CreditFame, …)`. 명예·악명 AddStat 7곳을 모두 바꾼다(검사: src에서 `AddStat(…"Honor"|"Infamy"…)`이 GrantFame 안 1곳만).

| 곳 | 지금 | 바꾼 뒤 |
|---|---|---|
| PvPService.luau:613 (뿔, 자루 없는 KO 악명) | AddStat | GrantFame(ctx PvP, Fair=판정) + Fair면 CommitFair |
| PvPService.luau:633 (빛, 깨끗한 뿔 KO 명예) | AddStat | 같음 |
| PvPService.luau:649 (빛, 수배범 KO 명예) | AddStat | 같음 |
| PvPService.luau:856 payLeaveBounty | AddStat | 떠나는 사람을 victim으로 JudgeKO(데이터가 풀리기 전) → GrantFame |
| PvPService.luau:602 → GrudgeService.AddToSack:407 | infamy만 | 5번째 인자 rankPts = Fair면 ScalePoints(1, bold) → sack.RankInfamy, Fair면 CommitFair |
| GrudgeService.luau:322 pay | AddStat(sack.Infamy) | GrantFame(thief,'Infamy',sack.Infamy,{RankPoints = sack.RankInfamy}). 되찾기·돌려주기는 0 |
| StoryQuestService.luau:489 (선택 Good/Evil, 왕관 조각 포함) | AddStat | GrantFame(ctx Kind='Story') — 진영이 안 맞는 점수(빛의 악명)는 판에 안 감 |
| StoryQuestService.luau:528 (거위 첫 참여) | AddStat | GrantFame(ctx Kind='Goose') |

**PvP KO 판정 (PvPService.HandleKO:504, 보상 분기 전 한 번):**
- facts: Bold = BoldMult(k,v), Fresh(막 부활), Repeated(10분 3번), Defense(미끼: victim이 먼저 때림), Revenge(킬러의 복수 표식이 victim, 90초), VictimWanted(별 ≥1), VictimBully(깡패 ≥1), VictimOutlaw, VictimKaiju, KillerKaiju, VictimHadSack(원한 자루 든 도둑 — CombatService.runDeathPipeline:1087에서 OnCarrierDown 전에 잡아 `HandleKO(victim, killer, ctx)`로 넘김).
- 친구(pcall `killer:IsFriendsWith`, 실패는 친구로, 쌍별 세션 캐시) → 어느 판에도 안 감.
- 면제(Revenge·VictimWanted·VictimBully·VictimOutlaw·VictimKaiju·KillerKaiju·VictimHadSack·Defense) → PvP 판에 안 감. 공정 검사는 그대로(현상수배범을 공정하게 잡으면 명예 판에 감).
- 공정 검사(BB10): Bold ≥ 1 / victim 직접 활동 60초 안 / 친구 아님 / victim 계정 7일·플레이 3시간 이상(STUDIO 시즌 생략) / 이번 주 같은 상대 3번 미만 / victim 오늘 YieldN < 5 / Fresh·Repeated 아님. 모두 통과 = Fair.
- 공정 아님 + 면제 아님 + 이유가 '공정성'(Weak·Idle·Newbie·Repeat·Fresh) → Unfair → `Credit(killer,'PvP',1)`. YieldCap만 걸린 것은 어느 판에도 안 감.
- 명예·악명 수치·골드·별·자루는 지금 그대로. 바뀌는 것은 판 점수뿐.
- **직접 활동 시계:** 지금 CombatService.luau:510이 플레이어에게 맞은 victim을 MarkActive한다. 그래서 자리 비운 사람도 맞는 순간 '활동'이 된다. `MarkActive(victim, "Hit")`로 바꾸고 PlayerService에 `GetLastOwnActive`(Hit 제외)를 둔다. 자동 전투는 이미 MarkActive를 안 한다.

**장인 명성(A23-24):**
- 표 붙이기: `LootService.ItemsGranted`(RollKill에서만 발생, 첫 왕 슬라임 보장 포함) 신호에서, 진영 Neutral + 직접 활동 60초 안이면 Enh70/30/10 개수만큼 HandScroll += n. LootService giveItem은 고치지 않는다.
- 쓰기: `LootService.Enhanced:Fire(player, tier, before, after, success, id)`로 6번째 인자 id만 추가(LootService.luau:361). 표가 있으면(아이템 수+1로 먼저 자름) 1개 쓰고, 성공이면 `Credit(player,'Artisan', after - before)`(+10에서 잘린 몫은 이미 빠짐). 실패·하락 0점. 옮기기 주문서는 Enhanced를 안 쏘므로 0점.
- 주가 바뀌거나 진영을 바꾸면 Artisan·HandScroll이 지워진다.

## 5. 저장소·쓰기·읽기 (OrderedDataStore)
- 판 저장소: `HH_Rank_<시즌>_<판>_W<WeekId>`, 키 `U_<userId>`, 값 = 점수×100 + 숨김×10 + 진영 코드(0 없음, 1 빛, 2 뿔, 3 장인). STUDIO 시즌은 HH_Rank_STUDIO_*에만 쓴다.
- 쓰기: dirty 표. 10초 루프가 마지막 쓰기 120초 지난 플레이어만 SetAsync. 바로 쓰기: 진영 바꿈(옛 판 RemoveAsync), 떠날 때, 주가 바뀔 때(지난 주 값을 지난 주 저장소에). 건너뛰기: SetIncrementSortedAsync 예산 < 5, 값 그대로, 자격 없음(계정 3일·플레이 30분 미만, STUDIO 시즌 생략), DebugTainted(STUDIO 밖), ExcludeUserIds. BindToClose는 플레이어 저장이 먼저, 판 쓰기는 남은 예산으로만.
- 읽기: 판마다 180초(45초씩 엇갈림) `GetSortedAsync(false, 50)`, GetSortedAsync 예산 ≥ 2일 때만. 서버에 캐시, 클라이언트는 캐시만 받는다. 이름은 `UserService:GetUserInfosByUserIdsAsync`(묶음, pcall, 1시간 캐시, 실패 '플레이어'), UserId ≤ 0은 StudioNames. 숨김 줄은 '<진영> 한 명' + UserId 0. 이 서버에 있는 사람은 지금 HideAnnounceName 속성으로 다시 가린다.
- [이 서버] 범위: GetReadyPlayers + data.Rank 주간 값 + PublicName으로 그때 계산.

## 6. 주간 정산 하나로 (A23-22·23·24)
```
정산 루프(60초): cur = WeekIndex(now), prev = cur-1
  이미 settled[prev] 있음 → 끝.  now < WeekStart(cur) + 600 → 기다림(모든 서버가 지난 주 값을 쓸 시간)
  doc = DataStore("HH_RankSettle_<시즌>"):GetAsync("W"..prev)
  없으면: 판 4개 지난 주 저장소 GetSortedAsync(false, 3), 점수 > 0만 → { Honor = {uid,uid,uid}, Infamy, Artisan, PvP }
          UpdateAsync("W"..prev, function(old) return old or new end)  -- 먼저 쓴 서버 것이 이김, 모두 같은 목록
          읽기 실패면 이 서버 판으로 대신하지 않고 SettleRetrySeconds 뒤 다시(서버마다 다른 목록이 생기는 것 방지)
  settled[prev] = doc → 접속 중인 모두에게 Apply, 이후 PlayerReady에서도 Apply
Apply(player): 내 UserId가 PvP 목록 r위 → data.Outlaw = { WeekId = cur } (+ 알림 1번)
               Honor/Infamy/Artisan r위 → data.RankReward = { WeekId = cur, Board, Rank = r } (여러 판이면 가장 높은 순위)
                                         + TitleService.Grant('Rank'..Board..r)
               WeekId가 이미 cur이면 아무것도 안 함(두 번 적용 0)
RefreshEffects: Outlaw 속성 = data.Outlaw.WeekId == cur
                RankReward 속성 = data.RankReward.WeekId == cur 이고 현재 진영 == 판 진영이면 판 id, 아니면 ""
                지난 주 Rank* 칭호는 TitleService.Revoke(TitleSel이 그것이면 "")
```
- 정산 문서 키에 시즌을 넣어 STUDIO가 PRE·B1 문서를 건드리지 않게 한다(계약 `HH_RankSettle_<WeekId>`에서 시즌만 덧붙임).
- DebugCommand 'RankSettle': STUDIO 시즌에서만, 지금 주 판으로 바로 정산·적용(시험용).

## 7. 무법자·보상이 걸리는 곳 (곱셈은 235f1ee 확정대로)
| 효과 | 곳 | 바꿀 것 |
|---|---|---|
| 자동 전투 금지 | CombatService.luau:629 bullyNoAuto | `BullyStacks ≥ 1 or Outlaw` |
| 자동 켜져 있으면 끄고 이유 | CombatService.luau:1149 onPlayerReady | `Outlaw` 속성 변화도 지켜봄 → SetStat AutoCombatEnabled false + Ranking.Text.OutlawAutoOff |
| 경험치 | ProgressionService.luau:140 GetXPMult | 벌칙 = 깡패 or 무법자 → ×0.5 한 번, 보상 = RankReward ~= "" → ×1.10 |
| 드랍 줄 | LootService.luau:302 RollKill | info.DropMult = 벌칙 0.5, info.RowBonus = 보상 1.10 |
| 줄 확률·대박 | LootService.luau:202 rollRows | 줄 = min(1, P × 황금 × DropMult × RowBonus), 대박 = min(1, Chance × 황금 × DropMult)(보상 안 곱함), 첫 주문서 보장 그대로 |
| 현상금 ×2 | PvPService.luau:187 bountyBullyStacks | 무법자를 깡패 1단계처럼 현상금 단위 1로(빛 무법자도 현상금이 생김), BountyMult ×2는 한 번만, 같은 수령 쿨다운 |
| 머리 위 '무법자' | CharacterVisuals.luau:264 updateNametag (+:59 REBUILD 표에 Outlaw) | 2번째 줄 끝에 빨간 `<font color>` '무법자'(RichText 이미 켜짐), 이름 숨기기와 무관 |
| HUD 칩 | 클라이언트(게임성 개발 BB11) | `Outlaw` 속성 → Ranking.Text.OutlawChip, `RankReward` 속성 → RewardChip |

## 8. BB37·BB12 닿는 곳
- BB37: `AnnounceService.PublicName(player, honorific)` → 보임: 닉네임(honorific이면 "님" 붙임), 숨김: '빛의 기사단 한 명'. 받침이 같아 "%s이"로 이어진다. 바꿀 곳: PvPService.luau:290 MostWanted, :662·:859 BountyAnnounce, :689·:694 게시판, GrudgeService.luau:375, ProgressionService.luau:414, GooseService.luau:574, KaijuService.luau:372(괴수 이름 → GameState·알림). Config.Text 다섯 줄 "%s님이"/"%s이(가)" → "%s이"(작게, 게임성 개발에게 알림). 설정 문구 '알림·랭킹에 내 이름 숨기기' + 안내 2줄은 Config.Announce.Text에 추가. onSetName(:124) → `RankingService.MarkHideChanged`.
- BB12: PlayerService.luau:278 buildLeaderstats를 Config.Leaderstats.Columns로 만들고(만든 순서 = 열 순서), 전투력 = CombatPower 속성, 명성 = 빛 Honor / 뿔 Infamy / 장인 `WeekArtisan` 속성(이번 주 장인 명성). LEADERSTAT_KEYS(:46)에 CombatPower·WeekArtisan 추가. 골드 열 없음.

## 9. 게임성 개발에게 줄 클라이언트 계약 (BB11 랭킹 창·게시판·HUD 칩)
- c→s `RequestRankings`(board ∈ Order, scope ∈ "Server" | "Global"): 인자 정확히 2개, IsReady, RateLimits.RequestRankings 1초. 캐시만 읽으므로 눌러도 DataStore 읽기는 늘지 않는다.
- s→c `Rankings` { Board, Scope, Rows = { { Rank, UserId(숨김 0), Name, Sub(같은 서버면 게임 닉네임), Faction, Value, Test? } ×≤50 }, Me = { Rank | nil, Value, Note? = "Ineligible" | "Private" | "Hidden" }, UpdatedAt(Util.Now), WeekId, WeekEndsAt }.
- 플레이어 속성(서버만 씀): `Outlaw`, `RankReward`, `RankRewardRank`, `WeekHonor`, `WeekInfamy`, `WeekArtisan`, `WeekPvP`.
- GameState: `RankWeekId`, `RankWeekEndsAt`(Net.GameStateDefaults 끝에).
- 문구: Config.Ranking.Text — OutlawChip "무법자: 자동 전투 불가 · 경험치·드랍 절반 (월요일까지)", RewardChip, PvPTabNote, RewardTabNote, Empty '아직 기록이 없어요', ArtisanGain '+%d 장인 명성'.
- 게시판(PvPService.updateBoard)은 서버 쪽이라 내가 한다: 명예 TOP3 · 악명 TOP3 · 무법자 TOP3, PublicName, 문구는 Config.Ranking.Text.Board로. 게시판 E → OpenPanel 'Ranking'은 MapBuilder 프롬프트가 필요해 게임성 개발과 정한다.

## 10. 오프라인 검사 (tools/test_ranking.py + tools/fixtures/ranking_offline.luau, 증거는 새 이름)
가짜 DataStoreService(정렬 저장소·예산·실패 주입), 가짜 Players·UserService·IsFriendsWith, os.time/os.clock 대역. 실제 소스(Config·Util·DataService·RankingService·AnnounceService + PvPService·GrudgeService·LootService·ProgressionService·PlayerService 일부 추출)를 돌린다.
1. WeekIndex: 일 23:59:59 KST = 2961, 월 00:00 KST(10/05) = 2962.
2. 약한 상대(Bold<1) KO → PvP +1, 주간 명예 0, 명예 수치는 ×0.5 그대로.
3. 공정 KO → 주간 명예/악명 +n, PvP 0. 친구 KO → 둘 다 0(친구 확인 실패도 친구).
4. 같은 상대 4번째(주) → PvP +1, 주간 0. 자리 비운 상대(맞기만 한 60초) → PvP. 새내기 → PvP(STUDIO 시즌은 생략). 막 부활 → PvP.
5. 면제: 복수·수배범·깡패·무법자·괴수·자루 도둑·미끼 방어 → PvP 0.
6. victim YieldN 5 → 주간 0, PvP 0.
7. 자루: Paid만 RankInfamy 반영, Avenged·Returned 0, sack.Infamy(수치)는 그대로. payLeaveBounty는 떠나는 사람을 victim으로.
8. 이야기·거위 첫 점수 반영, 진영 안 맞는 점수 0, WeekCap·PrivateServerId 0.
9. 장인: 표 있는 Enh30 +2 성공 → 3, 표 없음(자리 비움·빛 때 얻음) 0, 실패 0, +9에서 Enh10 → 1, 옮기기 0, 지난 주 표 0.
10. 쓰기: STUDIO는 HH_Rank_STUDIO_*만, 예산·값 그대로·자격·Tainted 건너뛰기, 진영 바꿈 RemoveAsync, 떠날 때 쓰기, 값 인코딩.
11. 숨기기: MarkHideChanged가 모든 줄을 숨김 값으로 다시 쓰고 HideSynced, 읽은 줄 가리기.
12. Victims JSONEncode 왕복, 100개·1..99 정리, 주 바뀌면 리셋.
13. 정산: 서버 2개가 같은 문서(먼저 쓴 것), 한 번만 적용, 읽기 실패 시 다시 시도, 정산 뒤 접속자도 받음, 다음 주에 꺼짐(속성·칭호).
14. 효과: 경험치 ×1.1 / ×0.5 / ×0.55, 깡패+무법자 ×0.5 한 번, 줄 ×1.1(1로 자름), 대박은 ×1.1 없음·벌칙 ×0.5, 첫 주문서 그대로, 진영이 다르면 보상 꺼짐, 현상금 최대 ×2, 자동 꺼짐+이유, 이름표 무법자(숨기기 켜도).
15. DebugCommand RankSettle은 STUDIO 시즌만, DebugTainted 표시. BB37: `NotifyAll.*PlayerDisplayName` grep 0건, 숨김 이름.
변이 검사(소스 복사본만 바꿈)로 각 규칙이 실제로 잡히는지 센다. 변이 검사를 끈 보고서는 커밋하지 않는다.

## 11. 다른 세션 파일에 닿는 것 (고치기 전에 한 줄 알림)
- 게임성 개발: Config.Text 다섯 줄(BB37 "%s이"), Config.Announce.Text 3줄 추가, LootService RollKill·rollRows·Enhanced 인자(SellItem 쪽은 안 건드림), StoryQuestService 2줄, GooseService·KaijuService·ProgressionService 각 1~2줄, TitleService(Revoke·기간 칭호), CharacterVisuals 이름표 1곳.
- 내 파일(10/07부터): PvPService, PlayerService, DataService, CombatService, JusticeService, Main 목록, 새 RankingService.

## 12-A. 검수 결정 2026-10-06 (아래 12의 제안을 대체)
- **D1 뺀다.** 주간 명예·악명 판은 공정한 PvP 점수만 센다. 이야기 선택·거위 첫 참여 같은 한 번뿐인 점수는 명예·악명 수치에만 들어가고 판에는 안 간다(GrantFame ctx.Kind = 'Story' / 'Goose'는 Credit하지 않음). 판의 뜻: "이번 주 공정한 대결로 얻은 명예/악명".
- **D2 그대로.** 괴수 처치, 원한 자루 든 도둑, 정당방위(상대가 먼저 때림)는 PvP 판에서 뺀다. 정당방위 판정 창은 Config 값(`Config.Ranking.DefenseWindowSeconds`, 기본 10초: 상대의 첫 타 뒤 10초 안에 쓰러뜨림).
- **D3 그대로.** 무법자는 깡패 1단계처럼 계산한다(Config.Bounty의 units 최소 1, ×BountyMult). 최대 ×2.
- **D4 끝을 둔다.** 월요일 0시+10분, 키에 시즌. 전체 읽기 실패 시 서버별 판으로 대신하지 않고 다시 시도. **2시간 동안 계속 실패하면 그 주 정산은 건너뛰고(보상·무법자 없음) 로그를 남긴다**(`Config.Ranking.SettleGiveUpSeconds = 7200`). STUDIO 시즌은 이 서버 판으로 정산한다.
- **D5 바닥:** 무법자는 그 주 무단 KO **3점 이상**일 때만(`Config.Ranking.OutlawMinScore = 3`). 1~3위라도 3점 미만이면 무법자가 아니다. 사용자에게는 검수가 알린다.
- **D6 그대로.** 맞는 것·자동 전투 타격은 내 활동이 아니다. `MarkActive(victim, "Hit")`를 따로 두고 자리 비움 판정은 `GetLastOwnActive`(걷기는 내 활동, A23-20).
- 파일: TitleService·CharacterVisuals·GooseService·KaijuService·ProgressionService는 개발2가 고쳐도 된다. Config.Text·LootService·StoryQuestService는 고치기 전에 게임성 개발에게 줄 단위로 알리고 작게. Enhanced 신호 6번째 인자는 듣는 쪽(TelemetryService·Fx 등) 전부 확인한 뒤.

## 12. 정한 것 (제안, 12-A가 대체)
- D1 이야기 선택·거위 첫 참여 점수(한 번뿐, 반복 불가)도 주간 판에 넣는다. A23-23의 "공정 점수만"을 'PvP 점수는 공정 검사 통과분만'으로 읽었다. 빼라면 ctx.Kind로 바로 끈다.
- D2 PvP 판 면제에 BB10 목록 외 3가지를 더했다: 괴수가 된 킬러, 원한 자루를 든 도둑, 미끼 방어(victim이 먼저 때림).
- D3 무법자 현상금: 무법자를 깡패 1단계처럼 현상금 단위 1로 센다. 안 그러면 빛 진영 무법자는 별이 없어 현상금이 0이라 ×2가 의미 없다.
- D4 정산은 월요일 0시 + 10분 뒤(지난 주 값이 다 써질 시간), 정산 문서 키에 시즌을 넣는다. 전체 읽기가 실패하면 '이 서버 판으로 대신'하지 않고 다시 시도한다(서버마다 다른 무법자가 생기는 것 방지). 계약 문구와 다른 점이라 확인 부탁.
- D5 무법자 최소 점수는 계약대로 1점. 베타 초반 사람이 적을 때 KO 1번으로 무법자가 될 수 있다. 최소 3점 같은 바닥을 둘지 사용자 질문이 필요하면 알려 달라.
- D6 victim '직접 활동'은 남에게 맞은 것을 빼고 센다(지금은 맞는 순간 활동으로 잡혀 자리 비움 판정이 안 됨).
