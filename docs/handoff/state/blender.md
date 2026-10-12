# Blender 손보기 — 상태 (2026-10-12)

## 10/13 새벽 — 진행판 (보고처 = 디자인 검수 local_2137d284…, 점수 승인도)
- 순서: 4면 → 스마트 메시(100) → 흰 모델 id를 디자인 검수에(Tripo에서 직접 봄) → 나도 받아서 봄, 다르면 상의 → 텍스처 첫 칸 앞면 한 장+조명 제거+8K(30) → 디자인 검수 확인 → (고칠 곳은 Tripo 편집/매직 브러시, 창 보여야 함) → PBR 한 번(5) → 내려받기 → Blender 크기·피벗·방향만.
- 동상 B 1a0812be·분수 C cd70436c: 텍스처 끝, 매직 브러시 3곳 대기(창 숨김) → 그 뒤 PBR. Daisy c9df2ff9·Rose 9e0487cc도 매직 브러시 대기. Lavender·Tulip·Sunflower PBR 돌림.
- 흰 모델 디자인 검수 답 대기: DoorSingle·ConeTree(내 의견 나무 4개 다 별로 → 다시 뽑기), LampArm·CastleWingL·DomeRibbed·DoorDouble·WindowBoxA·BenchA·BenchC·CastleRose. CastleWingR = WingL 완성판 Blender 좌우 뒤집기(메시에 굽기·노멀·UV 그대로).
- 잔액 10,075 (10/13 새벽). PBR 끝·받음(디스크): Lavender·Tulip·Sunflower → art/models/tripo/web/HaloFlowerPotHQ_<n>_SM_tex8k_pbr_src.fbx. PBR 돌림: DoorSingle d61f68e6. 텍스처 끝·PBR OK 대기: 묶음 2·3 8종(LampArm 6895c425, CastleWingL 10bf8543, DomeRibbed 2f0b12f2, DoorDouble d28f2316, WindowBoxA 82c8a278, BenchA bbf6251c, BenchC f12d3f90, CastleRose e51189a5). 텍스처 돌림: GateLeaf 2bc07ecc, DomeOnion 414b871a. 흰 모델 고르기 대기: ConeTree(새)·DomeOctagon·DomeBall·FlowerCart·BenchB.
- 페이지 localStorage: hhTexFn(텍스처 함수), hhSetFn/hhGoFn(스마트 메시 넣기/누르기), hhIdx3~7 + Cache 'hh' /hh-bundle3~7.
- **10/13 오전 갱신 (잔액 9,385):** 9종 PBR 끝·받음(touchup/<id>/<id>_TU.glb + WingR 뒤집기) → 디자인 검수 금속·WingR OK 대기 후 이미지 생성 3에 넘김. GateLeaf·DomeOnion 텍스처 끝 → PBR OK 대기. 묶음 5·6 텍스처 끝(ConeTree 2bbbd641, DomeOctagon f9e91fe2, DomeBall 66894770, FlowerCart af2e2b5f(화분 작음 — 모양), BenchB b8de1d3c) → PBR OK 대기. 흰 모델 고르기 대기: DomeOnionSlim·BreadStand·FruitStall·DomeBrick, JuiceParasol(내 의견 6ec4d75d; 46c0419e 빈 상자, 52b68046 뒤 막힘, 89bac495 지붕 처짐). Greenhouse 4면 있음 — 통과 여부 물음.
- **요령:** 브라우저 호출은 전부 tabId "seed"(디자인 검수가 같은 창에 자기 탭을 엶). 32장 같은 많은 그림은 한 파일(bundle)로 묶어 Adobe에 한 번 올리고 페이지 Cache API('hh')에 넣어 slice로 칸에 넣음. 에셋 목록 20개 넘으면 `fetch('https://api.tripo3d.ai/v2/studio/assets/v2?asset_type=mine&locale=ko&offset=20&size=40&type=all',{credentials:'include'})` → data.projects(id·model_url). 점수 버튼은 경로 id·상태 확인 후 JS click, 앞뒤 잔액 비교.

## 10/12 밤 늦게 — 바뀐 순서(사용자) + 대기 중
- 흰 모델 4개는 **디자인 검수가 Tripo에서 직접 보고 고름**(시트 보내지 않음). 나도 따로 보고, 다르면 이유 말하고 상의.
- 고장은 Blender가 아니라 Tripo 안에서(더 나은 흰 모델/스마트 메시 수정/다시 뽑기). PBR은 맨 끝 한 번. Blender는 크기·피벗·방향만.
- 동상·분수: 앞서 Blender로 색 고친 판(touchup/*_TU*)·다시 올린 분수(2451f3d9, PBR 5 나감)는 안 씀. 디자인 검수 답 기다림(동상 D는 받침대 옆면 찢김 — 사용자 지적).
- 꽃 화분 5종 흰 모델 생성 끝(각 100): Daisy c9df2ff9…, Lavender 3d8a7ade…, Rose aa0225fb…, Sunflower 5f8780fb…, Tulip f75480d2… (형제 id는 디자인 검수에 보낸 메시지). 잔액 12,335.

## 10/12 밤 — 빛 마을 동상·분수 (끝: 받음 + 최소 손보기, push 7035c69)
- **확정 방법(사용자 10/12 밤 직접 보여 줌):** 스마트 메시 4면 → 흰 모델 고름 → 왼쪽 메뉴 '텍스처' → **첫 칸(그림 한 장 탭)에 앞면 2D 한 장 업로드** → 조명 제거 켬 → 8K → 텍스처 생성(30) → **PBR 생성(5) 한 번** → (Roblox에서 2D에 더 가깝게 재질 한 번 더). 가운데 칸(멀티뷰 탭)은 쓰지 않음. 물건 하나 = 135점.
- 동상 `Halo_Statue` 흰 모델 D = f4fcec0d(방패 별 4갈래), 분수 `Town_Halo_Fountain3` 흰 모델 D = 16be0d85(기둥이 2D보다 45° 돌아감 → 배치 yaw +45). 시트 `art/review/blender/halo_statue_tex_compare_1012.jpg`, `town_fountain3_tex_compare_1012.jpg`.
- 내려받은 뒤 고칠 것: 분수 큰 그릇 안쪽 벽 주황·갈색 + 기둥 둘레 물 얼룩 → 색만 흰 대리석/하늘색; 동상 받침대 오른쪽 아래 어두운 틈.
- Tripo 잔액 12,840(오늘 13,230에서 390).
- **내려받기는 이제 묻지 않음**(사용자 10/12 22:05). 받는 법: 페이지 `$pinia…['feature-workspace'].current.latest.model_url`(마지막 판 FBX, 8K 색 + PBR 맵) → curl. 손본 판 `art/models/tripo/touchup/<id>/<id>_TU.glb`(디스크만), 스크립트(uvmask·extract_fbx·build_glb·render_views·fix_*) 같은 폴더에.
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
