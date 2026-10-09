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
- **게시판 2곳:** `Config.Board.Boards` — Meadow(`Landmarks.MeadowBoard` = 초원 도착 지점 옆 ~~(220,0,10)~~ → (230,0,12), Lv1 값) / Woods(`Landmarks.WoodsBoard` = WoodsGate ~~(474,0,0)~~ → (636,0,0), PvP 밖, Lv10 값). 서버는 플레이어가 그 자리에서 `Range` 14칸 안일 때만 받는다(자리를 옮기면 Landmarks만 고치면 됨).
- **카드:** 플레이어마다 게시판마다 4장, J1~J10 틀(목표 `Obj`는 이야기 단계와 같은 판정 = `StoryQuestService.EventAmount`). J7(자동 전투)은 자동 전투를 연 뒤에만. 숲 게시판은 늘 J6(골드)이나 J10(입구 지키기 15초) 중 하나가 있음(PvP 밖에서 되는 카드). 받거나 바꾼 자리에는 지금 판에 없고 최근 두 틀도 아닌 새 카드. 바꾸기 60초에 한 번.
- **들고 다니기 3개.** 다 하면 **바로 지급**: `HuntValue(게시판 Level, 1)`(초원 36골드+60XP, 숲 192+336), 그날(KST) 10개 뒤는 절반, 그날 5번째 의뢰는 30% 주문서 1장 더(하루 한 번). 고른 쪽은 `data.Story.N.Kind / Sneaky`에만 셈(명예·악명·랭킹 0). (→ A23-86 결정 1: 이제 하루 장부 `Deeds.Add`로 명예·악명 +1 / 반대 −1, 하루 6점까지. 랭킹 점수는 여전히 0, BoardService.) 토스트 "Job done! +36 gold · +60 XP" + "Your shard leaned to the light./dark.". 시간 제한·실패 없음.
- **목록:** `BoardService.JobRows` → QuestService 목록에 `Kind = "Job"` 줄(Id "job:N", Text = 목표 줄 예 ~~"King Slime 0/2"~~ → "Slime Prince 0/2"(BigSlime 화면 이름, A23-84), Progress/Target, CanClaim false, `Job = { Board, Side, Card, Guide = 그 사냥터 zone }`). M1_4 뒤 첫 의뢰 전까지 "Job Board · tap for directions" 줄 하나(Id "job:board", `Job.Guide = "MeadowBoard"`).
- **원격 계약(게임성 개발 1):**
  - c→s `BoardAction(boardId, action, slot?, side?)`: `"Open"`(창 열기, 게시판 ProximityPrompt에서) / `"Take", slot 1~4, "Kind" | "Sneaky"` / `"Reroll", slot`. 인자 더 있으면 무시, 속도 제한 `RateLimits.BoardAction` 0.3초.
  - s→c `Board`(그 플레이어만): `{ Board, Cards = { { Slot, Id, Kind = 왼쪽 버튼 글, Sneaky = 오른쪽 버튼 글, Goal = 목표 줄, Target, RewardGold, RewardXP } ×4 }, Held, Hold, Done(오늘 한 수), FullPerDay, Kind, Sneaky(지금까지 고른 수), RerollAt(os.time, 바꾸기 가능 시각) }` — Open·Take·Reroll 뒤마다 보냄.
  - 창: 카드 4장(이미지 생성 2가 글자 없는 카드 그림 만드는 중), 카드마다 [Kind]/[Sneaky] 두 버튼 + 목표·보상, 위에 "Kind 12 · Sneaky 3", 3개 들고 있으면 버튼 잠금("You carry 3 jobs."), 바꾸기 버튼(60초 남은 시간). 목록 'Job' 표시.
- 검사: `py tools/test_board.py`(88검사, 변이 22/22) + `tools/test_a23_14.py` board-switch(꺼짐 = 추가 그대로, 켜짐 = 빈 칸·Job 줄·다음 날 일일, 3348검사, 변이 33/33).

## 3. 서브 18개 (quest_volume §3-2: 새 12 + 당김 6)
- `StoryQuests.Subs` 끝에 S6·XR1·H2·R5·GW1·H3·R3·GW2·GW3·H5·R6·GW4·GW5·GW6·GW7·H6·R7·GW8. 모두 한 번만, 마지막은 A(천사)/B(악마) 선택(점수 1, A23-58 규칙), 끝 줄은 질문.
  - **마을형(Lv5~10: S6·XR1·H2·R5):** 120골드 + 레벨 칸 0.5, A = 70% 주문서 1 / B = HP 물약 3 + 60골드. 열림 M1_4 뒤 Lv5/8.
  - **숲형(Lv10+: 나머지):** `Reward{Gold=2, XP=2}`, A = 70% 주문서 1 / B = HP 물약 3 + **192골드**(HuntValue 1분). 열림 M2_7 뒤 각 레벨(GW1·H3·R3 12, GW2 11, GW3 14, H5·R6 15, GW4 16, GW5 17, GW6 19, GW7 21 + **GW1 뒤**, H6·R7 22, GW8 23).
  - 진영: H·R은 빛/뿔만, S6·GW4·GW5는 빛·뿔(S6은 진영별 단계: 빛 = 초원 도착 지점 슬라임 5 / 뿔 = 사냥 골드 80 → 우리 마을), 나머지는 모두(장인 저장은 Neutral A/B 이름).
  - 말하는 이: Tiny(XR1, NPC 말 걸기), Bright(H2·H5·H6, H5만 NPC), Smokey(R5·R6·R7, R6만 NPC), Grabbo(GW1·GW7), Sir Gleam(H3)·Rascal Rex(R3)(Speakers `Gleam`·`Rex`, 베타는 이름만), Fountain Shard(GW5), 안내자(이름 없는 줄 = 내 진영 안내자).
  - 대사: quest_volume 표의 한 줄 + A/B 그대로, story_depth §3·§5 ⑤(GW1 회의) 그대로, 모자란 1~2쪽은 같은 말투로 채움(검수 ⑭ 검사기로 훑음). H2 등불 안 줄은 lines_pack 1-5 ③ 고친 줄("a tiny 'B.' scratched in"). GW1 끝에 그로보 반응(LinesBy 자기 Pick), GW7 1쪽은 GW1에서 고른 쪽 기억(LinesBy From=GW1).
- 새 랜드마크: `HeroStatue` ~~(0,0,−360)~~ → (0,0,−370) 빛의 성채 영웅의 길, `LavaCrack` ~~(48,0,400)~~ → (48,0,410) 뿔 소굴 용암 수로(지도 v2 때 개발 1 확인, 지금 Config 값). 마커 Guide 키로도 씀.
- **목록 순위 고침(서브가 많아져서):** 0 = 받기·**진행 중** 대화/선택 카드, 1 = 상황(거위), 2 = 시작한 서브·S0, **3 = 새로 열린 제안(첫 대화 카드)**, 4 = 나머지, 같은 순위는 새 퀘스트 먼저. 새 제안이 진행 중인 마을 퀘스트를 밀어내지 않는다(검사).
- 검사: test_town_quests subs18-data·subs18-offered·subs18-flow + max-subs 갱신 — 431검사, 변이 69/69.

## 4. 다음
> 2026-10-09 검수: 이 절은 낡음 — ③ 몬스터 한마디(BarkService)는 main에 있고, PET-2·PET-4도 main에 들어감(ae1fa582). 게시판은 개발 1 창이 아직 없어 `Config.Board.Enabled = false` 그대로. 지금 일 순서는 `docs/handoff/review_handoff_2026-10-09.md` §8·§9.
- ③ 몬스터 한마디(lines_pack §2, BarkService 따로 + MonsterService 신호 한두 줄, Main ORDER와 같은 커밋) → BB38 이벤트 → PET-2·4 …
