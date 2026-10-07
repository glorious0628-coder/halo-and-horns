# 계급 장식 3D — 계급별 후광·뿔 모델을 머리 위에 (게임성 개발 2, 2026-10-07)

파일: 이미지 생성 1 45b6220(사용자 OK "좋아, 넣어") `art/models/acc/Acc_HaloR1~R5.glb`, `Acc_HornsR1~R5.glb`(각 메시 1개 + 텍스처 1장, 면 912~1,970). 시트 `art/review/acc/acc_final10.jpg`. 검사: `py tools/test_rank_marks.py`(81검사, 정적 12, 변이 13/13).

## 1. 서버 (CharacterVisuals.buildFactionMark)
- 빛·뿔은 계급(`Config.GetTitle`, 명예·악명 → R1~R5)마다 `ServerStorage[Config.Visuals.MarkModels.Folder = "MarkModels"]`의 `Acc_HaloR<n>` / `Acc_HornsR<n>`를 복제해 머리에 붙인다(MeshPart, 또는 메시 하나가 든 Model이면 그 안의 첫 BasePart).
  - 크기 = 원래 크기 × (머리 높이 / `HeadRef` 1.2). 블록 머리 1.2면 이미지 생성 1이 준 크기 그대로.
  - 자리: 모델 밑면이 머리 윗면에서 **후광 +0.3**(`HaloGap`) / **뿔 −0.06**(`HornsDepth`, 살짝 박힘), 둘 다 × 같은 비율. 앞쪽은 `Yaw` **0**(이미지 생성 1이 가져오기 전에 앞면을 Roblox −Z로 돌려 둠, 427baf8).
  - 무게 없음·충돌 없음·조회/터치 없음·그림자 없음, 머리에 용접(`mount`). 후광은 예전 원반처럼 금빛 PointLight, **R5만** 반짝이 효과(`Glow`: 후광 금빛, 뿔 불씨색) — 이미지 생성 1 "금빛 번짐·불씨는 효과로".
  - 계급이 오르내리면 지금처럼 Honor/Infamy 속성 변화로 다시 만든다(WATCH 그대로).
- **모델이 아직 Studio에 없으면 예전에 그리던 후광 원반·뿔 쐐기 그대로**(계급별로 따로: R3만 빠져도 R3만 옛 모양). 장인(길드)은 톱니 그대로.

## 2. Studio에 넣기 (검수 2026-10-07: 이미지 생성 1 → 게임성 개발 1)
1. **이미지 생성 1**: WorldKit에서 24개 묶음으로 10개 GLB를 가져오기(메시+텍스처, 하드 규칙 1 확인). 크기는 가져온 그대로(스터드 단위로 만든 모델).
2. 이미지 생성 1이 `Acc_HaloR1~R5` / `Acc_HornsR1~R5` **이름 그대로** rbxm(또는 애셋 id)을 게임성 개발 1에게 넘김. MeshPart 하나, 또는 메시 하나가 든 Model이면 됨(서버가 안의 첫 메시를 씀).
3. **게임성 개발 1**: 메인 place의 `ServerStorage/MarkModels` 폴더에 그대로 넣고 Play로 빛·뿔 캐릭터를 R1~R5로 바꿔 보며(디버그로 명예/악명 값) 확인 — ① 앞뒤가 맞는지(거꾸로면 `Config.Visuals.MarkModels.Yaw` = 180), ② 뿔이 머리에 살짝 박히고 후광이 떠 있는지, ③ 여러 아바타 머리 크기에서 괜찮은지. 숫자만 바꾸면 되고 코드는 안 고쳐도 됨.
4. place 저장·커밋은 게임성 개발 1.

## 3. 나중
- 계급 장식이 머리 장신구(Accessory)와 겹치면 `HaloGap` / `HornsDepth`를 올리거나, 아바타 모자 숨기기(개발 1 몫)를 정한다.
- 반짝이(Glow) 세기·색은 촬영 편집·검수가 보고 `Glow` 숫자만 바꾼다.
