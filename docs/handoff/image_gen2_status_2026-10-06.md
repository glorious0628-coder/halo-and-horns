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
