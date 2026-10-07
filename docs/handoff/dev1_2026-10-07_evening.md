# 게임성 개발 1 — 2026-10-07 저녁 (계정 바꾸기 전)

## 지도 v2 P2 (A23-53 / A23-74 "지형이 그림과 안 맞음")
- **코드:** 가지 `mapv2-p2`(Game-wtc2) → main. 오프라인 55묶음 통과, `tools/test_map_v2.py` 490/490·변이 28/28 + 새 검사 6개.
- **메인 Studio에 이미 한 것(MCP, 파일 저장은 아직):** `move --apply`(285개, 연못·왕 슬라임 언덕·고블린 야영지 3곳은 이야기 자리로,
  MeadowKit 조각별, MeadowPrimitiveBackup 자리도) → `terrain`(그림 지도처럼 둥근 해안·모래 띠·둥근 산, 3D 바다 바위 26,
  둥근 지형 연못 + 젤리 돌 9, 바다 색 8,181,214, 풀잎 끔, 교차로 금·빨강 줄 뺌) → `settle`(294개를 새 땅 높이로).
- **남은 순서:** sync(main과 같은 코드) → `py tools/map_v2_apply.py build` → `kits` → `py tools/play_mapv2_check.py pc` / `phone`
  (검수에 먼저 알림) → 사용자 Ctrl+S(파일) 확인.
- **백업:** `build/GoodEvil_before_v2.rbxl` = Studio 자동 복구본 17:12:56(v2 손대기 전, 검수 WorldKit3D·MeadowKit 들어 있음).
  되돌리기는 이 파일, 또는 ServerStorage.MapV1Backup(바꾼 옛 조각).
- **알아 둘 것(실측):** 지형 칸 쓰기에서 단단한 땅 윗면은 점유 경계보다 2 스터드 위에 그려진다(물은 아님) → `T.Lift = 2`.
  실행기의 `"__MODE__"` 바꾸기는 코드 줄(`local MODE = "__MODE__"`)을 바꿔야 한다(주석에 같은 글자가 있었음).
- 이미지 생성 1 시트(art/review/terrain/terrain_standout_2026-10-07.jpg): ②③⑦⑨ = 옛 덩어리 지형(없어짐), ⑬ 연못·⑫ 줄 = 고침,
  ①③⑧ 타일 = 이미지 개발 업로드 뒤 `tools/apply_surface_materials.lua`.
- 빛살 금지: WarService SunRays 모두 0 + SunRaysEffect Enabled=false (Studio Lighting의 효과는 Play 때 서버가 끔).

## 무기 먼저 (A23-74)
- 가지 `wtc-weapon-client`(Game-wtc) = 화면 쪽(대장간 빔·줄 탭 RequestTutorial·QuestTarget·FirstSteps 'the Forge'·가방 문구)
  + `origin/dev2-weapon` 49d2744 병합(c345d88). 검수 검토 통과 뒤 main → sync → `py tools/play_weapon_first.py pc` / `phone`.
- 개발 2 계약: `docs/design/weapon_first_server_2026-10-07.md` §4 a–h(a–e·g 끝, f 해당 없음, h = Studio에서 모루 앞 착지 확인).

## 소리 (소리 만들기 → 개발 1)
- 비어 있던 id 채우기: GooseArrive 113800368972766, Spend 80768400627761, RankUp 84902463002053, SkillLearn 113535664889883,
  GooseHonk 115693307820380(볼륨 0.4), ScrollSuccess 116061752455414. 표 `docs/design/sound_wiring_r4_2026-10-07.md`,
  확인 `py tools/sfx_wiring_check.py --ref origin/main`. 지도·무기 먼저 다음 차례.
