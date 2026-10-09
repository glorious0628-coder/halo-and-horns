# 빛 아바타 6종 직접 시각 검토

> 기록용(2026-10-09 검수): 2026-10-04 검토 기록이다. 이 치비 아바타들은 게임에서 빠졌다(SPEC A23-5). 아래 '다음 조치'는 진행하지 않는다.

원화 6장, NeutralFace 1254 원본 6장, 최신 정면 CG 6장, 성기사 남 생산 rigid CG 1장을 직접 확인했다. 총 19장. 실제 생산은 성기사 남·궁수 남 2종이고 나머지 4종은 로컬 후보다.

| 아바타 | 현재 연결 | 직접 확인 결과 | 다음 조치 |
|---|---|---|---|
| 빛 성기사 남 | 생산 rigid; 최신 skin은 로컬 | 두 눈 경계·홍채, 머리카락 이음, 작은 갑옷 장식이 뭉개짐 | 눈·머리카락·갑옷 장식 선명도 재제작 우선 |
| 빛 성기사 여 | 로컬 | 눈 흰자/홍채 경계 번짐, 머리카락·관 장식 둔해짐 | 눈 경계·곱슬머리·작은 금속 장식 재제작 필요 |
| 빛 궁수 남 | 생산 MouthRestored | 윙크 외곽 붓자국 번짐, 열린 눈 경계 흐림, 머리끝 검은 이음 | 승인 D/새 전신 원화의 별도 Tripo 재제작 대상; 기존 생산 원본 유지 |
| 빛 궁수 여 | 로컬 | 흰자의 삼각형/중복 선, 뾰족한 홍채, 닫힌 눈 각진 블록 | 눈의 삼각형/중복 경계 최우선; 현 후보 시각 품질 보류 |
| 빛 마법사 남 | 로컬 | 눈 경계 번짐 + 평상시 입 위 붉은 조각 두 개 | 입 위 붉은 조각 해결 전 현 후보 연결 보류; 눈·장식 선명도 재제작 필요 |
| 빛 마법사 여 | 로컬 | 눈 반사점/홍채 번짐, 헤일로 좌우 별 위치 차이 + 무릎 위 치마/맨 허벅지 | 눈·헤일로 위치와 세부 개선 및 단정한 하의 GPT 원화 선택 필요 |

원화의 눈과 장식은 현재 얼굴 PNG/CG보다 분명하다. 6종 모두 눈 번짐 또는 경계 깨짐을 직접 확인했다. 이전 raw2k→fixed 감사에서 머리 텍셀 밀도도 낮아졌지만, 현재 Face1254 자체의 번짐과 별도 문제다.

남마법사의 최신 CG는 FaceUnion v2이며 평상시 입 위 붉은 조각이 나타나 연결을 보류한다. 여궁수의 열린 눈은 단순 부드러움에 더해 삼각형/중복 경계가 보여 우선 수정 대상이다.

여마법사 APose는 현재 AGENTS의 치마 무릎길이 이상+타이츠 조건을 충족하지 않는다. 단정한 하의 GPT 원화 선택 전 새 업로드를 보류한다. 다른 여성 2종은 하의와 몸통을 덮고 있다.

생산 성기사 남의 기존 rigid CG와 최신 skin CG는 구분했다. 최신 CG 7개의 기록된 GLB SHA가 현재 파일과 모두 일치했다. CG 대부분은 얼굴/상반신이라 전신 복장은 APose 기준이고 실시간 모션 QA는 별도다. 남마법사 CG는 emission 조명이므로 종간 밝기 비교를 하지 않았다.

실제 확인한 모든 그림의 절대경로·SHA256·크기·CG source SHA는 [halo_review.json](halo_review.json)에 있다. 원본 이미지/GLB/UV/리깅 변경 0, Studio 0, 업로드 0, 유료 API 0이다. 승인 D와 새 Tripo 재제작은 별도이며 A/B/C는 거절 상태를 유지한다.

## 원본을 직접 확인한 경로

- 빛 성기사 남
  - `C:/Users/glori/Documents/Game/art/out/APose_HaloWarriorM.png` — 1024×1024; SHA256 `06f5852ec124151554ae687796658e6c8f62c5fff821cdfab97144c7ec88c42d`
  - `C:/Users/glori/Documents/Game/art/out/Costume_HaloWarriorM_Expression_Neutral_face.png` — 1254×1254; SHA256 `cc040072b0bad26912a5bbcd1ee35c024ed037c888043a0c58ee83e80d7f1e53`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloWarriorM/face_union_mouth_winding_v1_previews/Neutral_front.png` — 768×768; SHA256 `0c0dde931f4a244ce9881f6579eda8260d797bc7ed9a84ff0ca58e000bc14052`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloWarriorM/previews/Neutral_front.png` — 768×768; SHA256 `9def137a685d18eef8b445f6bddd6c66478fd4d12355041f2432854d86f3e53c`
- 빛 성기사 여
  - `C:/Users/glori/Documents/Game/art/out/APose_HaloWarriorF.png` — 1024×1024; SHA256 `62bf94feab90c94157f852a7e173d05d4a425071e80aaee1a8ca13885350f185`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloWarriorF/Costume_HaloWarriorF_Expression_Neutral_face.png` — 1254×1254; SHA256 `1c7a2e67c3eb5152e9858c09177a4ba4abcdbe55b339a784880bb19484d2b5f1`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloWarriorF/face_union_mouth_winding_v1_previews/Neutral_front.png` — 768×768; SHA256 `daa2f6663f1a12171d43621728d3750155e10d4d778b8b983b14d64d86a3f28f`
- 빛 궁수 남
  - `C:/Users/glori/Documents/Game/art/out/APose_HaloArcherM.png` — 1024×1024; SHA256 `4534e82d4407fa7956ef50be299092a0c19770181139fb0285b7bf3852422c63`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloArcherM/Costume_HaloArcherM_Expression_Neutral_face.png` — 1254×1254; SHA256 `9943b2a53752470f41d290466c96fc6aed4b9e7b4bd1a295588b111bc4832e1a`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloArcherM/face_union_mouth_v1_previews/Neutral_front.png` — 768×768; SHA256 `77fb8f7edd46baea5aaafac2444818e420d45b9f04f71a16e1e3bd4fb1ee7ed3`
- 빛 궁수 여
  - `C:/Users/glori/Documents/Game/art/out/APose_HaloArcherF.png` — 1024×1024; SHA256 `f8440a00ef2a55f166c9f6687fa003b9ac664889dc52c535ef437cb8a11d5b26`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloArcherF/Costume_HaloArcherF_Expression_Neutral_face.png` — 1254×1254; SHA256 `7c94c1b4d477ff6d6ecf98e8629e7db8bff762954ca269042638e5ec0db94898`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloArcherF/face_union_mouth_v1_previews/Neutral_front.png` — 768×768; SHA256 `025d37617738b53a2a5674e52cb1d4968fb92ca5051cc684695a8cb3f867fd62`
- 빛 마법사 남
  - `C:/Users/glori/Documents/Game/art/out/APose_HaloMageM.png` — 1024×1024; SHA256 `ac9c1b8bdb77a7c77137413b1718ffaa26510ba80a2acd08e6266b8731a33c9c`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloMageM/Costume_HaloMageM_Expression_Neutral_face.png` — 1254×1254; SHA256 `f5bfee0efaaa3299caf4fc570a2210098781d17e1ab03461047f7d6f521285aa`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloMageM/face_union_v2_previews/Neutral_front.png` — 768×768; SHA256 `87e69e9b15206aedd47b6a2a802ac7d7a3c96fc4b911b81f35c968823e1586de`
- 빛 마법사 여
  - `C:/Users/glori/Documents/Game/art/out/APose_HaloMageF.png` — 1024×1024; SHA256 `646356b5049ae50154128dbe06c30909cfa97b1d6f8fd83a49bf1295b1d9f8f1`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloMageF/Costume_HaloMageF_Expression_Neutral_face.png` — 1254×1254; SHA256 `27aebf29d62ad85502fb4fcad443f52a070522656236789ea1b7e3ec1274d13b`
  - `C:/Users/glori/Documents/Game/art/models/costume/expressions/Costume_HaloMageF/face_union_mouth_v1_previews/Neutral_front.png` — 768×768; SHA256 `601f5acb6d1f1052f06b9222040be7c71b08371ec09f063dd475d7f2ce813743`
