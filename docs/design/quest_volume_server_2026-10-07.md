# 퀘스트 많이(A23-56) 서버 쪽 — quest_volume §5 순서 (게임성 개발 2, 2026-10-07)

설계: `docs/design/quest_volume_2026-10-06.md`. 게임 글은 영어(A23-48).
- 메인 앞당김(3장 M3_1~M3_8 + E7 + Pip1): `docs/design/town_quests_server_2026-10-07.md` 9절(f3fb19c).

## 1. E12 레벨대별 일일 — 고블린 숲 Lv10~24
- `Config.Quests.Woods = { MinLevel = 10, MaxLevel = 24, RewardMinutes = 3, ChestMinutes = 6, Dailies }` — Newbie(Lv1~9)와 같은 방식: 줄은 템플릿 Id를 다시 쓰고, Targets는 정확한 수, 세 칸은 늘 서로 다른 목표.
  | 줄 | 목표 | Weight |
  |---|---|---|
  | Kill | 고블린 12~15 (보통 줄, 더 센 몬스터는 1, 약한 건 조각) | 3 |
  | Kill (Strict) | 고블린 우두머리 2 (고블린은 0) | 2 |
  | Release | 몬스터를 맞힌 수동 스킬 4~6번 | 3 |
  | Gold | 사냥 골드 150 / 200 / 250 | 3 |
  | Golden | 황금 몬스터 1 | 1 |
  | Goose | 거위 줄다리기 1 (빛·뿔만) | 1 |
  | Hunt / Plunder | PvP 1 (빛 / 뿔, Lv15+ · 새싹 보호 끝, 하루 하나 — 지금 규칙 그대로) | 1 |
- 보상: 한 칸 `HuntValue(level, 3)`, 세 칸 다 받으면 상자 `HuntValue(level, 6)` → 하루 = 사냥 15분어치(예전 템플릿 일일은 25분어치, 일은 약 3배였음). CR-M6 상한(5분)보다 작음.
- **Lv25+는 예전 템플릿 일일 그대로.** 상자는 지금처럼 '만든 레벨대'와 지금 레벨대 중 작은 것(Lv24 묶음을 Lv25에 받으면 숲 상자).
- 휴가: `Config.DailyDayMinutes` = Lv1~9 10분 / **Lv10~24 15분** / Lv25+ 25분, 하루 몫 70%(최대 3일) 그대로. 지난날 몫(f)은 그날 만든 레벨대로 계산.
- QuestService: `bandAt(level)`(Newbie → Woods → 없음), `newQuest`·`chestAt`·`runDayCheck`가 그 줄을 씀. A23-14 새싹 일일 줄은 그대로.
- 검사: `py tools/test_a23_14.py` 새 그룹 dailies-woods + 옛 Lv10 기대값을 Lv25(템플릿)·숲 밴드로 고침 — 3335검사, 변이 26/26.
- 개발 1: 화면은 그대로(일일 줄은 같은 Quests 원격). 숲 일일 Text 예 "Defeat Goblin Brute ×2", "Earn 200 gold by hunting".

## 2. E11 사냥터 게시판 (BoardService, 검수 OK 2026-10-07)
- **스위치:** `Config.Board.Enabled = false`(기본). 꺼져 있으면 게시판 원격은 아무것도 안 하고 QuestService는 지금처럼 '추가' 퀘스트를 만든다(검사로 지킴). **게임성 개발 1 게시판 화면이 들어오는 날 true로** — 그때부터 받은 일일 칸은 비고(`{ Kind = "Empty" }`, 목록에 안 나옴, 바꾸기 안 됨, 다음 날 일일로 다시 참), 게시판이 그 역할을 한다.
- **게시판 2곳:** `Config.Board.Boards` — Meadow(`Landmarks.MeadowBoard` = 초원 도착 지점 옆 (220,0,10), Lv1 값) / Woods(`Landmarks.WoodsBoard` = WoodsGate (474,0,0), PvP 밖, Lv10 값). 서버는 플레이어가 그 자리에서 `Range` 14칸 안일 때만 받는다(자리를 옮기면 Landmarks만 고치면 됨).
- **카드:** 플레이어마다 게시판마다 4장, J1~J10 틀(목표 `Obj`는 이야기 단계와 같은 판정 = `StoryQuestService.EventAmount`). J7(자동 전투)은 자동 전투를 연 뒤에만. 숲 게시판은 늘 J6(골드)이나 J10(입구 지키기 15초) 중 하나가 있음(PvP 밖에서 되는 카드). 받거나 바꾼 자리에는 지금 판에 없고 최근 두 틀도 아닌 새 카드. 바꾸기 60초에 한 번.
- **들고 다니기 3개.** 다 하면 **바로 지급**: `HuntValue(게시판 Level, 1)`(초원 36골드+60XP, 숲 192+336), 그날(KST) 10개 뒤는 절반, 그날 5번째 의뢰는 30% 주문서 1장 더(하루 한 번). 고른 쪽은 `data.Story.N.Kind / Sneaky`에만 셈(명예·악명·랭킹 0). 토스트 "Job done! +36 gold · +60 XP" + "Your shard leaned to the light./dark.". 시간 제한·실패 없음.
- **목록:** `BoardService.JobRows` → QuestService 목록에 `Kind = "Job"` 줄(Id "job:N", Text = 목표 줄 예 "King Slime 0/2", Progress/Target, CanClaim false, `Job = { Board, Side, Card, Guide = 그 사냥터 zone }`). M1_4 뒤 첫 의뢰 전까지 "Job Board · tap for directions" 줄 하나(Id "job:board", `Job.Guide = "MeadowBoard"`).
- **원격 계약(게임성 개발 1):**
  - c→s `BoardAction(boardId, action, slot?, side?)`: `"Open"`(창 열기, 게시판 ProximityPrompt에서) / `"Take", slot 1~4, "Kind" | "Sneaky"` / `"Reroll", slot`. 인자 더 있으면 무시, 속도 제한 `RateLimits.BoardAction` 0.3초.
  - s→c `Board`(그 플레이어만): `{ Board, Cards = { { Slot, Id, Kind = 왼쪽 버튼 글, Sneaky = 오른쪽 버튼 글, Goal = 목표 줄, Target, RewardGold, RewardXP } ×4 }, Held, Hold, Done(오늘 한 수), FullPerDay, Kind, Sneaky(지금까지 고른 수), RerollAt(os.time, 바꾸기 가능 시각) }` — Open·Take·Reroll 뒤마다 보냄.
  - 창: 카드 4장(이미지 생성 2가 글자 없는 카드 그림 만드는 중), 카드마다 [Kind]/[Sneaky] 두 버튼 + 목표·보상, 위에 "Kind 12 · Sneaky 3", 3개 들고 있으면 버튼 잠금("You carry 3 jobs."), 바꾸기 버튼(60초 남은 시간). 목록 'Job' 표시.
- 검사: `py tools/test_board.py`(88검사, 변이 22/22) + `tools/test_a23_14.py` board-switch(꺼짐 = 추가 그대로, 켜짐 = 빈 칸·Job 줄·다음 날 일일, 3348검사, 변이 33/33).

## 3. 다음
- 서브 18개 데이터(quest_volume §3-2) → ③ 몬스터 한마디(lines_pack §2) → BB38 이벤트 → PET-2·4 …
