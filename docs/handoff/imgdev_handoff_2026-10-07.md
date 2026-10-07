# 이미지 개발 인계 (2026-10-07 저녁 — 계정 옮기기, 검수 지시)

다음 계정의 '이미지 개발' 세션이 바로 이어 하도록 정리한 파일이다. 예전 상태 파일
`docs/handoff/image_dev_status_2026-10-06.md`는 기록용이고, **이 파일이 최신**이다.

## 0. 먼저 읽기 / 일하는 법
- 읽기: `AGENTS.md` → 이 파일 → `docs/design/window_art_audit_2026-10-07.md`(창 점검표·고친 뒤) →
  `docs/design/image_dev_session_handoff_2026-10-06.md`(역할·파일 담당).
- 역할: 그림 올리기, `Config.UIArt`, UIKit 모양·글자 스타일, HUD 배치(HudLayout), 창 틀(Panels 껍데기), 지형 재질,
  ZoneLook, 미니맵. 사용자 말·승인은 모두 **검수**를 거친다(사용자에게 직접 묻지 않는다). 사용자에게 쓰는 말은 한국어,
  게임 글자는 영어.
- 코드 작업은 worktree `C:\Users\glori\Documents\Roblox\Game-imgdev`(브랜치 imgdev). 커밋 순서:
  `git stash` → `git merge --ff-only origin/main` → `git stash pop` → `git commit -F - -- <경로들>` →
  `git push origin HEAD:main`(거절되면 `git fetch` + `git rebase origin/main` 뒤 다시). **공유 Game 폴더에서는
  git commit 금지 → `py tools/push_paths.py -m "제목" <경로들>`**(AGENTS f27ca7e).
- 시험은 연습 Studio `build/UiSandbox.rbxlx`만(모든 도구에 `STUDIO_NAME=UiSandbox`). UiSandbox는 켜 둬도 된다.
  **Play·창 열기 전마다** 검수에 "이미지 개발 — 무엇 — 몇 분"을 보내고, **요청 이름이 붙은** "전달함, 시작"을 받은
  뒤에만 시작한다(앱 메시지는 늦게 와서 순서가 섞인다 — 이미 쓴 허락은 다시 쓰지 않는다). 끝나면 Play·기기 흉내 끄고
  "끝". 메인 Studio(81671223175574) 동기화·Play는 **게임성 개발 1** 몫: 해시와 바뀐 파일을 보내 준다.

## 1. 오늘 끝난 것 (main)
| 해시 | 내용 |
| --- | --- |
| adc7311 | 폰 진영·직업 가로 배치 + UIKit.Typewriter |
| 8f7f122 | A23-66 미니맵 화살표가 캐릭터 시선 + 진영 화살표·게시판 그림 업로드 |
| 53db902 | 글꼴 Denk One + Montserrat(A23-63) + 넘침 고침 |
| 15ff595 | 9조각 '가운데 2px 띠' + 오프닝 폰 + 폰 [메뉴] + 빛 화살표 +2du |
| 491fa51 | 작은 PC 창 = PC 배치(UIScale만 줄임, UIKit.PxFloor) |
| 6f0ab5a | A23-68 꾸밈: HUD.Hint / ClearHint / HintShown(말풍선 BarkBubble 거울·금빛 테·공격 흔들림), QuestMarker.Focus(슬라임 위 마름모), 첫 [Claim] 전 접힘 + NEW!(UIKit.NewTag), 미니맵 누르면 큰 지도, Config.Fonts 읽기 |
| 5fe38d1 | 창 꾸미기 점검표 '지금 모습'(창 16개 + 확인 상자 + 알림, PC·폰) |
| eecc7b3 | 창 공통 틀(PanelCard 판·RibbonHeader 제목·둥근 X·그림 버튼 UIKit.ArtTextButton·높이 = 내용) + 확인 상자 DialogBox + 보상 팝업 UIKit.RewardPopup(Vacation) + 장인·티켓 상점 숨김 + 힌트 하나씩·Z/X + A23-71 스킬 없으면 물약이 공격 옆 |
| (이 커밋) | 이미지 생성 2 고급 25장 업로드·Id 교체 + Slice 6개 + FactionPickTitle 글자 칸, 창이 열려 있으면 알림은 창 위 한 줄(UI 2회차 #4), 폰 보상 팝업(넓은 판·첫 줄만·리본 한 줄) |

증거 사진: `art/review/`의 rookie_hint · window_audit(전·후) · notify_window · picker_view_hq (2026-10-07).

## 2. 다음 큐 (순서)
> **도착함(1d58f6c, 이 계정이 멈춘 뒤):** 보상 팝업 고급 9장 art/ui — RewardPanelHalo 512×294 Slice (62,66,449,231) Inner
> (0.076,0.16,0.848,0.707) · RewardPanelHorns 512×305 Slice (60,65,452,239) Inner (0.066,0.128,0.869,0.754) · RewardRibbonHalo
> 512×143 크기 고정 Text (0.22,0.31,0.56,0.44) · RewardRibbonHorns 512×149 크기 고정 Text (0.12,0.33,0.76,0.41) · 곧은 띠 예비
> RewardRibbonHaloStraight 512×100 Slice (71,49,441,51) Text (0.14,0.30,0.72,0.52) / RewardRibbonHornsStraight 512×106 Slice
> (42,52,469,54) Text (0.10,0.26,0.80,0.50) · RewardSlot 256×252 Inner (0.121,0.127,0.758,0.742) · RewardGlow 512 · RewardSparkle 256
> (흰색 + 밝기 알파, ImageColor3로 빛 = 금 / 뿔 = 주황). 세계 지도 UIP_WorldMapV2(1024×683 + _1536, 얼굴 느낌 뺌, map_transform
> 그대로). 값은 art/approved.json, 합친 모습 art/review/s2/reward_hq_sheet.jpg. → 1·2번을 이것으로 바로 시작(직접 보기 →
> 10장 이하 업로드 → Config 키·Slice·글자 칸 → RewardPopup 제목 칸을 띠 Text 값으로).
1. **보상 팝업 부품**(이미지 생성 2가 고급으로 받는 중): RewardPanelHalo / RewardPanelHorns(진영 판), RewardRibbonHalo /
   RewardRibbonHorns(휜 띠, 크기 고정 — 가장 긴 제목 'VACATION BONUS!'가 들어가는 폭, 글자 크기는 우리가), 예비 곧은 띠
   RewardRibbonHaloStraight / HornsStraight, RewardSlot(칸), RewardGlow(흰 빛무리), Sparkle(흰 반짝이). 받으면: 밝은·어두운
   바탕에서 직접 보기 → 10장 이하로 업로드 → Config 키 + Slice·글자 칸(approved.json 값). `UIKit.RewardPopup`은 키가 있으면
   알아서 쓴다(`NOTIFY.Reward.Panel / Banner / Slot / Glow`). Glow·Sparkle은 아직 코드에서 안 씀 → 빛무리는 빛살 밑, 반짝이는
   파티클로 넣기. 띠 글자 칸이 바뀌면 RewardPopup 제목 Position/Size(지금 BannerGold 기준 0.22/0.2/0.56/0.42)도 맞추기.
2. **세계 지도 고급판**(UIP_WorldMapV2, 얼굴 느낌 고친 것) 오면 업로드(고급 26장 중 마지막).
3. **알림 그림**: Toast(남색 알약 + 왼쪽 동그라미, FitHeight)·큰 알림 BannerAlert(빨간 띠)를 UIKit.Toast / Announce에 입히기.
   여러 줄 토스트는 왼쪽 동그라미가 세로로 늘어나니 줄 수 제한이나 Slice 고정 크기 검토. 개인 축하(레벨업·Stronger!)는
   BannerGold, 세계 소식은 BannerAlert로 나누는 안.
4. **사냥 게시판 창 BoardPanel**(E11): 서버 BoardService + 계약 `docs/design/quest_volume_server_2026-10-07.md` §2
   (`Config.Board.Enabled = false` 기본, s→c `Board` 원격, c→s `BoardAction(board, "Open" | "Take", slot, "Kind" | "Sneaky" |
   "Reroll", slot)`). **창은 이미지 개발 몫(개발 1 확인).** 프롬프트는 개발 1이 넣음(c13901c, MapBuilder.ensureJobBoards):
   `Workspace.Map.Landmarks.JobBoard_Meadow / JobBoard_Woods`에 ProximityPrompt "BoardPrompt"(속성 Board = "Meadow" /
   "Woods", "Look at jobs", E, 바로 누름, 거리 12), `Config.Board.Enabled = false`인 동안은 꺼져 있음. 클라는
   `ProximityPromptService.PromptTriggered`에서 이름이 BoardPrompt면 `BoardAction(prompt:GetAttribute("Board"), "Open")`을
   쏘고, `Board` 원격을 받으면 창을 연다. UiSandbox 시험은 서버 문맥에서 `Board` 원격을 가짜 payload로 쏴서 창을 그린다.
   설계: `Panels.Register("Board", { FixedBody = true })` + 창 몸통을 JobBoard 코르크판으로 바꾸는 opts(Body/Inner), JobCard
   4장(폰 2장 + ◀ ▶ + 점), 카드마다 Goal·보상 + [Kind](BtnKind + GlyphKindWing)·[Sneaky](BtnSneaky + GlyphSneakyHorns) +
   두 동기 줄, 위 "Kind n · Sneaky n · Jobs n/3", 바꾸기(RerollAt 남은 초), 3개 들면 잠금 + `Config.Board.Text.Full`.
5. **10/19 A23-69 [Stats] 탭 모양 확인**(UIKit 대체 모양, 빨간 점 위치, 749×361 스크롤 없이) — 설계 `docs/design/stat_points_2026-10-07.md` §4.
6. UI 2회차 남은 것: #5 퀘스트 체크 애니메이션 + Done!/Claim, #6 전쟁 막대(1:0에 확 쏠리지 않게, 숫자 밑 남색 판, YOU) —
   먼저 main에 개발 1이 한 것이 있는지 확인(#3 대장간 길 안내 2b5fd17, #8 두 번 눌러 사기 91bf695는 개발 1이 끝냄).
7. **골드 합친 표시 안**(검수 3회차): 첫 보상 150이 금고로 가서 HUD에 'Pouch 15'만 보이는 문제 → 주머니 + 금고 합친 골드
   표시 안(0.5일, 아직 시작 안 함).
8. A23-62 무료 VFX(Creator Store → UiSandbox, 스크립트 빼기, `docs/design/skill_vfx_sources.md`).
9. 작은 것: 폰 직업 카드 'Smash all around!' → 'Smash all' 잘림(picker_view_hq), 폰에서 창이 열려 있을 때 알림 한 줄이 창
   제목 띠를 가림(위·아래 자리가 없을 때), 카드·줄(Panels makeCard · Row)은 아직 코드 판(ListRow 그림은 창별로),
   작은 PC 창(655×340)에서 스킬 이름 'Shockwa…' 잘림, UiSandbox 월드가 옛 복사본(메인 place 커밋 뒤 새로 받기 — 개발 1 제안).

## 3. 도구
- `py tools/test_hud_layout.py` — HudLayout 오프라인 검사(9,315 + 돌연변이 50). HudLayout을 고치면 꼭 돌리고, 새 규칙엔
  검사 + 돌연변이를 같이 넣는다(fixture `tools/fixtures/hud_layout_offline.luau`).
- UiSandbox 찍기(모두 `device_view.sandbox`: UiSandbox 확인 후 시작, 끝나면 Play·기기 흉내 원복):
  `text_fit_view.py`(기기별 글자 넘침), `window_audit_view.py`(창 전부, `--tag after`, `--only Vacation`),
  `rookie_hint_view.py`(A23-68), `notify_window_view.py`(창 + 알림), `picker_view.py`(`--tag`), `slice_compare_view.py`,
  `minimap_*_view.py`, `menu_tap_view.py`.
- 업로드: `art/ui`에서 `py -m http.server 8765 --bind 127.0.0.1`을 띄우고 `py tools/upload_ui_assets.py --batch <json>
  --studio UiSandbox`(Config Id·asset_ids.json 교체까지). 배치 json = [{key, file, sha256}]. 끝나면 서버 끄기. 올린 Id는
  Edit에서 `AssetService:CreateEditableImageAsync`로 불러와지는지 확인.
- Studio 전용 확인 스위치(플레이어 속성): HintPreview("Attack" / "Q" / "Z" / "X"), FocusPreview(true), QuestMarkerPreview,
  SkillBarPreview.
- `execute_luau` Client 문맥은 모듈 복사본이다: 진짜 동작은 서버 원격(OpenPanel, Notify, Quests)이나 속성으로 일으킨다.
  UIKit 복사본(`kit.Gui = MainGui`)으로 Confirm / RewardPopup 견본은 찍을 수 있다. 기기 흉내에서는 MCP 마우스 위치가 안
  맞는다(GetGuiObjectsAtPosition으로 판정).

## 4. 주의
- 처음 쓰는 그림은 텍스처가 늦게 와 빈 판이 1초 보인다 → `NOTIFY.PreloadArt`에 넣기.
- UIKit 글자 바닥(실제 px)은 UIScale로 줄인 판 안에서도 지켜진다 → 팝업을 통째로 줄이면 글자가 상대적으로 커지고 줄이
  늘어난다. 짧은 화면은 판을 넓히고 칸·줄을 줄인다(RewardPopup compact).
- 그림 버튼(UIKit.ArtTextButton)은 TextButton이라 `btn.Text` 대입·setEnabled·paintButton이 그대로 된다. 글자색은 그림 톤이 정함.
- 9조각: 알약·캡슐은 Slice를 (끝 폭, 높이/2−1, 너비−끝 폭, 높이/2+1)로, 판은 둥근 모서리·장식이 모서리 칸 안.
- Roblox는 1024px 넘는 그림을 줄여 읽는다(MapParchment 1536 → 1024×682).
- 업로드 전 직접 보기·10장 이하·간격 두기. `art/out/v1/`와 노출 그림 4장(UIP_CharHaloArcher 등)은 절대 올리거나 참조하지 않기.
- 공유 폴더에는 다른 세션의 커밋 안 된 파일이 있다 — 경로를 지정해서만 올린다.
