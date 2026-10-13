# 첫 10분 2배 XP + '내일 또 오기' — 서버 (게임성 개발 2, 2026-10-14)

근거: SPEC A23-167(사용자 10/13 밤 "추천대로 하자"), `docs/design/research_rpg_lessons_2026-10-13.md` 2번(세션 2 약속).
가지 `dev2-early-xp`(origin/main 4f88cc5a 위). 화면(칩·카드·안내자 말풍선)은 게임성 개발 1 몫 — 아래 '클라이언트가 할 일'.

## 1. 첫 10분 2배 XP (A23-167)

- `Config.EarlyXP = { Enabled = true, Seconds = 600, Mult = 2 }`. 플레이 시간(`data.PlaytimeSeconds`, 5초마다 오름)이 600초 전이면 **모든 XP ×2**.
- 2배 XP 패스와 겹치면 **×2 한 번만**(둘 중 큰 것, ×4 아님) — `ProgressionService.XPBoost`. 패스는 10분 뒤에도 그대로 ×2라서 약속한 것을 잃지 않아요.
- 30분이 아니라 10분(패스 가치 보호). 옛 세이브(이미 10분 넘게 논 사람)는 해당 없음.
- 그대로인 것: 상한(A23-27 한 번에 한 레벨 등)은 2배 **뒤에** 걸려요. 자기 양을 상한으로 주는 보상(선택 카드·분실물 벤치)은 2배가 안 돼요(패스와 같음). 골드·`GetXPMult`는 안 바뀜. 화면 '+XP' 숫자는 실제로 들어간 양(2배)이 떠요.
- 장인 XP(`CraftService`, 따로 있는 제작 레벨)는 패스만 보고 첫 10분은 안 봐요(캐릭터 XP만 2배). 출석 창의 보상 미리 보기(AttendanceUI)는 패스만 반영 — 첫 10분에 XP 칸을 받으면 실제는 2배(1~5칸엔 XP 없음, 거의 안 생김).
- 남은 초: `ProgressionService.EarlyXPLeft(player)`. 클라는 속성 `PlaytimeSeconds`(이미 복제됨)로 `Config.EarlyXP.Seconds - PlaytimeSeconds`를 셀 수 있어요.

**속도 영향(관찰 아닌 계산):** Lv10까지 962 XP(EarlyMult 0.35). 슬라임만 잡는 기준(분당 12마리 × 5 XP = 60 XP/분)이면 전에는 약 16분, 이제는 약 8분에 Lv10, 10분 끝에 Lv10 근처(퀘스트 보상도 2배라 실제는 더 빠름). 10/17 시험 숫자판의 'Lv5까지 걸린 분'(A23-113 #2)으로 확인하고, 너무 빠르면 EarlyMult(A23-14 결정)나 Seconds를 최종 검수가 정해요.

## 2. '내일 또 오기' (A23-167 ②)

### 내일 선물 카드 — Fx `TomorrowGift { Tomorrow, Today?, Days }`
- 한 접속에서 **10분**(`Config.Return.Tomorrow.After`) 지나면, **KST 하루 한 번**(`data.Return.TomorrowDay`), **출석 7일 모으기 전까지만**(`MaxDays`; 그 뒤엔 습관이 생겼고 '덜 친절하게' 10/09).
- `Tomorrow` = 내일 출석하면 받는 칸(1~7), `Today` = 오늘 아직 안 받은 칸(받았으면 nil → [열기]로 출석 창), `Days` = 모은 날. 칸 계산은 `AttendanceService.NextSlots(player)`(7칸 뒤엔 1칸으로).
- 기다림: 첫 미션 전·싸우는 중·다른 카드 120초 안·구매 창 60초 안이면 30초 뒤 다시(최대 20번). 이 카드도 카드라서 다음 쉼표 카드는 120초 뒤에 와요.
- 신호 `ReturnService.TomorrowShown(player, tomorrowSlot)`.
- Roblox는 '나갈 때'를 서버가 알 수 없어요. 그래서 10분 시점에 보내고, 나가기 직전(예: 메뉴 열 때 `GuiService.MenuOpened`)에 보여 주고 싶으면 클라가 속성 `AttendSlot`·`AttendReady`로 같은 내용을 언제든 계산할 수 있어요(받았으면 내일 = AttendSlot, 안 받았으면 오늘 = AttendSlot, 내일 = 다음 칸).

### 돌아온 사람 — 속성 `Returned` + WelcomeBack `Days`·`News`
- 진짜 돌아옴(마지막 퇴장 6시간 뒤, 첫 미션 끝남 — 옛 규칙 그대로)이면 그 접속 동안 속성 `Returned = true`. 안내자 NPC가 한 번 할 말 = `Config.Return.Text.BackLines`(3줄 중 하나, 클라).
- 옛 Fx `WelcomeBack { Next, Zone }`에 **`Days`**(떠나 있던 날 수, 6~23시간 = 0)와 **`News`**(한 줄 또는 nil)가 더해졌어요.

### 자리 비운 동안 소식 1줄
- 모든 공개 서버의 **왕관전 승리(편마다)**와 **거위 판 수**를 시간(1시간) 단위로 공용 DataStore 한 줄(`HaloHorns_News_v1` / `Hours`, 7일치)에 모아요. 서버마다 5분에 한 번 + 닫힐 때 더하고(실패하면 다음에 다시), 읽기는 서버당 5분에 한 번까지.
- 떠난 시각의 다음 시간부터 지금까지를 더해서: 왕관전이 있었으면 `"While you were away, crown wars won: Halo 3, Horns 1"`(내 편 먼저), 없고 거위만 있었으면 `"Goose rounds while you were away: 2"`, 아무것도 없으면 nil. 비김·빈 판(Idle)은 안 셈. 이 서버에서 아직 안 쓴 수도 더함.
- 개인 서버는 세지도 읽지도 않아요(News 없음). 읽기 실패 = 카드는 오고 News만 없음.
- DataStore 부담: 서버당 5분에 쓰기 1번·읽기 1번 이하. 서버가 아주 많아지면(같은 키 쓰기 제한) 시간 칸을 서버별로 나누는 방식으로 바꿀 것(지금 베타 규모는 괜찮음).

## 클라이언트가 할 일 (게임성 개발 1)
1. 'XP x2' 칩: `PlaytimeSeconds < Config.EarlyXP.Seconds` 동안(패스 `PassXP2`가 있으면 안 보여도 됨). 남은 시간 표시 여부는 개발 1·최종 검수.
2. Fx `TomorrowGift` 카드: `Text.TomorrowTitle`, `TomorrowLine`(칸 번호), 칸 그림 = 출석 판 그 칸, `Today`가 있으면 `TodayLine` + [열기] → 출석 창.
3. 속성 `Returned` → 안내자 말풍선 `Text.BackLines` 한 번.
4. `WelcomeBack` 카드에 `News` 한 줄(있을 때만).
(글은 전부 `Config.Return.Text`에 있음 — 영어만, 짧게. 단어는 최종 검수가 바꿀 수 있음.)

## 시험
- `tools/test_gamepass.py`: 새 묶음 "A23-167 first minutes 2x XP"(새 세이브 ×2, 595초 ×2, 600초 끝, 패스와 겹쳐 ×2 한 번, 상한은 2배 뒤, 골드 그대로, 처치 줄 +8 XP, Lv1 왕 처치 한 레벨, 스위치, Config 없음) + 변이 10개. 다른 묶음의 플레이어는 플레이 시간 3600초로(10분 지난 사람).
- `tools/test_return.py`: 새 묶음 4개(내일 선물 카드, 기다림, 돌아옴·Days·소식, 소식 실패·개인 서버·옛 칸 지우기·닫힐 때) — 진짜 AttendanceService로 + 변이 30개.
- `tools/fixtures/health_offline.luau`·`loot_offline.luau`: 진짜 AddXP로 정확한 레벨을 세는 곳의 플레이어를 3600초로.
