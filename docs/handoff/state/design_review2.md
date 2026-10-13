# 디자인 검수 2 — 상태 (2026-10-13 오후)

역할(최종 검수 지시 10/13): **이미지 생성 2(local_aeaed629)의 2D 4면 판정 전부** + **Blender 손보기 2(local_9a2805c9, 사용자 Chrome·Tripo 계정 2)의 흰 모델 고르기·PBR 첫 검수**. 디자인 검수 1(local_2137d284) = Blender 손보기 1(local_1bcb35c4) 흰 모델·PBR + 이미지 생성 3 놓기 사진. 보고 = 최종 검수(local_8166f268)만. 빛 마을만. 판정 규칙·교훈은 `state/design_review.md`와 같음.

## 다시 시작하면 기다리는 것
1. **8K vs 4K 텍스처 비교**(사용자 결정: 텍스처 4K, 두 계정): Blender 손보기 2가 첫 1개를 8K·4K 둘 다 만들어 보냄 → 같은 자리 100% 크롭 나란히, 게임 크기 1024에서도 차이 보이는지 → 최종 검수에.
2. **(10/13 13시 판정: 9종 PBR 통과 → 최종 검수, 시트 `art/review/design2/pbr_gate_1013/`. FlowerBush 떨어짐 → 7cafd99b로 다시, Planter_D 4K PBR 대기)** Blender 손보기 2 PBR 결과 11종 → PBR 첫 검수(`tools/design_review/pbr_gate.py` 700 2048 → `pbr_gate_sheet.py`) → 통과만 최종 검수(이름 + 파일 경로 + ⑤ 메모).
   - 고른 흰 모델: Planter_D 105124b0 · FlowerCart_Bouquet 82912694 · Bal_E 781e6f4e · Bal_F 934efdb9 · Bal_A bcaca51e · Bal_B add2a937 · Bal_C 531c8172 · Bal_D 71359ce0 · NEW_FlowerBush 6e6bd726 · NEW_WallLamp 8ec1b5e1 · NEW_Hedge 67f8ae44
   - ⑤ 메모: Bouquet 4개 다 꽃 뒤 빈 껍데기 → 꽃 DoubleSided, 뒤를 수레 안/벽 쪽. Bal_C ㄱ 안쪽에 받침 높이 세모 바닥판 → 땅에 살짝 묻기. FlowerBush는 꽃 원판 자리 = 앞면 2D 꽃 자리라 고름.
   - 흰 모델 FBX `art/models/tripo/wm2_1013/<이름>/<id8>.fbx`, 시트 `art/review/blender2/wm_1013/<이름>.jpg`.
3. 큰 지도 V3 a·b = 통과, b 추천으로 최종 검수에 보냄(10/13).
4. **이미지 생성 2 빛 마을 소품 남은 11종 4면**(HaloFlagpole_1·2·3, HaloReasonHQ_GuardPost·PhotoDisc·Clothesline·PotionCrate·RackShieldSword·Scarecrow·VegGarden·Woodpile) → 내 판정 → 통과분 Blender 손보기 2 큐(점수 승인 나, 4K 125/개).

## 계정 2 진행(10/13 오후 늦게)
- PBR 최종 검수로 보낸 것(11): Bouquet·Bal_E·F·A·B·C·D·WallLamp·Hedge·Planter_D·FlowerBush(7cafd99b)·BreadBasket(a154d1da)·CafeTable(6f9f2ecd). 시트 `art/review/design2/pbr_gate_1013/`.
- 흰 모델 고름 → 텍스처·PBR 중: BellFrame 3adb21ff · Flagpole_1 99be186b · Flagpole_2 80eb3e39 · Flagpole_3 67b42ee8 · Clothesline c69458ae · RackShieldSword f31333d8 · Scarecrow 24fde989 · VegGarden a4222fbc(⑤ 흙 Studio 파트) · Woodpile 8274ab45.
- GuardPost = 계정 2 계속(흰 모델 7c300016 고름 → 텍스처·PBR). PotionCrate = 계정 1(Blender 손보기 1·디자인 검수 1, 최종 검수 결정). 최종 검수가 앞으로 records.json 확인 후 물건 배분. PhotoDisc = Studio 파트(이미지 생성 3, 최종 검수 결정).

- 최종 검수 PBR 최종 판정(10/13): 계정 2 14종 중 13 통과, **Bal_C 다시 → cd1fd3e2(열린 ㄱ, 45° 돌아 있음)로 텍스처·PBR 시험** — 어긋나면 스마트 메시 다시(125). ⑤ 메모 `docs/review/pbr_final_2026-10-13.md` '묶음 c'. GuardPost PBR 통과 보냄, PotionCrate fab0907c 텍스처·PBR 중.

- **A23-158 정정(사용자가 Blender 손보기 2에 직접): 텍스처 = 가운데 '멀티뷰' 탭에 2D 4면 · 4K · 조명 제거 → PBR.** 새 텍스처부터 → PBR 판정 때 뒤·옆이 예전(앞 한 장)보다 나은지 같이 봄. PotionCrate(fab0907c)는 옛 방식으로 이미 만듦·통과 보냄(뒤 V천 → ⑤ 뒤를 벽 쪽).
- **JuiceParasol 다시(A23-158):** 이미지 생성 2가 줄무늬 없는 하늘색 차양 + 흰 물결 테 4면 → 내 판정(빛살·X자 퍼짐 없는지 위에서도) → Blender 손보기 2.

- 대기(10/13 저녁): JuiceParasol v2 흰 모델(계정 2, Chrome에서 봄) · **NEW_ArmoryBarrels 다시**(계정 1 흰 모델 8개 모두 상자가 빈 X 격자 → 이미지 생성 2가 4면 상자 판을 진한 나무색으로 PIL → 내 확인 → 계정 2 스마트 메시 125 → Chrome 흰 모델 → 멀티뷰 텍스처) · 멀티뷰 다시 목록(최종 검수가 ~95개 가르는 중).

## 계정 2 몫(최종 검수 10/13)
Planter_D 4K PBR · FlowerBush 다시(7cafd99b) · BreadBasket · CafeTable(둘 다 4면 통과, 2×125 OK) · BellFrame(옆면 다시 그린 뒤) · 이미지 생성 2 소품 11종. **앞으로 새 스마트 메시는 계정 2.** Blender 손보기 2는 Chrome 창이 보여야 Tripo가 돎(창 차례 = 최종 검수).

## 2D 4면 판정 끝(10/13)
- 통과 → Blender 손보기 1: GatherBush·CandleCrate·Easel·NoticeBoard·ArmoryBarrels·WaterBuckets(디자인 검수 1 먼저 판정 따름).
- 통과 → (한때 Blender 손보기 2로 옮겼다가 **최종 검수 결정: 계정 1·디자인 검수 1 판정으로 되돌림** — 계정 2에서 간판 Bakery f894a49d·Flower 1344c266 흰 모델만 200점 겹침) 간판 Bakery·Flower·Juice·Potion, NEW_Beehive, NEW_WateringCan, NEW_SteppingStone(돌 하나; 옛 5개 줄 NEW_SteppingStones는 안 씀). 텍스처 4K → 1개 125점, 점수 승인·흰 모델·PBR 판정 = 나.
- 통과 → Blender 손보기 2: NEW_Hedge, NEW_WallLamp(_left/_right 이름 맞바꿈 6bfc4ff 뒤).

## 교훈
- **PBR 렌더 전에 파일 md5·`git status`를 확인**(두 Blender 세션이 같은 이름을 디스크에서 덮어쓸 수 있음 — PotionCrate 14:52~14:57 계정 1로 덮였던 사이에 렌더함). 시트 메시지에 md5 앞 8자리 적기.
- **사용자(10/13 저녁, "왜 검수하는 애는 크롬 안 봐?"): 계정 2 흰 모델은 Chrome의 Tripo에서 직접 돌려 보고 고름**(점토·wm_six = 보조). 순서: Blender 손보기 2가 '고르기 대기'일 때만 → 최종 검수에 "디자인 검수 2 / Chrome 흰 모델 보기 / N분" → '전달함, 시작' → Blender 손보기 2에 '지금 내가 봄' → 내 탭 하나(tabs_create_mcp, studio.tripo3d.ai/ko/workspace/generate/<id>)에서 위·아래·앞·뒤·양옆·3/4(Tripo 화면 버튼/JS 회전, 좌표 클릭·점수 버튼 금지) → 내 탭 닫기 → Blender 손보기 2에 '끝', 최종 검수에 '끝'. Chrome은 앞 탭만 그려져 둘이 겹치면 Blender 손보기 2가 멈춤. PBR도 가능하면 Tripo에서 한 번 돌려 봄.
- **사용자 지시(10/13): 흰 모델은 4개 각각 위·아래·앞·뒤·양옆 + 3/4를 다 보고 고름, 이유에 '위·아래 확인함'.** 도구 `tools/design_review/wm_six.py`(README 8).
- **난간·울타리처럼 바닥 모양이 중요한 것은 흰 모델을 바로 위(top)에서 꼭 봄** — Bal_C 531c8172가 옆에선 ㄱ인데 위에선 닫힌 세모(최종 검수가 잡음). 스크래치 `top.py`(위 + 뒤 3/4). 같은 2D라도 흰 모델이 45° 돌아 나오면 앞 한 장 텍스처가 어긋날 수 있음.
- 판정이 두 검수에서 겹치면 먼저 내려간 판정을 따르고, 정정은 관련 세션 모두에 한 번에(메시지가 엇갈림).
- 벽에 붙는 물건(벽 등불·간판): `_left` = 앞이 화면 오른쪽 → 벽판/기둥은 화면 왼쪽. 파일 이름 거꾸로 흔함.
- 옆면에서 앞면 볼록(그림 부조)은 판의 앞쪽 한쪽에만, 판은 팔·기둥 축 가운데. 측정: 판 아래 끝 가운데 x vs 기둥 꼭대기 가운데 x.
- 지붕 박공이 앞에 있으면 옆면은 경사 지붕면(박공·구멍 없음). 옆면을 앞면 복사로 그리는 고장 흔함.
- 여러 개 같은 돌·조각 줄은 하나만 4면으로(같은 카메라), Studio에서 여러 번 놓기.
- 덤불·잎 흰 모델은 **뒷면 안 지운 흰 실루엣(검은 바탕)으로 앞·옆 비침 검사** 먼저(점토 렌더는 뒷면을 지워 구멍이 안 보임) — FlowerBush 6e6bd726 실수. 스크립트: 스크래치 `holes.py`와 같은 방법(Workbench FLAT 흰색, backface culling 끔).
- 흰 모델은 `clay_views.py`로 직접 크게(창 없이) — 아래(low)에서 받침 갈라짐이 잘 보임. 앞면 2D 무늬 자리와 모양 자리가 맞는 흰 모델을 고르면 텍스처가 제자리에 앉음.
