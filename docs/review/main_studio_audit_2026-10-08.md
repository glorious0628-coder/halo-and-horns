# 메인 Studio 적용 확인 (2026-10-07, 읽기 전용)

**확인 기준:** `build/GoodEvil.rbxlx`(사용자가 17:55:54에 저장, 21,395,764 B), `place/GoodEvil.rbxlx`(14:06, ce27afa), origin/main `src/`. Studio와 MCP는 쓰지 않았습니다. 17:55 뒤에 한 작업은 틀렸다고 하지 않고 "저장 파일에 아직 없음(⏳)"으로 적었습니다.

**요약**
- 저장 파일의 스크립트 105개는 모두 cf78a4d(17:09)와 같습니다. 17:55 전에 push된 코드 가운데 빠진 것은 없습니다. origin/main과 다른 6개(Config·MapBuilder·HUD·Intro·QuestTarget·WarService)는 모두 17:59 뒤 커밋(0652ae92·0a69905b·30e3d3e5)에서 바뀐 것입니다.
- **md에는 됐다고 적혀 있지만 실제로는 다른 것**
  1. settle을 실행한 뒤 Horns 성이 약 33 stud 땅에 묻혔습니다(절반쯤). 폐허 장식 13개와 나무 2그루는 땅속에 들어갔습니다.
  2. 하늘 왕관 빌보드가 꺼져 있고 켜는 코드도 없어서 한 번도 보이지 않습니다.
  3. 제단은 아직 0.5초 누르기입니다.
  4. 자동 번역 끄기 훅이 ProximityPrompt에는 적용되지 않습니다.
  5. `tools/test_place_english.py`가 한글을 읽지 못해서, 지금까지의 "통과" 기록은 증거가 되지 않습니다.
- **저장하지 않은 작업이 사라질 위험:** 20:56 확인 기록(main_checklist, 0fe49458)에는 SunRays 꺼짐과 FF2 타일 9장이 들어가 있는데, 파일은 17:55 그대로입니다. 저장하지 않고 닫으면 사라집니다. (이 기록이 어느 Studio에서 나왔는지는 확실하지 않습니다. 같은 폴더의 story 로그는 Game-wtc2에서 썼습니다.)
- `place/`는 14:06본이라 `build/`보다 약 4시간 늦습니다.
- **21:01~21:03에 새로 들어온 것(파일에는 아직 없음):** 말풍선 12장이 업로드됐고 origin/main Config에 id가 기록됐습니다(270b9c3e). 몬스터 색 고친 텍스처 3장도 검수 OK를 받았습니다(a2a97be0·d867c779). 아직 업로드와 적용은 안 됐습니다.

## 1. ◐ / ❌: md와 다르거나 일부만 된 것

| ID | 주장 | 상태 | 근거 | 고칠 사람 |
|---|---|---|---|---|
| MV-03 | settle로 294개를 새 땅 높이에 놓음 | ◐ | 294개 모두 처리는 됐습니다. 그런데 HornsCastle은 MapV2Ground -33.27이라 v4 중심 Y가 -0.37(14:06에는 32.71), 바닥 약 -33입니다. 폐허 BrokenPillar 6·Tombstone 2·SoulWisp 2·RedEye 2·DarkBush 1이 통째로 땅속에 있고, Decor.Tree 2그루가 25·43 stud 가라앉았습니다. Halo 성은 정상입니다 | 개발 1 |
| K3-02 | 하늘 왕관 빌보드가 앞 ¾ 각도로 보임 | ◐ | 카메라 각도는 맞습니다(위 25.0°, 옆 30.0°). 하지만 CrownSkyBillboard가 Enabled=false이고, 켜는 코드가 저장 파일에도 origin/main에도 없습니다. 지금 보이는 왕관은 3D CrownOfBalance입니다 | 검수 결정 → 개발 1 |
| OLD-02 | 대장간·제단·물약이 E키로 바로 열림(Hold 0) | ◐ | 대장간·물약·게시판은 0입니다. 제단 AltarPrompt만 HoldDuration 0.5입니다(ensureAltarPrompt, 10/02부터). SPEC A23-10에는 제단이 없고 HANDOFF_CODEX:55에만 있습니다 | 검수 결정 → 개발 1 |
| A74-11 | 자동 번역 끔 | ◐ | ClientMain의 GuiBase2d 훅은 들어갔습니다. ProximityPrompt는 GuiBase2d가 아니라서 빠지고, AltarPrompt는 AutoLocalize=true입니다. Creator Dashboard 스위치는 사용자가 꺼야 합니다 | 개발 1, 사용자 |
| MV-04 | 맵 v2가 main과 17:55 저장본에 들어감 | ◐ | 지형, 이동한 285개, v2 Zone 파트는 있습니다. 코드(0652ae92, 17:59)는 없습니다. Config HaloTown이 (0,0,-400) 160×160이고 v2는 (0,0,-515) 400×370입니다. Bounds·Spawn·Gate·QuestTarget Field·HUD STORY_SPOT·Intro Halo도 모두 v1입니다. 이대로 플레이하면 Zone(v2)과 Config(v1)가 어긋납니다. md에도 "남은 것"으로 적혀 있습니다 | 개발 1 |
| A74-01 | 프롤로그 검은 띠 없앰(PC·폰) | ◐ | 코드는 들어갔습니다(IntroBars 0). 사진은 PC만 있고, 폰은 20:56 로그(bars=[])뿐입니다 | 개발 1 (폰 사진) |
| A74-02 | 한국어 팀 알림 → 영어 | ◐ | 코드와 인스턴스는 들어갔습니다(HookTeamLine, ChatLocalization []). cf78a4d 뒤에 한국어 로케일로 Play해서 확인한 기록이 없습니다 | 개발 1 |
| A74-08 | 미니맵이 이동 방향으로 돎 | ◐ | A23-66 코드는 있습니다. 하지만 A74-03(카메라가 등 뒤로) 조건이 빠졌고, 16:24 뒤 PC·폰 사진이 없습니다 | 개발 1 |
| D71-02 | 첫 스킬 뒤에만 자동 전투, 배운 스킬만 사용 | ◐ | 코드는 들어갔습니다(SkillService 잠금, S0 SkillHit). Lv5 Play 확인은 dev1_handoff:37에 아직 남아 있습니다 | 개발 1 |
| SND-02 | 새 효과음 업로드·연결표 전달 | ◐ | 57개 가운데 30개만 Config에 연결됐습니다. SkillLearn·GooseArrive·Spend·RankUp은 아직 ""입니다. md에도 "연결은 나중"으로 적혀 있습니다 | 개발 1 (서버 이벤트는 개발 2) |
| X-PLACE | place/ = build/ (AGENTS 규칙 3) | ❌ | place/는 14:06본입니다. 스크립트 88/105만 origin/main과 같고 FountainFx가 없습니다. WorldKit3D는 20개이고 MeadowKit과 새 지형이 없습니다 | 개발 1 |

## 2. ❌: 아직 안 한 요청 (md에 "완료"라는 주장 없음)

| ID | 요청 | 근거 | 고칠 사람 |
|---|---|---|---|
| K3-07 | 분수를 Halo 분수 HD ②로 | Town_Halo_Fountain 인스턴스가 없고 K_Fountain 그대로입니다. 인벤토리에 "아직 업로드 안 됨" | 이미지 생성 1 → 배치 |
| K3-08 | 텍스처 고친 성 2채로 교체 | Mesh/Texture id가 처음 Tripo 것 그대로입니다 | 이미지 생성 1 → 개발 1 |
| A74-03 | 걸을 때 카메라가 등 뒤로 | CameraFollow MinDot 0.5 그대로이고 fix/a2374-camera2는 병합 전입니다 | 검수 리뷰 → 개발 1 |
| A74-04 | 무기 먼저(첫 목표 대장간) | FirstSteps에 "Forge"가 0개입니다. dev2-weapon·wtc-weapon-client·dev2-sound는 병합 전입니다 | 검수 → 개발 1 |
| A74-05 | 몬스터별 말풍선 12종 | 21:03에 업로드와 origin Config 기록은 끝났습니다(270b9c3e). bark2 코드는 병합 전이고 저장 파일에는 BarkBubble 하나뿐입니다 | 검수 bark2 → 개발 1 |
| A74-06 | Dailies 글자가 테두리에 겹침 | main에 고친 커밋이 없고 imgdev-hud-wip에만 있습니다 | 이미지 개발 → 검수 → 개발 1 |
| A74-07 | PC·폰 같은 HUD 틀 | HudLayout은 여전히 A23-40 B이고 imgdev-hud-wip은 병합 전입니다 | 이미지 개발 → 검수 → 개발 1 |
| A74-09 | 몬스터 색이 형광 초록 | Slime TextureID가 10:24 것 그대로입니다. 고친 텍스처 3장은 21:03에 검수 OK를 받았지만 업로드 전입니다 | 이미지 개발 업로드 → 개발 1 |
| A74-10 | 몬스터가 비치거나 겹침 | translucent·separation 브랜치는 병합 전입니다 | 검수 → 개발 1 |
| D69 | 스탯 포인트 | main에 StatPoints가 0개이고 dev2-sound에만 있습니다 | 개발 2 → 검수 → 개발 1 |
| D62 | 스킬에 무료 이펙트 | SkillFx 0개입니다. 출처 표에는 분수 텍스처만 있습니다 | 이미지 개발 → 사용자 선택 → 개발 1 |

## 3. ⏳ 저장 뒤 / ? 모름

| ID | 주장 | 상태 | 근거 | 고칠 사람 |
|---|---|---|---|---|
| MV-05 | SunRays 끔 | ⏳ | 파일의 WarService는 2c5e84ed이고 Lighting.SunRays가 Enabled=true, 0.04입니다. 20:56 기록에서는 꺼져 있습니다 | 개발 1 저장 |
| MV-07 | FF2 지형 타일 9장 | ⏳ | 파일의 MaterialService 9개는 모두 옛 id입니다(30e3d3e5는 19:02). 20:56 기록에서는 새 id입니다 | 개발 1 저장 |
| K3-04 | 숲 키트(202개, 나무 102) | ⏳ | 파일에 Decor.WoodsKit이 없고 원시 Tree 30개 그대로입니다. 19:02 Edit 확인을 어느 Studio에서 했는지 기록이 없습니다 | 개발 1 확인 |
| MS-03 | 기기 에뮬레이터 끔 | ? | Studio 설정이라 .rbxlx에 저장되지 않습니다 | 개발 1 (실행 중 Studio 확인) |

## 4. ✅ 적용됨 (저장 파일에서 확인)

| ID | 내용 | 근거 |
|---|---|---|
| MS-01·02·04 | 17:55 저장, cf78a4d 동기화, place/=713fd05 | 105/105가 cf78a4dc와 같습니다. place/ 104/104가 713fd05와 같습니다(WorldKit3D 20개인데 커밋 본문은 19개, Crown_Broken_B 하나 차이) |
| MS-05·06, K3-03 | WorldKit3D 61, MeadowKit 60 + 백업 68, 숲 모델 17 | 이름과 개수가 맞습니다. Kit_W_Campfire만 없습니다(다시 그리는 중) |
| MV-01·02 | v2 이동 285·MapV1Backup·Zone 크기, 바다 색·바위 26·젤리돌 9·금/빨강 띠 제거 | 해안과 산 모양은 눈으로만 판단할 수 있습니다 |
| MV-06 | 밝은 낮 조명, 큰 간판 제거 | TextLabel은 7개입니다(주장의 "8"은 숫자만 틀림). clearGateSigns 있음 |
| K3-01·05·06 | 성 2채와 KitOld, 교차로 키트 37·KitStage 27, MarkModels 10 | id가 맞습니다. Horns 성 높이 문제는 MV-03에 있습니다 |
| K3-09~12 | FountainFx, GhostKing/Minion, 몬스터 14종, 슬라임 뒷면 없는 텍스처 | 해시와 id가 맞습니다. 분수 물줄기는 Play에서만 볼 수 있습니다 |
| D71-01, D70, D68, D61 | 스킬 Lv5/15/25, 도시락 카드, 첫 3분, 앞 반원 공격 | 코드가 같고 Play 로그가 있습니다 |
| D66-65, D63, D60, D58, D57, D51, D40, D36 | 카메라 따라가기, 폰트, MP 표시, 반대편 감점, 중립 막음, 우클릭 회전, HUD B, 퀘스트 표시 | 소스가 origin/main과 같습니다 |
| D48 | 영어만 표시 | 인스턴스 한글 0개입니다(바이트를 디코드해서 다시 셈). 도구 버그는 5절에 적었습니다 |
| SND-01 | 효과음 30개 연결 | HurtBig·PumpkinKing·GhostKing·SkillReady 등이 있습니다 |
| ART-01~07 | 보상창, 월드맵, 광선 제거, 초상화, UI 25, 숲 아이콘, GE_Basalt와 영어 라벨, Firefly 20장 | id가 모두 맞습니다(IconRankPvP는 aebf974d에서 일부러 바꾼 id) |
| OLD-01·03·04 | 안전 지역에서 이동 취소 안 됨, 몬스터 움직임 35클립, 내 이름표·마법사 1.1초·물약 25 | 소스가 같습니다 |
| BB-01·02, E11 | 플레이어 목록·PublicName, 핼러윈, 일거리 게시판 코드 | 들어가 있습니다. BB37 2인 확인은 남았습니다. 게시판은 Board.Enabled=false라 안 보이는 것이 정상입니다 |

## 5. 그 밖에 찾은 것
- `tools/test_place_english.py`의 scan_file이 Roblox 바이트 참조를 Latin-1로 읽어서 한글을 보지 못합니다. 84c7dbdd 전 place(한국어 라벨 9개)도 0으로 보고했습니다. 도구 주인인 개발 2가 고치고, 검수가 다시 돌려야 합니다.
- beta_board의 HW-11(시작 안 함)과 RP6-C(진행 중)는 실제로 파일에 다 들어가 있습니다. 검수가 완료로 바꿔야 합니다.
- HANDOFF_CODEX:55의 제단 문구와 `art/ui/asset_ids.json`의 UIP_IconPouch 메모(옛 id를 새 것처럼 적음)를 정리해야 합니다.

## 6. 게임성 개발 1 할 일 (우선순위 순)
1. **지금 열려 있는 메인 Studio부터 저장합니다.** 검수에게 "전달함, 시작"을 받은 뒤 File > Save to File As `build/GoodEvil.rbxlx`로 저장하고 시간과 해시를 확인합니다. 17:55 뒤에 바뀐 SunRays·FF2 타일이 파일에 없습니다.
2. **묻힌 장식을 Edit에서 바로잡습니다.** 대상은 HornsCastle(약 +33 stud), 폐허 13개, Decor.Tree 2그루입니다. |MapV2Ground|>5인 조각은 MapV2Ground=0으로 두고 MapV2Settled를 지운 뒤 `py tools/map_v2_apply.py settle`을 다시 돌립니다. 숲 키트가 원시 나무를 바꿨을 수 있으니 먼저 눈으로 확인합니다.
3. **origin/main 동기화와 맵 v2 마무리.** `git rev-list --left-right --count HEAD...origin/main`이 `0 0`인지 확인합니다. 그다음 `py tools/sync_to_studio.py` → `py tools/map_v2_apply.py build` → kits 순서로 돌려 Zone(v2)과 Config(v1)가 어긋난 것을 해결합니다.
4. MaterialService가 FF2 새 id인지 확인합니다. 아니면 `tools/apply_surface_materials.lua`를 Edit에서 돌립니다. Lighting.SunRays.Enabled=false도 파일에 남도록 합니다.
5. 메인 Studio에 Decor.WoodsKit(202개, 나무 102)이 없으면 `tools/worldkit/woods_kit_place.luau`를 돌립니다.
6. 하늘 왕관 빌보드는 500 stud 밖에서 켜는 코드를 넣을지, 안 쓰는 것으로 문서를 고칠지 검수와 정합니다.
7. ClientMain 훅에 ProximityPrompt `AutoLocalize=false`를 추가합니다. 제단 HoldDuration은 검수 결정에 따라 0으로 바꾸거나 문서를 고칩니다.
8. 효과음 r4 연결: `docs/design/sound_wiring_r4_2026-10-07.md`대로 연결한 뒤 `py tools/sfx_wiring_check.py --ref origin/main`으로 확인합니다.
9. 검수 통과 뒤 병합합니다. 순서는 camera2 → dev2-sound와 wtc-weapon-client(한 번에) → translucent·separation → bark2(270b9c3e의 12줄 유지) → imgdev-hud-wip입니다. 하나씩 병합할 때마다 sync합니다.
10. 몬스터 색 고친 텍스처 3장은 이미지 개발이 업로드하면 CustomModels의 TextureID를 바꿉니다.
11. PC·폰 Play로 확인하고 사진을 남깁니다: 프롤로그(폰), 한국어 로케일 팀 알림, Lv5 자동 전투, 미니맵 회전, 분수 물줄기, BB37 2인. 에뮬레이터 Device = none도 확인합니다.
12. 마지막으로 Save to File As `build/`로 저장하고 `place/`로 복사합니다(시간과 해시 확인). 그다음 `py tools/push_paths.py`로 src와 함께 push합니다.