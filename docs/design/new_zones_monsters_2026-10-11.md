# 새 구역 몬스터 초안 (게임성 개발 2, 2026-10-11, SPEC A23-119 / A23-123)

호박밭·유령 숲이 숨겨진 자리(A23-119)에 들어올 새 구역 둘과 몬스터 7종의 **데이터 초안**이다. 슬라임 없음(A23-123). 전부 `Config.luau`에 있고 **스위치가 꺼져 있어서 지금 게임은 그대로**다. 땅·3D·그림이 없어서 숫자와 이름만 먼저 잡았다.

## 스위치
- `Config.NewZones.Enabled = false` (꺼짐이 출하 값). 새 구역·몬스터는 모두 `Season = "NewZones"`라서 할로윈 철과 같은 길로 꺼진다: 안 나오고, `Config.MonsterActive` = false, 스폰 수 0.
- 두 구역은 꺼진 동안 `Config.ZoneOrder`에도 없다(`Config.ZoneAt`·지도·MapBuilder가 아무것도 못 봄). 켜면 `Config.NewZonesApply()`가 `ZoneOrder` 끝에 한 번씩만 넣는다(두 번 불러도 안 늘어남).
- 켜는 법: `Config.NewZones.Enabled = true`로 바꾸고 커밋 → 메인 반영 1이 Studio에 반영. **아래 '먼저 있어야 할 것'이 끝나기 전에는 켜지 않는다.**

## 먼저 있어야 할 것 (켜기 전)
1. **진짜 구역 사각형과 땅.** 지금 `Config.Zones.CoralCoast` / `CrystalWoods`의 사각형은 **임시**(지도 경계 x 1840 동쪽, 아무 구역과도 안 겹침). 이미지 생성 1이 땅 조각(`Config.Map.Lands`에 `Season = "NewZones"`)·길·문을 만들고, 그 값에 맞춰 `Center`/`Size`/`Spawn`을 고친다. 땅(Terrain)이 없으면 몬스터가 땅을 못 찾는다.
2. **3D 모델 7종** (A23-125: Tripo 앞·뒤·좌·우 → Blender 손질 → Roblox 재질). 지금은 `ModelFrom`으로 기존 모델을 색만 바꿔 빌려 쓴다(A23-96에 따라 임시).
3. **말풍선 그림**(`BarkBubbleCoralCrab`, `BarkBubbleCrystalLizard`; 없으면 둥근 코드 말풍선) · **재료 아이콘**(`IconSeaShell`, `IconCrystalShard`; 없으면 코드 대체) · 구역 이름 그림.
4. **작은 지도·큰 지도 그림**, **음악**(구역 BGM).
5. 켠 뒤 시험 갱신: `tools/test_map_v2.py`는 "`ZoneOrder`의 모든 구역이 v2 배치에 있다"를 본다 → 배치(`tools/preview_map.lua`)에 새 구역을 넣어야 한다(켠 상태로는 아직 안 돌려 봄).

## 몬스터 7종
| 이름(id) | 구역 | Lv | HP | 공격 | XP | 골드 | 마리수 | 크기 | 빌려 쓰는 모델 | 역할 |
|---|---|---|---|---|---|---|---|---|---|---|
| Coral Crab (CoralCrab) | 산호 해안 | 8 | 60 | 4 | 20 | 11 | 8 | 0.9 | Goblin | 기본 근접 |
| Jellyfish (Jellyfish) | 산호 해안 | 9 | 65 | 5 | 22 | 12 | 5 | 0.9 | LittleGhost | 떠다님(Float 1.5) |
| Hermit Crab (HermitCrab) | 산호 해안 | 11 | 120 | 7 | 36 | 20 | 3 | 1.3 | GoblinBrute | 단단한 놈, 퀘스트에서는 Coral Crab으로 셈 |
| Crystal Lizard (CrystalLizard) | 수정 동굴 숲 | 14 | 95 | 6 | 30 | 17 | 9 | 0.8 | Goblin | 작고 빠르고 많음(속도 14) |
| Cave Bat (CaveBat) | 수정 동굴 숲 | 15 | 110 | 7 | 34 | 19 | 5 | 0.8 | LittleGhost | 날아다님(Float 2) |
| Glowing Mushroom (GlowMushroom) | 수정 동굴 숲 | 17 | 200 | 8 | 50 | 28 | 4 | 1.2 | GoblinBrute | 느린 탱커 |
| Crystal Golem (CrystalGolem) | 수정 동굴 숲 | 21 | 480 | 15 | 110 | 75 | 2 | 1.9 | SkeletonKnight | 큰 놈(보스 아님, 일반 풀에 소수) |

공통: 슬라임 모양·슬라임 모델 없음, 원거리(Ranged)·보스(Boss) 없음, 기존 칸을 뺏지 않는 추가형(`Takes` 없음 → 전체 상한(`GlobalCap`) 밖). 추천 레벨은 산호 해안 8~11, 수정 동굴 숲 14~21이고 **레벨 제한은 없다**(할로윈 구역과 같음).

## 재료 2개
- **Sea Shell**(산호 해안): 판매 4골드, Jelly 2 ≤ 4 ≤ Goblin Tooth 6 사이.
- **Crystal Shard**(수정 동굴 숲): 판매 8골드, Goblin Tooth 6 ≤ 8 ≤ Old Bone 14 사이.
- 둘 다 팔기용 재료(`Material`), 아이템 목록 순서에 레벨 순으로 끼워 넣음.

## 왜 이 숫자인가 (이웃 비교)
기존 몬스터를 레벨 순으로 두 줄로 세웠다. 새 몬스터는 자기 레벨 바로 아래·위 이웃 사이에 두었다(같아도 됨). 크기 1.2 미만은 '기본' 줄, 1.2 이상은 '큰 놈' 줄.

| 줄 | 이웃(Lv: HP / 공격 / XP / 골드) |
|---|---|
| 기본 | Slime Lv2: 10 / 2 / 5 / 3 → Goblin Lv12: 90 / 6 / 28 / 16 → Skeleton Lv26: 450 / 14 / 65 / 65 |
| 큰 놈 | Slime Prince Lv5: 40 / 4 / 18 / 10 → Goblin Brute Lv18: 260 / 12 / 70 / 40 → Skeleton Knight Lv30: 1300 / 24 / 170 / 170 |

- 산호 해안 게·해파리(기본, Lv8~9): Slime Lv2와 Goblin Lv12 사이. 소라게(큰 놈, Lv11): Prince와 Brute 사이.
- 수정 도마뱀·박쥐(기본, Lv14~15): Goblin 이상, Skeleton 미만. 버섯(큰 놈, Lv17): Prince~Brute. 골렘(큰 놈, Lv21): Brute~Knight (Skeleton보다 센 것은 큰 놈 줄이라서 맞다).
- 한 구역 안에서는 레벨이 오를수록 HP·XP가 늘어난다.
- **드랍**: 스크롤·이동 스크롤·물약 확률은 이웃보다 높지 않다(기본 = Goblin 줄, 큰 놈 = Goblin Brute 줄). 무기 줄은 골렘만(4단계, Brute의 0.005보다 낮은 0.003). 도마뱀·박쥐는 Goblin과 같은 줄이라 같은 확률이다.
- 시험(`tools/test_new_zones.py`)이 위 규칙을 숫자로 확인한다.

## 해야 할 일 (TODO)
- [ ] 진짜 사각형·땅·길·문(이미지 생성 1), 켠 뒤 `Config.Map.Lands`·지도 배치 갱신
- [ ] 7종 3D 모델(이미지 생성 2 4방향 그림 → Tripo → Blender), 그다음 `ModelFrom` 빼기
- [ ] 말풍선 그림 2종·재료 아이콘 2개·구역 그림·작은/큰 지도 그림·음악
- [ ] **수정 고슴도치 = 그 구역 이야기 퀘스트 펫**(몬스터 아님; 초원 아기 슬라임 펫 PET-4와 같은 방식, 털은 짧게). 이야기 퀘스트 줄 자체도 아직 없음
- [ ] 이 구역을 가리키는 퀘스트·일일·안내(Guide) 문장(아직 없음)
- [ ] 한국어 글(한국어 모드가 생긴 뒤, A23-111): 지금은 영어 전용, 글은 중앙 표에 있음
- [ ] 숫자는 임시: 켠 뒤 직접 플레이해서 조정(A23-12)

## 시험
`tools/test_new_zones.py`: 스위치 꺼짐 확인, 꺼진 동안 새 몬스터 0마리·새 구역이 `ZoneOrder`에 없음·기존 모든 구역 사각형 위 점에서 `ZoneAt`이 기준 커밋 048127fa9e와 같음, 켜면 한 번만 추가·몬스터가 `Count`만큼 나옴·기존 값 불변, 몬스터·드랍·말풍선·영어 전용 글자 검사. 고장 내 보기(변이) 55개가 모두 걸러진다. 결과: `docs/art/verification_2026-10-11/offline_dev2_new_zones_2026-10-11.json`.
