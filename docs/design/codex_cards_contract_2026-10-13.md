# 몬스터 도감 카드 — 화면 약속 (서버 게임성 개발 2 → 화면 게임성 개발 1, 2026-10-13)

SPEC A23-153, 설계 `docs/design/codex_cards_2026-10-12.md`. 서버 = `src/ServerScriptService/CodexService.luau`, 숫자·글 = `Config.Codex`(Shared, 클라이언트도 읽음). 시험 `py tools/test_codex.py`. 능력치 없음, 팔지 않음.

## 1. 무엇을 세나
- **시리즈 1 = 11종, 구역 페이지 3개** (`Config.Codex.Pages`, 카드 순서 = `Config.Codex.Order`, 종류 → 페이지 번호 `Config.Codex.PageOf[kind]`):
  - SlimeMeadow: `Slime`, `FlowerSlime`, `BigSlime`, `SlimeKing`(보스) → 칭호 `SlimeScholar` "Slime Scholar"
  - GoblinWoods: `Goblin`, `SlingshotGoblin`, `GoblinBrute` → `GoblinScholar` "Goblin Scholar"
  - SkeletonRuins: `Skeleton`, `SkeletonArcher`, `SkeletonKnight`, `CaptainClatter`(보스) → `SkeletonScholar` "Skeleton Scholar"
- 세는 규칙 = 처치 기록(KillLog)과 같음: `MonsterKilled`(보상 받은 처치, 자동 전투 포함, 보스 '작은 몫' 포함), **개인 몬스터(첫 KO 왕) 제외**. 그래서 `Codex[kind].Kills == KillLog.ByKind[kind]`.
- 단계 `Stage`: 0 없음 · **1 Card**(처음 잡음) · **2 Silver**(100) · **3 Gold Holo**(1000). 표 `Config.Codex.Steps`, 보스 `BossSteps`(지금 같은 1/100/1000). `Config.CodexStage(kind, kills)`로 계산 가능.
- **Gold Foil**: 그 종류 황금 몬스터를 처음 잡으면(`Golden >= 1`) 따로 생기는 카드. **보스는 황금이 안 나와서 포일 없음**(`Config.CodexCanGold(kind)` = false) → 그림은 9장이면 됨.
- `First` = 처음 잡은 때(os.time). **0 = 도감 전**(옛 저장에서 옮겨 온 카드) → 날짜 대신 `Config.Codex.Text.Before` "Before the Codex".

## 2. 원격 (`Net.Names`)
| 이름 | 방향 | 내용 |
|---|---|---|
| `CodexOpen` | c→s | 인자 없음. "내 도감 보내 줘". 1초에 1번(`Config.RateLimits.CodexOpen`), 준비 안 됐으면 무시. 답 = `Codex`. **도감 창 열 때 보내기**(처치 수는 잡을 때마다 보내지 않음). |
| `Codex` | s→c(본인) | `{ V = 1, Cards = { [kind] = { Kills, Golden, Stage, First } }, Glow }` — 접속 때 1번 + `CodexOpen` 답. 카드 없는 종류는 빠짐(= 실루엣). |
| `CodexUp` | s→c(본인) | 순간 1개마다 1번(아래 표). 큐에 넣고 차례로 보여 주기(한 처치에 2개 올 수 있음: Card 다음 Golden, Card 다음 Page, Holo 다음 Glow). |

`CodexUp` 내용: `{ Event, Kind?, Stage?, Card? = { Kills, Golden, Stage, First }, Gold, XP, Title?, Page?, Key, Args, Text, Debug? }`
- `Gold`/`XP` = **실제로 더해진 양**(2배 패스 포함; 최고 레벨이면 XP 0). Page·Glow는 보상 없음(0 또는 없음).
- `Key` = 글 키(`"Config.Codex.Text.<Event>"`), `Args` = 그 글의 `%s` 값, `Text` = 완성된 영어 한 줄(보상 붙음, 예: `"New card: Slime! +9 gold · +15 XP"`). 화면은 `Text`를 그대로 써도 되고 `Key`+`Args`로 따로 그려도 됨(보상 줄 = `Config.Codex.Text.Reward` / `RewardGold`).
- `Debug = true` = Studio 시험 명령으로 다시 띄운 순간(저장·보상 없음).

| Event | 언제 | 글(`Config.Codex.Text`) | 보상 |
|---|---|---|---|
| `Card` | 처음 잡음(Stage 1) | `Card` "New card: %s!" | 그 몬스터 3마리 몫 XP·골드 |
| `Silver` | 100마리(Stage 2) | `Silver` "%s card is now Silver!" | 20마리 몫 |
| `Holo` | 1000마리(Stage 3) | `Holo` "%s card is now Gold Holo!" | 100마리 몫 |
| `Golden` | 그 종류 황금 처음 | `Golden` "Gold Foil card: %s!" | 5마리 몫 |
| `Page` | 페이지 다 채움(그 칭호를 새로 얻을 때만) | `Page` "%s page done! New title: %s" (구역 이름, 칭호 이름) | 칭호 |
| `Glow` | 11종 모두 Gold Holo | `Glow` "Every card is Gold Holo! Your sparkle is on." | 꾸미기(아래 속성) |

보스(King Slime·Captain Clatter)는 단계 보상이 1/3/10마리 몫(`Reward.BossStage`). 보상 = 은행 골드(출처 `"Codex"`, 털리지 않음) + XP. 숫자 `Config.Codex.Reward`.

## 3. 속성 (Player attribute)
- `CodexCards` (숫자) = 가진 카드 수(Stage ≥ 1), 0..11 — HUD [Codex] 단추 옆 "3/11" 같은 표시용.
- `CodexGlow` (true/false) = 11종 모두 Gold Holo. **모든 클라이언트에 보임** → 그 플레이어 후광/뿔 반짝이·도감 카드 테두리 꾸미기를 화면이 그림(능력치 없음). 새 그림이 필요하면 승인 그림부터.
- 칭호는 원래 칭호 체계 그대로(`TitlesOwned`, `SetTitle`).

## 4. 글 키 (게임 글은 영어만, 중앙 표 = `Config.Codex.Text`, 하드코딩 금지)
- 서버가 보내는 줄: `Config.Codex.Text.Card / Silver / Holo / Golden / Page / Glow / Reward / RewardGold`.
- 화면용(서버가 만든 표, 화면이 씀): `Name` "Monster Codex", `Stages[1..3]` "Card" / "Silver" / "Gold Holo", `Foil` "Gold Foil", `Before` "Before the Codex".
- 카드 이름: `Config.MonsterTypes[kind].Name`(긴 이름, 카드 앞면) / `.Short`(알림 줄). 페이지 이름: `Config.Zones[page.Id].Name`.
- **카드 뒷면 이야기**: `Config.Codex.Lore[kind].Halo / Horns / Neutral` (내 진영 말투; 진영 None이면 Neutral). 초안 33줄 — 최종 검수가 고치면 이 표만 바꾸면 됨.
- 뒷면의 나머지(드롭·나오는 곳): `Config.Loot` 드롭 줄, `MonsterTypes[kind].Zone`. 잡은 수·처음 날짜 = 카드 `Kills`, `First`. 화면 칸 이름("Kills", "Drops" 등)은 화면 쪽 글 표에.

## 5. 저장 (save v5)
- `data.Codex = { [kind] = { Kills, Golden, Stage, First } }` — `Config.Data.Version = 5`. 옛 저장(v1~v4)은 처음 들어올 때 **처치 기록(`KillLog.ByKind`)에서 카드가 한 번 만들어짐**(Golden 0, First 0, 보상·알림 없음; 다 찬 페이지 칭호는 조용히 줌). v4 서버는 v5 저장을 거절(CR-L3).
- 고쳐 쓰기 `Config.SanitizeCodex`: 시리즈 1 종류만, Kills ≥ 1인 줄만, 0..10억 정수, Golden ≤ Kills(보스 0), 단계는 처치 수보다 낮으면 올리고 높아도 빼앗지 않음.

## 6. Studio 시험 (메인 Studio는 메인 반영 1만)
서버 명령 막대: `game.ServerScriptService.DebugCommand:Invoke("<이름>", "Codex", "<값>")`
- `"Slime:99"` → Slime 99마리(단계는 숫자대로, 보상 없음) → 1마리 더 잡으면 Silver 순간.
- `"show:Slime:Silver"` → `CodexUp` Silver 한 번 더(저장·보상 없음, `Debug = true`). Event = Card/Silver/Holo/Golden/Page/Glow.
- `"Slime:0"` 그 카드 지움, `"reset"` 전부 지움.

## 7. 화면 쪽 메모(게임성 개발 1)
- `Config.Codex.ServerToast = true`(지금): 서버가 같은 줄을 보상 토스트로도 보냄. **카드 순간 화면이 들어가면 개발 1이 false로** — 그때부터 줄은 `CodexUp`에서만.
- 순서: 접속 `Codex` → 창 열 때 `CodexOpen` → 순간은 `CodexUp`(창이 열려 있으면 그 카드만 새로 그리기, 아니면 가운데 카드 순간). 빛살 무늬 금지(A23-153).
- 남은 결정(최종 검수): 보스 단계 숫자(1000마리 Captain Clatter ≈ 20분마다 1번 = 330시간), 뒷면 이야기 33줄 다듬기, 꾸미기 그림.
