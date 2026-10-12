# 무기 쥐기: 로블록스 기본 먼저 → 부위 조절 계획 (A23-150 7번, 2026-10-12, 게임성 개발 1)

사용자: "칼부터 모든 무기 다 로블록스 기본 모델이 … 어케 드는지 확인하고나서 부위 조절하기로". 이 문서 = ① 본 것 + ② 조절 계획. **코드는 사용자 OK 뒤(③).**

## 사진
- 한 장 비교: `docs/art/verification_2026-10-12/main_apply/grip_plan_sheet_2026-10-12.png` (무기 7줄 × 우리 앞·옆 / 로블록스 앞·옆·휘두르기, 사용자 아바타)
- 원본: `main_apply/tool_basics/` (7가지 × 사용자 아바타·기본 R15 몸, 앞·옆·3/4·걷기·휘두르기, `log.txt`에 손·팔·자루 방향 숫자), `main_apply/arm_check3/` (팔 접힘 고친 뒤 우리 9가지), `main_apply/tool_grip2/`
- 기본 R15 몸 4종(지팡이·망치·조련사 봉·플라스크)은 Studio 창이 중간에 최소화돼 흰 화면 → 필요하면 다시.

## ① 로블록스 기본은 어떻게 드나 (본 것)
- **모든 무기가 같은 자세**: 오른팔을 어깨 높이로 앞으로 쭉 뻗고(위팔·아래팔 모두 정면, 손 = 몸통 기준 (1.3~1.5, +0.5, −1.8)), 무기는 주먹에서 **위로 똑바로 섬**(자루 방향 = 위, 팔과 직각). 걸어도 팔은 그대로.
- 기본 휘두르기(toolslash) = 팔을 내리찍어 손이 엉덩이 옆, 무기는 앞을 가리킴 — 한 가지뿐.
- 무기마다 다른 건 **Tool.Grip(자루 어디를, 어떤 각도로 쥐나)** 하나뿐. 활도 오른손에만 들림(기본 Tool은 오른손 전용).
- 참고 검색: 공식 문서 = Handle 파트가 손의 RightGripAttachment에 붙고 Grip은 "도구마다 직접 맞춤"; RPG 게임들은 Animate의 toolnone을 자기 들기 동작으로 바꾸거나 무기를 Motor6D로 달아 애니로 움직임. ClassicSword의 Grip 숫자는 공개된 게 없어 Studio에서 재는 중(`tools/play_classic_sword_grip.py`).

## ② 계획: 뼈대 = 로블록스 쥐기, 그 위에 우리 메시
- **모든 무기 공통(뼈대)**: 무기마다 주먹이 감싸는 파트 하나를 `Handle`로, 손의 `RightGripAttachment`(활은 `LeftGripAttachment`)에 로블록스 방식 그대로 붙임. 쥐는 점 = Handle의 원점, 무기 긴 축 = Handle의 위(+Y) — 로블록스 기본과 같은 규칙. 우리 메시는 Handle에 붙임(메시의 쥐는 점 = Handle 쥐는 점). 무기마다 다른 건 표의 "쥐는 점·각도·크기"만(설정 표 한 곳).
- **서 있는 자세(팔)**: 두 가지 중 고름 — 사진 비교용.
  - (가) 로블록스 기본 toolnone 그대로: 팔 앞으로 뻗고 무기 세움(로블록스다움, 모든 무기 같음).
  - (나) **추천**: 쥐는 법은 로블록스 규칙, 팔만 우리 "준비 자세"(무기별: 칼은 옆에 내리고 끝 앞·위, 지팡이는 옆에 세움, 활은 왼손 앞). 오늘 고친 팔 접힘(BodyScale) 뒤 모습이 사진 "ours" 열.
- **공격**: 지금 우리 직업별 공격 동작(Fx) 유지(로블록스 기본 휘두르기는 한 가지라 직업 구분이 안 됨).

| 무기(직업) | 로블록스 기본(본 것) | 지금 우리 | 조절안: 쥐는 점 · 방향 · 크기 · 손 |
|---|---|---|---|
| 한손검(성기사) | 팔 앞, 칼 위로 섬 | 옆에 내림, 끝 앞·45° 위 | 쥐는 점 = 자루 아래에서 **60%**(날밑 바로 밑, 지금 50%) · 날 = Handle 위쪽 · 전체 길이 키의 **0.75** 근처(ClassicSword 값 재면 맞춤) · 오른손 |
| 어둠 검(광전사) | 위와 같음 | 옆, 끝 40° 위, 몸 숙임 | 한손검과 같은 규칙(A23-128 한손검). 숙인 몸·낮은 끝은 팔 자세로만 |
| 활(레인저) | 오른손, 활이 손 앞에 섬(시위를 쥔 꼴 — 변환 때 긴 파트가 시위라 틀림) | 왼손, 옆에 세움 | Handle = **활 몸 가운데(손잡이)**, 쥐는 점 50% · 활 면 세로, 시위는 몸 쪽 · 키의 0.55~0.7 · **왼손**(LeftGripAttachment, 로블록스 규칙의 좌우 대칭) |
| 지팡이(빛 마법사) | 팔 앞, 지팡이 섬 | 옆에 세움, 구슬 얼굴 밖 | 쥐는 점 = 아래에서 **45%**(지금 50%, 구슬이 손에서 더 멀게) · 위로 섬 · 키의 0.65~0.75(A23-142 유지) · 오른손 |
| 망치(대장장이) | 팔 앞, 망치 섬 | 어깨 높이로 듦 + 왼손 허리 | 쥐는 점 = 아래에서 **30%**(지금과 같음) · 머리 위 · 키의 0.35~0.55 · 오른손 |
| 조련사 봉 | 팔 앞, 봉 섬 | 앞을 가리킴 + 왼손 허리 | 쥐는 점 = 아래에서 **30%**(같음) · 앞 끝 위 · 키의 0.3~0.6 · 오른손 |
| 플라스크 지팡이(연금술사) | 팔 앞, 지팡이 섬 | 옆에 세움 + 왼손 허리 | 쥐는 점 = 아래에서 **45%**(지금 53%) · 위로 섬, 플라스크 위 · 키의 0.65~0.75 · 오른손 |

## ③ 사용자 OK 뒤 코드 (무엇을 버리고 남기나)
- 남김: 무기 메시·크기 규칙(CharacterVisuals), 직업별 공격 동작(Fx), 팔 풀이(WeaponPose: 이제 몸에 맞춤, BodyPoint).
- 바꿈: 무기를 손에 붙이는 법 → Handle + Grip(로블록스 규칙), 무기별 쥐는 점·각도를 표 한 곳(Config)에. (가)를 고르면 WeaponPose의 서기 자세 대신 로블록스 toolnone.
- 버림: 무기마다 손 안에서 다르게 돌려 붙이던 옛 fist() 각도 규칙(Handle 규칙으로 하나로).

## ③ 코드 = 사용자 고름 (가) "로블록스 기본 그대로" (10/13, 가지 fix/tool-grip, 게임성 개발 1)
- **무기 = 진짜 Roblox Tool `WeaponModel`, 오른손(활도).** Handle = 주먹이 감싸는 파트: 칼·어둠 검 = 자루(1.2), 망치 = 자루(1.9), 지팡이 3종·조련사 봉 = 막대(Shaft → 이름 Handle), 활 2종 = 가운데 조각(Arc3 → Handle). 나머지 파트는 Handle에 용접. 손에는 엔진이 RightGrip 용접(RightGripAttachment × Tool.Grip)을 붙이고, 기본 Animate가 toolnone(팔 앞·무기 세움)을 저절로 틂.
- **Grip 표 한 곳 = `Config.WeaponGrips`** (Point = Handle 아래에서 몇 %, Turn = 주먹 안에서 돌림) → `Config.WeaponGrip(종류, Handle 길이)` = Tool.Grip. 칼·어둠 검 **0.75**(처음 표 0.6 → 메인 반영 1 ClassicSword 사진에 맞춤: Tool.Grip (0,0,-1.5)·손잡이 4칸, 주먹 가운데 = 자루 아래에서 74%, 주먹 윗면이 날밑에 닿음; 0.6이면 날밑 아래 0.2칸 틈), 지팡이·갈고리 지팡이·플라스크 지팡이 0.45, 망치·조련사 봉 0.3, 활·짧은 활 0.5, 짧은 활만 Turn 15°(옆으로 기울임 — 전과 같음). 갈고리 지팡이(어둠 마법사)·짧은 활(그림자 사냥꾼)은 시트 7종에 없어 지팡이·활 줄을 씀. 옛 `fist()` 각도 규칙은 지움(주먹 축 = Roblox 쥐는 점의 축).
- **왜 진짜 Tool(같은 붙임 + toolnone 직접 재생이 아니라):** 가방 칸(Backpack CoreGui)은 이미 꺼짐(VitalsUI), place·코드에 ClickDetector 없음(Tool을 들면 ClickDetector가 안 먹는 문제 없음), 공격 입력은 우리 Swing 원격이라 `ManualActivationOnly = true`로 클릭·탭이 Tool을 안 깨움, `CanBeDropped = false`, 장비 창은 서버가 WeaponModel을 새로 만드는 것뿐 → toolnone을 따로 틀 코드가 필요 없음.
- **활:** 서기·걷기 = 오른손(사용자 결정). 공격은 직업별 동작 그대로(레인저·그림자 사냥꾼 클립 = 왼손 활, 오른손 시위) → 그 클립이 도는 동안만 `Fx.bowHand`가 화면마다 활을 왼손 쥐는 점으로 옮김(지역 용접 BowGrip = LeftGripAttachment × 같은 Grip, RightGrip 끔), 끝나면 오른손으로. 활의 HandMuzzle·HandBowRest(AttackHand = LeftHand)는 왼손 기준.
- **끈 것:** WeaponPose 서기·걷기 자세(Hold / OneHand / OffHand / TwoHand / 지팡이 발끝 들기), Config.ClassGrips의 자세 값(줄에는 Weapon만 남음), Fx의 WeaponPose용 내보내기(Animating·SolveArm). WeaponPose = Studio 측정(GripProbe: dGrip·point·axis)만.
- **그대로:** 직업별 공격 클립(Fx MOTION·archerPose·staffPose — 시험이 main 11213d87 해시로 지킴), 무기 모양·길이(LEN, 지팡이 = 아바타 키의 0.65~0.75), HeroPreview 3D 몸에 무기(Tool도 남김).
- **시험:** 새 `tools/test_tool_grip.py`(9줄 × 9단계 × 손 3개: Tool·Grip·쥐는 점·Handle 축·길이·활 왼손 넘김·정적 + 변이). 은퇴: `test_one_hand_grips` / `test_two_hand_grip` / `test_weapon_pose`(지운 서기 자세 계산 시험). `test_weapon_motion`·`test_class_grips_server`·`test_unarmed_start`는 새 규칙에 맞춤.
- **메인 사진(메인 반영 1):** `HH_MAIN_STUDIO=1 py tools/play_tool_grip_ours.py` → 9종 앞·옆·3/4·걷기·공격 + GripProbe 줄.
- **볼 것:** Tool을 들 때 마우스 커서 모양이 바뀌는지, 망치·조련사 봉·플라스크 지팡이도 팔 앞에 세운 모습이 괜찮은지, 활 공격 때 왼손으로 넘어가는 순간 튐이 없는지, Hero 창 3D 몸의 무기.
- **나중(메시 연결 때):** 지팡이 Tripo 메시(원점 = 전체 길이 43%)는 이제 쥐는 점이 막대의 45%(전체의 약 39%)라 맞춰야 함 — 메시가 Handle을 대신하면 그 메시 기준 Point를 다시 정함(이미지 개발·최종 검수).
