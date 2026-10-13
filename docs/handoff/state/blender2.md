# Blender 손보기 2 — 상태 (2026-10-13)

Tripo 계정 2(사용자 Chrome, Claude Chrome 확장) · 빛 마을만 · 흰 모델 고르기·PBR 첫 검수 = **디자인 검수 2**(local_b0cabbea) → 최종 검수(local_8166f268).

## 정해진 것 (10/13)
- **텍스처 = 4K(20점)**: 계정 2(premium)는 8K가 체험 1번뿐. 사용자 "4K가 낫겠엉", 8K/4K 비교(Planter_D) 뒤 최종 검수 4K 확정. 물건 하나 = 스마트 메시 100 + 4K 20 + PBR 5 = **125점**.
- 계정 1 잔액이 낮아 앞으로 새 스마트 메시는 계정 2(최종 검수 10/13).
- 잔액 24,130 (10/13 오후). 스마트 메시 11번 중 처음 2번(Planter_D·FlowerCart_Bouquet)은 잔액이 안 줄었음 — records.json `_web2_account_note_1013`에 기록만.

## 한 것
- 11종 흰 모델(44개) → `art/models/tripo/wm2_1013/<이름>/<id8>.fbx`, 점토 시트 `art/review/blender2/wm_1013/<이름>.jpg`.
- 고른 것 → 텍스처 4K → PBR 원본 FBX `art/models/tripo/web/<이름>_SM_tex4k_pbr_src.fbx`: FlowerCart_Bouquet 82912694, Bal_E 781e6f4e, Bal_F 934efdb9, Bal_A bcaca51e, Bal_B add2a937, Bal_C 531c8172, Bal_D 71359ce0, WallLamp 8ec1b5e1, Hedge 67f8ae44 → 디자인 검수 2 통과 → **최종 검수 판정 대기**(통과 전엔 Blender 손대지 않음).
- FlowerBush 6e6bd726 PBR = 디자인 검수 2 탈락(잎 사이 뚫림) → **7cafd99b-625a-466f-9f4a-5fbee34bbca6로 텍스처 4K + PBR 다시**.
- Planter_D 105124b0: 8K 체험(`_SM_tex8k_src.fbx`, 버림) vs 4K(`_SM_tex4k_src.fbx`) 비교 `art/review/blender2/tex8k_vs_4k_1013/` → 4K 확정 → **PBR 아직 안 누름**.
- 간판 SignBakery f894a49d·SignFlower 1344c266 스마트 메시 = 계정 1과 겹쳐 누름(200점) → 예비로만 둠, 텍스처 안 누름. 간판 Juice·Potion·Beehive·WateringCan·SteppingStone = Blender 손보기 1 몫(누르지 않음).

## 남은 일 (순서)
1. Planter_D PBR (texture-pbr/105124b0-e593-41b9-bdec-7a56f649a3be)
2. FlowerBush 7cafd99b 텍스처 4K → PBR → FBX → 디자인 검수 2
3. NEW_BreadBasket·NEW_CafeTable 스마트 메시(4면 통과) → 흰 모델 FBX·시트 → 디자인 검수 2
4. NEW_BellFrame = 옆면 다시 그린 뒤(디자인 검수 2 알림)
5. 이미지 생성 2가 그릴 11종(4면 통과 뒤)
6. 최종 통과한 것: Blender 크기·피벗·방향만(`art/models/tripo/touchup/Halo_Statue/build_glb.py`, `--basecolor` 없이) → `touchup/<id>/<id>_TU.glb` → 이미지 생성 3. ⑤ 메모: Bouquet 꽃 DoubleSided·뒤를 수레 안쪽으로, Bal_C ㄱ 안쪽 세모 바닥판.

## 요령
- **Chrome 창이 화면에 보여야 Tripo 페이지가 돎**(visibilityState hidden이면 앱이 안 뜨고 스크립트가 45초 멈춤). 멈추면 최종 검수에 "창 보이게" 부탁. 내 탭은 Claude 그룹의 Tripo 탭 하나.
- 그림 넣기(Adobe 업로드는 이 세션 권한에서 막힘): 페이지에 `input#hhStage`(aria-label hhStage)를 만들고 `find "file input labelled hhStage"` → `file_upload`(10 MB 아래) → JS가 DataTransfer로 Tripo 칸에. 페이지 함수는 localStorage `hh2Def`(hhPrep·hhFill·hhGo, 스마트 메시), `hh2TexDef`(hhTexPrep·hhTexSet·hhTexGo, 텍스처), `hh2Pbr`/`hh2PbrW`(PBR). 매 페이지 이동 뒤 `eval(localStorage.getItem(...))`.
- hhPrep 뒤 store tab이 `low_poly`인지 꼭 확인(아니면 '생성 65' 다른 모드). hhGo는 탭·4칸 pass·4개·파일 이름을 확인한 뒤에만 누름.
- 숨은 탭에선 setTimeout이 1분에 한 번으로 느려짐 → `window.__sl`(MessageChannel+fetch) 사용. JS 한 번 45초 넘으면 끊김 → 넣기와 누르기를 나눠 호출.
- 결과 FBX 받기: 페이지에서 model_url을 `id 날짜 uuid 파일 만료 서명` 줄로 바꿔 `http://127.0.0.1:8765`(scratchpad recv.py, `timeout 120 py recv.py <out>` 백그라운드)로 POST → `py tools/design_review/tripo_dl.py <lines> <dir>`. 브라우저 다운로드·Downloads 폴더 안 씀.
- 점토 렌더: `blender --background --factory-startup --python tools/design_review/clay_views.py -- <out> <fbx…>`, 텍스처 비교 `tex_views.py`.
