# 호박밭·유령 숲 숨기기 (게임성 개발 3, 2026-10-11, SPEC A23-119)

사용자 10/11: 공개 베타가 12/1로 옮겨 가서 핼러윈 철을 건너뛴다. 호박밭(PumpkinPatch)과 유령 숲(HauntedHollow)을 **숨긴다**. 코드·데이터는 지우지 않는다. 그 자리에는 나중에 새 몬스터가 사는 새 구역이 들어온다.

## 스위치 하나
`Config.Halloween.Enabled = false` (Config.luau). 이미 있던 철(Season = "Halloween") 장치가 모든 곳을 끈다 — 따로 `if` 를 더 달지 않았다:

| 무엇 | 꺼진 모습 | 어디서 |
|---|---|---|
| 구역 | 두 구역이 `Config.ZoneAt`에서 빠진다(그 땅은 바깥(Outskirts)으로 읽힘), 이동 목록(`Config.Travel.Destinations`)에는 원래 없었다 | `Config.ZoneAt` |
| 몬스터 | 호박 슬라임·박쥐 고블린·유령 3종·두 왕이 안 나온다. 그들이 먹던 칸(고블린 3칸 등)은 기본 몬스터로 돌아온다 | `Config.MonsterActive` / MonsterService |
| 왕 시간표 | 호박 대왕·유령 왕이 안 나오고 GameState `*NextAt` = 0, 안내 방송·사탕 상자 없음 | HalloweenService |
| 길 표지판 | 숨김 | HalloweenService |
| 줄 | HUD 호박 대왕 줄 없음 | EventHUD |
| 지도 | 큰 지도(WorldMap)는 원래 철 땅·길·구역을 건너뜀. **작은 지도(MiniMap)는 건너뛰지 않았다 → 이번에 고침**(철이 꺼진 땅·길·구역은 안 그림) | WorldMap / MiniMap |
| 잃어버린 물건 | '사탕 주머니'(CandyBag, 호박밭)는 안 나온다 | LostFoundService |
| 왕 일기·사탕 단지 | 퀘스트 책의 두 줄이 안 보인다(페이지를 연 사람은 단지가 남음) | QuestBook |
| 소식 창 | 'Halloween: the Pumpkin Patch ...' 줄을 뺐다. **'full launch on December 19'**는 날짜를 뺐다(정식 출시는 1월 말, 날짜는 12월에 정함) | `Config.Help.News` |
| 퀘스트·일일·업적 | 이야기 퀘스트와 일일은 이 구역·몬스터를 한 번도 이름으로 가리킨 적이 없다(호박 슬라임은 '슬라임' 일일에 세지던 것이라 슬라임 일일은 그대로 세어진다). 안내(Guide)에도 없다 → 막힐 곳 없음 | 시험이 확인 |

라이브 스위치 `Halloween`(SwitchService)은 `켜짐 AND Config 값`이라 **끄기만** 된다. 다시 보이게 하려면 `Config.Halloween.Enabled = true` + 새 `EndsAt`를 커밋한다.

## 그대로 둔 것
- **땅·장식은 지우지 않는다.** 메인 Studio 지도(Terrain)에는 호박밭·유령 숲 땅과 장식이 구워져 있고 MapBuilder는 시작 때 비어 있으면 다시 채운다. 구역이 숨은 동안 그 땅은 바깥(Outskirts) 구역으로 읽히는 빈 풍경이다. 새 구역이 같은 자리를 쓸 때 월드 쪽(이미지 생성 1)이 바꾼다.
- 사탕(Candy) 재료와 사탕 단지·'Party Guest 2026'·'Pumpkin Pal'·'Candy Keeper' 칭호 데이터(이미 가진 사람의 것).
- 배지 `Halloween2026`: 사탕이 있거나 왕을 함께 잡은 사람만 받는다(철 중 기록). 숨은 동안은 아무도 새로 못 받는다. **Creator Dashboard에서 배지를 8개 만들 때 이 배지는 만들지 않아도 된다**(launch_ops_checklist).
- 분석 퍼널 `KingDiary`(4단계): 일기 페이지를 못 열어 비어 있다. 베타 첫 주 보는 값이 아니다.
- 플레이어는 늘 집 마을에서 되살아난다(`respawnZoneId`) → 숨은 구역에 갇히는 저장은 없다.

## 시험
`tools/test_halloween_hidden.py` — 기본 Config로(철 켜기 없이): 두 구역이 `ZoneAt`에서 빠짐·모든 철 몬스터가 꺼짐·왕 시간표 0·QuestBook 줄 없음·CandyBag 안 나옴·소식 창에 호박/핼러윈 줄 없음·일정(12/1·1월 말)과 어긋난 날짜 없음·퀘스트/일일/안내가 두 구역과 철 몬스터를 이름으로 가리키지 않음·MiniMap이 철이 꺼진 땅·구역을 안 그림. 옛 `test_halloween`은 철 중 동작을 보므로 `Enabled = true`를 시험 안에서 켠다.
