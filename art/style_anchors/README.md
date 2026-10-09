# 그림체 기준 그림 (SPEC A23-80 ②, 검수 2026-10-08)

새 그림·새 3D를 만들 때 해당 기준 그림을 Firefly/Tripo 참조로 넣는다. 옛 그림(UIP_*, art/out/v1, 노출 사본 4장, 치비 코스튬)은 참조 금지.

- `ui_icon.png` ← `art/ui/IconPotionHP.png` (복사함) — UI 아이콘 기준(→ art/style_anchors/ui_icon.png): 묶음 1 스타일 보드 마스터. 남색 굵은 외곽, 광택, 작은 금 장식. 보조 = art/ui/IconSkills.png(사용자 '너무 좋아'). 참조 금지 = UIP_* 전부, Codex 10/03 Weapon 1024 파일
- `ui_panel.png` ← `art/ui/PanelMain.png` (복사함) — UI 창·틀 기준(→ ui_panel.png): 고급 스타일 보드 마스터(남색 테, 금 줄, 사파이어 모서리, 크림 속). 버튼은 art/ui/BtnPrimary.png를 같이 넣음. PanelParchment·Pill 같은 옛 크림 틀은 참조 금지
- `character.png` ← `art/ui/PTR_TownSmokey.png` (복사함) — 캐릭터 기준(→ character.png): 고급, '마을 NPC 초상 그림체 기준'(approved.json). 블록 장난감 몸, 얼굴·손만 드러남. 전신 블록 캐릭터·3D 원본은 art/review/b1/CLS_HaloWarrior_M_cut.png(스타일 보드 고름 3)를 같이 넣음. art/models/costume/** 치비, UIP_Char*는 참조 금지
- `monster.png` ← `art/out/CON_SlimeCube.png` (복사함) — 몬스터 기준(→ monster.png): 첫 사냥 몬스터 컨셉. 광택 젤리 장난감, 검은 타원 눈 + 하이라이트, 얼굴 표식 없음. 3D 완료
- `terrain.png` ← `art/ui/Tex_Grass_FF2.png` (복사함) — 지형 타일 기준(→ terrain.png): 시안 잔디 색(172,197,82)에 맞춘 이음매 없는 타일, 3×3 검사 통과. 다른 구역 타일도 이 붓질과 밝기에 맞춤
- `zone_<구역>.jpg` ← `art/review/concept/Concept_<구역>.jpg` (7개 모두) (복사함) — 구역 장면 색·조명 기준(→ zone_<구역>.jpg): 구역마다 art/review/concept/Concept_<구역>.jpg를 하나씩 둠. 주의: Concept_SlimeMeadow의 둥근 슬라임 석상은 IP 금지(빨간 X)라서 잘라낸 판만 참조함 (→ A23-93: 장소 기준은 새 시안 묶음(전체 1 + 부분 5, 고급). 10/09 기준 묶음이 있는 곳 = 빛·뿔 마을·호박밭·유령 숲 `art/review/s2/place_<구역>_sheet.jpg`, 원본 `art/out/s2/places/`)
- `prop_crossroads.png` ← `art/out/hq/HQ_Kit_X_PlazaWall.png` (복사함) — 교차로 소품 기준(→ prop_crossroads.png): 따뜻한 베이지 돌 + 이끼·꽃, 시안 계단·담에서 잘라 만든 고급. 청록은 길드 표시에만
- `prop_meadow.png` ← `art/out/hq/HQ_Kit_M_MeadowArch.png` (복사함) — 말랑 초원 소품 기준(→ prop_meadow.png): 갈색 나무 + 진초록 덩굴 + 흰·노랑 꽃, 시안 참조 고급. 파스텔 Kit_M_* 묶음은 참조 금지
- `prop_woods.png` ← `art/out/hq/HQ_W_Gate.png` (복사함) — 고블린 숲 소품 기준(→ prop_woods.png): 초콜릿 나무, 밧줄, 이끼, 호박색 등불(고급). 나무는 art/out/hq/HQ_W_Tree_A.png를 같이 넣음
- `prop_halo.png` ← `art/out/hq/HQ_Town_Halo_KnightStatue.png` (복사함) — 빛 마을 소품 기준(→ prop_halo.png): 흰 대리석 + 금 + 하늘색 천, 얼굴 없는 투구(고급). 빛 마을 분수(HQ_Town_Halo_Fountain.png)도 빛 마을 기준으로만 씀
- `prop_horns.png` ← `art/out/hq/HQ_Town_Horns_Castle_v4B.png` (복사함) — 뿔 마을 소품 기준(→ prop_horns.png): 사용자가 고른 뿔 성 v6mv의 앞모습(숯검정 돌, 빨간 지붕, 금, 용암은 밑단). 적갈색 문·벽·가게를 맞출 기준
- `prop_ruins.png` ← `art/out/hq/HQ_R_Arch_A.png` (복사함) — 해골 폐허 소품 기준(→ prop_ruins.png): 회색 연보라 돌 + 이끼 + 보라 천, 해골·얼굴 없음. PillarA·StoneMarker 색을 맞출 기준
- `prop_pumpkin.png` ← `art/out/hq/HQ_Kit_P_PumpkinCluster.png` (복사함) — 호박밭 소품 기준(→ prop_pumpkin.png): 통통한 골 호박 + 덩굴 + 흙, 조각하지 않음, 얼굴 없음(고급)
- `prop_hollow.png` ← `art/out/hq/HQ_H_TreeTwisted.png` (복사함) — 유령 숲 소품 기준(→ prop_hollow.png): 굵게 꼬인 줄기 + 보라 잎 덩어리, 페인트 질감(고급). GF_* 옛 무료 메시는 참조 금지
- 초원 시안(zone_SlimeMeadow.jpg)의 둥근 물방울 슬라임 석상은 IP 금지(빨간 X) — 그 부분은 참조하지 않는다.
