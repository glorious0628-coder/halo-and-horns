# 이미지 생성 2 상태 (2026-10-06, 사용자 지시로 중지 — 계정 이동)

규칙·할 일 순서: `docs/design/image_gen2_session_handoff_2026-10-06.md`. 크레딧: 지금까지 **0**(Firefly GPT Image 2.5 Sunburst, 중간만).

## 끝난 것 (커밋·푸시됨, 검수 OK, 이미지 개발에 파일·키 전달)
| 묶음 | 커밋 | 시트 | 내용 |
|---|---|---|---|
| 2 진영 화면 9 | 5d16034 | `art/review/s2/b2_faction_sheet.png` | FactionCardHalo/Horns/Artisan, FactionTitle·Premise·Footer, ClassCardHalo/Horns/Artisan(→Config ClassCardNeutral). 글자 칸 분수 = approved.json `layout`, 9조각 = `slice` |
| 4·5 공통 창·HUD 14 + 아이콘 4 | 7a7d26e | `art/review/s2/b45_common_ui_sheet.png` | PanelDark·PanelHeader·TitleRibbon·BtnSecondary·BtnConfirm·BtnSquare·BtnRound·ListRow·Chip·DialogBox·GlyphClose·StatusPlate·BarTrack·BarFill + IconSafe·IconHammer·IconBoot·IconAttack (`slice` 있음) |
| 7 가방 등급 칸 6 + 글리프 7 | f03d940 | `art/review/s2/b7_slots_glyphs_sheet.png` | A23-32 어두운 칸(본체 Rect 36,40,476,480 / 아이콘 76,80,436,436), SlotRare가 크림 마스터 대체(옛 기록 `SlotRare_CreamMaster`), GlyphBow·Bag·Map·Menu·Shrink·Expand·Sort |
| 8·9 아이콘 8 + 퀘스트 마커 2 | 7b4fe91 | `art/review/s2/b89_items_marker_sheet.png` | IconPotionMP, Weapon_{Warrior,Mage,Archer}_T8, Star(흰색), IconCoin, IconSprout, IconWantedStar, IconQuestMarker·IconQuestMarkerArrow(A23-36, 흰색) |
| 14 Q 스킬 3 + 도구 | ae9a7ea | `art/review/s2/b14_skillq_sheet.png` | Skill_Warrior_Q·Skill_Mage_Q·Skill_Archer_Q, `tools/img2/`(누끼·검사 도구) |
| 10 직업 그림 8 + 11a 초상 3 | 97456b9 | `art/review/s2/b10_class_guide_sheet.png` | **사용자 확인 전 — 업로드 금지.** 파일은 `art/review/s2/human/`(art/ui 아님), approved.json status `pending-user`. 옷차림 검사 통과. 빛 전사 마스터는 `art/review/b1/CLS_HaloWarrior_M_cut.png`(역시 pending-user) |

- 이미 끝나 있어 다시 안 그린 것: 주문서(IconScrollEnh/Move + Band), 젤리, 사탕, 아기 슬라임, 특성 아이콘(묶음 3).
- 취소: A23-35 그림 글자(사용자 정정 — 모든 글자는 TextLabel). make_title·글꼴 4개 지움(커밋 전이라 흔적 없음).

## 받았지만 커밋 안 한 것 / 생성됐지만 아직 안 받은 것
- 로컬 `art/out/s2/`에 안 고른 원본(_src)이 많이 있음(커밋 안 함, 지워도 됨).
- Firefly에 생성은 됐지만 **아직 내려받지 않은 것**(asset_search에서 문구 첫머리로 찾기):
  - A23-38 메뉴: `IconSettings`(a·b, "Game menu icon of a settings gear"), `IconNews`(a·b, "Game menu icon of fresh news"), `UIP_MenuTile`(a·b, "One square game menu tile").
  - 안내자 초상 b안 3장(필요 없음, a안으로 골라 둠).
  - 묶음 12 일부 a안: UIP_ListRowSelected_a, UIP_Toast_a, UIP_BannerGold_a, UIP_NameTag_a, UIP_WarMeterFrame_a(마지막 것은 생성 중에 멈춤).
- 문구 파일은 모두 `art/prompts/`에 있음(묶음 12·13 20개 + IconSettings·IconNews·UIP_MenuTile 포함, 아직 커밋 안 함 — 다음 세션이 그림과 같이 커밋).

## 다음 할 일 (순서)
1. **사용자 확인:** b10 시트(직업 그림 9 + 초상 3)를 사용자가 보면 → approved로 바꾸고 `art/review/s2/human/*.png`를 `art/ui/`로 옮겨 커밋 → 이미지 개발에 전달(키: CLS_*, PTR_Guide*; Config CharHalo... 자리).
2. A23-38: IconSettings·IconNews·UIP_MenuTile 내려받기 → 고르기 → 6칸 가로 줄 시안(PC 64·폰 48, 승인 메뉴 아이콘 5장 8875c87과 같이) → 커밋 → 이미지 개발.
3. 묶음 12·13(20장) 생성 이어서: 아직 시작 안 한 것 = WarCrownPip, QuestRow, AutoRingOn, NpcMarkerBubble, RewardRays(검정 바탕, 밝기→투명), TabOn, TabOff, InputField, QuestTab, BannerAlert, GlyphQuest·Auto·Back·Lock·Check + 전부 b안.
4. 묶음 15·16 무기 T1~T6, 17 펫 배지·감정 스티커(글자 없이), 19 직업 그림 나머지 9(같은 직업 그림을 문구로 맞춤).
5. 상점 NPC 최종 모습, 옷·방어구·액세서리, 몬스터 콘셉트.

## 브라우저·요령
- 내 Firefly 탭은 내장 브라우저 **"tab-1"**(대기열 `window.__s2_Q3`, 지금 `__s2_stop=true`로 멈춤). **"seed"는 이미지 생성 1의 탭 — 절대 건드리지 않는다.** 새 세션이면 `preview_start(url)`로 새 탭을 열고 `__s2_` 접두어 함수를 다시 정의(로그인·모델 Sunburst `gpt-image-2.5-prism`·품질 `medium`·비율 확인).
- 생성은 대기열(JS)로: 진행 원·`pending`이 사라진 뒤 생성 버튼, 비율은 `sp-menu-item[aria-label="정사각형 (1:1)"]` 클릭, 문구는 `execCommand('insertText')`.
- 내려받기: `asset_search`(GenAIAsset)에 **문구 첫머리를 그대로 query로**(짧은 일반어는 일부만 나옴) → `asset_get_presigned_urls` → `curl -sL` → `art/out/s2/`.
- 누끼: 외곽선 있는 UI·아이콘은 기본 tol 48, **외곽선 없는 사람 그림은 `--tol 28 --soft 6`**(옷 그늘이 회색 배경과 섞여 뚫림). 떠 있는 반짝이는 문구에서 'glow and sparkles'를 빼고 'crisp hard edge … one single solid object' 문구로. 도구 설명은 `tools/img2/README.md`.

## 새 계정 진행 (2026-10-06 오후, 한도로 다시 멈춤 — 1시 40분 이후 재시작)
- 끝: 471686b 메뉴 칸 판·IconSettings·IconNews / 50bf8ea 직업 8 + 초상 3 사용자 OK → art/ui(장인 궁수 거절, A23-39 펫 조련사로) / 이번 커밋 = 묶음 12 일부 5(ListRowSelected·Toast·BannerGold·WarMeterFrame·WarCrownPip, 시트 art/review/s2/b12_part1_sheet.png) — 이미지 개발에 아직 안 알림.
- 생성 중이던 것: 펫 조련사 a(CLS_ArtisanTamer_M, 2:3, 문구 art/prompts/CLS_ArtisanTamer_M.txt) — asset_search "An artisan guild pet tamer boy"로 받아 누끼 → 장인 직업 카드 시트로 사용자 확인. 내 탭은 이제 "tab-4"(JS __s2_all/__s2_setPrompt/__s2_gen, 모델 Sunburst·중간 확인됨).
- 다음: 펫 조련사 b → 묶음 12·13 남은 15장(NameTag·QuestRow·AutoRingOn·NpcMarkerBubble·RewardRays·TabOn/Off·InputField·QuestTab·BannerAlert·Glyph 5) + ListRowSelected b(더 진한 금빛) → 15·16 무기(지휘봉 포함) → 17 → 19. 크레딧 0.

## 재시작 뒤 (2026-10-06 오후 2, 크레딧 0)
- 커밋: 7f56285 펫 조련사(남, pending-user) · a601f39 묶음 12·13 16장 · 83eaffb 둥근 미니맵 틀 · 38ea615 무기 23장(T1~T6 + 조련 지휘봉) + 느낌표 · 0a5603a 묶음 17(배지·스티커·거위·클로버) · af64891 묶음 19 반대 성별 9 + 상점 NPC 2(pending-user) + 승인 사람 그림 11장 발밑 그림자 정리(재업로드 요청) · 81ec677 TitleRibbon slice [118,40,394,95]. 모두 이미지 개발에 전달.
- 사용자 확인 대기: 펫 조련사 남(b10_tamer_sheet) + b19_people_sheet(9 + NPC 2). OK 오면 approved → art/review/s2/human/*.png를 art/ui로 → 이미지 개발.
- 진행 중: A23-45 유령 가족 시안(CON_GhostMinion_A/B, CON_GhostKing_A/B, 각 2장) → 시트·사용자 고르기 → IconMonGhostMinion/King → 시안 경로를 이미지 생성 1에게. 그다음 묶음 18 작은 것(LogoPlate·EventBannerHalloween·MapParchment·Shard_Base·IconAltar, 대기열에 있음).
- 브라우저: 내 탭 "tab-1"(seed는 이미지 생성 1). JS __s2_Q/__s2_run/__s2_log 대기열(첫 생성 뒤엔 execCommand insertText + ' '/delete로 버튼이 켜짐). 다운로드는 __s2_log 클릭 시각 ↔ asset createDate(약 +20초)로 짝지음.
- 도구: tools/img2/clean_haze.py(사람 그림 발밑 그림자·회색 얼룩, 작은 점) — 사람 그림 누끼 뒤 항상.
- 남은 것: 옷·방어구·액세서리는 정식 이후(A23-21). 정식용 후보(BadgeDot·Toggle·GlyphGear/Paw·PetPaw·PetStat·재료 4·Map_* 지도 아이콘·랭크 배지)는 검수 지시 뒤에.

## 오후 3 (2026-10-06, 크레딧 0)
- 커밋: 2975f24 사람 그림 14장 사용자 OK → art/ui · 95e33ae 유령 가족 시안 8 · 2440d24 유령 아이콘 2(고름 A1·A2) + 묶음 18 작은 것 5(LogoPlate·EventBannerHalloween·MapParchment·ShardBase·IconAltar) · 9a8b47a 지도 표시 6 + BadgeDot·IconPetPaw·GradeSlotBack. 펫 속도 = IconBoot 공용(검수).
- 규칙(검수 전달): 사용자 확인·고르기는 검수에게(시트 + 추천). 데스크톱 화면 조작은 바로 직전에 검수에게 "이미지 생성 2 — 무엇 — 몇 초"(OK 필요 없음). 내 브라우저 탭 작업은 알릴 필요 없음.
- 진행 중: ① ToggleTrack·ToggleKnob·GlyphGear(BB3 설정 창, 언어 줄은 글자 EN/한) ② MapZoneHauntedHollow + 대왕 칩 아이콘(IconChipGhostKing·IconChipPumpkinKing) ③ 지도 표시 나머지 8(교차로·마을 3·사냥터 4). 시트 스크립트 scratchpad settings_sheet.py → art/review/s2/settings_chips_maps_sheet.png.
- (오후 4) 648f8f9 설정 스위치·톱니·대왕 칩·지도 표시 15 세트 · 7fb375a 메뉴 칸 아이콘 7 · 3c9166a 랭킹 메달 3 · 9be09d8 칭호 배지 12 · 1124ced PortraitFrame·PetCard. 다음: A23-47 소품 2D(이미지 생성 1의 kit_<구역>.md 기다림, art/out/kit/<구역>/<이름>.png, 시트 먼저 검수) — 기다리는 동안 MapKaiju·MapGrudgeSack·MapPvP 생성 중.

## 오후 5 (2026-10-06, 크레딧 0)
- 커밋: 1f059dc·552fd95 배지 고침(검수 통과) + MapKaiju·GrudgeSack(분홍)·PvP(검정) · 7c3c95a 소품 틀 시험 3(검수: 틀 통과, "우리 표시" 넣기) · **f9d128c 교차로 작은 소품 16종**(톱니 황동·청록 크리스털 표시, `art/out/kit/crossroads/X_*.png` + `_src.png`, 시트 `art/review/s2/kit_crossroads16_sheet.png`, 일지 19) → 검수에게 시트 보냄.
- 사용자 결정(검수 전달): **3D는 모두 Tripo**(눈은 검수가 손봄), **Meshy 결제·사용 안 함** — Meshy 다시 열지 않기. 시안 속 캐릭터·몬스터 눈은 단순하게(검은 타원 + 하이라이트 1~2). A23-48 게임 화면은 영어만 → 그림 속 글자는 계속 없음.
- 소품 요령: 문구 = `scratchpad/mk_kit.py`의 KIT 꼬리말(3/4·회색 배경·그림자 없음·글자 없음). 누끼 `cut_keep --long 1024 --holes --keep-largest` → `clean_haze`. 회색 재질(모루·화덕 벽돌·연석·크림 그늘)은 `--tol 14~18 --soft 5`. 떠 있는 부품(깃발 후광)은 `--keep-largest` 빼고 `clean_haze --min-island 300`. 막힌 회색 틈(깃발 천과 막대 사이, 고리 속)은 채도<10·밝기 127±14 덩어리를 지움. 유리 속 회색빛은 유리 표현이라 둠.
- 다음: 검수 답(화로 테두리가 톱니보다 凸 모양 — 바꿀지) → 마을판(빛: 금 후광·날개 손잡이 / 뿔: 휜 뿔 손잡이·주황 틈빛) 소품은 마을 시안이 정해지면. 3D는 사용자 '예' 받은 묶음만(검수가 합계 물음).
- **6b351e0 빛·뿔 마을 작은 소품 34종**(마을마다 17: 통·상자·화분·벤치·가로등·노점·빵/과일 수레·울타리·덤불·빈 간판·연석·깃발·화로·무기 걸이·물약 상자·의자) — `art/out/kit/{halo_town,horns_town}/<Town>_<Name>.png`, 시트 `art/review/s2/kit_{halo,horns}_town17_sheet.png`, 일지 20 → 검수에 보냄. 문구 `scratchpad/mk_kit_town.py`.
- 누끼 요령 추가: 흰 물건 `--tol 18`. 회색 돌·쇠가 많은 물건은 "회색 주머니 지우기"를 끄고(`--no-pockets`), 원본 모서리에서 잰 배경색과 똑같고(±9) 평평한(표준편차<3) 400px 넘는 덩어리만 지운다(뿔 상자 쇠 모서리·화분 테두리가 갉혔던 일). 둥근 테두리 윗면이 배경색이면 `--holes`를 빼고 다시 딴다.
