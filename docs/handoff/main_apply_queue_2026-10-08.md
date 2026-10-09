# 메인 반영 순서 (게임성 개발 1 → 메인 반영 1, 2026-10-08 15시 이후)

> 기록용(2026-10-09 검수): 10/08 메인 반영 순서 기록이에요. 6번째 묶음의 '카메라 기본 Free'는 SPEC A23-91(10/09)로 바뀌었어요(기본 Follow, 콘솔식, c3be8e44). 지금 할 일은 `docs/handoff/role_prompts/01_mainapply.md`예요.

역할(사용자 10/08 15시): 메인 Studio = **메인 반영 1**만. 개발 1은 코드만. 아래는 개발 1 묶음을 메인에 넣는 순서다.
검수 초원 지형 2차(meadow_terrain apply)는 검수 몫 — sync 뒤 검수가 먼저 넣고 나서 3단계부터 이어 간다.
화면을 쓰는 단계(창 복원·Play·저장 키)는 지금처럼 검수 "전달함, 시작"을 받은 뒤에 한다.

## 이 순서에 들어가는 코드(origin/main)
- 0f4211a6 dev2 몬스터 겹침 3차(MonsterService) 병합
- b8efe680 멈춤 카드 PauseCard.luau + 후원자 게시판 이름 줄 글자칸, 6e8bb06d 게시판 글자 여백
- 8a0853af Audio 보류(첫 임무·오프닝·선택 창 동안 경보·3-2-1 소리 없음), SkillBar 키 표시 = Settings.KeyBadges,
  Fx 스티커 TextRect(EmoOuch 빈 말풍선 그림용), Config.Sky.Neutral 안개 150,205,228·조명 Tint 255,245,230,
  crossroads_3d_swap 게시판 보존 + board_fit, gate_faces_hide 도구, preview_map 물 색
- (남의 것, 같은 sync) 87f8e6b 개발 3 KeyBadges 설정 V2(옛 저장본 키 표시 한 번 끔), 7fab73be EmoOuch 그림 Id 비움

| 단계 | 명령 | Edit/Play | 확인할 것 |
|---|---|---|---|
| 1 | origin/main과 같은 깨끗한 worktree에서 `py tools/sync_to_studio.py` 뒤 `py tools/luau_check.py src/StarterPlayer/StarterPlayerScripts/Audio.luau src/StarterPlayer/StarterPlayerScripts/SkillBar.luau src/StarterPlayer/StarterPlayerScripts/Fx.luau src/StarterPlayer/StarterPlayerScripts/PauseCard.luau src/ReplicatedStorage/Shared/Config.luau src/ServerScriptService/MonsterService.luau` | Edit | "동기화 완료", "문법 OK". sync 전 `git rev-list --left-right --count HEAD...origin/main` = `0 0` |
| 2 | (검수) 초원 지형 2차 | Edit | 검수가 "끝"을 줄 때까지 기다림 |
| 3 | `py tools/edit_style_round.py gates` (= tools/worldkit/gate_faces_hide.luau apply + 관문마다 Edit 사진) | Edit | style_round/gates.txt에 "hid N face parts": 초원 SlimeStatue·Eye, 고블린 TotemEyes, 뿔 Eye 2, 해골 Skull·SkullEye 2·Jaw. 사진: 기둥·Lintel은 그대로, 눈·해골·턱 안 보임. 지우지 않음(StyleHidden 속성, 투명) |
| 4 | 저장(체크포인트) → `py tools/edit_style_round.py swap` (= crossroads_snapshot → crossroads_3d_swap 두 번 → 비교) | Edit | style_round/swap_diff.txt 끝줄 "X_SupporterBoard + SupporterFace kept the same: True; MostWantedBoard the same: True", "run 1 -> run 2: no difference". before→run 1에 gone/moved가 있으면 손으로 옮긴 소품이 되돌아간 것 → 저장하지 말고 체크포인트를 다시 열기 |
| 5 | `py tools/play_separation_check.py pc` 그다음 `phone` (내 시험 Play, fresh 저장) | Play | results.json: 초원 서쪽 끝에서 슬라임 2마리 이상, "smallest gap / (rA + rB)" ≥ 0.90, 이동선 넘은 슬라임 0, 6초 동안 위치가 바뀜(안 얼어 있음), MonsterService 오류 0. 사진 03_horizon_sea·04_high_view = 안개가 하늘색과 이어짐(바다 끝 회색 띠 없음), 낮빛 살짝 따뜻 |
| 6 | 사용자 계정 저장본으로 Play(StudioFreshSave 끄고, play 도구 말고 MCP start_stop_play) → 아래 "키 표시 확인" 코드를 Client에서 실행 → Settings 창의 'Key hints'를 켰다 끄고 다시 실행 | Play | 처음: 보이는 키 글자 0(설정 V2가 옛 저장본 KeyBadges를 끔). 'Key hints' 켬: HUD 칸·물약·스킬 버튼에 키 글자가 생김(스킬 버튼은 Lv5 이상만 있음). 끔: 다시 0. PC 사진 1장씩. 폰은 키 글자가 원래 없음 |
| 7 | `py tools/play_supporter_check.py pc`, `py tools/play_pause_card_check.py pc` | Play | 둘 다 7/7(이전 결과와 같음) — 이번 sync로 깨진 것 없는지 |
| 8 | 저장(Save to File `build/GoodEvil.rbxlx`) → 시간·해시 확인 → place/ 복사 → push | Edit | place/ = build/ 해시 같음 |

## 키 표시 확인 코드 (단계 6, Client)
```lua
local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("MainGui")
local shown, names = 0, {}
for _, d in gui and gui:GetDescendants() or {} do
	if d:IsA("TextLabel") and (d.Name == "Key" or d.Name == "KeyBadge") and d.Visible and d.Text ~= "" then
		local ok, vis = pcall(function()
			local p = d
			while p and p ~= gui do
				if p:IsA("GuiObject") and not p.Visible then return false end
				p = p.Parent
			end
			return true
		end)
		if ok and vis then shown += 1; table.insert(names, d:GetFullName():sub(-60) .. "=" .. d.Text) end
	end
end
return "visible key letters: " .. shown .. "\n" .. table.concat(names, "\n")
```

## 2번째 묶음 (A23-81 퀘스트 다시 짜기 + Lv5 키 안내, 개발 1 다음 커밋)
sync 뒤 내 시험 Play(fresh 저장 또는 사용자 저장본) PC·폰 사진:
| 단계 | 무엇 | Edit/Play | 확인할 것 |
|---|---|---|---|
| A | 왼쪽 퀘스트 줄 | Play | 진행 중인 것만, 최대 3줄, 메인(또는 첫 임무) 줄이 맨 위, 한 줄 = 짧은 이름 + 3/5(PC도 안 잘림), "Daily Quests 0/3" 같은 빈 줄 없음. 첫 임무 전(첫 [Claim] 전)에는 1줄만 |
| B | Q 키(PC) / 줄 탭(폰) / 줄 옆 ▼ | Play | 퀘스트 창이 열림: 탭 Main·Side·Daily·Event·Faction(진행 중 수가 이름 옆), 각 탭에 In progress / Available / Done. Q 다시 → 닫힘 |
| C | 창에서 일일 줄 누르기 | Play | 창이 닫히고 화면 화살표(QuestMarker)가 그 퀘스트 쪽으로. [Claim]·[New]가 HUD와 같게 동작([New]은 확인 창) |
| D | Event 탭 | Play | 황금 거위·호박 대왕 등 진행 중이면 그 줄, 왕관 전쟁 다음 왕관 남은 시간 줄 |
| E | Lv5 첫 스킬 뒤 키 안내(PC) | Play | 진짜 레벨업(DebugCommand Level 4 + XP = XPToNext(4)-1 + 슬라임 1마리)으로 Lv5 → "New skill!" 뒤 Z를 한 번 누르면 2.5초 뒤(안 누르면 25초 뒤) 카드 "Tip / Tip: You can change your keys in Settings!" [Open Settings]·[OK]. [Open Settings] → 설정 창 Keys 탭. 한 번만(다시 Z를 눌러도 안 나옴). 폰은 안 나옴 |
| F | 메뉴 → Help | Play | 조작 줄 끝에 같은 안내 문장, [Key settings] 버튼 → 설정 Keys 탭(PC) |
| G | 사용자 저장본(옛 한국어 일일 퀘스트가 남은 저장)으로 Play | Play | 왼쪽 줄·퀘스트 창의 일일 퀘스트 글이 영어(예: "Rob 1 Knight of Light 0/1"). 옛 저장의 한국어 글("빛의 기사단 1명 털기")이 화면에 안 보임 — 화면이 Config 영어 틀로 다시 씀(서버 쪽 고침은 개발 3) |
| H | 퀘스트 창 Side / Faction / Event 탭 | Play | Available = 레벨을 기다리는 서브 "제목 · Opens at Lv N"(개발 3 Book), Done = 끝낸 이야기 퀘스트(최신 먼저). **Main 탭에는 Available 칸이 없음**(메인 줄은 레벨 문이 없음). Daily 탭 Done = 오늘 몇 개 + 이번 접속에 끝낸 일일 |

같은 묶음 뒤 슬라임 간격 Play(검수 10/08 "구역 선 근처 슬라임 무리"): `py tools/play_separation_check.py pc` 그다음 `phone` (내 시험 Play, fresh 저장. 도구가 초원 서쪽 끝 슬라임 옆으로 가장 가까운 슬라임 3마리를 몇 스터드씩만 모아 옴 → 서쪽 끝으로 걸어가 6초 표본). 확인 = results.json의 슬라임 2마리 이상·몸 겹침 비율 ≥ 0.90·이동선 넘은 슬라임 0·멈춰 있지 않음 + 사진 02_at_the_edge. Config.Monsters → Config.MonsterTypes로 고쳐서 이번엔 슬라임을 찾음(전에는 0마리).

## 3번째 묶음 (조명 깊이, 개발 1 가지 lighting) — 같은 자리에서 전후 사진
- sync(Config.Sky.Neutral: ClockTime 15.3·Ambient 72,76,86·OutdoorAmbient 110,120,135·FogStart 150·FogEnd 950·노출 -0.05,
  WarService: ShadowSoftness 0.15·EnvironmentDiffuseScale 0.5·Contrast 0.12·Saturation -0.05·LightingStyle Realistic).
- Edit에서 한 번: `game.Lighting.Technology = Enum.Technology.ShadowMap`(장소 설정 — 게임 스크립트로는 못 바꿈, MCP execute_luau가
  거절하면 Studio 속성 창에서 Lighting > Technology; 이유 = 깊이는 해 그림자에서
  나오고, Future의 등불 그림자는 폰에 비싸고 등불이 적음). 그리고 tools/preview_map.lua는 다시 돌리지 않아도 됨(Play에서 WarService가 씀).
- Play PC·폰: 초원 언덕·길·폭포를 바꾸기 전과 같은 자리·같은 각도로. 확인 = 그늘 쪽이 어두워졌는지(어두운 10% 밝기가 0.5 근처로),
  그림자가 또렷하고 길어졌는지, 먼 언덕이 하늘색으로 흐려지는지, 연두가 덜 형광인지. 너무 어두우면 노출만 +0.1씩.
- Atmosphere는 넣지 않음(A9-3: 왕관 전쟁 하늘의 안개색·ZoneLook 구역 안개가 깨짐) — 먼 곳 흐림은 가까워진 안개 거리로.

## 4번째 묶음 (A23-79 다시 오기 화면: ComeBack·KingDiary + 멈춤 카드·초대·퀘스트 창, 개발 1)
sync 뒤 내 시험 Play(fresh 저장), PC·폰 사진. 서버 신호는 Server 쪽 execute_luau로 직접 쏘면 됨
(`local Net = require(game.ReplicatedStorage.Shared.Net) local p = game.Players:GetPlayers()[1]` 다음 아래 줄):
| 단계 | 무엇(Server) | 확인할 것 |
|---|---|---|
| A | `Net.Fx(p, "PauseCard", { Why = "Daily", Next = "Hunt and get stronger!", Tomorrow = "New dailies", OptIn = true })` | 카드 몸글 2줄 "Next time: …" / "Tomorrow: New dailies". [OK] 뒤 오류 없음(Studio는 Roblox 알림 동의 창을 못 띄움 → 출력창 `[Metrics]` 줄에 OptIn cannot 또는 아무것도 없음, 둘 다 정상) |
| B | `Net.Fx(p, "WelcomeBack", { Next = "Lv 10", Zone = "SlimeMeadow" })` → [Go] | 이동 + 출력창 `[Metrics]` WelcomeBackGo(Studio에서도 찍힘) |
| C | `p:SetAttribute("MyWay", "")` 다음 `p:SetAttribute("MyWay", "True Knight")` | 2초 알림 "Your way: True Knight" 한 번(첫 값은 조용) |
| D | `p:SetAttribute("DiaryPages", 2)` + `Net.Fx(p, "DiaryPage", { Page = 2, Today = 2, Late = false })` | 조용한 카드 "King Diary / Page 2 is open!" [Read]·[OK]. [Read] → 일기 창 Diary 탭, 1·2쪽 대왕 두 줄씩, 3쪽부터 "Beat a king together…" 또는 "Opens on …" |
| E | 일기 창 Candy Jar 탭 | "Your candy: N"(가방의 Candy 수), Pumpkin Pal 50 / Candy Keeper 200, 모자라면 [Trade] 꺼짐 |
| F | Q → Event 탭 | "King Diary · 2/9 pages"·"Candy Jar · …" 줄(누르면 일기 창, 뒤로 가기), Event 탭 이름 옆 숫자에 이 두 줄은 안 셈 |
| G | `p:SetAttribute("DiaryPages", 9)` + `Net.Fx(p, "DiaryDone", {})` | 보상 팝업(빛 무리·반짝이, 햇살 무늬 없음) "You read all 9 pages!" / "New title: Party Guest 2026" [Yay!] |
| H | Shop 창을 열기(있으면) | 출력창 `[Metrics]` ShopOpen |
- 시험: test_come_back(39·변이 27), test_king_diary(34·변이 21), test_pause_card(53·변이 27), test_invite(34·변이 18), test_quest_window(51·변이 30).
- 남은 연결(다른 세션): 이미지 개발 ShopUI = 패스 칸 볼 때 `C.ComeBack.Metric("PassView", id)`, 구매 창 열 때 `C.ComeBack.Metric("PurchasePrompt", id)`;
  [Invite a friend] 버튼 = 보일 때 `C.Invite.Seen(source)`, 누를 때 `C.Invite.Prompt(source)`(source = Menu / PlayerList / GooseWin / WarWin);
  일기 메뉴 칸은 아이콘 그림이 오면(지금은 퀘스트 창 Event 탭과 새 쪽 카드로 엶).

## 5번째 묶음 (노란 바닥 원 FxRing 줄이기, 검수 10/08 촬영 편집 관찰)
- sync 뒤 내 시험 Play PC·폰: 빛 진영 전사로 초원 언덕에서 슬라임을 10번쯤 때리기 → 공격자 발밑에 노란 원판이 더는 안 생김(베기 자국·맞은 불꽃·숫자는 그대로). 마법사·주먹(펫 박치기)은 맞은 몬스터 밑에 작고 옅은 표시만 0.2초. 다른 플레이어의 기본 공격엔 원 없음. 스킬(Z) 범위 원은 그대로. 사진: 언덕 위 전사 공격 직후 1장, 마법사 1장.
- 시험: tools/test_hit_ring.py(10·변이 7/7).

## 6번째 묶음 (조명 한 단계 어둡게 + 카메라 기본 Free + 하늘 6면 코드로, 사용자 10/08)
- sync 뒤 Play PC·폰: 3번째 묶음과 같은 자리·각도 전후 사진(초원 언덕·길·폭포, 교차로 분수). 확인 = 전체가 한 단계 어두움(노출 -0.25, 해 밝기 2.0, 그늘 95,104,118), 그림자·대비 그대로. 왕관 전쟁 새벽(Dawn)·일식(Eclipse) 하늘도 같은 단계(일식은 반만: 밤에도 몬스터 보임).
- 하늘 6면: WarService가 Start에 Config.Sky.Faces를 Lighting.Sky에 넣음(빈 칸은 그대로) → Edit에서 손으로 넣은 값과 같으면 정상. 왕관 전쟁 하늘 바뀔 때 면은 안 바뀜.
- 카메라: 새 저장(fresh)은 Free(로블록스 기본). **이미 저장된 계정은 저장된 값 그대로(Follow였으면 Follow)** — 검수 결정대로 옮기기 없음, 설정 Camera에서 Free로.
- 시험: lighting_depth 변이 18/18, camera_input 69/69(설정 없음 = Free 검사 추가), keys_settings 60/60, map_v2·zone_look·notify_sound·return 통과.

## 하지 않을 것
- tools/worldkit/meadow_terrain.luau, meadow_dress.luau = 검수 도구(검수가 올림).
- 전사 도발(X, Lv25, 베타 동안 꺼짐)·두 플레이어 붙어 서기 = Play에서 안 봄(오프라인 시험 monster_spacing 몫, 검수 OK).
- 경보 소리 보류(괴수 사이렌·전쟁 30초·3-2-1)는 Play에서 일부러 만들기 어려움 → 오프라인 test_audio(290·변이 99/99) 몫.

## 나중에 (그림이 오면)
- EmoOuch 빈 말풍선 그림 + Config.UIArt.Parts.EmoOuch.TextRect가 오면(이미지 개발): 몬스터를 때려 아픈 스티커에 "Ouch!"가 그림 칸 안에 보이는지 PC·폰 사진.
- IconSaved가 Config.UIArt에 들어오면(이미지 개발 상점 묶음): 멈춤 카드 위에 저장 표시 그림.
