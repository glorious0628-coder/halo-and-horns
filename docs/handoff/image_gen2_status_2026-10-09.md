# 이미지 생성 2 상태 (2026-10-09 밤)

## 끝난 것
- 빛 마을 건물 8개 뒤·좌·우 24장 (고급 5크레딧 × 24 = 120) — Gate, Tower, Cathedral, DomeHouseA, DomeHouseB, Shop, Statue, ArchBridge. 파일 `art/out/s2/halo/HaloProp_<이름>_{front,back,left,right}_HQ_src.png`(1024², 회색 바탕), 시트 `art/review/s2/halo_mv_<이름>.jpg`(`py tools/_img2_sheet.py <이름>`), 프롬프트 `art/prompts/HaloProp_<이름>_{back,left,right}.txt`(`tools/_halo_prop_mv_prompts.py`, 둥근 집·가게 차양은 앞쪽 벽에만 평평하게 — 검수 지적 반영).
- 분수(Fountain)는 앞면만(검수 OK).

## 방법 (새 Firefly 화면, 10/09)
- 프롬프트 칸이 textarea가 아니라 ProseMirror(`div.ProseMirror[contenteditable]`): `focus` → `execCommand('selectAll')` → `execCommand('insertText')`. 3번째 선택(품질)은 low/medium/high 그대로, 모델 값 `openai:firefly:colligo:gpt-image-2.5-prism`(화면 이름 "GPT Image 2.5 Sunburst"), 비율 1:1 값 `{"height":1024,"width":1024}`.
- 참조: Adobe MCP로 앞면 PNG 올리기(asset_initialize_file_upload → curl PUT → finalize) → presignedAssetUrl을 페이지에서 fetch → `input#file-input`에 넣기.
- 결과 받기: asset_search(GenAIAsset, 이미지 mediaType 필터, createDate desc)가 소리 세션 오디오·이미지 생성 1 그림과 섞이므로 query/시각으로 구분 → asset_get_presigned_urls의 **downloadUrl**(1024 PNG; renditionURL은 600px JPEG라 쓰지 말 것).
- 한 장 약 50~60초. 기다릴 때 javascript_tool은 45초 안에 끝나야 함.

- 한 장짜리 소품 11개(고급): `art/out/s2/halo/HaloProp_<이름>_front_HQ_src.png`, 시트 `art/review/s2/halo_props_singles_sheet.jpg`. 구름 덤불·바다 바위 아치·둥근 나무는 첫 판이 어긋나(화분·탑·받침대가 붙음) v2로 다시 그림: `..._front_v2_HQ_src.png`, 시트 `halo_props_redo_sheet.jpg` → 이 셋은 v2를 쓸 것.
- 뿔 성채 시안 1장(고급): `art/out/s2/horns/HornsProp_Castle_front_HQ_src.png`, 시트 `art/review/s2/horns_castle_front.jpg`, 프롬프트 `art/prompts/HornsProp_Castle_front.txt`(뿔 마을 시안 문 패널을 스타일 참조).

## 크레딧
- 오늘 밤 고급: 뒤·좌·우 24 + 소품 11 + 성채 1 + 소품 다시 3 = 39장 = 195크레딧. 잔액은 마지막 확인값 7885(10/09 06:29 UTC 계정 전환 전) 기준 약 7,700대 추정 — 정확한 값은 Firefly 화면에서 다음에 확인.

## 남은 것 (검수 큐)
1. 뿔 마을 소품 멀티뷰·한 장짜리(`docs/design/horns_town_plan_2026-10-09.md` 표): 문·감시탑·전쟁 천막·노점·나무집·돌다리는 멀티뷰, 모닥불·말뚝 울타리·화로·등불·깃대·침엽수·현무암 기둥·통/상자는 한 장.

## 10/10 아침 추가
- 빛 마을 가게 간판 4종(고급, 물약 v2·빵집·주스·꽃; 장난감은 검수가 뺌): `art/out/s2/halo/HaloSign_*_front_HQ_src.png`, 시트 `art/review/s2/halo_signs_sheet.jpg`. 프롬프트 `tools/_halo_npc_sign_prompts.py`.
- 빛 마을 NPC 5명 전신 후보(중간): `art/out/s2/npc/NPC_Halo<이름>_{A,B}_src.png`(+FlowerGirl C·D), 시트 `art/review/s2/halo_npc_candidates_sheet.jpg`, 추천 `halo_npc_picks_sheet.jpg`. 사용자 승인 대기 → 승인되면 앞면을 참조로 뒤·좌·우(고급).
- 뿔 마을: 앞면 22 + 성채 1(고급) → `art/out/s2/horns/HornsProp_<이름>_front_HQ_src.png`(+ v2: RockColumnB·C·Pine), 건물 9개 + 성채 뒤·좌·우 30장 → `..._{back,left,right}_HQ_src.png`, 시트 `art/review/s2/horns_*`. 도구 `tools/_horns_prop_prompts.py`, `_horns_prop_mv_prompts.py`, `_img2_sheet_horns.py`. StallSmith는 앞면만(뒤·좌·우 건너뜀, 검수 결정 대기).
- 방법 메모(10/10): 숨김 창에서도 프롬프트 입력·생성은 돌아감(새로고침 금지). Adobe 참조 링크(at.adobe.com)는 몇 시간 뒤 403 → 다시 올림. 새 asset_search는 이미지 mediaType 필터 + 시각 순서로 매핑.
- 크레딧(10/10 아침까지 고급): 간판 6 + 뿔 앞면 18+3 + 성채 1 + 뒤·좌·우 30 + 빛 소품 v2 등 = 약 300(어젯밤 분 제외). 화면 잔액은 다음에 확인.

## 10/10 오전 추가
- 빛 마을 NPC 5명 뒤·좌·우 15장(고급): `art/out/s2/npc/NPC_Halo<이름>_{back,left,right}_HQ_src.png`, 시트 `art/review/s2/halo_npc_mv_sheet.jpg`. approved.json에 NPC_Halo*·HaloSign_* 키(승인 2026-10-10).
- 새 탑(사람 키 문, 땅 높이): `art/out/s2/halo/HaloProp_Tower_v2_{front,back,left,right}_HQ_src.png`, 시트 `art/review/s2/halo_tower_v2_sheet.jpg`.
- 바닥 메달리온(후보 A 월계수 + 후광 고리 고름, B·C는 후보): `art/out/s2/halo/HaloFloor_Medallion_A_HQ_src.png`(원본), `..._HQ_cut.png`(1024² 투명 원형 PNG, `tools/_img2_circle_cut.py`), 시트 `halo_medallion_cut_check.jpg`, 후보 시트 `halo_tower_medallion_sheet.jpg`.
- 남은 큐(사용 한도 때문에 초기화 뒤): 깨진 왕관 새 그림(후보 중간 3 → 검수가 고름 → 4면), StallSnack(앞 + 뒤·좌·우), A23-106 건물 실내 시안(대성당·돔집·물약·빵집·주스·꽃).

## 10/10 낮 추가 (A23-107)
- 납작한 장식(빛 마을) 고급 + 투명 PNG: 세로 깃발 2종·금 방패·둥근 창·문 위 후광 장식·차양 → `art/out/s2/halo/deco/HaloDecoHQ_<이름>_{src,cut}.png`, 확인 시트 `art/review/s2/halo_deco_cut_check.jpg`(후보 시트 halo_deco_candidates_sheet.jpg, 방패 재시도 halo_shield2_sheet.jpg). 방패 문장 첫 판은 깃발꼴이라 금 방패로 다시.
- 왕관 부품(금 반쪽·붉은 반쪽·루비·사파이어·후광 고리·금 간 자국) 앞 6 + 뒤·옆 9 → `art/out/s2/crown/`, 시트 `crown_parts_front_sheet.jpg`·`crown_parts_mv_sheet.jpg`.
- 남은 큐: 빛 마을 문·대성당·탑 부품(이미지 생성 1과 접합 기준 맞춤 대기) → StallSnack → 실내 시안 → 뿔 성채 부품·붉은 깃발·황소 문장.

## 10/10 오후 추가 (A23-107 부품별)
- 빛 마을 부품 2D(고급, 재사용 없이 새로, `docs/design/halo_parts_plan_2026-10-10.md` 기준): `art/out/s2/halo/parts/HaloPart_<부품>_{front,back,left,right}_HQ_src.png`, 시트 `halo_parts_{gate,cath,tower}_{front,mv}.jpg`. 입체 부품은 4면, 평면(문짝·창)은 앞 + 뒤. 도구 `tools/_halo_parts_prompts.py`, `tools/_img2_parts_sheet.py`.
- 뿔 마을 StallSnack(뜨거운 간식 노점) 4면(StallSmith 대체), 장식 6종 투명 PNG, 왕관 부품 15장(`art/out/s2/crown/`).
- 남은 큐: 빛 마을 반복 소품 종류별 새로(이미지 생성 1 목록 대기), 실내 시안(24장 중간 재시도), 뿔 마을 성채 부품·붉은 깃발·황소 문장.

## 10/10 오후 추가 2
- A23-106 실내 시안 24장(중간, 0크레딧): `art/out/s2/interior/Interior_<Cathedral|DomeHouse|PotionShop|Bakery|JuiceShop|FlowerShop>_{whole,part1,part2,part3}.png`, 시트 `art/review/s2/halo_interior_sheet.jpg`(c1655ea). 검수가 고르면 고급으로 다시.
- 빛 마을 반복 소품 새 종류 각 4가지(고급, 화분·난간·등불·꽃항아리·구름덤불·토피어리·둥근나무) → `art/out/s2/halo/variants/HaloVar_<종류>_{A..D}_HQ_src.png`, 시트 `art/review/s2/halo_variants_sheet.jpg`. 구름덤불 첫판은 금 돔·깃발이 붙어서 `HaloVar2_CloudBush_*`로 다시(구름만). BannerPole·다른 종류는 이미지 생성 1 목록 오면. 도구 `tools/_img2_grid_sheet.py`.
- 남은 큐: 뿔 마을 성채 부품·붉은 깃발·황소 문장, 빛 마을 집·가게 부품(문틀·문짝·창).

## 10/10 오후 추가 3 (검수 지적 반영)
- 깃발·후광 고리 뺀 부품 앞면 v2 8장(고급): `art/out/s2/halo/parts/HaloPart_{CathBody,CathTowerA,CathTowerB,CathDome,TowerDome,TowerDoorFrame,GateLantern,GateTowerR}_v2_front_HQ_src.png`, 시트 `art/review/s2/halo_parts_fix_front.jpg`. 도구 `tools/_halo_parts_fix.py`. 옛 뒤·좌·우(깃발·고리 붙은 것)는 쓰지 말 것 — v2 앞면 통과 뒤 다시.
- 큐(Firefly 숨김 창): 왕관 붉은 반쪽 새 3안(중간) → 반복 소품 새 14종 + 빛 마을 돔집 12·가게 4·계단 3·작은 다리 3·깃대 3(앞면 고급).
- 남은 큐: 뿔 마을 소품 7장 재작업(검수 지적: 장식 과다 제거), 직업 무기 9종(A23-108) 멀티뷰.

## 10/10 오후 추가 4 (큐 처리 결과)
- 왕관 붉은 반쪽 새 3안(중간): `art/out/s2/crown/CrownNew_{A,B,C}_src.png`, 시트 `art/review/s2/crown_new_candidates.jpg` — 검수 선택 대기(추천 A 반구+아치, 차선 C).
- 반복 소품 부족분 14(`HaloVar3_*`, 시트 halo_variants3_sheet.jpg), 돔집 12(`art/out/s2/halo/houses/`), 가게 4·계단 3·다리 3·깃대 3(`.../shops,stairs,bridges,poles/`, 시트 halo_shops_stairs_bridges_sheet.jpg·halo_flagpoles_sheet.jpg).
- 뿔 마을 소품 재작업 8(`HornsProp_*_v2_front_HQ_src.png`, 시트 horns_fix_sheet.jpg, 도구 `tools/_horns_prop_fix.py`).
- 직업 무기(A23-108) 앞 10(+연금술사 v2)·뒤·옆 18: `art/out/s2/weapons/Weapon_<진영_직업>_{front,back,edge}_HQ_src.png`, 시트 `weapons_front_sheet.jpg`·`weapons_mv_sheet.jpg`(연금술사는 병+막대 두 점이라 앞면만), 도구 `tools/_weapon_prompts.py`.
- 부품 앞면 v2 8장은 검수 통과 대기 → 통과하면 뒤·좌·우. 실내는 베타 뒤(중간 24장 보관).
- Firefly 참조 링크(at.adobe.com)는 몇 시간 뒤 만료: `build/img2_halo_mv/refs3.json`(10/10 04:40 UTC 업로드). 재업로드는 asset_initialize → curl PUT → asset_finalize.

## 10/10 오후 추가 5 (뿔 마을 성채·문 부품)
- 앞면 17장 + 재작업 3(본관 v2·문짝 L·R v2: 아치 윗면): `art/out/s2/horns/parts/HornsPart_<이름>[_v2]_front_HQ_src.png`, 시트 `art/review/s2/horns_parts_front_sheet.jpg`·`horns_parts_fix_sheet.jpg`, 도구 `tools/_horns_parts_prompts.py`. 깃발·등불·불꽃·후광·용암빛 안 구움. 황소 방패는 밖으로 뿔이 붙은 모양.
- 남은 큐(검수 통과 후): 입체 부품 4면 — 빛 마을 부품 v2 8개(뒤·좌·우), 뿔 부품 12개(본관·탑 L·R·성벽 A·B·문틀·계단·뿔 L·R·기둥 L·R·상인방), 납작(깃발 2·문짝 2·방패)은 앞·뒤. 왕관 3안 선택 후 4면+부품.
- 이 세션은 한 사용자 턴에 피어 메시지 10건 한도에 걸림 → 사용자 메시지가 와야 다시 보낼 수 있음. 검수는 이 문서와 최종 보고로 확인.

## 10/10 저녁 추가 6
- 빛 기사 마스코트 머리카락 새 후보 4(중간): `art/out/s2/fac/hair/Fac_MascotHalo_Hair_{A..D}_src.png`, 시트 fac_mascot_halo_hair_candidates.jpg — 검수 2장 선택 대기.
- 집 차양·나무 색 바꿈(PIL 색상 이동): `houses/HaloDomeHouse_{02,06,10,12}_front_HQ_recolor.png`, 사과 금빛 열매·버들 초록 `HaloVar3_RoundTree_{E,F}_HQ_src`(원본 *_orig).
- 무기 고침 3(광전사 v2·조련사 v2, 연금술사는 v3 불합격 → v4 큐)·계단 4·5·반달 다리 v2·깃대 3 v2: `art/out/s2/redo/`, 시트 redo_weapons_stairs_sheet.jpg.
- 지붕 다시 7(집 01·05·07·11·12, 꽃집 유리 온실, 주스 줄무늬 지붕): `art/out/s2/halo/roofs/`, 시트 halo_roofs_v2_sheet.jpg.
- 큐 진행 중: 부품 v2 8개 뒤·좌·우 24장 → 연금술사 v4·왕관 A 앞(와인빛)·뿔 깃대(천 없음)·뿔 문장 천(뿔 한 쌍).
- 남음: 왕관 A 4면+부품, 반복 소품 13장 깃발 빼기, 집·가게 12+4 뒤·옆(부품 분해 halo_parts_plan), 뿔 성채는 A23-112 대칭 콘셉트 뒤.

## 10/10 밤 추가 7
- 부품 v2 8개 뒤·좌·우 24장 `art/out/s2/halo/parts/HaloPart_<이름>_{back,left,right}_v2_HQ_src.png`(시트 halo_parts_v2_mv_sheet.jpg). 본관 오른쪽은 첫 판이 앞면처럼 넓게 나와 `HaloPart_CathBody_right_v3_HQ_src.png`(좁은 끝벽)가 최종. 문 오른 탑·작은 탑 뒤는 민벽.
- 지붕 다시 7: `art/out/s2/halo/roofs/`. 왕관 A 앞(와인빛, 고급) `art/out/s2/redo2/CrownA_front_v2_HQ_src.png`, 뿔 깃대(천 없음)·뿔 한 쌍 문장 천·연금술사 병 하나 v4(`redo2/`).
- 큐: 왕관 A 3면 + 부품 6(금 반구·와인 반구·가운데 아치·꼭대기 구슬·사파이어·가넷).
- 남음: 반복 소품 13장 깃발·금돔 빼기, 집·가게 뒤·옆(부품 분해), 뿔 성채는 A23-112 대칭 콘셉트 뒤.

## 10/10 밤 추가 8
- 왕관 A(와인빛) 4면 + 부품 7(금 반구·와인 반구·가운데 아치 v2·꼭대기 구슬·사파이어·가넷): `art/out/s2/crown/A/`, 시트 crown_A_mv_parts_sheet.jpg.
- 반복 소품 13장 깃발·파란 판·금돔 뺀 판(난간 4·등불 4·플랜터 2·꽃 화분 3): `art/out/s2/halo/variants4/HaloVar4_*`, 시트 halo_variants4_sheet.jpg — 옛 HaloVar_Balustrade/Lantern/Planter_A,D/PotFlowers_A,C,D 대체.
- 대기: 마스코트 머리카락 선택, 집·가게 뒤·옆, 뿔 성채(대칭 콘셉트 뒤).

## 10/10 밤 추가 9
- 빛 기사 마스코트 C 고급+누끼: `art/out/s2/fac/hq2/`(approved 키 FacMascotHaloC) → 이미지 개발에 교체 요청.
- 장인 길드 Coming soon 카드 후보 3(중간): `art/out/s2/fac/artisan/Fac_ArtisanCard_{A,B,C}_src.png`, 시트 `art/review/s2/fac_artisan_card_candidates.jpg` — 검수 선택 대기(망치·모루 문장, 자물쇠, 글자 없음).
- 뿔 깃대 v4(L자 팔·걸이, 십자가 모양 아님): `art/out/s2/redo2/HornsProp_BannerPole_v4_front_HQ_src.png`.
- 남음: 뿔 천 뒷면, 집·가게 뒤·옆(부품 분해: 몸통·지붕·문·창 유리·차양 따로).

## 10/10 밤 추가 10
- 장인 카드 B 고급+누끼: `art/out/s2/fac/artisan/Fac_ArtisanCard_B_HQ_{src,cut}.png`, approved 키 FactionPickSoon → 이미지 개발.
- 뿔 깃대 v5(갈고리 뺌, 팔 끝 창끝 장식 + 짧은 쇠띠 둘) `redo2/HornsProp_BannerPole_v5_front_HQ_src.png`, 뿔 천 뒷면 `redo2/HornsBannerCloth_back_HQ_src.png`.
- 남음: 집·가게 뒤·옆(부품 분해).

## 10/10 밤 추가 11
- 집 12·가게 4 뒤·좌·우 48장(고급): `art/out/s2/halo/houses_mv/<건물>_{back,left,right}.png`, 4면 시트 halo_houses_mv_sheet_1·2.jpg, halo_shops_mv_sheet.jpg. 기준 앞면 = 지붕 v2(01·05·07·11·12, 주스·꽃집) + 차양 색 바꾼 판(02·06·10·12). 뒤 = 창 2개·문 없음, 옆 = 큰 아치창 1개.
- 뿔 마스코트 새 후보 5(중간, 빛 C 그림체) `art/out/s2/fac/horns2/` — 검수 선택 대기.
- 부품 분해(몸통·지붕·문·창 유리·차양)는 각 건물 4면 + 지붕 v2 앞면으로 이미지 생성 1이 Tripo 때 나눔(별도 부품 그림 필요하면 요청).

## 10/10 밤 추가 12
- 뿔 마스코트 D 고급+누끼(approved FacMascotHornsD) → 이미지 개발에 교체 요청. 빛 C·뿔 D 둘 다 높이 1024 기준.
- 스킬 Q 아이콘 6 후보 12(중간, A23-116): `art/out/s2/skills/SkillQ_<HaloSlam|CraterSmash|StarFall|PurplePop|FeatherRain|SparkShower>_{A,B}.png`, 시트 `art/review/s2/skill_q_icon_candidates.jpg` — 검수 선택 대기(빛 = 크림~하늘색+금 테 배지, 뿔 = 자두색+진홍 테 배지, 글자·빛줄기 없음).
- 뿔 스킬 Z·X·빛 Z·X 12개 아이콘은 Q 승인 뒤.

## 10/10 밤 추가 13
- 검수 10/10 선택(Q 6) → High 12장(5크레딧×12) → 6장 골라 누끼: `art/out/s2/skills_final/Skill_{Warrior,Mage,Archer}_Q_{Halo,Horns}.png`(512 RGBA), 원본 `art/out/s2/skills_hq/`, 확인 `art/review/s2/skill_q_hq_check.jpg`·`skill_q_final_cut_check.jpg`. approved.json `SkillQ_Icons`, 프롬프트 `art/prompts/SkillQ_Icons_HQ.txt`. 누끼 도구 `tools/_img2_circle_cut2.py`는 안 쓰고 cutout_flat 사용(배지 밖으로 나온 후광·칼자루 보존).
- 다음: 이미지 개발이 업로드·`Skill_<Class>_Q_<Faction>` 교체, 나는 Z·X 12개(같은 틀).

## 10/10 밤 추가 14
- 스킬 Z·X 아이콘 12종 중간 후보 24장(A/B): `art/out/s2/skills_zx/SkillZX_<WarriorZ|WarriorX|HornsWarriorZ|HornsWarriorX|MageZ|MageX|HornsMageZ|HornsMageX|ArcherZ|ArcherX|HornsArcherZ|HornsArcherX>_{A,B}.png`, 시트 `art/review/s2/skill_zx_icon_candidates.jpg`(줄마다 두 스킬, 각 A·B). 검수 선택 대기 → 고급 → 누끼 → 이미지 개발. (새·박쥐는 점 눈 + 미소 — 문서대로.)
