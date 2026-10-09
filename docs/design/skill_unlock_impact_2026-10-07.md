> **검수 결정(2026-10-07, 이 목록의 D1~D6):** D1 = ~~S0 시험 b를 스킬 없는 Kill 2로~~ → **사용자 정정: S0 시험 b는 스킬 그대로(A), 자동 전투는 Lv5 뒤**(dev2 940fb2e대로) · D2 = M1_3 앞에 'Lv5 · Learn your first skill (now Lv%d)' 단계 추가 · D3 = Lv1-4 일일은 왕 슬라임·슬라임·골드(중복 거르기) · D4 = 옛 세이브 한 번 보정은 넣는다(작음, SkillRule71 깃발) · D5 = 퍼널 FirstSkillHit를 AutoUnlocked 뒤로 · D6 = Help 'Your first skill comes at Lv 5…', 다음 목표 'Next goal · Lv%d: first skill + Iron weapon (now Lv%d)'.

# A23-71 스킬 해금 변경: 고칠 곳 목록 (2026-10-07)

> 기록용(10/07 당시, 반영 끝: `Config.Skills.Unlock = { Q = 5, Z = 15, X = 25 }`, SkillSlots 기본 0). 지금과 다른 점: 스킬 키는 Z·X·C(Q·Z·X는 내부 id), 'Press Q' 안내는 지금 키 이름으로 나옴(최신: SPEC A23-78). SkillLearn 소리는 소리 만들기 세션 몫으로 들어감(ab708339), 메인 Studio 동기화·Play는 이제 메인 반영 1(10/09 역할). 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

**기준**
- **코드 기준:** origin/main `eecc7b3`(13:08, 이미지 개발이 방금 올림)에서 줄 번호를 하나씩 확인했다.
  - dev2 `c15b67b`의 서버 파일은 main과 같다.
  - dev2의 Config.luau는 1446줄 뒤가 6줄씩 아래에 있다(예: 2006 → 2012, 2839 → 2845).
- **해금 숫자:** SPEC A23-71 정정본대로 **Q = Lv5, Z = Lv15, X = Lv25**로 한다(사용자 "5, 15, 25에 배울 수 있게 하자", 90ac571).
  - 작업 지시에 적힌 Z Lv10·X Lv15는 정정 전 안이다. 이 목록은 모두 5/15/25 기준이다.
- **지금 main의 상태:** `Config.Skills.Unlock`이 아직 `{ Q = 1, Z = 5, X = 8 }`이다.
  - 그래서 화면은 예전과 같고 Q가 Lv1부터 보인다.
  - 클라의 숨김 작업은 이미 들어가 있다. 개발 2가 Config를 바꾸면 그때 함께 켜진다.

## 0. 이미 끝난 것 (다시 하지 말 것)

| 커밋 | 들어간 것 |
|---|---|
| da6402b (개발 1) | **SkillBar:** 해금 전에는 버튼을 숨긴다(`visible = st.On and not st.Locked`). 배우는 순간에는 "New skill! 이름" + 버튼 톡 + "Press Q"/"Tap the new button" + 소리(SkillLearn이 없으면 PowerUp). 해금 전에 키를 누르면 "Skills come at Lv N".<br>**FirstSteps:** 첫 처치 뒤 Q 힌트를 지우고 first_steps 테스트도 고쳤다.<br>**test_skill_learn:** Unlock을 5/15/25로 덮어써서 시험한다. |
| eecc7b3 (이미지 개발) | HUD.Hint가 "Z"/"X"를 지원하고, 힌트는 한 번에 하나만 뜬다.<br>Q가 숨으면 물약이 공격 버튼 옆으로 붙는다(HudLayout `hidden.q`, HUD `L.SkillHidden`). hud_layout 테스트에 이 경우를 더했다. |

**받은 목록에서 뺀 것**
- **중복:** Config Unlock·Defaults, S0, M1_3, 일일, Help, Skills.Text, SkillBar 예비값, 서버 테스트는 두 번씩 적혀 있어 하나로 합쳤다.
- **이미 끝남:** FirstSteps Q 힌트와 그 테스트, SkillBar의 잠긴 칸 표시, HUD HintTarget Z/X, Hidden.q, HudLayout 빈칸.
- **숫자가 틀림:** Q5/Z10/X15로 적힌 항목들, 'Lv10에 Z 배우는 순간과 숲 안내 빛이 겹침'(Z는 이제 Lv15).
- **바꿀 것 없음, 확인만:** Fx 레벨업 배너, Keybinds SkillQ, ClassPicker·안내자 문구(스킬 말이 없음).

## 1. 게임성 개발 2: 서버·Config (dev2, 한 묶음으로)

| # | 위치 | 지금 | 바꿀 것 |
|---|---|---|---|
| S1 | Config.luau:553 (+주석 540-541) | `Unlock = { Q = 1, Z = 5, X = 8 }`, 주석 "Q (Lv1) / Z (Lv5) / X (Lv8)" | **[필수]** `{ Q = 5, Z = 15, X = 25 }`로 바꾸고 주석도 고친다 |
| S2 | Config.luau:194-196 (Data.Defaults) | `SkillSlots = 1`, 주석 "1 = Q, 2 = +Z at Lv5, 3 = +X at Lv8" | **[필수]** `0`으로 바꾼다. 주석은 "0 = none, 1 = Q Lv5, 2 = +Z Lv15, 3 = +X Lv25, all after a rebirth, never lowered". Mirrored(209)는 그대로 |
| S3 | SkillService.luau:73-75 `slotsOf` | `num(attr, 1)`을 1..3으로 자른다. 그래서 Q는 늘 허용된다 | **[필수]** 기본값 0, 범위 0..3. 그러면 Cast(378-381)가 수동 Q에는 "Locked"를 보내고, 자동 Q는 조용히 거절한다 |
| S4 | SkillService.luau:409-418 `slotsFor` (+머리 주석 18-20, 409 구획 제목) | `n = 1`에서 시작해 Z(5)·X(8)에서 1씩 더한다. 환생이면 3 | **[필수]** `n = 0`에서 시작해 Q 5 / Z 15 / X 25에서 1씩 더한다. 환생이면 3(SKL-2)은 그대로.<br>권함: 규칙을 `Config.SkillSlotsAt(level, rebirths)`로 옮긴다. 그러면 퀘스트·게시판·테스트가 같은 규칙을 쓴다 |
| S5 | SkillService.luau:421-436 catchUp, 476-478 | 칸을 올리기만 하고 내리지 않는다. 레벨업·환생으로 새 칸이 열리면 Fx "SkillUnlocked"를 보낸다 | 바꿀 것 없음. Lv5가 되면 SkillSlots 1과 Fx Q가 저절로 간다. 클라는 이 Fx를 듣지 않는다 |
| S6 | DataService.luau:426-436 (fillDefaults 436 앞) | Lv1-4 옛 세이브에는 SkillSlots = 1이 저장돼 있다. 칸은 줄지 않으므로 Q가 계속 열린다 | **[D4 결정 뒤]** 한 번만 보정한다.<br>- 저장 깃발(예: `SkillRule71`, 새 세이브는 기본 true)이 없으면 `SkillSlots = (옛값 >= 2) and 1 or 0`으로 바꾼다.<br>- 옛 규칙에서 2 이상이면 Lv5를 넘은 것이다. 나머지는 PlayerReady 때 catchUp이 맞춘다.<br>- 베타 전이라 테스트 계정뿐이므로 생략도 가능하다 |
| S7 | Config.luau:2004-2008 (S0 시험 b = 2006), StoryQuestService.luau:279 | 자동 전투를 여는 S0의 시험 b가 `{ Type = "SkillHit", Min = 2 }`다. 그래서 자동 전투가 Lv5까지 잠긴다. AGENTS의 "진영 직후, 레벨 조건 없음"과 부딪친다 | **[D1 결정 뒤]** Key "b"는 그대로 두고 스킬이 필요 없는 시험으로 바꾼다.<br>- 있는 타입만 쓴 예: `{ Key = "b", Type = "Kill", Kind = "Slime", Near = "SlimePond", Radius = 40, Count = 2 }`. eventAmount 209-212가 Near를 지원한다.<br>- 다른 길: 자동 전투를 Lv5부터로 받아들이고 A23-1 문구를 고친다 |
| S8 | Config.luau:2046-2050 (M1_3), Main 순서 1951 | 단계가 `SkillHit Min 1 ×3` 하나뿐이다. Main 퀘스트는 목록 순서대로 온다(StoryQuestService:434-445). 그래서 Lv1-4에서는 메인 줄이 멈춘다 | **[D2 결정 뒤]** 맨 앞에 레벨 단계를 넣는다: `{ Text = "Lv5 · Learn your first skill (now Lv%d)", Guide = "SlimeMeadow", Obj = { Type = "Level", Level = 5 } }`. 2126·2226·2235·2244와 같은 꼴이다.<br>- 지금 Start 줄은 SkillHit 단계로 옮기고, 새 Start를 단다(예: "Grow to Lv5 to learn your first skill!").<br>- 다른 퀘스트: M2_5(2114)와 N1(2286)은 M1_3 뒤라 저절로 Lv5 이후다. M3_7(2237)과 GW7(2638)은 Lv21이다 |
| S9 | Config.luau:2809 (Templates Release), 2839 (Newbie), 주석 2818-2820; QuestService.luau:261-270 | 'Skill hits'가 Lv1-9 일일 후보(가중 3)이고, 모든 추가 퀘스트 후보(가중 20)다. Lv1-4는 이걸 끝낼 수 없다 | **[필수]**<br>- Templates의 Release 줄에 `NeedSkill = true`를 붙인다. 밴드 줄은 템플릿을 그대로 쓰므로 2839·2856·추가 퀘스트가 모두 해당된다.<br>- 261줄 루프에서 `rt.NeedSkill`이고 `max(data.SkillSlots, SkillSlotsAt(level, rebirths)) < 1`이면 그 줄을 뺀다.<br>- 주의: 그러면 Lv1-4 후보는 Kill(왕 슬라임)·Kill(슬라임)·Gold뿐이다. 270줄이 후보 전체로 돌아가므로 셋째 칸에서 같은 왕 슬라임 3을 또 뽑을 수 있다 → `(Id, Monster)`로 중복을 거른다.<br>- Lv1-4 세트는 왕 슬라임 3 + 슬라임 12-15 + 골드가 된다(D3). 2820줄 주석도 고친다 |
| S10 | QuestService.luau:349-361 ensureSlots | 저장된 미완료 Release(일일·추가)는 문구만 다시 쓴다 | **[선택]** 스킬이 없는 플레이어의 미완료 Release는 onFactionChanged(1095-1113)처럼 다시 뽑는다. 일일 보상은 그대로 둔다(CR-L12). 이걸 하면 T4도 고쳐야 한다 |
| S11 | Config.luau:2762 (게시판 J4), 주석 2731; BoardService.luau:117-122 eligible, 175-189 cardsOf | J4 'Hit 3 at once'(SkillHit Min 3)가 초원 게시판(Level 1)에도 나온다. eligible은 NeedAuto만 보고, cardsOf는 저장된 카드를 다시 검사하지 않는다 | **[Board.Enabled를 켜기 전]**<br>- J4에 `NeedSkill = true`를 붙인다.<br>- eligible에서 SkillSlots < 1이면 false를 돌려준다.<br>- cardsOf에서 저장된 J4도 거른다.<br>지금은 `Board.Enabled = false`(2734)라 급하지 않다 |
| S12 | TelemetryService.luau:210, 321 | 옛 세이브 따라잡기가 `if done.M1_3 or done.S0 then Step(FirstSkillHit)`다 | **[S7을 바꾸면]** `or done.S0`을 지운다. 321줄 주석('a skill kill during trial b is expected')도 고친다 |
| S13 | Config.luau:3009-3011 Analytics.Steps (+TelemetryService.luau:31-33 예비 목록) | FirstSkillHit가 8번째(FirstKill과 FirstMissionDone 사이)다. 이제 Lv5 뒤, 보통 FirstWeapon·AutoUnlocked 뒤에 생기므로 가짜 이탈로 보인다 | **[D5 결정 뒤]** 이름은 그대로 두고 위치를 AutoUnlocked 뒤(Level10 앞)로 옮긴다. 두 목록을 같이 고친다 |
| S14 | Config.luau:3297 (Help Combat), 3290 (TouchLines) | "Skills cost 20 MP. You can use one again after 3 seconds." Lv5 얘기가 없다 | **[권함, 문구는 D6]** 예: "Your first skill comes at Lv 5. It costs 20 MP; wait 3 s to use it again." 주제당 4줄 한도를 지킨다. 3290줄은 그대로 둬도 된다 |
| S15 | Config.luau:625-627 Skills.Text | NewSkill "New skill! %s (%s)", NewSkillTouch, TryIt를 아무 코드도 쓰지 않는다. 실제 화면 문구는 SkillBar.luau:87-90에 따로 있다 | **[선택]** A23-71 문구로 맞춘다: NewSkill "New skill! %s", LearnKey "Press %s", LearnTouch "Tap the new button", Later "Skills come at Lv %d". TryIt은 지운다.<br>그다음 개발 1이 SkillBar에서 이 값을 읽게 한다. skill_kit_offline.luau:147도 같이 고친다 |
| S16 | Config.luau:1909 NextIronLevel; QuestService.luau:553 nextGoalText | 대장간 뒤 다음 목표는 "Iron weapon at Lv%d"다. 철 무기(237, MinLevel 5)도 Lv5다 | **[선택, D6]** 예: "Next goal · Lv%d: first skill + Iron weapon (now Lv%d)" |
| S17 | CombatService.luau:1556-1577 autoTick; SkillService.luau:404-407 AutoCast | 자동 Q는 `skills.Cast(p, "Q", true)`를 거치고, 자동 Z는 slotsOf ≥ 2를 본다 | 바꿀 것 없음. S3 뒤에는 자동 전투가 배운 스킬만 쓴다.<br>CombatService.Release와 SkillService가 없을 때의 대체 경로(1495, 1576)에는 칸 검사를 넣지 않는다. 테스트가 이 함수를 직접 부른다(T6) |

### 개발 2 테스트

| # | 위치 | 지금 | 바꿀 것 |
|---|---|---|---|
| T1 | tools/fixtures/skill_kit_offline.luau:58-59, 147; tools/test_skill_kit.py:3, 23 | Unlock 1/5/8을 기대한다. 변이는 `"Unlock = { Q = 1, Z = 5, X = 8 }"` 문자열을 찾는데, Config가 바뀌면 맞는 문자열이 없어 적용되지 않는다 | 5/15/25와 'Lv5 / Lv15 / Lv25'로 고친다. 변이 원문을 새 줄로 바꾼다(예: Q 5 → 1). S15를 하면 147줄도 |
| T2 | tools/fixtures/skills_offline.luau:73-121 (slots 그룹), 83·233 (Lv9 영웅), Z를 쓰는 `Level = 5` 영웅들(약 54곳 중 Z를 쓰는 것); tools/test_skills.py:201 | 기본 1칸, Lv1/4/5/9 → 1/1/2/3칸, 4→5에서 Z 알림, 7→8에서 X | **기대값:** 기본 0칸. Lv1/4/5/14/15/25 → 0/0/1/1/2/3칸. 4→5에서 Q가 열리고 알림, 14→15에서 Z, 24→25에서 X(알림 없음).<br>**영웅 레벨:** Z 영웅은 `C0.Skills.Unlock.Z`, X 영웅은 `C0.Skills.Unlock.X`로.<br>**새 검사:** Lv4에서 UseSkill "Q"와 옛 Release 원격이 둘 다 'Q:Locked'이고 MP가 그대로인지. Lv4 자동 전투는 휘두르기만 하는지.<br>**계약·변이:** 201줄 계약 문구를 고친다. 변이 2개를 더한다(`n = 0`을 1로, clamp 하한 0을 1로) |
| T3 | tools/fixtures/a23_14_offline.luau:303, 355-363, 442·504 (worldWithKill 430, 기본 Lv1); test_a23_14.py 계약 | Lv1·5·9 모두 Kill/Release/Gold 세트를 기대한다. Release 진행·재추첨을 Lv1 세계에서 시험한다 | Lv1 세트는 왕 슬라임 + 슬라임 + 골드, Lv5·9 세트는 Kill/Release/Gold를 기대하게 바꾼다. Release 시험은 Lv5 세계로 옮긴다. 'Lv1-4 추가 퀘스트에 Release 없음' 검사를 더한다. 중복 거르기 코드가 바뀌면 변이 문자열도 고친다 |
| T4 (새로 찾음) | tools/fixtures/onboarding_offline.luau:207 (`saved()`가 Level 1), 435-460, 498-516, 519-530 | Lv1 세이브에 저장된 Release 일일·추가가 남는지 검사한다(옛 문구 이전, 보상 유지, 수락 전 보상) | S10을 하면 이 세 경우가 깨진다 → 해당 세이브만 Level 5로 올린다. S10을 안 하면 그대로 둔다 |
| T5 | tools/fixtures/board_offline.luau:73 (기본 Lv6) | J4 제외 검사가 없다 | S11 할 때: Lv4 초원 게시판에 J4가 없고, 저장된 J4도 버리는지 검사 |
| T6 | skill_release_offline.luau:43/116, auto_combat_offline.luau:47/220/284/306, unarmed_offline.luau:297/303, tamer_offline.luau:102 | Lv1 영웅이 SkillService 없이 `Combat.Release`를 직접 부른다 | 칸 검사가 SkillService.Cast에만 있으면 그대로 통과한다. CombatService에도 검사를 넣으면 영웅을 Lv5 + SkillSlots 1로 올려야 한다 |
| T7 | tools/fixtures/metrics_offline.luau:113, 145, 153-161, 184; tools/test_metrics.py:54 | FirstSkillHit가 8번째, M1_3 완료로 따라잡기 | S13·S12를 할 때 기대 문자열과 변이 원문을 고친다 |
| T8 | halloween_offline.luau:1599-1618; town_quests_offline.luau:1166-1167; tools/test_story_text.py | S0은 시험 a만 검사한다. town_quests에는 M1_3 중인 Lv6 영웅이 있다 | S7: 새 시험 b 검사를 더한다. S8: 'Lv3은 M1_3 레벨 단계에서 기다리고, Lv5에 SkillHit 단계로 넘어감' 검사를 더한다. test_story_text(Level 단계 "now Lv%d" 형식)를 다시 돌린다 |
| T9 | 증거 | — | 새 날짜 이름으로 다시 만든다: offline_dev2_skills / skill_kit / a23_14 / onboarding / board / metrics / halloween / town_quests `_2026-10-07` |

## 2. 게임성 개발 1: 클라 (메인 Studio)

| # | 위치 | 지금 | 바꿀 것 |
|---|---|---|---|
| C1 | SkillBar.luau:434-449 stateOf(`Locked = level < unlock`, 443), 770-771 OnAttr | 버튼을 숨길지 Level로만 정하고 SkillSlots·Rebirths는 보지 않는다.<br>서버는 다음 두 경우에 Q를 허용한다:<br>- 환생: Rebirths ≥ 1이면 3칸, 레벨은 Lv1. Lv50 이상이라 베타 밖이다.<br>- Lv5 이상에서 무료 직업 변경: Lv1로 내려가지만 칸은 남는다(`FreeKeepLevelBelow = 5`, Config 461). **베타에서 생긴다.**<br>그러면 버튼은 없는데 자동 전투가 Q를 쓴다. 또 Lv5가 될 때마다 'New skill!'이 다시 뜬다 | **[필수, D7]** 칸 번호 > SkillSlots일 때만 Locked로 본다. 속성이 없으면 Level 규칙을 쓴다. OnAttr에 "SkillSlots"와 "Rebirths"를 더한다.<br>주의: 접속 때 PlayerReady의 catchUp이 SkillSlots를 조용히 올린다. DataLoaded 뒤에 올라가면 가짜 배우는 순간이 뜰 수 있다. 접속·Lv4→5·직업 변경·환생 네 경우를 시험한다 |
| C2 | SkillBar.luau:51 | 예비값 `Unlock = { Q = 1, Z = 5, X = 8 }` | `{ Q = 5, Z = 15, X = 25 }` |
| C3 | tools/fixtures/skill_learn_offline.luau:119 | Config.Skills.Unlock을 5/15/25로 덮어쓴다 | dev2 Config를 병합한 뒤 이 줄을 지운다. C1 검사를 더한다: SkillSlots 1(또는 Rebirths 1)인 Lv1 → Q가 보이고 배우는 순간은 없음 |
| C4 | SkillBar.luau:302 (PressScale) + 643-648 (LearnPop) | 버튼에 UIScale "PressScale"이 이미 있는데, 톡 효과를 위해 둘째 UIScale "LearnPop"을 붙인다 | **[확인 필요]** 한 GuiObject에는 UIScale이 하나만 적용될 수 있다 → 톡이 안 보일 수 있다. Studio에서 Lv4→5로 직접 본다. 안 보이면 PressScale을 트윈하거나 감싸는 프레임에 붙인다. 오프라인 테스트(153줄)는 트윈만 보므로 이 문제를 못 잡는다 |
| C5 | HUD.luau:2145 (HUD 자체 Q 버튼 ui.release), 3856-3869 doRelease, 4181-4186 (SkillBar가 Q를 안 가질 때 키 처리) | SkillBar가 못 뜨면 HUD의 Q 버튼이 Lv1에도 보인다. 누르면 레벨 검사 없이 Release를 보낸다 | **[낮음]** doRelease 첫 줄에서 Q를 아직 안 배웠으면 조용히 끝낸다. ui.release.Visible도 같은 규칙으로. 서버는 S3 뒤 어차피 거절한다 |
| C6 | SkillBar.luau:344-372 (자물쇠·"Lv N"), 464-479 (잠김 색), 704-705 (잠김 흔들기) | 잠긴 버튼은 이제 화면에 안 나오므로 쓰이지 않는 코드다 | **[선택]** 정리. 머리 주석은 이미 고쳐져 있다 |
| C7 | tools/fixtures/hunt_bot_client.luau:56-59 | MP와 재사용 시간만 보고 Release를 쏜다 | Level ≥ Unlock.Q(또는 SkillSlots ≥ 1) 조건을 더한다. Lv1-4 처치 속도를 다시 재서 새 날짜 파일(verification_2026-10-07/…)에 쓴다 |
| C8 | Config.luau:3718-3721 (Config.Audio.Sounds) | SkillLearn 항목이 없다. SkillBar는 대신 PowerUp을 튼다(LevelUp 파일을 1.12배로) | 파일이 오면 `SkillLearn = { File = "SkillLearn", Volume ≈ 0.7, Max = 1, Gap = 2 }`과 Duck 설정을 넣는다. Lv5에서는 LevelUp 소리와 같은 순간에 나므로 구별돼야 한다 |
| C9 | HUD.luau:223 HintSkill "Try your skill!" | Q 힌트의 기본 문구다. SkillBar는 자기 문구를 넘기므로 지금 이 기본값을 쓰는 곳은 Studio HintPreview뿐이다 | **[선택]** 그대로 두거나 "Press Q"로 바꾼다 |

## 3. 이미지 개발

| # | 위치 | 지금 | 바꿀 것 |
|---|---|---|---|
| I1 | HUD.luau:4425-4432 (ClusterTop/ClusterLeft 계산) | 숨은 auto는 건너뛰지만 q는 늘 센다. EventHUD(860/1093)와 GrudgeGhost(105)가 이 값을 읽는다 | **[낮음]** Q가 숨어 있으면 q도 건너뛴다 |
| I2 | QuestMarker.luau:105 AVOID | 화면 가장자리 표시가 숨은 q/z/x 자리도 피한다 | **[낮음, 선택]** HUD.Layout에 숨김 정보를 실어 그 자리는 빼고 계산한다 |
| I3 | HudLayout.luau:227-234 | q만 처리한다. Lv5-14에는 Q만 있고 Z·X 자리는 비워 둔다(주석대로) | Lv5(Q만 있음) 화면을 폰 749×361과 PC에서 한 번 확인한다 |
| I4 | tools/skillbar_view.py:2-4, 27-28, 36, 42 | 'Lv1: Z·X 잠김, Q 준비', 'Lv10 + Z' 장면을 찍는다 | 장면을 바꾼다: Lv1(버튼 없음) / Lv5(Q) / Lv15(Q+Z, SkillBarPreview) / Lv25 |
| I5 | tools/rookie_hint_view.py:5, 29, 48, 72, 235; tools/text_fit_view.py:45 | hint_q는 첫 임무 중 "Try your skill!" 장면이다. 가짜 일일로 'Hit 4 monsters with a skill'을 쓴다 | hint_q는 Lv5 배우는 순간으로 바꾼다(SkillSlots·Level을 5로 설정한 뒤 "Press Q"/"Tap the new button"). 가짜 일일은 'Defeat King Slime ×3'처럼 스킬이 없는 목표로. 새 날짜로 다시 찍는다 |

## 4. 소리

| 위치 | 지금 | 바꿀 것 |
|---|---|---|
| art/sfx/ (SkillLearn 파일 없음), tools/sfx_game.py | 없음. PowerUp으로 대신한다 | 개발 2가 PowerUp·LevelUp과 구별되는 짧은 '배웠다' 소리를 만들어 올린다. 연결은 개발 1(C8) |

## 5. 검수: 결정과 문서

**결정 (개발 2가 시작하기 전에)**
- **D1 S0 시험 b:** 스킬이 필요 없는 시험으로 바꾼다(추천, S7). 다른 길은 자동 전투를 Lv5부터로 받아들이고 A23-1 문구를 고치는 것이다.
- **D2 M1_3:** Lv5 레벨 단계를 넣는다(추천, S8). 다른 길은 Main 순서에서 M1_4를 M1_3 앞으로 옮기는 것이다.
- **D3 Lv1-4 일일 셋째 목표:** 왕 슬라임 3 + 슬라임 12-15 + 골드(추천).
- **D4 옛 세이브 보정(S6):** 할지 정한다. 베타 전이라 테스트 계정뿐이다.
- **D5 퍼널:** FirstSkillHit 위치를 AutoUnlocked 뒤로 옮길지(S13).
- **D6 문구:** Help 문구(S14)와 '다음 목표'에 첫 스킬을 넣을지(S16).
- **D7 클라가 SkillSlots를 따른다(C1):** 직업 변경·환생 뒤에도 Q를 유지한다. A23-71이 "SKL-2 그대로"라고 했으므로 확인만 하면 된다.

**문서**

| 위치 | 지금 | 바꿀 것 |
|---|---|---|
| docs/SPEC_ADDENDUM.md:24 (A23-2 ②), 118 (A23-68 #2), 261 (A23-49) | 스킬 한 번에 2마리 시험 / 첫 처치 뒤 "Try your skill!" / Q(Lv1)·Z(Lv5)·X(Lv8) | 각 줄 끝에 '→ A23-71'을 단다. D1대로 바꾸면 24줄 ②도 고친다 |
| docs/GDD.md:57-59, 152-155 | 왕관 조각 시험 ②가 스킬이고, 30초 루프에 '스킬 쓰고'가 Lv1 기준으로 있다 | '첫 스킬은 Lv5(A23-71)'를 넣는다 |
| docs/design/skill_kit_beta_2026-10-06.md:21-24, 82-90, 108, 120-121, 252 | Q Lv1 / Z Lv5 / X Lv8, SK1·SK2 시각, "New skill! {Name} ({Key})" | 맨 위에 'A23-71이 §0·§2를 대체'를 넣고 숫자를 5/15/25로 고친다 |
| docs/design/beta_board_2026-10-06.md | A23-71 줄이 없다. QC-7은 Lv5/Lv10 시각만 잰다 | A23-71 줄을 만든다(담당은 SPEC:97). QC-7에 'Lv5 첫 스킬까지 걸린 시간, Lv1-4 처치 속도'를 더한다 |
| docs/design/skills_server_2026-10-07.md:18, 21 (개발 2 메모) | SkillSlots 1 = Q, 기본값 1 | 0..3(5/15/25), 기본값 0으로 |
| ideas_first10_2026-10-07.md, quest_chain_2026-10-06.md, early_churn_research_2026-10-07.md, beta_basics_2026-10-05.md:1382 (BB24) | 7분쯤 M1-3에서 스킬, 첫 처치 뒤 "Try your skill!" | 본문은 두고 주석만 단다: 첫 스킬은 Lv5. BB24에는 '첫 스킬은 SkillBar 배우는 순간이 맡음, 중복 안내 금지' |

## 6. 위험

1. **반쪽 반영이 가장 위험하다.** Config의 Unlock만 바뀌면 다음이 동시에 생긴다:
   - 클라(da6402b)는 Lv1-4에서 Q를 숨긴다.
   - 서버 slotsOf는 아직 1이라 자동 전투가 버튼 없는 Q를 쓴다.
   - M1_3과 일일 Release는 끝낼 수 없는 채로 남는다.

   그래서 S1-S4, S7-S9, S14는 한 커밋에 넣는다.
2. **첫 10분 막힘.** 위 묶음에서 하나라도 빠지면 이렇게 된다:
   - M1_3에서 메인 줄이 멈춘다. 그 뒤의 M1_4, 마을 퀘스트, 게시판 안내도 밀린다.
   - S0 시험 b 때문에 자동 전투가 Lv5까지 잠긴다.
   - Lv1-4는 일일 셋 중 하나와 추가 퀘스트를 끝내지 못한다.
3. **자동 전투가 안 배운 스킬을 쓰는 경우.**
   - 서버는 S3 뒤에 막힌다(Cast가 칸 수를 검사한다).
   - 남는 구멍은 C1의 불일치다: Lv5 이상에서 무료 직업 변경을 하면 서버는 Q를 허용하는데 화면에는 버튼이 없다. 베타에서도 생긴다.
4. **옛 세이브.** Lv1-4인데 SkillSlots 1이 저장된 세이브는 칸이 줄지 않아 Q가 남는다(S6).
5. **테스트가 Lv1 Q를 가정한다.** T1-T4, T7-T8, 사냥 봇(C7), 화면 도구(I4-I5)가 해당된다. Config만 바꾸고 돌리면 skills·skill_kit·a23_14 테스트가 실패한다.
6. **초반 사냥이 느려진다.**
   - Lv1-4에는 Q(6배 범위 공격)가 없다. 왕 슬라임 처치(M1_2 ×2, 일일 ×3)가 오래 걸린다. Lv5 도달도 skill_kit 예상(9~12분)보다 늦을 수 있다.
   - 전사·궁수는 Lv5 전에 MP를 쓸 곳이 없다. MP 물약 버튼과 MP 물약 드랍이 헛돈다. 마법사는 평타에 MP를 쓰므로 괜찮다.
   - QC-7에서 잰다.
7. **Lv5 순간이 붐빈다.** 'Level up! Lv5' 배너, 철 무기 열림, 'New skill!', 'Press Q', LevelUp 소리, PowerUp 소리가 한꺼번에 나온다. PowerUp은 같은 LevelUp 파일이라 소리도 겹친다. 직접 플레이로 확인한다.
8. **톡 효과가 안 보일 수 있다(C4).**
9. **Halo 카드 문구.** 'Skills heal allies'(Config 749, 4314; FactionPicker 102)는 Lv1-4에서 아무 효과가 없다. Lv5부터는 맞는 말이라 그대로 둬도 된다.

## 7. 순서 제안

1. **검수:** D1-D7을 정하고 보드에 A23-71 줄을 만든다.
2. **개발 2 (dev2):**
   - origin/main `eecc7b3`을 병합한다.
   - S1-S4, S7-S9, S14를 고친다. S6·S12·S13은 결정대로.
   - T1-T3, T7-T8을 고친다. T4·T5는 S10·S11을 할 때.
   - 증거를 새 날짜로 만들고 한 커밋에 넣는다.
3. **개발 1:**
   - C1-C3를 같은 때 준비해서 dev2 병합과 함께 넣는다. C1이 없으면 직업 변경 뒤 불일치가 남는다.
   - C7 사냥 봇을 고친다.
4. **병합 → Studio 동기화 → 직접 플레이.** 동기화 전에 검수의 '전달함, 시작'을 받는다. 플레이에서 볼 것:
   - 새 캐릭터 Lv1: 스킬 버튼이 없고, 물약이 공격 버튼 옆에 있고, Q 키는 'Skills come at Lv 5'.
   - 스킬 없이 S0을 끝내고 자동 전투가 열리는지.
   - Lv1 일일 세 개 구성.
   - M1_3에 'Lv5 · Learn your first skill'이 뜨는지.
   - Lv4→5: 배너·톡(C4)·Press Q·소리, Q가 써지는지, M1_3이 다음 단계로 넘어가는지.
   - Lv5 이상에서 무료 직업 변경.
   - 폰 화면.

   끝나면 Play를 멈춘다.
5. **이미지 개발:** I1-I5.
6. **소리:** SkillLearn 파일을 만들고 올린 뒤 C8로 연결한다.
7. **검수:** 문서를 고치고 QC-7에 Lv5 도달 시각과 Lv1-4 처치 속도를 더한다.