# 왕 슬라임 금 왕관 붙이기 (style drift #25, 검수 OK 10/08)

- 어느 모델: `ServerStorage.CustomModels.BigSlime`(왕 슬라임)만. 일반 Slime에는 붙이지 않음. 메시 = `art/models/tripo/KingSlimeCrown.glb`(단색 금, 텍스처 없음 → MeshPart Color (255,153,15) · Material Metal 또는 SmoothPlastic), 몸 메시 = `MonsterSlimeCube_backfix.glb`(뒷면 자국 지운 판).
- 위치·크기: 두 GLB는 같은 좌표에서 만들어짐. 몸 MeshPart 높이를 H(스터드)라 하면 왕관 MeshPart Size = (0.458, 0.379, 0.457)·H, 왕관 중심 = 몸 MeshPart 중심 + 몸의 로컬 축으로 (-0.036, +0.384, -0.147)·H (가져온 그대로의 X·Y·Z, 몸에 회전을 따로 줬으면 같은 회전을 왕관에도).
- 붙이는 법: 왕관 Anchored=false, CanCollide=false, CanQuery/CanTouch=false, Massless=true → WeldConstraint(Part0 = 몸 MeshPart, Part1 = 왕관)로 용접, 모델 안에 넣어 애니메이션·피격 흔들림을 같이 따라가게. 크기 바꾸는 효과(ScaleTo)가 있으면 모델 단위로 함께 바뀜.
