# 게임성 개발 2 인계 상태 (2026-10-06 저녁, 계정 옮기기로 멈춤)
> **최신(2026-10-06 밤):** A23-34 맨손 시작(4610671 + 증거 693c653) + 검수 3건 고침 + A23-39 펫 조련사(0b0133f) 끝, 병합 요청은 검수 경유. 계약: `docs/design/unarmed_start_server_2026-10-06.md`, `docs/design/pet_tamer_server_2026-10-06.md`(개발 1 연출 원격 계약 10/15). 검사: test_unarmed_start 224·72/72, test_tamer 93·36/36, 다른 묶음 전부 통과.
> **다음 순서(검수, A23-48 반영):** 영어 전환(Config.luau 플레이어용 문구 전부 약 600줄을 영어로 바꾸기, '내 캐릭터 창' = Hero; **건드리지 않기(dev1 몫): Config.Settings.Window, Config.Help, BuildLabel, Keybinds Auto LabelEn**; 안내자 Welcome Lines는 영어로; 서버가 보내는 모든 문구를 영어로, 쉬운 영어·용어는 docs/design/glossary_en_2026-10-06.md, LocaleId·Settings.Lang 만들지 않음, 검사는 영어 기준) + DataService 잠금 재시도(6초×5, '저장 불러오는 중…', Studio 잠금 만료) → A23-46 마을 사람 서브 퀘스트(H1·R1·N3 10/15까지, 처음부터 영어, NPC id·대화 키 계약 개발 1에) → 랭킹 낮은 2건 → BB14 나머지 → 펫 PET-1·2·4·6.
> **그 뒤(10/22 목표):** IDEA-TITLE → IDEA-HWWEEKEND(끝나면 시간당 보상 숫자를 검수에) → IDEA-HWSTAMP → IDEA-MARKGROW(밀리면 정식으로). 아래 절들은 지난 기록.
일하는 곳: worktree C:/Users/glori/Documents/Roblox/Game-dev2 (dev2 브랜치, origin/dev2에 푸시됨). Studio 금지.

## 병합 대기 커밋 (dev2, main 5664842 위, 게임성 개발 1 [348428]에 병합 요청 보냄 — C 묶음 다음에 병합한다고 답함)
1. **eac036f** 랭킹 서비스(BB10)·주간 정산·무법자·1~3위 보상 — test_ranking 474→(BB11 뒤) 486검사, 변이 186/186. 검수 10건 + 반복 KO 결정 + 자체 검토 2회 반영. 메모 docs/design/ranking_service_plan_2026-10-06.md §13.
2. **ff38ce4** 가방 '얻은 순'(A23-32 ItemSeq): Inventory 페이로드에 ItemSeq·WeaponSeq 추가, test_item_seq 40·15/15, loot fixture 페이로드 모양 2곳 수정.
3. **e078bf5** 마을 게시판(BB11 서버): '이 서버 · 이번 주 순위' + 명예·악명·장인·이번 주 PvP 각 TOP3 + 현상수배 한 줄, 무법자 딱지는 지금 무법자만. RankingService.ServerTop. 게시판 ProximityPrompt→OpenPanel 'Ranking'은 게임성 개발 1 몫.

## 커밋 안 한 파일 (dev2 작업 트리) — BB14 쓰러짐 화면 서버 쪽, 오프라인 통과(32검사, 변이 16/16)했지만 지시대로 커밋 안 함
- src: CombatService.luau(DamagePlayer 5번째 인자 sourceKind, lastSource, sendKO → Net.Fx(victim,'KO',{By,Name,Faction,Lost,Sack,RespawnIn}), onCharacterDied 몸 위치/자유낙하), KaijuService.luau(밟기 sourceKind "Kaiju"), MonsterService.luau(rec.Kind 넘김 1줄, 게임성 개발 1 파일 — 병합 때 알릴 것), Config.luau(끝 블록 Config.Death 문구·팁 KO/EN).
- tools: dev2_offline.py(Suite에 world 파일 옵션), fixtures/dev2_world.luau(새, ranking_offline의 세계를 옮김), fixtures/ranking_offline.luau(세계 부분 빠짐), test_ranking.py(world=), fixtures/ko_screen_offline.luau(새), test_ko_screen.py(새).
- 증거: docs/art/verification_2026-10-06/offline_dev2_ko_screen_2026-10-06.json(새), offline_ranking_2026-10-06.json(다시 돌림 486·186/186). 나머지 offline_*.json 변경은 다른 세션 증거라 `git checkout --`으로 되돌릴 것.
- 다음 세션: 위 파일을 그대로 커밋(제목 예: "쓰러짐 화면 서버 쪽(BB14 KO 페이로드)")하고 병합 요청에 추가하면 됨. 커밋 전에 `py tools/test_ko_screen.py`, `py tools/test_ranking.py` 한 번 더.

## 다음 할 일 (검수 순서)
1. **A23-34 맨손 시작 서버 쪽** — C 묶음(게임성 개발 1: LootService onEquipWeapon·FitWeaponToLevel·ProgressionService)이 main에 들어간 뒤 rebase하고 시작. 범위 조사 결과(에이전트 4명): 핵심은 Config.WeaponDamage가 tier 0을 tier 1로 바꿔치기하는 것(→ Weapons[tier] 없으면 Config.Combat.Unarmed), CombatPower(맨손은 PowerOf - PowerOf(1,0)로 Lv1=0), Config.Combat.Unarmed {Damage=5, Range=7, Interval=0.8} 제안(슬라임 HP10에 4대), WeaponName/WeaponArtKey tier 0, Data.Defaults WeaponTier/OwnedMask 0(DataService 이주가 비트 1을 강제로 켜는 곳 고침), Shop/Loot/Quest/Telemetry의 '시작 무기 비트' 가정, M1_1 보상 T1 지급+장착(한 번) + "첫 무기를 받았어요! 전투력 0 → N", CharacterVisuals 무기 0 = 빈손. 조사 원문: 세션 작업 폴더의 workflow 결과(w8iu5oj0m) — 없으면 다시 조사.
2. BB14 위 파일 커밋·병합(이미 완료 상태).
3. 펫 서버 PET-1(이동 속도 한곳 계산, 상한 ×1.35) → PET-2(저장·EquipPet·펫 XP) → PET-4(길 잃은 아기 슬라임) → PET-6(획득 전체 알림).
4. 10/17 뒤 후보(검수 메모): 뿅뿅 꼬마 슬라임·호박 까꿍 유령·사냥터 숨결(docs/design/fun_world_ideas_2026-10-06.md).

## 규칙 기억
- 병합 전 `git rebase main`, 경로 지정 커밋, 변이 포함 증거만 커밋(--no-mutations 보고서는 status 'passed-no-mutations'라 커밋 금지).
- halloween 오프라인 3건 실패는 main HUD 쪽(이미지 개발 몫), dev2 변경과 무관.
