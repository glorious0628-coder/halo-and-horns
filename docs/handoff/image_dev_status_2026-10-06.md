# 이미지 개발 인계 상태 (2026-10-06 오후, 계정 옮기느라 멈춤 — 검수 지시)

> **최신(20시경, 사용자 PC 재시작 전 정리):** 오늘 저녁 main — 61a1b43 퀘스트 목표 마커(A23-36, 흰색·받기 금·48px·화면 위 ScreenGui·가장자리 화살표·어두운 테, 검수 통과), f94cc86 위 줄 맞추기(A23-40 보강: [메뉴]·전쟁 미터가 Roblox 버튼 줄 가운데 34px) + 미니맵 캐릭터 방향 회전(A23-51) + 스킬 아이콘 11·지도 화살표 업로드(검수 통과), 7cc9d60 SkillBar Q·Z·X(SKL-4a) + UIKit.ButtonFeel·WindowIn/Out·ReducedMotion + 미니맵 화살표 22/20du·N 17px + WorldMapV2 업로드(검수 중), 1f9d291 A23-60 스킬 버튼 MP 숫자 없앰(흐리게 + "Not enough MP", UiSandbox PC·폰 확인 끝). Game-imgdev = main(커밋 안 된 것 없음). UiSandbox는 Edit, 기기 흉내 꺼짐. **남은 것(순서):** 큰 지도 바탕 연결(Config.Map v2 뒤, 키 WorldMapV2·변환식 있음) → 품질 아이디어 ① 효과음 + Audio.luau(Kenney CC0 30개, build/devlog/sfx/, 10/12 고르기·10/15 업로드, 출처 docs/devlog/sfx_licenses.md, 소리 크기 표는 검수) ② UIKit.Typewriter·Audio.Talk ③ 새싹 HUD 최소판(HudLayout.Reveal: Lv1 첫 3분 왕관 결정·내 점수·다음 이벤트 숨김, 첫 [Claim] 때 NEW!) → 진영 고르기 화면 2장 + 영어 글자(A23-57 보강: 이미지 생성 2의 글자 없는 새 카드 빛·뿔 2장·제목 띠·직업 카드가 승인되면 업로드 → 가운데 2장 배치에 TextLabel 영어 이름·설명(용어표, Fredoka One + Builder Sans), PC·폰·844 넘침 확인; 순서는 ① 소리 다음, ② 대화창 무렵; 그 전엔 개발 1이 지금 카드 2장만 가운데로) → SKL-4b SkillFx(Fx 계약 10/09 뒤). SKL-1 뒤 다시 볼 것: Z·X 키 배지, 스킬 이름 알약 넘침. [메뉴] 펼친 화면은 메인에서 개발 1이 확인(연습 Studio에선 MCP 클릭 안 먹음). 시험 도구: tools/quest_marker_view.py · topbar_view.py · minimap_turn_view.py · skillbar_view.py(모두 STUDIO_NAME=UiSandbox, Play 전 검수 "전달함, 시작").
>
> **17:20(새 세션 시작):** main에 들어간 것 — 351eb39 B안 HUD(둥근 지도·퀘스트 2줄·아래 가운데 얼굴/바/아이콘 칸, 폰 오른쪽 위), 73429ec·052c7b4 미니맵(보는 쪽이 위·세모 = 캐릭터 방향), 59a159e ZoneLook(기본 빛 = 서버 Config.Sky), a0e8098 가독성·유령 숲 해 질 녘·그림 31장, 75afd6a [메뉴] 오른쪽 위·왼쪽으로 펼침·그림 102장, 6db6b0d 게임 글자 영어(A23-48)·묶음 2 글자 없는 카드, addc169 2차 검수 2-5~2-7 도구. Skill_*_Q 3장은 이미 올라가 Q 버튼에 연결됨(L.RefreshSkillIcon). **Game-imgdev(imgdev)** = main 6db6b0d + WIP abc82dc(QuestTarget·QuestMarker·오프라인 시험 22검사 변형 6/6, font_compare_view·terrain_view 도구) + 커밋 안 됨(ClientMain ORDER 끝에 QuestTarget·QuestMarker, 시험 증거를 변형 없이 다시 돌린 것). font_compare_view는 A23-48(영어만)로 필요 없어져 버림. **다음:** QuestTarget 영어·gold 판정 맞추기 → QuestMarker 48px↑·진행 하늘/흰·받기 금 → UiSandbox 확인(지역 4곳) → main(ORDER 줄은 개발 1과 맞춤) → SKL-4a SkillBar(Q·Z·X + 자동·유령 자리, 3화면) → 유령 숲 ZoneLook·남은 업로드 → SKL-4b SkillFx.
>
> **이전(새 계정, 한도로 멈춤 13시경):** ① 미완성 src는 worktree `Game-imgdev`(브랜치 imgdev, 백업 imgdev-wip-backup)에만 있음 — 작업 폴더 src는 HEAD, addc169(2차 검수 2-5~2-7 도구) 푸시. ② 업로드 14장 끝(기록만 커밋, Config 키는 아직): MenuTile·IconSettings·IconNews, CLS_* 8 → Char{Halo,Horns,Neutral}* 자리(ClassPicker가 다른 성별로 대체), PTR_Guide* 3 → 새 키 PortraitGuide*(Panels 환영창 Char..WarriorM 대신, 개발 1에 알리고). ③ 다음: Config 키 넣기 → UiSandbox(열려 있음, Edit) 확인 → 커밋 → A23-40 B안 배치(HudLayout B + 폰 위 가운데·오른쪽 위, 캡처 1280×720·749×361·844×390) → 게임 화면 위 글꼴 견본 2~3개. 아직 안 올린 것: Skill_*_Q 3, 묶음 2 진영 화면 9.

## 끝난 것 (push 완료)
- 오전: a62c6e8(그림 20장), aebf974(PvP 탭), 938c230(진영 특성 10장), bff00df(드랍·호박 대왕 알림 그림), f0e011a, 7dd8103(ART-DEL1 정리), 9759dd3.
- 65b2ccb 화면 배치 v2 계산 모듈(HudLayout) + 오프라인 검사.
- b9ada3b 사냥터마다 한 분위기(ZoneLook) · 새 땅 그림 13종 · 나무 그림 적용 준비(apply_surface_materials.lua). 메인 적용은 게임성 개발 1 차례.
- 0e7f14e → 34ac656 채팅창: Roblox 기본 자리·크기, PC도 닫힌 채 시작.

## 커밋 안 한 파일 (작업 폴더에만 있음 — 그대로 이어 쓰면 됨)
- **HUD v2 연결(UiSandbox에만 붙임, 사용자 배치 선택 대기라 커밋 보류):** `HUD.luau`(v2 전체 다시 짬: 왼쪽 위 얼굴·배지·HP/MP·전투력 줄, 오른쪽 위 버튼 줄·퀘스트 판, 전투 묶음, 칩 순서, 전쟁 막대 진영 배지, HUD.Layout/IsVisible/GuideTarget/QuestTarget), `VitalsUI.luau`(둥근 물약 버튼, PlaceBars/PlacePotions), `GrudgeGhost.luau`(Rects.ghost). v2 이전 HUD 백업은 세션 scratch에만 있었음 → 되돌릴 땐 `git checkout HEAD -- <파일>`. PC 캡처 build/hudv2/pc.jpeg(문제: 왼쪽 위 전투력 줄이 HP 막대와 겹쳐 보임 — 확인 필요).
- **HudLayout 보강:** `HudLayout.luau`(물약 간격 POTION_GAP 6, 퀘스트 최소 48du, PouchLine), `tools/test_hud_layout.py`, `tools/fixtures/hud_layout_offline.luau`, 증거 `docs/art/verification_2026-10-06/hud_layout_offline_2026-10-06.{json,png}`(37경우, 변형 25/25 통과).
- **새 모듈(아직 커밋 안 함):** `MiniMap.luau`, `PlayerListUI.luau`(우리 Tab 목록), ClientMain ORDER 끝에 "MiniMap","PlayerListUI" 추가. `tools/test_keys_settings.py`에 PlayerListUI Tab 허용 추가 — 변형 검사 다시 돌려야 함. 게임성 개발 1 말: 지금 작업 폴더에선 beta_basics 'HUD stats title passes the TitleSel attribute'와 keys 정적 검사가 내 HUD v2·Tab 때문에 실패 → 커밋 때 두 검사 맞출 것.
- **Config.luau:** 내 Config.UIArt 덩어리 4개(새 그림 키·Id: PanelCard→PanelDark, RibbonHeader→PanelHeader, BarTrack, BtnAttack 주황, BtnSkill, LevelBadge*, BtnPotion, 글리프·등급 칸·아이콘 묶음 7~9, 이음 고친 Tex_ 6장, Colors.Orange/Confirm). 다른 세션 줄이 섞이면 임시 인덱스로 내 덩어리만 커밋. `art/ui/asset_ids.json`도 같이.
- **멈춘 위성 작업(workflow 중간 중지):** `UIKit.luau`(글자 스타일 StyleText/StyledLabel, PlaceNotify), `EventHUD.luau`(v2 알림 열, LuckShort, Relayout), 새 `QuestTarget.luau`·`QuestMarker.luau` — 만들다 멈춰서 **검사 안 됨**. 이어 쓰기 전 diff 보고 test_halloween 문자열 검사 다시 돌릴 것. QuestTarget/QuestMarker는 아직 ORDER에 없음.
- **도구 안전 고침:** `tools/device_view.py`(ensure_sandbox·sandbox()·LuauError), `world_blend_view.py`, `zone_look_view.py`, `font_samples_view.py`, `docs/design/world_blend_2026-10-06.md` — 2차 검수 ①~⑤ 고침, 커밋만 남음.
- **글꼴 비교 견본(새):** `tools/font_compare_view.py`, 결과 `art/review/font_compare_2026-10-06.png` + 쪽별 `art/review/font_compare_2026-10-06/`(fonts·numbers·strokeA·strokeB 찍음, 아직 안 봄). 후보 쪽(`--pages cand`, PC + 폰 749×361 ×2)은 아직 안 찍음.
- tools/terrain_view.py: LeafyGrass·Basalt·Cobblestone 자리 좌표 고칠 것.

## 연습 Studio
- build/UiSandbox.rbxlx는 저장 안 하고 닫음(검수 지시). 다시 열면 HUD v2 등은 `STUDIO_NAME=UiSandbox py tools/sync_to_studio.py`류로 다시 넣어야 함. 모든 Studio 도구에 `STUDIO_NAME=UiSandbox`.

## 다음 할 일 (순서)
1. 사용자 HUD 배치 선택(정리한 v2 vs 사진식) 기다림 → 고른 안에 맞춰 HUD v2 연결 마무리 → beta_basics·keys 검사 맞추고 커밋 → 해시를 게임성 개발 1에.
2. Nanum vs Noto 견본: 찍은 4쪽 보고 후보 2~3개 고르기 → `py tools/font_compare_view.py --pages cand` → 검수에. 글꼴은 사용자가 고르기 전엔 바꾸지 않음.
3. QuestMarker(48px 이상, 진행=하늘색/흰색, 받기=금색, ZoneLook 구역 4곳에서 보이는지) + QuestTarget(HUD 안내 대상과 같은 결과, 호박밭 길: 표지판 (368,0,136) → 통로 x351–369 z126–194 → 밭 가운데 (360,235)).
4. 미니맵 둥근 모양 옵션, 우리 Tab 목록 마무리.
5. 2차 검수 ①~⑤ 커밋(위 도구 고침).
6. **받았지만 안 올린 그림:** 묶음 14 Q 스킬 3장 `art/ui/Skill_{Warrior,Mage,Archer}_Q.png`(ae9a7ea, 시트 사용자에게 보여 줌, 가장자리 확인 끝) → 업로드 → Config 키 → HUD 스킬 버튼 아이콘을 직업별로(IconSpecial 대신, 둥근 BtnSkill 안 ~74%). 묶음 2 진영 화면 9장(5d16034), TitleRibbon(크림) 적용. 묶음 10·11a(97456b9)는 사용자 확인 전 업로드 금지.
7. 게임성 개발 1에 전할 것: Config.Weapons T8 색 청록 → 슬라임 초록 110,210,110(이미지 생성 2 요청).
8. 메인 적용 뒤 옛 파일 지우기: UIP_PortraitRing/LevelBadge/BtnAttack/BtnSpecial/ShieldHalo/ShieldHorns/IconPotionHP, 옛 Tex_*. ART-DEL2: 옛 FreshTyped 카드 + art/fonts/jua/ (git rm).
