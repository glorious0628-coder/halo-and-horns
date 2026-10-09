# 소리가 비어 있는 새 기능 (소리 만들기, 2026-10-10)

방법: 최근 2일 커밋 목록 + `Config.Audio`·`Audio.luau`(창 소리는 `T.Windows = { Panels, WorldMap, PlayerListUI }`만)를 읽고 기능마다 지금 나는 소리를 확인했다. 게임을 직접 켜서 들어 본 것은 아니다(코드 기준). 소리 연결은 게임성 개발 1.

## A. 올려 놓았는데 아직 게임에 안 이어진 것 (새 소리 없음, 연결만)
`Config.Audio.Files`에 아래 10개 id가 아직 없다(`art/sfx/asset_ids.json` 'ids'에는 있음).
| 키 | 쓸 곳 |
|---|---|
| QuestOpen / QuestTab | 퀘스트 책 열기 / 탭 바꾸기(QuestBook·HUD) |
| StampPress | 출석 도장 찍기 |
| Chest7Open | 7일 상자 열기 |
| WelcomeBack | 돌아온 선물 카드(PauseCard) |
| DiaryPage | 왕 일기 책장 넘기기(KingDiary) |
| CandyPlop | 사탕 떨어짐(할로윈 마당) |
| KingHelpHome / KingTickleCoins | King Slime 도움·간지럼 장면 |
| TipDing | Tip 알림(이스터 에그 EG05 등) |
창 소리 목록 `T.Windows`에 `PetWindow`·`KingDiary`·`QuestBook`·`PauseCard`도 더하면 열기·닫기는 기존 WindowOpen/Close로 된다.

## B. 이미 있는 소리로 되는 것 (새로 안 만듦)
| 기능 | 제안 소리 |
|---|---|
| 펫 창 열기·닫기 | WindowOpen/WindowClose (T.Windows에 PetWindow) |
| 펫 '따라오게' / '넣어 두기' 버튼 | Tap (Equip을 넣어 두기에) |
| 펫 레벨 오름 | LevelUp을 Volume 0.5·Speed 1.2로, 또는 SkillLearn |
| 물약 판 구매 | Spend + Potion (서버 Notify의 Sound = "Spend") |
| 선택 여운(반짝이·보라 연기) 시작 | 선택 순간에 이미 Purify/Devour가 남 → 여운은 조용히 |
| 이스터 에그 대화 열림 / 칭호 얻음 | QuestNew(대화) / RankUp(칭호) |
| 주민 말풍선(BarkService·Town 주민) | TalkBlip을 아주 작게(Volume 0.12), 몬스터 말풍선은 조용히 |
| 마름모(◆) 목표 갱신 | Tap을 작게(Volume 0.2)로 충분 — 마음에 안 들면 C의 DiamondTick |

## C. 새로 만들 것 (제안, 모두 직접 합성 → 크레딧 0; 듣는 판단은 사용자가 플레이하며)
| 새 소리 | 쓸 곳 | 모양 |
|---|---|---|
| **Warp** | 마을 이동 판 밟기 / 순간이동(TravelDone) | 0.7초, 위로 올라가는 반짝 공기 + 작은 종 '슈웅', 도착은 같은 소리를 거꾸로 짧게(WarpIn) — 깜짝 놀라지 않게 부드럽게 |
| **DiamondTick** (선택) | 마름모 목표가 바뀔 때 | 0.1초 나무 '톡', 아주 작게 |
| **SecretFound** | 숨은 이스터 에그를 찾았을 때 | 0.8초 반짝 3음 올림(빛 쪽 장난), 레벨업보다 작고 부드럽게 |
| **PetCall** / **PetStow** (선택) | 펫 따라오게 / 넣어 두기 | 따라오게 = 짧은 2음 '뾰로', 넣어 두기 = 작은 '뽁' 빨려 들어감 |
| 분수 물소리 / 폭포 물소리 | 이미 만들어 올림 | (끝) — 연결: 개발 1 |

## D. 하지 않을 것
- 몬스터 말풍선 소리, 선택 여운 소리, 모든 버튼 클릭 소리(귀가 지침 — '덜 친절한 화면' A23-99).
- 교회 종·성가·무서운 소리(소리 규칙).

## 배경 음악 연결 요청(개발 1에 이미 보냄)
구역 곡 8 + 보스 층 4 + 물소리 2, id는 `art/sfx/asset_ids.json` 'bgm' 절.
