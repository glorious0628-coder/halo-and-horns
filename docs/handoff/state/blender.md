# Blender 손보기 — 상태 (2026-10-12)

## ⛔ 10/13 저녁 — Tripo 점수 버튼 전부 멈춤 (사용자)
- 사용자가 점수 쓰는 데 화남 → **사용자가 다시 OK할 때까지 스마트 메시·텍스처·PBR 아무것도 누르지 않음.** 계정 1 잔액 1,355. 도는 Tripo 일 없음.


## 10/13 저녁 — 흰 모델 고르기 = 합의 (사용자)
- 디자인 검수가 Tripo 화면에서 4개를 직접 돌려 보고 하나 고름 → **나와 메시지로 의논해 합의** → 그 뒤에만 텍스처(멀티뷰 4면·4K·조명 제거) → PBR. 합의 전엔 텍스처 누르지 않음. 내 의견은 build/tripo_wm1 FBX를 white_model_sheet로 사방·위·아래 보고 보냄.
- 멀티뷰 텍스처 도우미: hhMvUp(멀티뷰 탭+4칸 넣기) / hhMvGo(누르기, 20점 확인). 그림 묶음은 window.__hhB<N>(Tripo가 Cache를 지움).

## 10/13 오후 — 텍스처 방식 바뀜 (사용자, 정정판)
- **새 텍스처 = 가운데 '멀티뷰' 탭에 2D 4면**(앞·왼쪽·오른쪽·뒷면 칸, 스마트 메시와 같은 순서: 왼쪽 칸 ← _right, 오른쪽 칸 ← _left) + 조명 제거 + 4K → 텍스처 생성 → 바로 PBR. 첫 탭(앞면 사진 한 장)은 안 씀. hhTexFn/hhTexUp은 첫 탭용이라 새 텍스처에 쓰지 말 것 — 멀티뷰 탭용 함수 새로 만들어야 함. 이미 만든 것은 그대로.
- 지금 내 큐 없음, 계정 1 잔액 1,455(1,505→1,455 = GuardPost·PotionCrate 계정 1 텍스처 20×2 + PBR 5×2, 둘 다 예비). GateLeafR 거울판 만듦(노멀맵 빛 차이 주의, 이미지 생성 3이 사진에서 봄).


> **10/18 정리(최종 검수):** 옛 절은 지움 — 전부 git 역사에 있음: `git show b558445b:docs/handoff/state/blender.md`. 아래 = 지금 필요한 절 + 방법·도구 메모.

## 앱 안 브라우저에서 Tripo에 그림 넣기 (10/12 밤 시험 통과)
- Adobe에 올리기(`asset_initialize_file_upload` → `curl -X PUT --data-binary @파일` → `asset_finalize_file_upload`) → Tripo 페이지에서 `fetch(presignedAssetUrl)` → File → DataTransfer로 칸에 넣기. base64를 JS에 붙이지 말 것(너무 무거움).
- 스마트 메시 탭 → 큐브(멀티뷰) 아이콘. `input[type=file]` 순서 0 앞 · 1 왼쪽 · 2 오른쪽 · 3 뒷면. **왼쪽 칸 = 캐릭터의 왼쪽이 보이는 그림(화면 왼쪽을 봄, 우리 `_right` 파일)**, 오른쪽 칸 ← `_left`.
- 창이 좁으면 왼쪽 패널이 잘림 → 보기 크기 1280x832로 맞추고 작업, 끝나면 되돌림.
- 내보내기(GLB)는 사용자 허락 뒤. Tripo Studio 내보내기는 앞 = Blender -y, 바닥 가운데 피벗 → `tools/view_match_2d.py --front -y`.

## 실패해서 버린 것 (다시 하지 말 것)
- Blender로 Tripo 얼굴 면 펴기(평면 맞추기·라플라스·구멍 메우기·나누기): 접힌 선, 머리카락이 얼굴에 들어감. 얼굴 2D 투영 칠은 3D 조각된 눈·이 자리와 어긋나 빛 받으면 이가 두 동강.
- Tripo 매직 브러시를 합성 입력으로: 확대만 되고 화면 이동·생성 모드 붓은 안 먹힘.

## 도구 (10/12)
- `tools/view_match_2d.py` — GLB를 2D 4면과 같은 틀로 찍기(`--front -y` = Tripo Studio 내보내기). 2D | 옛 | 새 시트에 씀.
- `tools/face_clean_bl.py` + `tools/face_clean_2d.py` — 얼굴만 떼어 평면 UV로 굽고 2D 기준으로 다시 그리기(실험, 위 이유로 안 씀).
- `tools/blender_view.py` — 2D | Tripo | 새 판을 Blender 창에 띄우는 보기 전용 스크립트. (`tools/blender_live.py` = 파일로 Blender 창을 조종하는 리스너, 로컬만, 올리지 않음.)
