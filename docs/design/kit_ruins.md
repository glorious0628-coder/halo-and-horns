# 해골 유적 키트 목록 (A23-47, 이미지 생성 1 초안 2026-10-07)

순서(초원·숲과 같음): 장면 시안 `art/review/concept/Concept_SkeletonRuins.jpg` + 세계 지도 v2(`docs/design/world_map_v2_2026-10-06.md`) → 시안 속 물건을 **한 장에 하나씩** 2D(중간 0크레딧, 3/4 앞모습, 전체가 그림 안, 단색 회색 배경, 글자 없음) → 고르기(검수) → 최종만 고급(5) → Tripo(웹 ①부터는 Smart Mesh) → Blender 정면 렌더 비교 → WorldKit(가져오기 버튼은 사용자) → 게임성 개발 1.
- **넓이(v2):** 유적 땅 x 1260~1780, z -290~290 (520×580). 고갯길(x 1190~1260, 돌 아치 (1225, 0)) → 관문 (1260, 0) → 도착 지점 (1280, 0). 왕관 큰길(z 0)이 동쪽으로 이어지고, 남쪽 둘레길 '유적 길'은 (1300, 150)→(1700, 150). Lv25+, **PvP 극한**(빨강 경계).
- **분위기(ART_DIRECTION §6):** "부서지고 창백하게" — 옛 왕국이 무너진 **오래된 돌 유적**. 연보라 회색 돌, 부드러운 이끼, 빛바랜 보라 천, 은은한 연보라 영혼불, 푸른 달빛. 신비롭고 조용하게, **무섭지 않게**(아이용). 스토리 4장 「옛 왕국의 무덤」도 그림에서는 무덤이 아니라 "옛 왕국의 돌 유적"으로 보이게 한다.

## 그림체 꼬리말 (유적 공통 — 문구 = 머리 한 문장 + 물건 한두 문장 + 꼬리)
- **머리:** `Moonlit ruin colors: pale lavender-gray stone, soft moss green, faded purple cloth, gentle lavender glow, chunky rounded shapes with softly cracked edges.`
- **꼬리:** `Single standalone game prop for a cute toy-world kids RPG, chunky rounded toy proportions with slightly exaggerated soft bevels, smooth hand-painted toy plastic and painted stone materials, simple clean shapes with a few large color blocks, soft friendly colors, soft even studio light from the top left. Three-quarter front view from slightly above, the whole object fully inside the frame with a wide margin, centered, standing on nothing. Isolated on a plain flat medium gray background, no ground, no shadow, no other objects. No faces, no eyes, no skulls, no bones, no crosses, no graves. Wordless, blank unmarked surfaces.`
- 숲 꼬리와 같은 틀(재질만 painted stone, 색만 soft). 머리+꼬리 약 780자라 물건 문장은 200자 안쪽(전체 1000자 미만, 넘으면 Firefly 생성 버튼이 조용히 안 눌림).

## 지킬 것 (시안에 있어도 그리지 않음)
- **얼굴·눈 없음:** 시안의 얼굴 있는 돌 표지(눈·웃는 입)와 관문 위 둥근 돌 가면은 쓰지 않는다. 가면 자리 = **왕관 무늬 둥근 돌 메달**(얼굴 없음). 지도 v2 랜드마크 '돌 가면'도 '왕관 메달'로 바꿔 읽는다.
- **해골·뼈·피·무덤 없음:** 묘비·십자가·RIP·관은 없다. 지금 게임의 '묘비 16'은 **옛 돌 이정표/기념석**(둥근 머리 돌, 글자·얼굴·십자 없음)으로 바꾼다.
- **해골 몬스터와 다른 모양:** 뼈 같은 흰색, 갈비뼈·두개골 모양, 해골 기사 갑옷 무늬를 소품에 쓰지 않는다. 돌은 연보라 회색, 장식은 빛바랜 금·보라 천.
- **빨강 = 극한 PvP 경계 색:** 빨간 끝 말뚝 줄에만 쓴다. 다른 소품에는 빨강을 쓰지 않는다.
- **채집 노드 색 금지:** 하늘색 크리스털·구리색 광석처럼 보이는 장식은 피한다.
- 영혼불은 그림에서 돌 그릇 + 작은 연보라 빛까지만. 불꽃·빛은 Studio(Neon/파티클, PointLight는 맵 전체 40 제한 — 지금 유적 6개).

## 큰 것 (이미지 생성 1)
| 이름 | 모양 | 크기(스터드) | 개수 | 자리(v2, 제안) |
|---|---|---|---|---|
| R_BrokenTower | 반쯤 무너진 둥근 옛 성탑 + 앞면의 큰 둥근 돌 **왕관 메달**(얼굴 없음) + 꼭대기 연보라 영혼불 그릇 — 입구 랜드마크 | 높이 50~60 | 1 | (1560, -140) |
| R_Gate | 무너진 옛 왕국 성문: 둥근 돌탑 2 + 금 간 아치 + 부서진 성가퀴 + 빈 돌 간판(글자 SurfaceGui). `Gate_SkeletonRuins` + `Lintel` 유지 | 폭 26, 높이 22 | 1 | (1260, 0) |
| R_Arch_A/B | 부서진 돌 아치 2종(한쪽 무너짐 / 쐐기돌만 남음, 밑에 돌무더기) | 높이 18~20 | 3 | 퀘스트 M4-2 자리 3곳(개발 1이 v2로 옮김) |
| R_CrownAltar | 왕관 제단 폐허: 둥근 돌 단 + 계단 + 금 간 커다란 돌 왕관 조각(장래 해골왕 자리, 얼굴 없음) | 지름 30, 높이 10 | 1 | 동쪽 안쪽 (1700, 0) |
| R_WallRuin | 무너진 성벽 한 칸(성가퀴 들쭉날쭉, 이끼, 빈 창 하나만) | 폭 16, 높이 10 | 8+ | 가장자리·길 둘레 |
| R_Cliff_A/B | 판석이 겹친 연보라 바위 덩어리 2종(능선 앞 덧대기) | 폭 14~20 | 10+ | 북·남·동 능선 앞 |

## 작은 것 (이미지 생성 2) — 문구 `art/prompts/KIT_Ruins_<이름>.txt`, Studio 이름 `Kit_R_<이름>`
| 이름 | 모양(문구 요약) | 크기(스터드) | 개수 | 자리 |
|---|---|---|---|---|
| PillarA / PillarB | 부서진 둥근 홈 돌기둥 2종(받침·머리, 들쭉날쭉 끝, 금·이끼) | 높이 6~12 | 각 10+ | 기둥 광장·길가 |
| PillarFallen | 쓰러진 기둥 토막(굴러간 머리 조각) | 길이 10 | 6+ | 광장 둘레 |
| StoneMarker | 둥근 머리 옛 돌 이정표(이끼, 글자·얼굴·십자 없음) — 지금 '묘비' 대신 | 높이 3 | 16 | 흩어서 |
| SpiritBowl | 다리 셋 돌 그릇 + 연보라 잔빛(불꽃은 Studio) | 높이 3 | 6 | 지금 영혼불 자리 |
| Banner | 휜 장대 + 아래가 찢어진 빛바랜 보라 깃발(희미한 왕관 무늬만, 글자 없음) | 높이 8 | 4~6 | 길 양옆 (지금 4개 자리) |
| Rubble | 네모 돌 조각 무더기 2종 | 3~5 | 15+ | 아치·벽 밑 |
| StairsRuin | 이끼 낀 부서진 돌계단 조각 | 폭 6 | 4 | 제단·탑 앞 |
| StoneLantern | 둥근 갓 돌 등롱 + 연보라 빛(Neon) | 높이 5 | 8 | 큰길 양옆 |
| MoonFlowers | 은은히 빛나는 연보라 꽃 무더기(빛은 Neon) | 2 | 20+ | 바닥 덮개 |
| MossPatch | 이끼·풀 덮인 판석 조각 | 4 | 20+ | 바닥 덮개 |
| SignPost | 돌 받침 + 빈 판 2장 화살표 이정표(글자 SurfaceGui) | 높이 5 | 3 | 갈림길 |
| CrownPieces | 바닥에 흩어진 돌 왕관 조각 3~4개(금빛 테 흔적) | 3 | 6 | 제단 둘레 |

- 3D로 갈 것(나중 고급 + Tripo 후보): Pillar A/B, PillarFallen, StoneMarker, SpiritBowl, StoneLantern, SignPost, CrownPieces. 바위·이끼·꽃은 무료(Creator Store/생성) 먼저.

## 빈 땅 점검
- 왕관 큰길(z 0)과 유적 길(z 150) 양옆에 돌 등롱·깃발·기둥, 길 위는 비움.
- 40×40보다 큰 빈 땅 없음 — 판석·이끼·돌무더기로 채우되 해골 병사·기사 무리 자리는 비우고 둘레만 채운다.
- 입구(관문)에서 보이는 랜드마크 = 무너진 성탑 + 왕관 메달(높이 50~60, 영혼불).
- PvP 극한 경계: 빨간 말뚝 줄(지금 MapBuilder 계약)은 관문 바로 안쪽 그대로. 빨강은 이 줄에만.
