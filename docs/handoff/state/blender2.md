# Blender 손보기 2 — 상태 (2026-10-14 아침)

Tripo 계정 2 · 사용자 Chrome(Claude Chrome 확장) · 역할 파일 `role_prompts/16_blender2.md`. 흰 모델 고르기·PBR 첫 판정 = '디자인 검수', 최종 = '최종 검수'(세션 id는 list_sessions).

## 끝난 것 (10/14)
- **HaloVar4_Baluster(난간 기둥 부품, A23-172 Tripo 비교 1개, 125점):** 스마트 메시 흰 모델 d2cb7d72 · db407464 · **a7a73124(고름)** · 6a4879ed → 디자인 검수가 Tripo에서 직접 보고 고름 + 나와 합의 → 텍스처 멀티뷰 4면·조명 제거·4K 29c5640c(20) → PBR 8fc77956(5).
  - 원본 `art/models/tripo/web/HaloVar4_Baluster_p_SM_texMV4k_pbr_src.fbx`(5.9 MB, 디스크만). 흰 모델 FBX `art/models/tripo/wm2_1014/HaloVar4_Baluster/<id8>.fbx`(디스크만). 시트 `art/review/design/pbr_gate_20261014/HaloVar4_Baluster_p_SM_texMV4k_pbr_src.jpg`. records.json 키 `HaloVar4_Baluster_p_web2_sm_texMV4k_pbr` (push ee97ce5).
  - 잔액 21,365 → 21,130(내 것 125; 그 사이 남의 HD 생성 55×2, 093f98de 등 — 사용자 시험으로 보임, 최종 검수에 알림).

## 기다리는 것
1. Baluster PBR 판정: 디자인 검수 → 최종 검수(최종 검수가 Meshy 판 옆 시트로 사용자에게). 둘 다 통과 → Blender **크기·피벗·방향만**: `blender --background --factory-startup --python art/models/tripo/touchup/Halo_Statue/build_glb.py -- <fbx> art/models/tripo/touchup/HaloVar4_Baluster_p/HaloVar4_Baluster_p_TU.glb`(`--basecolor` 없음) → 앞 렌더로 확인 → records에 final 줄. 떨어지면 ②: 다른 흰 모델(db407464가 다음 후보) → 텍스처 → PBR(25, 최종 검수 OK 뒤).
2. 다음 물건은 최종 검수가 개수·점수를 사용자에게 보인 뒤 줌.

## 바뀐 방식 (사용자 10/14, 최종 검수 전달) — 다음 물건부터
- 흰 모델 = 스마트 메시(100) 대신 **일반 생성(이미지→3D) 'HD 모델' 탭 + 멀티뷰 4면 + '일반 설정 › 지오메트리 및 텍스처'에서 텍스처 끔**. 텍스처는 따로 멀티뷰 4K(20) → PBR(5) 그대로.
- 값(10/14 확인, 안 누름): 텍스처 켬 65 / 텍스처 끔 + 울트라 메시 켬 30 / 텍스처 끔 + 울트라 끔 15. HD는 한 번에 1개(4개 중 고르려면 4번). 몇 번 뽑을지·울트라 켤지는 최종 검수가 정함. 설정은 계정에 '자동 저장'(사용자와 같이 씀) → 바꾼 뒤 원래대로 되돌리기.

## 요령 (Chrome)
- 시작: `tabs_context_mcp {createIfEmpty:true}`(이 세션 그룹 없으면 새 창) → navigate `https://studio.tripo3d.ai/ko/workspace/generate`. 탭 열기 전 최종 검수에 "Blender 손보기 2 / 무엇 / 몇 초" → '전달함, 시작'. 로그인 화면이면 멈추고 최종 검수(비밀번호 금지).
- 탭이 hidden이어도 JS·생성·내려받기 됐음(10/14). 기다리기는 `window.__sl(ms)`(MessageChannel 잠) — 정의는 매 새 페이지마다 다시.
- 페이지 이동은 `__vue_app__.config.globalProperties.$router.push(...)`. store = `$pinia.state.value`: 잔액 `['feature-user'].payment.wallet.total_credit`, 생성 `['workspace-generate-store']`(tab low_poly = 스마트 메시, high_detail = HD; multiViewImages), 텍스처 `['workspace-texture-store']`(textureTab multiViewGenerate, delight, textureMultiViewImages — 스마트 메시 4면이 미리 들어 있고 audit 값은 null), 현재 `['feature-workspace'].current.latest.model_url`.
- 그림 넣기: 페이지에 `input#hhStage`(aria-label hhStage, multiple) 만들고 `find "file input labelled hhStage"` → `file_upload`(4장, 10 MB 아래) → DataTransfer로 칸에(앞 ← front, 왼쪽 ← _right, 오른쪽 ← _left, 뒷면 ← back; 새 파일 이름).
- 점수 버튼: 경로·projectId·탭·설정·버튼 글자('생성 100', '텍스처 생성 20', 'PBR 생성 5')를 확인한 뒤에만 JS click, 앞뒤 잔액 비교. 텍스처 = 왼쪽 메뉴 '텍스처'(left<200), PBR = 왼쪽 메뉴 'PBR'.
- 형제 4개 = `api.tripo3d.ai/v2/studio/assets/v2?asset_type=mine&locale=ko&offset=0&size=8&type=all`(credentials include) 맨 위 4개.
- 파일 받기(브라우저 내려받기·Downloads 금지): scratchpad `recv2.py <outdir> <N>`(127.0.0.1:8765, POST /<이름>) 백그라운드로 먼저 띄우고, 페이지에서 `fetch(model_url)` → blob → POST. JS 결과에 서명 주소는 '[BLOCKED]'로 가려져 그대로 못 받음. 수신기가 늦게 뜨면 'Failed to fetch' → blob을 window에 두고 다시 POST.
- 흰 모델 의견: `tools/white_model_sheet.py`(점토 8방향+위) + 열린 모서리·조각 수 셈(Blender bmesh). PBR 시트: `tools/design_review/pbr_gate.py` → `pbr_gate_sheet.py`.
- 디자인 검수가 '지금 내가 봄' 보내면 내 탭에서 아무것도 안 돌리고 '쉼', '끝' 오면 다시.
