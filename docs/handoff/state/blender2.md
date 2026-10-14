# Blender 손보기 2 — 상태 (2026-10-14 09:45)

## 지금 (10/14 09:45)
- **새 규칙(사용자 10/14 "블렌더 작업은 코덱스한테 시켜봐"):** Blender 일(assemble_parts.py·axis_fit_bar.py·크기·피벗·방향)은 내가 직접 안 돌리고 Codex CLI(`codex exec -C <Game> -s workspace-write --skip-git-repo-check -`, exe = tools/codex_image.py codex_exe())에 시킨다. 못 하면 보고하고 멈춤.
- **Codex 첫 시험 = 됨:** 지시문 `build/codex_jobs/balustrade_codex_test/task.md` → assemble_parts.py(layout_nojoin.json) → `build/tripo_parts/HaloVar4_Balustrade_C_tripo_codex.glb` + final_gate 렌더. 기존 `_tripo.glb`와 물체 13·삼각형 103,648·치수 2.058×1.192×0.77·파일 크기 같음, 앞/알베도/3/4 렌더 픽셀 차이 0(내가 PIL로 확인). 4분 45초, Codex 토큰 77,646(gpt-6.1-sol, 한도 메시지 없음). 지시문은 짧게: Codex가 AGENTS.md 등 문서를 읽느라 토큰을 씀.
- 다음: 최종 검수 '전달함, 시작' 뒤 Chrome(Tripo) 큐 — JuiceMan a94e810f·MailBoy 2065ea15·OldSailor 4958667f 파일만 → NEW_WhiteRock_a·b·c(12000) → NEW_ArmoryBarrel(8000) → 단순 14 → 분수 부품 → 나무 부품. 설정 = HD 탭, 4K('55'), 조명 제거, PBR, 삼각형.


Tripo 계정 2 · 사용자 Chrome(Claude Chrome 확장) · 역할 파일 `role_prompts/16_blender2.md`. 흰 모델 고르기·PBR 첫 판정 = '디자인 검수', 최종 = '최종 검수'(세션 id는 list_sessions).

## 끝난 것 (10/14)
- **HaloVar4_Baluster(난간 기둥 부품, A23-172 Tripo 비교 1개, 125점):** 스마트 메시 흰 모델 d2cb7d72 · db407464 · **a7a73124(고름)** · 6a4879ed → 디자인 검수가 Tripo에서 직접 보고 고름 + 나와 합의 → 텍스처 멀티뷰 4면·조명 제거·4K 29c5640c(20) → PBR 8fc77956(5).
  - 원본 `art/models/tripo/web/HaloVar4_Baluster_p_SM_texMV4k_pbr_src.fbx`(5.9 MB, 디스크만). 흰 모델 FBX `art/models/tripo/wm2_1014/HaloVar4_Baluster/<id8>.fbx`(디스크만). 시트 `art/review/design/pbr_gate_20261014/HaloVar4_Baluster_p_SM_texMV4k_pbr_src.jpg`. records.json 키 `HaloVar4_Baluster_p_web2_sm_texMV4k_pbr` (push ee97ce5).
  - 잔액 21,365 → 21,130(내 것 125; 그 사이 HD 생성 55×2 — 093f98de는 사용자 직접 시험으로 확인, records `USER_HD_test_093f98de_web2`).
  - 메시지 엇갈림: 디자인 검수가 나중에 고름을 6a4879ed로 바꿈(a7a73124 열린 모서리 376·조각 5 = 비침 위험). 그땐 a7a73124 텍스처·PBR이 이미 끝남 → 최종 검수 10/14: a7a73124 그대로 PBR 판정(갓 밑 100% 크롭), 비침이 보이면 그때 6a4879ed 텍스처·PBR(25) 승인. **6a4879ed는 안 누름.**

## 기다리는 것
- (10/14) 디자인 검수 PBR 첫 판정 **통과**(시트 art/review/design/pbr_gate_1014_dr/, 갓 밑·받침 고리 비침 0, 금 진함은 ⑤). 6a4879ed 다시 안 함. **최종 검수도 통과(최종 통과).** 비교용이라 Blender 크기·피벗·방향은 보류 — 엔진 나눔 결정 뒤 최종 검수가 지시. 오늘 할 일 없음.
1. Baluster PBR 판정: 디자인 검수 → 최종 검수(최종 검수가 Meshy 판 옆 시트로 사용자에게). 둘 다 통과 → Blender **크기·피벗·방향만**: `blender --background --factory-startup --python art/models/tripo/touchup/Halo_Statue/build_glb.py -- <fbx> art/models/tripo/touchup/HaloVar4_Baluster_p/HaloVar4_Baluster_p_TU.glb`(`--basecolor` 없음) → 앞 렌더로 확인 → records에 final 줄. 떨어지면 ②: 다른 흰 모델(db407464가 다음 후보) → 텍스처 → PBR(25, 최종 검수 OK 뒤).
2. 다음 물건은 최종 검수가 개수·점수를 사용자에게 보인 뒤 줌.

## 진행 (10/14 낮, 빛 마을 HD 묶음 1~3 — 목록 docs/review/halo_tripo_hd_list_2026-10-14.md)
- 최종 검수 지시: GLB만(FBX 없음 OK) · 멀티뷰엔 'AI 완성' 없음 = 그대로 · **텍스처 4K = 55점**(8K 아님) · 폴리곤: 사람 20000, **둥근 것 있는 부품 12000**, 납작·네모 부품 8000. Blender 크기·피벗 안 함(최종 검수가 assemble_parts.py로 합침).
- 원본 HD GLB 앞 = **+X** (pbr_gate.py에 `<glb>:+x`). 결과 `art/models/tripo/web/<이름>_HD_pbr_src.glb`, 시트 `art/review/design/pbr_gate_hd_1014/`, 작업 목록 scratchpad hd_jobs.txt, records 키 `<이름>_web2_hd`.
- 끝: 난간 4(CornerPost 최종 통과) + 사람 9(BakerGranny·BellElder·Bright·FlowerFarmer·FlowerGirl·Folk4·HerbHusband·HerbWife 판정 보냄). Tripo에서 도는 중: JuiceMan a94e810f · MailBoy 2065ea15 · OldSailor 4958667f. 남은 사람: PondAngler·PotionMerchant·SirGleam·StarScholar → 묶음 3(14).
- 14:xx Chrome 탭 그룹 사라짐 → 그 뒤 Claude in Chrome 확장 '연결 안 됨'(사용자가 Chrome 다시 열어야). 잔액 20,190(마지막 확인).
- **사람 = 사용자 최종(10/14):** 통짜 사람 생성 멈춤. 사람은 부품(머리·몸·소품) 2D를 이미지 생성 2가 따로 → 각각 HD 55(머리·몸 폴리곤 12000, 소품 8000) → Blender 합침. 스마트 메시 안 씀. 이미지 생성 2가 Bright로 시범 → 사용자 OK 뒤 최종 검수가 큐에 넣음. 만든 사람 HD는 파일만, records에 '통짜 HD, 사용자 방식 아님'. Rail·Base 두께 = 최종 검수가 Blender 축별 맞춤(다시 생성 안 함).
- **다음 큐(연결되면):** JuiceMan a94e810f·MailBoy 2065ea15·OldSailor 4958667f 파일만 받기 → NEW_WhiteRock_a·b·c(12000) → NEW_ArmoryBarrel(8000) (2D parts/<이름>_*_ns.png) → 단순 14 → 분수 부품 Town_Halo_Fountain3_Basin(12000)·_MidTier(12000)·_Top(8000) → 나무 부품 HaloVar3_TreePlanter(8000)·HaloVar3_TreeFruit(4000)·HaloVar3_RoundTree_E/F/G_Trunk(8000)·_E/F/G_Canopy(12000) (모두 parts/, HD 4K 55). 단순 14 = (HD 55; 이름: HaloSign_SignBakery/SignFlower/SignPotion, HaloFlagpole_1, HaloReasonHQ_GuardPost, HaloChunk_* = noshadow/chunks/).

## 지금 방식 (SPEC A23-174, 사용자 10/14 낮, 최종 검수 전달) — 다음 물건부터
- **지금은 대기.** 다음 물건은 최종 검수가 목록·점수를 사용자에게 보인 뒤 보냄.
- **A23-175 (사용자 "Tripo HD!"):** 부품도 큰 것도 전부 Tripo HD(65점). Meshy는 대체용으로만. 최종 검수가 빛 마을 목록·점수 뽑는 중 → 사용자 '가' 뒤 목록 옴.
- Tripo 생성 = **'HD 모델' 탭 한 번에**: 멀티뷰 4면, 울트라 메시·AI 완성·텍스처 8K·조명 제거·PBR 켬, 삼각형, **폴리곤 수 20000(작은 부품 8000)**, **65점/개**.
- 스마트 메시·흰 모델 4개 고르기·따로 텍스처(20)/PBR(5) **없음**. 위 '할 일 1'의 ② 되돌리기(다른 흰 모델 → 텍스처 → PBR)도 이 방식으로 바뀜.
- 설정은 계정에 자동 저장(사용자와 같이 씀) → **폴리곤 수 말고는 바꾸지 않음**. 누르기 전 버튼 글자 '65'·폴리곤 수 확인, 앞뒤 잔액 비교.
- 디자인 검수는 결과 **PBR 판정만** 함 → 최종 검수.
- (지난 방식, 10/14 아침: HD + 텍스처 끔 15/30점 → 따로 텍스처·PBR = 더는 안 씀.)

## 요령 (Chrome)
- 시작: `tabs_context_mcp {createIfEmpty:true}`(이 세션 그룹 없으면 새 창) → navigate `https://studio.tripo3d.ai/ko/workspace/generate`. 탭 열기 전 최종 검수에 "Blender 손보기 2 / 무엇 / 몇 초" → '전달함, 시작'. 로그인 화면이면 멈추고 최종 검수(비밀번호 금지).
- 탭이 hidden이어도 JS·생성·내려받기 됐음(10/14). 기다리기는 `window.__sl(ms)`(MessageChannel 잠) — 정의는 매 새 페이지마다 다시.
- 페이지 이동은 `__vue_app__.config.globalProperties.$router.push(...)`. store = `$pinia.state.value`: 잔액 `['feature-user'].payment.wallet.total_credit`, 생성 `['workspace-generate-store']`(tab low_poly = 스마트 메시, high_detail = HD; multiViewImages), 텍스처 `['workspace-texture-store']`(textureTab multiViewGenerate, delight, textureMultiViewImages — 스마트 메시 4면이 미리 들어 있고 audit 값은 null), 현재 `['feature-workspace'].current.latest.model_url`.
- 그림 넣기: 페이지에 `input#hhStage`(aria-label hhStage, multiple) 만들고 `find "file input labelled hhStage"` → `file_upload`(4장, 10 MB 아래) → DataTransfer로 칸에(앞 ← front, 왼쪽 ← _right, 오른쪽 ← _left, 뒷면 ← back; 새 파일 이름).
- 점수 버튼: 경로·projectId·탭·설정·버튼 글자(HD '65'(옛: '생성 100', '텍스처 생성 20', 'PBR 생성 5'))를 확인한 뒤에만 JS click, 앞뒤 잔액 비교. 텍스처 = 왼쪽 메뉴 '텍스처'(left<200), PBR = 왼쪽 메뉴 'PBR'.
- 형제 4개 = `api.tripo3d.ai/v2/studio/assets/v2?asset_type=mine&locale=ko&offset=0&size=8&type=all`(credentials include) 맨 위 4개.
- 파일 받기(브라우저 내려받기·Downloads 금지): scratchpad `recv2.py <outdir> <N>`(127.0.0.1:8765, POST /<이름>) 백그라운드로 먼저 띄우고, 페이지에서 `fetch(model_url)` → blob → POST. JS 결과에 서명 주소는 '[BLOCKED]'로 가려져 그대로 못 받음. 수신기가 늦게 뜨면 'Failed to fetch' → blob을 window에 두고 다시 POST.
- 흰 모델 의견: `tools/white_model_sheet.py`(점토 8방향+위) + 열린 모서리·조각 수 셈(Blender bmesh). PBR 시트: `tools/design_review/pbr_gate.py` → `pbr_gate_sheet.py`.
- 디자인 검수가 '지금 내가 봄' 보내면 내 탭에서 아무것도 안 돌리고 '쉼', '끝' 오면 다시.
