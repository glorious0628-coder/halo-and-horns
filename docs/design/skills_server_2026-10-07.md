# SKL-2 스킬 서버 1차 (게임성 개발 2, 2026-10-07)

설계: `docs/design/skill_kit_beta_2026-10-06.md` §1~§4·§8-1·§9, SPEC A23-49. 표는 SKL-1(`Config.Skills`, `Config.SkillKit`/`SkillDef`, 291c9f0)을 그대로 읽는다(서버는 표를 고치지 않음). 게임 글은 영어(A23-48): 서버는 **코드만** 보내고, 글은 클라가 `Config.Skills.Text`에서 고른다.

## 1. 무엇이 생겼나
- **새 `SkillService.luau`** — Q·Z·X 시전의 단 하나의 입구 `SkillService.Cast(player, slot, isAuto)`.
  - **공동 간격 0.5초**(`Skills.GlobalGap`): 아무 스킬 뒤 0.5초 안에 손으로 누르면 **1번만 줄 세움**(간격이 끝나면 저절로 나감). 줄에 하나 있으면 다른 누름은 버림. 자동 시전은 줄 서지 않고 다음 틱.
  - **거절은 MP 쓰기 전**: 잠김(칸 없음·플래그 꺼짐) / 재사용 중 / MP 부족 / 대상 없음 → MP·재사용 그대로.
  - **Q** = 지금 `CombatService.Release` 그대로(MP 20, 3초, x6, r9). Release는 이제 시전되면 `true`를 돌려주고, `Released`에 `Slot = "Q"`를 담는다. 옛 `Release` 원격도 SkillService를 거친다(간격·줄·거절 말 같음).
  - **Z 모양(1차):** `Line`(띠 Len×Width, Range/Len 안 조준 원뿔에서 가장 가까운 대상 쪽, 없으면 바라보는 쪽 — 빈 띠도 시전됨), `Chain`(Range 안 조준 대상 → Jump 칸 안 가장 가까운 새 대상, 모두 Hits번, 같은 대상 두 번 없음, 첫 대상 없으면 `NoTarget`).
  - **X**: Roar·Field·Hop은 SKL-3 — 그 전에는 XEnabled를 켜도 X는 조용히 아무것도 안 함(MP 그대로).
  - **뒤 몬스터(A23-61 서버 조준, 검수 2026-10-07 — 스윙과 같은 규칙):** 조준 원뿔 안에 대상이 없으면 그 스킬 거리 안 가장 가까운 **몬스터**(사방)를 겨누고, 시전이 나갈 때 몸(root)을 그쪽으로 돌린다. 이렇게 돌린 시전은 몬스터만 맞힌다(사람은 앞 원뿔 규칙 그대로). Q(Meteor·Arrow Rain·Pet Rush의 대상 원)와 Z(Line·Chain) 모두. 자동 Q도 사방의 몬스터를 보고 쏜다. 자동 규칙이 '안 쏨'이면 몸도 안 돌린다.
  - 피해: 대상마다 한 번, `ComputeMonsterHit`(직업 배율, 치명타 없음) × Mult. 끌기(Earth Cleave·Hook Chain 5칸, **손으로 쓸 때만**)·밀기(Pierce Shot·Slime Roll 3칸)는 `MonsterService.Displace`.
  - 빛: 시전자 12칸 안 빛 동료(나 포함)에게 실제 피해의 10% 치유. 뿔: 실제 피해의 10% 흡혈. 둘 다 DamageWindow(아래). 장인은 없음(A6).
  - 사람: `Skills.PvPZX`가 켜지고 **손으로 쓴** Z만(지금은 꺼짐 → Z·X는 사람을 고르지도 때리지도 않음). Q는 지금처럼 사람도 맞힘.
  - `CombatService.Released`를 Z도 쏜다: `{ Slot, Auto, MonstersHit, PlayersHit, Total, Center, Radius, Healed, Stacks = 0, Perfect = false }` → 퀘스트("스킬 쓰기"는 손으로 쓰고 몬스터 1마리 이상)·게시판·괴수 그대로 센다.
- **새 `DamageWindow.luau`** — 짝(보낸 사람 → 받는 사람)마다 최근 **3초** 합계: 사람 피해 35%(활성 괴수 8%), 빛 치유 동료당 30%, 뿔 흡혈 3%. **Q와 Z(나중에 X)가 같이 센다**(Q의 시전당 상한이 이 창으로 바뀜). 기본 공격(스윙)은 지금 규칙 그대로. 나간 사람은 잊음.
- **칸(해금):** 저장 `SkillSlots`(1 = Q, 2 = +Z Lv5, 3 = +X Lv8, 환생 1번 이상 = 3), 속성으로 복사(Mirrored). **줄지 않음**(직업·진영 바꾸기, 레벨 초기화, 환생 뒤에도). 옛 저장은 접속 때 따라잡기. 레벨 오를 때 새 칸이 열리면 그 칸의 플래그가 켜져 있을 때만 `Fx "SkillUnlocked"`.
- **자동 전투:** `CombatService.autoTick`이 Q 전에 `SkillService.AutoCast`(Z, ZEnabled일 때) → Z를 쓰면 그 틱은 끝, Q는 간격 뒤. Z 자동 조건(`Defs[kit].Z.Auto`): 전사·대장장이 띠 안 2마리 이상 또는 큰 몬스터 1(Scale 1.5 이상·보스), **끌기 없음** / 궁수·조련사 줄 위 1마리 이상 / 마법사·연금술사 1마리 이상, 흩어진 2마리 이상(첫 대상에서 9칸 밖)이면 Q보다 먼저, 아니면 Q가 준비돼 있으면 Q 먼저. 자동은 사람을 고르지 않는다.
- **`MonsterService.Displace(rec, "Pull" | "Push", fromPos, studs, player)`**(개발 1 파일, 미리 알림): 끌기는 시전자 쪽 최대 studs, **시전자 3칸 앞에서 멈춤**; 밀기는 반대쪽. 거리 ÷ 몸 크기, **보스는 안 움직임**, 남의 개인 몬스터 안 움직임. 끝 자리가 지금 서 있는 지역, 자기 지역 사각형(안쪽 6칸), 집에서 LeashRadius(60) 안, 땅(물·능선 아님), 벽·장식 없음이어야 함 — 안 되면 3/4·1/2·1/4로 줄여 보고 다 안 되면 안 움직임. 0.2초 미끄러짐(Shove와 같은 방식, Shove는 그대로).
- 그 밖에: Net `UseSkill`(끝에 한 줄), `RateLimits.UseSkill = 0.1`, `Data.Defaults.SkillSlots = 1` + Mirrored, Main INIT/START에 `DamageWindow`·`SkillService`(PlayerService 앞).

## 2. 클라 계약 (게임성 개발 1 · 이미지 개발)
- **보내기:** `Net.Get("UseSkill"):FireServer(slot)` — slot = `"Q"` | `"Z"` | `"X"`, 다른 인자 없음. 한 번 누름 = 한 번(길게 눌러 반복 없음). 옛 Q 버튼의 `Release`도 그대로 동작.
- **받기 (Net.Fx):**
  - `"SkillPress"` `{ Slot, Result }` — 누른 사람에게만. Result: `"Queued"`(0.5초 흰 테), `"Cooldown"`(흔들기), `"NoMP"`(흔들기 + `Config.Skills.Text.NoMP`), `"NoTarget"`(흔들기 + `Text.NoTarget`), `"Locked"`(흔들기; 보통 버튼이 안 보여서 안 옴).
  - `"Skill"` `{ UserId, Character, Class, Kit, Faction, Slot, Shape, From, Center, Dir, Len, Width, Radius, Points, Life = 0.3, Auto, Total, Hits = { { P, A, C = false, K = "M" | "P", V? } }, Statuses = {} }` — 시전자 + 근처 사람에게(CR-L49 거리). Line: `From`(시전자 자리)·`Dir`(단위 벡터)·`Len`·`Width`·`Center`(띠 가운데). Chain: `Points`(맞은 순서대로 자리)·`Radius`(Jump). `Life` 동안 바닥 표시(§6-2). `Statuses`는 SKL-3(Guard·Taunt·Slow·MP).
  - `"SkillUnlocked"` `{ Slot }` — 그 칸 플래그가 켜져 있을 때만, 레벨업·환생 순간에. 안내 1쪽 + 금빛 링(SKL-7).
- **속성(플레이어):** `SkillSlots`(1~3, 보일 버튼 수 — 플래그도 함께 볼 것), `SkillReadyAt`(Q, 기존), `SkillReadyAtZ`, `SkillReadyAtX`(서버 시각 `workspace:GetServerTimeNow()` 기준, 진짜 부활 때 0). 재사용 쓸기·남은 초는 이것으로.
- Q의 기존 `"Release"` Fx는 그대로(SkillFx가 Q도 다시 그릴지는 이미지 개발이 정함).

## 3. 검사
- `py tools/test_skills.py` — 143검사 + 정적 13, 변이 81/81 — 칸·해금·알림, 원격 검증·간격·줄 1번·캐릭터 바뀌면 줄 버림, 거절 순서(MP·재사용 그대로), 띠(너비·길이·뒤·조준 방향·빈 띠), 사슬(4번·10칸·12칸 못 감·같은 대상 없음), 끌기(손만)·밀기, PvPZX 꺼짐/켜짐, Q→Z·Z→Q 35% 창·3초 뒤 다시, 자동 Z는 사람 안 때림, 장인 PvP 없음, 빛 치유 30% 창(12칸)·뿔 흡혈 3% 창, 장인 치유·흡혈 없음, 자동 규칙(전사 2마리/큰 몬스터, 마법사 Q 먼저/흩어지면 Z, 궁수 1마리, 내 누름 뒤 양보), 진짜/꾸밈 부활, 창 단위(3초 경계·음수 없음·잘못된 숫자), Displace 실제 코드(3칸 앞 멈춤·크기·보스·남의 몬스터·leash·지역 끝·물·벽·줄인 걸음·다른 지역 겹침), 뒤 몬스터 조준(Earth Cleave·Chain Bolt·Meteor가 뒤 슬라임으로 + 몸 돌림, 앞 대상이 이김, 뒤 적은 안 맞음·적만 뒤면 No target, 자동 Meteor, 안 쏘는 자동은 안 돎).
- 기존 묶음(전투·자동·스킬 Q·조련사·맨손 등)은 SkillService 없는 세계에서 옛 길(시전당 상한)로 그대로 통과 — 새 길은 test_skills가 본다.

## 3-1. A23-71 처음에는 스킬 없음 (사용자 2026-10-07, 서버)
- `Config.Skills.Unlock = { Q = 5, Z = 15, X = 25 }`(옛 1/5/8).
- `Config.SkillSlotsFor(level, rebirths)` 하나로 칸 수를 센다(0~3, 환생하면 3). SkillService와 DataService가 같이 쓴다.
- 저장:
  - `SkillSlots` 기본값은 0이다(Lv5 전에는 칸 없음).
  - 예전 저장(`SkillsA71`가 없는 것)은 불러올 때 **한 번만** 레벨·환생으로 다시 센다. 이때만 줄어들 수 있다(예: Lv8에 칸 3 → 1).
  - 그 뒤로는 SKL-2 규칙 그대로 올라가기만 한다. Version은 3 그대로다(BB2처럼 더하기만).
- 시전:
  - 칸이 0이면 Q도 거절한다("Locked", MP 그대로). 옛 Release 원격도 같다.
  - 자동 전투는 휘두르기만 하고 스킬은 안 쓴다.
- 알림: Lv5에 `Fx "SkillUnlocked" { Slot = "Q" }`를 보낸다(Q는 늘 보냄). Z·X는 플래그가 켜져 있을 때만이다.
  - 레벨이 한 번에 여러 칸을 넘으면(예: Lv4 → 16) 칸마다 차례로 보낸다(Q, Z).
- 스킬이 필요한 일은 Lv5 전에는 주지 않는다.
  - 새싹·숲 일일과 여분의 'Skill hits'(Release) 줄: 스킬이 있을 때만 뽑는다.
    - 예전에 받은 미완료 줄은 접속 때 다른 줄로 바꾼다(일일 보상은 그대로).
  - 게시판 J4 'Hit 3 at once': `NeedSkill = true`.
  - 이야기 M1_3·M2_5: 앞에 'Lv5 · Learn your first skill (now Lv%d)' 단계가 있다. 이미 Lv5 이상이면 바로 지나간다.
  - N1(장인): `Requires.Level = 5`.
  - 그 밖에 스킬 맞히기 단계, 또는 스킬 시험이 남은 Trials(S0 시험 b)는 칸이 0인 동안 줄 끝에 ' · Skills come at Lv5'가 붙는다.
    - S0은 (A)안이다: 시험 b는 그대로 두고, Lv5에 첫 스킬을 쓰면 끝난다. 검수 답을 기다리는 중이다.
- 클라(개발 1):
  - SkillBar는 지금 레벨만 보고 잠근다. 서버 기준은 `SkillSlots` 속성(환생 3, 레벨 초기화해도 안 줄어듦)이니 그것으로 맞춰 달라고 했다.

## 4. 다음 (SKL-3, 10/13~15)
- X: Roar(도발 `_tauntUntil`·Guard)·Field(장판 1Hz, 시전당 1타)·Hop(`ZoneService.AllowMove`, 자루·괴수 거절), X 진영 차이(빛 Guard / 뿔 MP 훔치기 상한 20), 자동 X→Z→Q, SK1·SK2와 SkillHit `Slot` 거르기, 다음 목표 줄, 장판 끝나는 조건, 보스·거위 느리게 ×0.75.
