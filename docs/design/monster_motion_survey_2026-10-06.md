# 몬스터 움직임 조사 — 무료 먼저 (2026-10-06)

> 기록용(10/06 당시). 지금과 다른 점: Tripo 비용은 사용자에게 묻지 않음(상시 OK, 묶음은 검수 승인, A23-47 보강 4; 지금은 Tripo 웹 25,000 계정 HD 55포인트, A23-47 보강 8·A23-96); 다른 몬스터 모델을 빌려 키운 것(GhostMinion·GhostKing ← LittleGhost 등)은 각자 새 모델로(최신: SPEC A23-96, `remake_list_2026-10-09.md`). 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

- 요청: 사용자 "몬스터들이 너무 경직된 느낌, 좀 더 자연스럽게 행동하면 좋겠어. 움직임 에셋 무료 한 번 살펴봐." (검수 → 이미지 생성 1)
- 규칙: A23-41 순서 = ① 딱 맞는 무료 → ② Tripo(크레딧 먼저 알림) → ③ 유료(후보만, 결제는 사용자).
- 이 조사는 읽기만 했다. Studio 0, 크레딧 0, 내려받기 0, 커밋 0. Tripo는 `balance`와 `--dry`만 돌렸다(무료).
- 표시: **[관찰]** = 파일·코드·데이터에서 직접 봄. **[추정]** = 계산이나 짐작(화면에서는 아직 확인 안 함).
- 줄 번호: `MonsterService.luau`는 작업본 기준(다른 세션의 FACE 수정이 아직 커밋 전). 나머지 파일은 HEAD와 같다.

## 0. 요약
1. 딱딱해 보이는 큰 이유는 "동작 파일이 모자라서"보다 **있는 동작을 쓰는 방법**이다. 싸우는 동안 마지막 자세로 굳고, 칼은 맞은 뒤 약 1.1초에 휘두르고, 쓰러지기는 0.3초 만에 사라지고, 걷기는 몸 속도보다 느려 미끄러진다(§1-2). 코드로 고치면 **무료**다.
2. 무료 동작(Roblox 공식 팩·Mixamo·Quaternius)은 우리 뼈대(Tripo 41뼈)에 **바로 안 맞는다**. Blender에서 뼈 이름을 맞추는 작업(중간 난이도)이 먼저 필요하다. 그래서 A23-41의 "딱 맞는 무료"는 지금 없다.
3. 슬라임·호박·유령·펫은 뼈 없는 메시 1개다. 동작 파일을 쓸 수 없으니 **코드 움직임**이 답이다(무료).
4. 사람형 5종에 Tripo 동작 2개씩(Run·LookAround) = **100크레딧($1)**. 나중 것까지 다 해도 220. 지금 API 잔액 **2,455**.

## 1. 지금 상태

### 1-1. 몬스터별 표 [관찰]
정의: `src/ReplicatedStorage/Shared/Config.luau:1255-1293`. 모델: 저장된 `build/GoodEvil.rbxlx`(10-06 12:41)의 `ServerStorage.CustomModels`를 글자로만 읽음. place 안에 `Animation`/`AnimationId`는 0개다(코드의 AnimationId는 플레이어용, `Fx.luau:105-110`).

| 몬스터 | 몸·뼈대 | 있는 동작 | 지금 움직이는 방법 | 빠진 것 |
|---|---|---|---|---|
| **Goblin · GoblinBrute · Skeleton · SkeletonKnight · BatGoblin** (사람형 5종) | Tripo 자동 리깅 `spec: tripo`, 뼈 41개(손가락 없음). MeshPart 1개 + Bone + AnimationController(안 씀) | Idle·Walk·Slash·Hurt·Fall. 5종 모두 **같은 Tripo 프리셋**(records.json). 15fps 데이터 `src/ReplicatedStorage/MonsterAnims/<종>_<동작>.luau`: Idle 2.07초, Walk 2.33, Slash 2.0, Hurt 1.0, Fall 3.0 | 클라이언트 `MonsterMotion.luau`가 매 프레임 `Bone.Transform`을 씀(:115-171, 고르기 :139-150). 몸 전체 기울기·찌르기·움찔은 `Fx.luau` VisualJoint.C0 트윈(준비 :3034-3093, 때리기 :1351-1382). WOBBLE은 끔(:1230-1233) | 두리번, 달리기(쫓기), 뼈로 하는 공격 준비, 등장. 쓰러짐은 파일은 있지만 거의 안 보임. BatGoblin 날개(박쥐 망토)는 뼈가 없어 안 움직임 |
| **Slime · BigSlime · PumpkinSlime** | 뼈 없는 MeshPart 1개(Tripo) | 파일 없음 | `Fx.luau` WOBBLE: 통통 뛰기+늘어남/납작(:1250-1267), 숨쉬기(:1254), 맞으면 출렁(:1268-1269), 퐁 등장(:1271-1278), 죽을 때 퍼짐(:1236-1243). 준비 = 납작(:3065-3067), 때리기 = 앞으로 통(:1360-1365) | 두리번, 쫓을 때 다른 뛰기 |
| **PumpkinKing** (보스) | 위와 같음, 크기 ×2.5 | 없음 | 슬라임과 같음. 집에 갈 땐 위로 둥실+사라짐(`MonsterService.luau:1042-1052`) | 두리번, 보스 등장, 무거운 착지 |
| **LittleGhost** | 뼈 없는 MeshPart 1개, Float 1.5 | 없음 | WOBBLE Float: 천천히 둥실(`Fx.luau:1289-1295`), 맞으면 살짝 내려감. 준비·때리기는 사람형과 같은 C0 기울기 | 두리번, 이동 방향 기울기, 등장, 귀여운 쓰러짐(지금은 줄며 사라짐) |
| **GhostMinion · GhostKing** (보스) | 저장 파일에는 자기 틀이 없어 LittleGhost를 ×0.6 / ×1.8로 빌림(`ModelFrom`, `MonsterService.luau:333-337`). 자기 Tripo GLB는 14:45에 생김 | 없음 | LittleGhost와 같음 | 위와 같음 + GhostKing 등장 |
| **PetBabySlime** (펫) | 뼈 없는 MeshPart 1개, 클라이언트만 그림 | 없음 | `PetFollow.luau`: PivotTo로 따라가며 통통(:182), 머리받기 = 목표까지 미끄러지기(:155-167). 크기 변화 0(`Bump`는 시간값뿐 :25, :203). 펫 틀을 PetModels로 옮기는 서버 코드는 Game-dev2에만 있음(main 미합류) | 숨쉬기, 늘어남/납작, 두리번, 머리받기 납작 |
| (참고) GoldenGoose | 이벤트 동물, MeshPart 1개 | 없음 | 서버가 둥실+흔들(`GooseService.luau:373-375`) | — |

공통: 서버 쪽 몸 들썩임은 없앴다(`MonsterService.luau:956-957`). 움직임은 전부 클라이언트(MonsterMotion·WOBBLE·그림자)다.

### 1-2. 사람형 5종이 딱딱해 보이는 이유 (코드·데이터로 확인, 화면 확인 전)
1. **싸우는 동안 굳음 [관찰]**: Slash는 2.0초인데 공격 간격은 약 1.5~1.75초다(쿨 1.5초 `Config.luau:1223`, AI는 0.25초마다 `MonsterService.luau:1901`). 같은 동작이 또 오면 처음부터 틀지 않고(`MonsterMotion.luau:99-100`) 마지막 장면에서 멈춘다(:156). 싸우는 동안 Slash가 계속 먼저라(:143) Hurt도 안 나온다.
2. **칼이 늦게 나감 [관찰]**: Slash는 맞히는 순간(AttackSeq, `MonsterService.luau:1525-1527`)에 시작한다(`MonsterMotion.luau:77-80`). 데이터에서 팔이 가장 빨리 도는 때는 클립 1.13초째다(5종 같음). 그래서 칼은 피해가 들어간 **약 1.1초 뒤**에 휘둘러진다. 준비 0.28초(`Config.luau:3320`) 동안 뼈는 Idle이다.
3. **쓰러짐이 안 보임 [관찰]**: 서버가 0.3초 동안 줄이며 지우고 0.4초에 없앤다(`MonsterService.luau:79-80`, :1028-1061). Fall은 3.0초이고 크게 넘어지는 때는 1.6초째다.
4. **걷기 미끄러짐, 돌아다니기 = 쫓기 [관찰+추정]**: 속도는 늘 `def.Speed`다(`MonsterService.luau:868`, 돌아다니기 :1794-1801도 같음). Walk는 1.17초에 두 걸음 → 속도 12면 한 걸음 약 7스터드. 키 5스터드 고블린에게 **[추정] 발이 2~3배 미끄러진다.** 재생 빠르기는 움직임과 상관없다(`MonsterMotion.luau:154`).
5. **가만히가 작고 다 같음 [관찰]**: 5종이 같은 `preset:idle`. 뼈 움직임 합이 Walk의 약 1/6. 두리번이 없다.
6. **등장 없음 [관찰]**: 퐁 등장은 슬라임 갈래 안에만 있다(`Fx.luau:1271-1278`). 사람형·유령은 갑자기 나타난다.
7. (작음) 시즌이 끝나 BatGoblin이 집에 갈 때(Leaving) Fall이 나온다. `MonsterMotion.luau:141`이 Leaving을 안 본다.

## 2. 무료 후보
우리 사람형 뼈대 [관찰]: Tripo `spec: tripo` 41개 — Root, Hip, Pelvis, Waist, Spine01·02, NeckTwist01·02, Head, L_/R_ Clavicle·Upperarm·Forearm·Hand·Thigh·Calf·Foot·ToeBase + Twist 뼈들. R15(Motor6D)도 Mixamo 이름도 아니다. 게임은 Roblox 동작 에셋이 아니라 Luau 데이터를 재생한다. 그래서 어떤 동작이든 끝은 **"Tripo 뼈 이름의 GLB → `tools/glb_anim_to_luau.py` → MonsterAnims"** 다.

| 후보 | 출처·만든 곳 | 라이선스 | 맞는 몬스터 | 옮기는 수고 | 위험 |
|---|---|---|---|---|---|
| (a) Roblox 공식 아바타 동작 묶음(Zombie·Knight·Ninja 등) | Roblox, [Use animations](https://create.roblox.com/docs/animation/using) | 기본 동작 대신 내 게임에 써도 된다고 문서에 있음 | 플레이어(R15 사람 몸)용. 뼈 이름이 달라 우리 몬스터엔 안 맞음 [추정, 거의 확실] | **높음**: 몬스터를 R15로 바꾸고(Avatar 자동 설정, 치비 몸은 실패 이력 `README_KO.md:788`) MonsterMotion을 Animator로 바꿔야 함 | 몬스터 구조 갈아엎기 |
| (a) Creator Store 무료 모델 속 동작(KeyframeSequence) | 여러 사람 | Store에 '동작' 분류 없음. 동작 에셋은 'Restricted'라 Open Use 불가([2025-07-31 공지](https://devforum.roblox.com/t/improving-animation-asset-permissions/3852101)) | R15 위주 | **높음**: 우리 계정으로 다시 올리고 뼈 맞추기 | 권리 불명. 넣는다면 **`build/WorldKit.rbxlx`에만** 넣고 스크립트 0개 확인(이번엔 아무것도 안 넣음) |
| (a) Studio 애니메이션 편집기로 직접 | Roblox(무료) | 우리 것 | 사람형 5종(뼈 편집 가능) | **높음**: 손으로 키프레임 + 데이터로 바꾸기 | 시간 많이 듦 |
| (b) Mixamo | Adobe, [mixamo.com](https://www.mixamo.com), [FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)(검색 요약 기준) | 무료. 게임 포함 상업 사용 OK, 로열티 없음. 원본 파일만 따로 재배포 금지. AI 학습 금지 | 사람형 5종(검과 방패 묶음, 좀비 묶음 중 무섭지 않은 것) | **중간**: Blender에서 Mixamo 뼈 22개 → Tripo 뼈 이름 표를 1번 만들고, 동작마다 팔이 몸을 뚫는지 확인. 다른 길: `spec: mixamo` 뼈대(고블린은 이미 `art/models/tripo/MonsterGoblin_rig_f922….glb`, 23관절)로 모델 교체 | 내려받기에 Adobe 로그인(사용자). 치비 비율이라 팔·다리 겹침 [추정]. mixamo 뼈대에는 Tripo 프리셋이 안 됨(1004, `tools/tripo_api.py:280`) |
| (c) Quaternius Universal Animation Library 1 · 2 | Quaternius, [UAL1](https://quaternius.itch.io/universal-animation-library), [UAL2](https://quaternius.itch.io/universal-animation-library-2) | **CC0**(출처 표시도 필요 없음). 무료판 UAL1 45개, UAL2 42개. 전부 받기: UAL1 Pro $9.99 / Source $14.99, UAL2 $14.99 | 사람형 5종. UAL2에 좀비 걷기(해골), 칼 콤보, 맞기 있음 | **중간**: Mixamo와 같은 Blender 길("Mixamo와 호환"이라고 적힘). FBX·GLB 있음 | 내려받기는 사용자 OK 필요 |
| (도구) Blender 확장 "Retarget" | KBS-DEV, [extensions.blender.org](https://extensions.blender.org/add-ons/retarget/) | GPL-3, 로그인 없음, Blender 5.0+ (우리는 5.2.2) | (b)·(c)용 | 설치 1번 | 설치는 사용자 OK. 안 깔면 bpy 스크립트(Copy Rotation → 굽기)로 직접 |
| (d) **코드 움직임** | 우리(Fx WOBBLE, MonsterMotion, PetFollow) | 우리 것 | **슬라임 3종·PumpkinKing·유령 3종·펫**(뼈가 없어 이것뿐). 사람형도 코드로 얹는 층(머리 두리번, 쫓을 때 숙이기, 걷기 빠르기) | 낮음~중간(코드만) | 크레딧 0 |
| (참고) AI 글→동작 사이트(NoCapMocap, Bloxlab 등) | 외부 | 계정·결제 | R15 위주, 우리 뼈는 결과가 들쭉날쭉 | 높음 | 안 씀 |

판단: 사람형은 Tripo가 1개 10크레딧이고 지금 뼈대에 바로 맞는다. 무료 (b)·(c)는 Tripo에 없는 동작(좀비 걷기, 방패 막기)이 필요할 때 여는 게 낫다. 뼈 없는 몸은 무료 동작이 들어갈 자리가 없다 → (d).

## 3. Tripo 동작 비용
| 항목 | 값 | 출처 |
|---|---|---|
| 리깅 검사 / 리깅 / 동작 1개 | 0 / 25 / 10 크레딧 (1크레딧 = $0.01) | `docs/vendor/tripo_api/pricing.md:4`, :52-54 |
| 사람형 뼈대(v1.0) 프리셋 | 101개 `preset:biped:*` — idle, walk, run, look_around, standing_relax, wait, scratch, slash, chop, box_01, front_kick_01, hit_to_body_01, hit_to_head, hurt, fall, defeat_02, jump, jump_down, swagger, cheer, victory_celebration 등 | `README_KO.md:533-534` |
| 사람 아닌 뼈대(v2.5) | 사람형 11개 + 네발·여섯발·여덟발 걷기, 뱀·물고기 기어가기뿐. 새·덩어리용 없음 → 슬라임·호박·유령은 Tripo 동작 불가 | `README_KO.md:529-531` |
| 한 번에 보내기 | 최대 5개 묶음 가능(`models.md:28`). 우리 도구는 1개씩, 제자리(animate_in_place) | `tools/tripo_api.py:307-310` |
| 우리 도구 이름표 | `anim`은 Idle·Walk·Slash·Hurt·Fall 5개만 앎 → Run·LookAround를 쓰려면 `MONSTER_ANIMS`에 줄 추가 필요 | `tools/tripo_api.py:281-282` |
| 이미 있는 뼈대 id (`--rig`로 쓰면 리깅 25 안 냄) | Goblin 82ac2597…, GoblinBrute cd48c877…, Skeleton 855126b4…, SkeletonKnight 348435e6…, BatGoblin d7bd0d9c…. dry: Goblin 동작 2개 = 20 | `art/models/tripo/records.json` |
| 지금까지 몬스터 동작에 쓴 것 | 400크레딧(5종 리깅+동작) | records.json 합계 |
| **지금 API 잔액** | **2,455크레딧($24.55), 묶인 것 0** — 2026-10-06 `py tools/tripo_api.py balance` | |
| Tripo 웹(Tripo Studio) | 2026-09-30 "글→동작" 추가: **사람형만**, 리깅 20·동작 20, 1~10초, 5구간까지 이어 붙임, 뼈 UE5·Mixamo·VRM·Unity·ActorCore. 웹에서 프리셋 1개가 몇 포인트인지는 **모름**(공식 요금 페이지가 403). 웹 무료판 결과는 공개 CC BY 4.0(출처 표시)이라는 글과 상업 불가라는 글이 섞임 → 사용자 웹 계정 등급 확인 필요 | [spatialinsiders](https://spatialinsiders.com/stories/tripo-rigging-animation-text-to-motion) |

주의:
- 프리셋 원본은 길다(hurt 14초, slash 6.6초) → `glb_anim_to_luau.py --from/--to`로 잘라 쓴다(:4-5). 잘라 쓰기는 무료다.
- 작업 id가 언제 만료되는지 문서에 없다. 만료면 가져오기(0) + 리깅(25)을 다시 해야 하고, 새 뼈대 쉼 자세가 조금 달라질 수 있다 [추정].
- 짧은 이름 `preset:idle`은 v1.0 뼈대에서 됐다(records.json). 긴 이름 `preset:biped:look_around`가 같은 뼈대에서 되는지는 아직 안 해 봤다 [추정: 됨] → **고블린 1개(10크레딧)로 먼저 시험.**

## 4. 몬스터별 추천 묶음 + 비용
아이 안전: 피·잔인함 없음. 쓰러짐 = 귀엽게 넘어지고 별 "펑". 무서운 좀비 동작은 안 씀. 이겼을 때 놀리기도 귀엽게.

### 4-1. 사람형 5종 공통 코드 수정 (무료, 베타 전 꼭)
1. 공격마다 Slash를 처음부터 튼다. 휘두른 뒤에는 Hurt가 끼어들 수 있게 한다.
2. Slash를 준비 시작(WindupAt)에 틀고, 클립 앞을 잘라 "팔이 가장 빨리 도는 때 = 맞는 때"로 맞춘다(지금 1.13초 → 0.28초). 준비 시간은 그대로라 난이도는 안 바뀐다.
3. 쓰러짐: 몸을 1.0~1.2초 남기고 Fall의 넘어지는 부분만 빠르게 → 별 펑 → 사라짐.
4. 돌아다닐 땐 느리게(약 절반), 쫓을 땐 지금 속도. 걷기 재생 빠르기를 실제 속도에 맞춘다. 쫓을 땐 Run.
5. 가만히 있을 땐 Idle과 LookAround를 섞는다(몇 초마다, 몬스터마다 다른 때).
6. 등장: 땅에서 쑥 올라오기 또는 퐁(슬라임처럼) + 먼지.
7. Leaving이면 Fall 대신 둥실.
- 담당 제안: 클라이언트(MonsterMotion·Fx·PetFollow) = 게임성 개발 1, 서버(돌아다니기 속도·없애는 시간) = 게임성 개발 2, Tripo 동작 만들기·잘라 바꾸기 = 이미지 생성 1. `MonsterService.luau`는 지금 다른 세션이 고치는 중이라 순서를 맞춘다.

### 4-2. 몬스터별
| 몬스터 | 베타 전 꼭 | 나중 | 출처 | 크레딧 (베타 전 / 나중) |
|---|---|---|---|---|
| Goblin | Run, LookAround + 4-1 | scratch(머리 긁기), cheer(이겼을 때), hit_to_body_01 | Tripo + 코드 | 20 / 30 |
| GoblinBrute | Run, LookAround + 4-1 | chop(내려찍기), swagger(으쓱 걷기), hit_to_body_01 | Tripo + 코드 | 20 / 30 |
| Skeleton | Run, LookAround + 4-1 | hit_to_body_01, cheer. 무료 길이 열리면 UAL2 좀비 걷기 | Tripo + 코드 (+무료) | 20 / 20 |
| SkeletonKnight | Run, LookAround + 4-1 | swagger, hit_to_body_01. 무료 길이 열리면 Mixamo 방패 막기 | Tripo + 코드 (+무료) | 20 / 20 |
| BatGoblin | Run, LookAround + 4-1 | chop(몽둥이 내려찍기), hit_to_body_01. 날개 펄럭은 Blender로 날개 뼈 추가 필요(높음) | Tripo + 코드 | 20 / 20 |
| Slime · BigSlime · PumpkinSlime | 두리번(몸 천천히 돌기), 쫓을 땐 더 빠르고 높게 뛰며 앞으로 숙임 | 표정 바꾸기는 메시 1개라 불가 → 스티커 그대로 | 코드 | 0 / 0 |
| PumpkinKing | 등장(위에서 쿵 + 먼지 고리), 두리번 | 무거운 착지 때 땅 흔들 | 코드 | 0 / 0 |
| LittleGhost · GhostMinion | 이동 방향으로 기울기·좌우 살랑, 두리번, 등장(아래서 스르르 + 투명→보임), 쓰러짐(빙글 돌며 작아지고 별 펑) | 공격 = 아래로 슝 내려왔다 앞으로 | 코드 | 0 / 0 |
| GhostKing | 위와 같음 + 보스 등장(반짝이며 나타남) | 홀 휘두르기는 팔 뼈가 없어 몸 전체로만 | 코드 | 0 / 0 |
| PetBabySlime | 슬라임처럼 늘어남/납작·숨쉬기, 머리받기 때 납작, 멈추면 주인 보기 | 기분 좋을 때 통통 | 코드(펫 틀이 main에 들어온 뒤) | 0 / 0 |

**Tripo 합계: 베타 전 100크레딧($1.00) · 나중 120 · 전부 220.** 뼈대 id가 만료됐으면 리깅 25×5 = 125가 더 든다(최대 345). 잔액 2,455로 충분하다. 코드 수정(4-1, 뼈 없는 몬스터 전부)은 0크레딧이다.

## 5. 열린 질문 (사용자·검수가 정할 것)
1. Tripo 100크레딧(사람형 5종 × Run·LookAround)을 써도 될까? 먼저 고블린 LookAround 1개(10)로 이름·뼈대 id가 되는지 시험하는 안.
2. 돌아다닐 때 속도를 절반으로 낮춰도 될까? 쫓는 속도는 그대로라 난이도는 같다. 사냥터가 덜 "바빠" 보일 수는 있다.
3. 쓰러진 몸을 1.0~1.2초 남겨도 될까? 보상은 지금처럼 바로 들어오고, 보이는 것만 길어진다.
4. 공격: 준비 0.28초를 그대로 두고 클립을 맞추는 안(추천, 난이도 같음)과, 사람형만 준비를 약 0.5초로 늘려 팔 드는 게 보이게 하는 안(피할 시간이 늘어 쉬워짐) 중 무엇?
5. 무료 Mixamo·Quaternius 길을 열까? Blender 확장 설치 + 사용자 내려받기(Mixamo는 Adobe 로그인)가 필요하고 중간 작업이다. Tripo에 없는 동작이 필요할 때만 여는 안.
6. Tripo 웹 "글→동작"(동작 20)으로 몬스터만의 동작을 만들까? 그 전에 웹 계정 등급(무료판 라이선스)을 확인.
7. BatGoblin 날개 펄럭은 베타 뒤로 미뤄도 될까?
8. GhostMinion·GhostKing 자기 모델이 지금 Studio에 들어가 있나? 저장 파일(12:41)에는 없다. 넣기 전이면 LittleGhost를 빌려 쓴다.

## 출처 (웹)
- Mixamo FAQ(Adobe): https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- Quaternius UAL1: https://quaternius.itch.io/universal-animation-library · https://quaternius.com/packs/universalanimationlibrary.html · UAL2: https://quaternius.itch.io/universal-animation-library-2
- Roblox 동작 사용: https://create.roblox.com/docs/animation/using · 동작 권한 공지: https://devforum.roblox.com/t/improving-animation-asset-permissions/3852101 · Toolbox 동작 분류 없음: https://devforum.roblox.com/t/how-to-find-animations-in-the-toolbox/2182742
- Blender Retarget 확장: https://extensions.blender.org/add-ons/retarget/
- Tripo 글→동작(웹): https://spatialinsiders.com/stories/tripo-rigging-animation-text-to-motion · Tripo API 요금: https://developers.tripo3d.ai/en/pricing (`pricing.md`, 2026-10-03 사본)
