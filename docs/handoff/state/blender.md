# Blender 손보기 — 상태 (2026-10-12 오후)

## 지금
- **MailBoy 끝(새 방식)**: 사용자와 같이 Tripo에서 다시 만듦 — 스마트 메시(앞면 2D 한 장, 코 없는 흰 모델) → 왼쪽 메뉴 '텍스처'(앞면 그림 자동 첨부, 조명 제거 OFF, 8K, 30점). 얼굴이 2D처럼 또렷. 파일 `art/models/tripo/web/NPC_HaloMailBoy_SM_tex8k_src.glb`(앞 = Blender -y, 바닥 가운데 피벗, 10,452면, 8192 색 맵), 기록 records.json `NPC_HaloMailBoy_web_sm_tex8k`, 시트 `art/review/blender/mailboy_sm_tex8k_1012.jpg` → 최종 검수 판정 대기.
- 사용자 10/12: "앞으로 이 방법으로 꽃이든 뭐든 건물이든 다 만들자" → 최종 검수에 전달(SPEC 정리 부탁). 2D 그림엔 그림자 넣지 말 것 → 이미지 생성 2·최종 검수에 전달. Tripo 잔액 130점 미만이면 사용자에게 바로 알림(계정 바꿈). 잔액 13,230(10/12 16:20).
- 최종 검수 새 순서(A23-148 바깥선 취소, A23-149 골격 먼저): ① PotFlowers_E 시험 ② 화분·덤불 14 ③ 무기 28 최소 손보기 ④ 밈 Donut·Twist ⑤ 소품 골격 + Tripo 조각. 위 새 Tripo 방식과 어떻게 합칠지 최종 검수 답 기다림.

## 실패해서 버린 것 (다시 하지 말 것)
- Blender로 Tripo 얼굴 면 펴기(평면 맞추기·라플라스·구멍 메우기·나누기): 접힌 선, 머리카락이 얼굴에 들어감. 얼굴 2D 투영 칠은 3D 조각된 눈·이 자리와 어긋나 빛 받으면 이가 두 동강.
- Tripo 매직 브러시를 합성 입력으로: 확대만 되고 화면 이동·생성 모드 붓은 안 먹힘. 사람이 직접 하거나 새 방식으로.

## 도구 (10/12)
- `tools/view_match_2d.py` — GLB를 2D 4면과 같은 틀로 찍기(`--front -y` = Tripo Studio 내보내기). 2D | 옛 | 새 시트에 씀.
- `tools/face_clean_bl.py` + `tools/face_clean_2d.py` — 얼굴만 떼어 평면 UV로 굽고 2D 기준으로 다시 그리기(실험, 위 이유로 지금은 안 씀).
- `tools/blender_view.py` — 2D | Tripo | 새 판을 Blender 창에 띄우는 보기 전용 스크립트. (`tools/blender_live.py` = 파일로 Blender 창을 조종하는 리스너, 로컬만, 올리지 않음.)
