# 메인 반영 순서 (게임성 개발 1 → 메인 반영 1, 2026-10-08 15시 이후)

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

## 하지 않을 것
- tools/worldkit/meadow_terrain.luau, meadow_dress.luau = 검수 도구(검수가 올림).
- 전사 도발(X, Lv25, 베타 동안 꺼짐)·두 플레이어 붙어 서기 = Play에서 안 봄(오프라인 시험 monster_spacing 몫, 검수 OK).
- 경보 소리 보류(괴수 사이렌·전쟁 30초·3-2-1)는 Play에서 일부러 만들기 어려움 → 오프라인 test_audio(290·변이 99/99) 몫.

## 나중에 (그림이 오면)
- EmoOuch 빈 말풍선 그림 + Config.UIArt.Parts.EmoOuch.TextRect가 오면(이미지 개발): 몬스터를 때려 아픈 스티커에 "Ouch!"가 그림 칸 안에 보이는지 PC·폰 사진.
- IconSaved가 Config.UIArt에 들어오면(이미지 개발 상점 묶음): 멈춤 카드 위에 저장 표시 그림.
