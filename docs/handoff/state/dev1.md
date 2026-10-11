# 게임성 개발 1 — 인계 상태 (2026-10-11 저녁, 19:00 리셋 전 정리)

클라 코드만(창·HUD·Config·Fx). worktree `C:/Users/glori/Documents/Roblox/Game-wtc` (브랜치 `invite`).
- 일 전에 `git fetch && git reset --keep origin/main`(이 worktree는 시험이 다시 쓴 docs/art 보고서가 늘 '바뀜'이라 ff-merge가 막힘 — reset --keep은 그대로 둠).
- 커밋은 pathspec. main에 올릴 때 거절되면 임시 detached worktree(`../tmp-dev1-push`)에서 cherry-pick → push → 지우기.
- 큰 코드는 사용자 규칙대로 **API 쓰기 모드**(`py tools/api_agent.py run ... --write --branch api/<이름>`, 안내 `docs/handoff/api_agent_howto.md`). 나는 프롬프트·diff 읽기·임시 worktree 시험·병합 요청만.
- Studio sync·사진은 메인 반영 1. 보고는 검수 local_94cfa4bc-942c-4ac1-97a4-e9f609739523.

## 오늘 main에 들어간 것 (요약)
- BB9 스킬 창 SkillBook(dfea1c5d → 글씨·한 화면·검토 고침 d86e4dce·키 숨김 f3bfc406).
- 걷는 바닥 WalkGround + Shared/Ground.luau(c45ed8c6).
- 쥐기: 대검 두 손 IK(dev1-twohand2) → 지팡이·플라스크(dev1-staffgrip) → 대검 폼멜·지팡이 작게·빈 손 몸 위 점·팔라딘 칼(dev1-grips9) → 팔라딘 얼굴·어둠 마법사 허리·중립 톱니 작게(dev1-grips10). 참고 문서 `docs/design/grip_reference_2026-10-11.md`, 목록 `grip_audit9_2026-10-11.md`, 시험 test_two_hand_grip·test_one_hand_grips. Studio 측정: 속성 GripProbe=true면 콘솔 `[WeaponPose] probe` 줄.
- King 뛰어 내려찍기 Fx 포물선(dev1-leapfx, 개발 2 landcircle과 병합).
- 빛 마을 조명 C2c(ZoneLook HaloTown).
- 한국어 모드 계약 v4.1 + 보강(`docs/design/l10n_contract_2026-10-11.md`, 7f3d691c) — 검수 승인. 개발 2에게 서버 13가지 전달.
- 스트리밍 위험표·미리 받기 계획(`docs/review/streaming_risk_2026-10-11.md`, a4ed79a2) — 켜기 결정은 검수(리셋 뒤).

## 다음 큐 (순서대로)
1. **api/dev1-l10n-core a8462d18** (L10n 중심: L10n.luau·TextKo·Net.NotifyKey/AllKey·UIKit Lang/LangChanged/Tx·알림 Key): 내가 이미 임시 worktree에서 시험함 — test_l10n 92·29/29, english, notify_sound 65/65, toast_queue 7/7, keys_settings, skill_book 32/32, quest_window 44/44 통과. 검수 병합 요청 보냄 → 병합 확인.
2. 한국어 클라 다음 덩어리(API 쓰기, 계약 §10-1 나머지): L10nText 처리기(간판 TextKey·현상수배판 BoardRows·글자 그림 Lettering 먼저), 프롬프트 훅(ActionKey/ObjectKey), Announce 조합기 → L10n.T, 이름표·몬스터 바 클라 조합, l10n_export --lettering·클라 표 export/apply. 그다음 첫 10분 화면 UIKit.Tx 키로.
3. 스트리밍 고침(검수가 켜기 정하면): A표 T-1(Intro RequestStreamAroundAsync)·T-2/T-3(모루 Config 좌표)·T-4(안내 앵커)·T-5·T-8 + B표 6줄, 미리 받기 P0~P6(Audio 118 나누기) — API 쓰기로.
4. 메인 사진 확인 뒤 쥐기 손보기(dev1-grips10 사진: 팔라딘 앞·3/4, 어둠 마법사 허리 100% 크롭, 중립 톱니).
5. 스킬 소리 41개 연결(id 오면), 개발 2 Z·X 패킷 필드(ContactDelay 등) SkillFx 연결.
6. 나중: 장인 기능 클라, 슬롯별 화면 흔들림 세기.

## 브랜치 / worktree (지워도 되는 것)
- 병합됨: ../Game-dev1-opening(dev1-opening-v2, 6단계 때 병합 예정 — **지우지 말 것**), ../Game-dev1-twohand·twohand2, ../Game-dev1-staffgrip, ../Game-dev1-grips9, ../Game-dev1-grips10, ../Game-dev1-leapfx — 지워도 됨(worktree 만들기가 몇 분 걸리니 필요할 때만 새로).
- 옛: ../Game-dev1-tiles(dev1-hint), ../Game-dev1-grips(dev1-grips2), ../Game-dev1-zonelook — 지워도 됨.

## 알아둘 것
- 시험은 동시에 3개까지. Luau 오프라인: build/luau_cli_0_741(새 worktree에는 Game/build에서 복사).
- Bash 도구는 문자열 속 \n을 줄바꿈으로 바꿈 → 시험 파일 수정은 Write/Edit로.
- 직업 id는 Warrior/Mage/Archer뿐(진영으로 이름이 바뀜: 연금술사 = Mage+Neutral).
- HUD.luau·Fx.luau·UIKit.luau는 지역 변수 200개 한도 근처 → 새 값은 표(L / MOTION / UIKit 필드)에.
