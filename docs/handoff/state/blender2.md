# Blender 손보기 2 — 상태 (2026-10-13 오후)

Tripo 계정 2(사용자 Chrome, Claude Chrome 확장) · 빛 마을만 · 흰 모델 고르기·PBR 첫 검수 = **디자인 검수 2**(local_b0cabbea) → 최종 검수(local_8166f268). 넘기는 곳 = 이미지 생성 3(local_d54578c7).

## ⛔ 지금 멈춤 (10/13 저녁, 최종 검수 전달)
- **Tripo 점수 쓰는 버튼(스마트 메시·텍스처·PBR) 전부 멈춤** — 사용자가 점수 쓰는 것에 화남. 사용자가 다시 OK할 때까지(최종 검수가 전함) 아무것도 누르지 않음. 파일 정리·기록만.
- 계정 2 사용: 25,500 → 22,075 (10/13 하루 3,425점).

## 정해진 것 (10/13)
- **텍스처 = 왼쪽 '텍스처'를 열면 나오는 기본 탭(가운데 멀티뷰)** — 스마트 메시 때 넣은 4면이 자동으로 들어 있음, 따로 올리지 않음. 기본값이 조명 제거 꺼짐·8K라 **조명 제거 켜고 4K(20점)로 바꿔서** 누름(사용자 10/13 오후 "멀티뷰로 해줘 … 4k, 조명 제거 체크", SPEC A23-158). 앞면 한 장(첫 칸) 방식은 그만. 이미 앞면 한 장으로 만든 것을 다시 할지는 최종 검수가 Bal_C 멀티뷰 결과로 정함.
- 계정 2(premium)는 8K가 체험 1번뿐(썼음) → 4K. 물건 하나 = 스마트 메시 100 + 4K 20 + PBR 5 = 125점.
- 디자인 검수 2가 흰 모델 4개를 Tripo 화면에서 직접 돌려 보고 하나 고름 → **나와 메시지로 의논해 합의한 뒤에만** 텍스처(사용자 지시, 최종 검수 10/13 저녁). id 4개 + FBX 경로 보내고, '지금 내가 봄' 오면 내 Tripo 탭 쉬고 **'쉼'이라고 답함**(탭 둘이 같이 돌면 멈춤), '끝' 오면 다시.
- 계정 1과 겹치지 않게: 새 일은 최종 검수/디자인 검수 2가 준 것만.
- 잔액 22,325 (10/13 오후). 스마트 메시 처음 2번은 잔액이 안 줄었음(records `_web2_account_note_1013`).

## 끝난 것
- 최종 통과 → TU.glb(크기·피벗·방향만, 디스크만) → 이미지 생성 3에 넘김(24종): FlowerCart_Bouquet, Balustrade_E·F·A·B·D, NEW_WallLamp, NEW_Hedge, Planter_D, NEW_FlowerBush(7cafd99b), NEW_BreadBasket, NEW_CafeTable, HaloSign_SignJuice, NEW_BellFrame, HaloFlagpole_1·2·3, HaloReasonHQ_Clothesline·RackShieldSword·Scarecrow·VegGarden·Woodpile·GuardPost·PotionCrate. ⑤ 메모 `docs/review/pbr_final_2026-10-13.md`.
- 예비(안 씀): 간판 Bakery·Flower 계정 2 흰 모델, Juice 나머지, Planter_D 8K 판(`_SM_tex8k_src.fbx`), 옛 Bal_C 531c8172(`_SM_tex4k_pbr_src.fbx`).

## 남은 일
1. HaloVar4_Balustrade_C cd1fd3e2(멀티뷰 텍스처, 사용자가 누름) PBR → `art/models/tripo/web/HaloVar4_Balustrade_C_SM_texMV4k_pbr_src.fbx` → 디자인 검수 2·최종 검수 판정 대기 → 통과면 TU.
2. 새 큐(최종 검수/디자인 검수 2가 줌; 이미지 생성 2가 그릴 것) → 스마트 메시 → 디자인 검수 2 고름 → 멀티뷰 텍스처 → PBR.

## 요령
- **Chrome 창이 화면에 보여야 Tripo가 돎**(다른 창에 덮이면 hidden → 스크립트 45초 멈춤). 사용자가 Chrome을 화면 오른쪽 절반에 둠. 멈추면 최종 검수에 한 줄; 창 옮기기·앞으로 가져오기는 최종 검수 '전달함, 시작' 없이는 안 함.
- 숨은 탭에선 setTimeout이 느려짐 → 매 호출 `eval(localStorage.getItem('hh2Def'))` 뒤 `window.__sl(ms)` 사용. JS 한 번 45초 넘으면 끊김(누르기가 늦게 실행될 수 있음 — 끊긴 뒤엔 반드시 목록으로 확인, 10/13 Juice가 이렇게 눌림).
- 페이지 함수(localStorage): `hh2Def`(hhPrep·hhFill·hhGo 스마트 메시; hhPrep 뒤 store tab이 `low_poly`인지 확인), `hh2TexMV`(멀티뷰 텍스처: `(id, go)` → 탭·4칸·조명 제거·4K·'텍스처 생성 20' 확인 뒤 누름), `hh2PbrX`(PBR: 누른 뒤 8초 안에 잔액/버튼 변화 없으면 한 번 더), `hh2TexDef`(옛 앞면 한 장 — 쓰지 않음).
- 그림 넣기: 페이지에 `input#hhStage`(aria-label hhStage) → `find "file input labelled hhStage"` → `file_upload`(4장 10 MB 아래) → hhFill이 DataTransfer로 칸에(칸 순서 0 앞 · 1 왼쪽 ← `_right` · 2 오른쪽 ← `_left` · 3 뒤). Adobe 업로드는 이 세션 권한에서 막힘.
- 결과 FBX: 페이지에서 model_url을 `이름 날짜 uuid 파일 만료 서명` 줄로 → `http://127.0.0.1:8765`(scratchpad recv.py, `timeout N py recv.py <out>` 백그라운드; **한 번에 하나만** 띄울 것 — 겹치면 앞 것이 받음) → `py tools/design_review/tripo_dl.py <lines> <dir>`. 흰 모델 FBX `art/models/tripo/wm2_1013/<이름>/<id8>.fbx`.
- 같은 생성의 형제 4개 = 에셋 목록(최신순)에서 4개씩 연속; URL id가 그 묶음 안에 있는지 확인.
- TU: `blender --background --factory-startup --python art/models/tripo/touchup/Halo_Statue/build_glb.py -- <fbx> touchup/<이름>/<이름>_TU.glb`(`--basecolor` 없음) → scratchpad `front_glb.py`로 -Y 앞 렌더해 2D 앞면과 같은지 확인.
