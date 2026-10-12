# Blender 손보기 — 상태 (2026-10-12)

## 10/12 밤 — 빛 마을 동상·분수 (내려받기 전 멈춤, 사용자 허락 대기)
- **확정 방법(사용자 10/12 밤 직접 보여 줌):** 스마트 메시 4면 → 흰 모델 고름 → 왼쪽 메뉴 '텍스처' → **첫 칸(그림 한 장 탭)에 앞면 2D 한 장 업로드** → 조명 제거 켬 → 8K → 텍스처 생성(30) → **PBR 생성(5) 한 번** → (Roblox에서 2D에 더 가깝게 재질 한 번 더). 가운데 칸(멀티뷰 탭)은 쓰지 않음. 물건 하나 = 135점.
- 동상 `Halo_Statue` 흰 모델 D = f4fcec0d(방패 별 4갈래), 분수 `Town_Halo_Fountain3` 흰 모델 D = 16be0d85(기둥이 2D보다 45° 돌아감 → 배치 yaw +45). 시트 `art/review/blender/halo_statue_tex_compare_1012.jpg`, `town_fountain3_tex_compare_1012.jpg`.
- 내려받은 뒤 고칠 것: 분수 큰 그릇 안쪽 벽 주황·갈색 + 기둥 둘레 물 얼룩 → 색만 흰 대리석/하늘색; 동상 받침대 오른쪽 아래 어두운 틈.
- Tripo 잔액 12,840(오늘 13,230에서 390).
- **조작 요령:** 앱 창이 숨겨지면 화면 캡처가 잘림 → 최종 검수에 "창 보이게". Tripo 화면에서 좌표 클릭·드래그 금지(엉뚱한 버튼 맞음). 버튼은 요소 확인 뒤 JS, 3D 시점은 canvas에 JS PointerEvent 드래그·WheelEvent. 사용자가 창에서 같이 누르는 중이면 손 뗌.

## 10/12 저녁 정리 (사용자 "모든 세션 다 여기까지만 하고 정리해줘")
- **새 3D 방법 (SPEC A23-150)**: 그림자 없는 3D 렌더 2D **4면**(앞·왼·오른·뒤) → Tripo 웹 **스마트 메시**(4면 입력, 흰 모델 4개 = 100점) → 가장 잘 나온 흰 모델(사람은 **얼굴 빈 것**) → **왼쪽 메뉴 '텍스처'**(붙은 그림 그대로) **'조명 없이' 체크** → **8K**(30점) → 최소 Blender(A23-147) → records.json → 이미지 생성 4가 Roblox에. 물건 하나 = **130점**. 바깥선 없음.
- **Tripo 잔액 13,230점**(25k 계정, 앱 안 브라우저에 로그인돼 있음). **130점 아래가 되면 사용자에게 바로 알림**(다음 하나를 못 만듦 → 사용자가 계정 바꿈).
- **MailBoy = 사람이라 맨 마지막**(사용자 "인물은 맨 마지막에"). 새 4면 `art/out/s2/noshadow/npc/NPC_HaloMailBoy_{front,back,left,right}_ns.png` 준비됨(그림자 없음·단정 확인), 아직 생성 안 함.
- **남길 파일**: `art/models/tripo/web/NPC_HaloMailBoy_SM_tex8k_src.glb`(앞면 한 장으로 만든 시험 판, 기록 `NPC_HaloMailBoy_web_sm_tex8k`, 시트 `art/review/blender/mailboy_sm_tex8k_1012.jpg`) — 새 MailBoy 4면 판이 통과할 때까지 비교용으로 둠, 그다음 지움.
- **다음**: 최종 검수가 통과시켜 보내는 **빛 마을 물건** 4면 묶음부터(순서 `docs/review/noshadow_redo_2026-10-12.md`). 새 Tripo 생성은 묶음이 올 때까지 시작하지 않음.

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
