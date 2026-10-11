# 게임성 개발 2 — 상태 (2026-10-11 밤, 스스로 비우기 전 정리)

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). 큰 코드는 api_agent 쓰기 모드로 맡길 수 있음
(`py tools/api_agent.py run --prompt-file P.md --out build/api_agent/<job> --model opus|sonnet --max-usd 5 --max-turns 60~80
--make-worktree <ref> --write --branch api/<이름> [--allow-run-modified-py]`). 보고처 = '모든 것 검수'(id는 list_sessions로).
보고는 묶음마다 한 번(send_message), 그다음 턴 끝내기. 대화가 길어지면 이 파일 적고 push → clear_session("self").

## 오늘 밤 push한 가지 (검수 검토·병합 대기)
1. **fix/spawnclear 5e524e70** — A23-129 몹이 나무·바위·건물 안에서 안 나옴. worktree `C:/Users/glori/Documents/Roblox/wt_spawnclear`.
   MonsterService CLEAR 색인(Map 아래 모든 BasePart, CanQuery 꺼진 나무 메시도) + groundPoint(x,z,maxY,def) 몸 겹침 검사;
   pickSpawnPoint·SpawnEvent·MOB3.Spot·SpawnPersonal만 def. 시험 tools/test_spawn_clear.py(117·변이 35/35).
   읽기 전용 Studio 조각 tools/spawn_clear_probe.luau(메인 반영 1이 Edit execute_luau로; 구역마다 500 뽑기, RESULT OK/FAIL).
   기다리는 것: 검수 반박 검토, 숲 나무 규칙 판단(지금 = 나무 통짜 상자 → 고블린 숲 약 절반 면적 제외; 대안 = 줄기 기둥만),
   메인 반영 1 probe 결과(첫 색인 ms 포함).
2. **fix/lesstext-server 249a68a0** — A23-130 급한 묶음. worktree `C:/Users/glori/Documents/Roblox/wt_lesstext_server`.
   거위 시작 "Golden Goose!" 2초 한 번(Goose.StartSeconds, Text.Start; CoopStart·Story.GooseStart 삭제), 첫 미션 QuestStart·
   QuestReady 끔(5/5 때 줄 글 = 미션 줄 그대로), Claimed 하나 "+%s gold"(소리 QuestDone 유지). 시험 a23_14 99/99 등 보고함.

## 지금 할 일 (검수 지시, 다음 묶음)
**서버 글 판정표대로 고치기** — `docs/review/server_text_verdicts_2026-10-11.md`(358줄: OFF 105·SHORT 112·KEEP 141 + 표가
빠뜨린 글 21 + 끌 때 깨지는 것 44). 같은 가지 fix/lesstext-server(wt_lesstext_server)에서 이어서.
- 규칙: 소리 붙은 줄은 소리만 남기기(빈 글 Notify — UIKit이 빈 글을 버리는지, Audio.NotifySound가 소리를 내는지 먼저 확인),
  인자 개수 바뀌는 줄은 호출도 고침(예 GrudgeService:369), 빠뜨린 21개는 같은 기준(A23-99/130: 보상·위험/실패·막힌 이유·한 번뿐인
  안전만)으로 확인, 하드코딩 글은 Config.Text로.
- 개발 1 `origin/fix/lesstext`가 Config·StoryQuestService도 고침 → push 전 `git merge-tree --write-tree origin/fix/lesstext HEAD`로
  충돌 확인, 필요하면 origin/main 위로 rebase.
- 시험: 바뀐 글 키를 tools/*.py·tools/fixtures/*.luau에서 grep → 그 시험들 + 바뀐 서비스를 읽는 시험 전부(`grep -ln "<Service>.luau"
  tools/test_*.py`). 보고서(docs/art/verification_*) 덮어쓴 것은 커밋 전에 되돌림.

## 그다음 큐
1. **황금 알 줍기** Goose.Mode="Eggs" — 설계 `docs/design/golden_egg_2026-10-11.md` + SPEC A23-131·A23-134(알 술래 켬, 광장 같은
   속도, 명예/악명 1시간 한 번 +5, 장인도 알, 깃털 재료, 장인 1등 ×1.5). 검수가 spawnclear 검토 뒤 보냄.
2. **저장 v4 표**(개발 3과 합의, 개발 3 문서 `origin/dev3-v4-tables:docs/design/save_v4_tables_2026-10-11.md`): 내 답 = 역할별
   제작 레벨 OK, Pets.List[uid].Roll 보존은 개발 3 가지(Roll = { Spd 정수 5..10 }만 명시 보존), 순서 dev3 가지(Version 3) 먼저 →
   내 C1이 Version 4(T9 마스크·WeaponEnhance[9]·Spares·Market sanitize), 내 칸 추가 Shop = { Day, N }(오토 싼 재료 하루 50)·
   EggHonorAt(os.time), Gear.Own 상한 = Spares와 같게(키당 20, 합 60은 쓰는 쪽).
3. 11e §4: `api/dev2-l10n-a`(job dev2_l10n_a done, 79/80턴 $5.10, 커밋 1·13파일, uncommitted 2) 필수 시험 돌리고 실패 보완 →
   병합 요청. 제작 설계 `api/dev2-crafting-design` ea0ce9bc의 저장 호환·거래 원자성·열린 결정 11개 정리(A23-127 반영).
4. 한국어 서버 B·C(알림 → NotifyKey 등)는 제작 덩어리 사이사이에(옛 큐 그대로, 영어 글 한 글자도 그대로 비교 시험).

## worktree·도구
- 새 가벼운 worktree 만들기(0.5GB, 몇 초): `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` →
  `MSYS_NO_PATHCONV=1 git sparse-checkout set --no-cone /src/ /tools/ /docs/ /AGENTS.md`(Git Bash가 /src/를 C:/Program Files/Git/src/로
  바꿔 버림) → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`. worktree 안에서 `git commit -m … -- <경로>`.
- 옛 worktree: Game-dev2-ci, Game-dev2-hint(stage된 빛 마을 도구 8개 = 옛 검수 흔적, 건드리지 말 것), Game-dev2-pet, Game-dev2-snap.
- test_halloween은 art GLB가 필요: `art/models/tripo/MonsterBatGoblin_{Idle,Walk,Slash,Hurt,Fall}.glb`·`MonsterGoblin_Idle.glb`를
  Game에서 잠깐 복사 → 시험 → 지움. test_a23_14는 느림(변이 99개 약 40분, 출력은 끝에 한 번).
- 원래 있던 실패(내 변경과 무관, main에서도 같음): halloween 'pattern 0회' 2개, ops_safety 변이 "Halloween is not applied",
  test_skills STATIC "Q heals / steals through the window"(SkillService, 확인 안 함).
- 파이썬으로 고칠 때 Bash 안 `\n`·`\t`가 바뀜 → Write로 스크립트 파일을 만들어 실행.

## 참고
- 설계: docs/design/field_boss_crowd_2026-10-11.md, boss_leap_2026-10-11.md, new_zones_monsters_2026-10-11.md,
  crafting_market_2026-10-11.md(api/dev2-crafting-design).
