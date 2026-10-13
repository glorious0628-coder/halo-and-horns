# Meshy API 길 (최종 검수 2026-10-13 밤) — 사용자가 MESHY_API_KEY를 .env에 넣음

도구: `py tools/meshy_api.py` (balance · mesh · retex · status · fetch). 키는 `.env`의 `MESHY_API_KEY`(출력·채팅·커밋 금지). 기록 `art/models/meshy/records.json`, 파일 `art/models/meshy/<이름>/`.

## 값 (docs.meshy.ai, 2026-10)
| 일 | 크레딧 |
|---|---|
| 4면 → 메시만(`multi-image-to-3d`, should_texture=false) | 20 |
| 4면 → 메시 + 2K/4K 텍스처(+PBR 포함, 추가 0) | 30 (8K 35) |
| 다시 입히기(`retexture`, 4면 `multiview_image_urls`, meshy-7, 4K) | 10 |
| geometry_resolution "2k"(더 고운 메시) | +5 |
- 계정: 월 3,000 + 영구 115 = **3,115**(10/13 밤 조회). 30/개 → **한 달 약 100개**. Tripo(125점/개, 남은 23,700점 ≈ 190개)와 같이 쓰면 7곳 150개는 넉넉.
- FAILED는 환불. 같은 계정 동시 작업 한도(Pro 10개). 입력은 jpg/png/webp ≤20 MB, 데이터 URI로 바로 보냄(업로드 서버 필요 없음, 브라우저 없음, 화면 없음).

## 다섯 단계(A23-154·159)에 맞추기
① 그림자 없는 2D 4면(그대로) → ② **메시만 20크레딧** → `thumbnail_urls`(앞·오른·뒤·왼) + GLB를 받아 **디자인 검수가 점토 렌더/Blender로 돌려 보고 통과**(Tripo처럼 4개 중 고르기가 아니라 1개 판정; 떨어지면 geometry 2k(+5)나 다른 4면으로 다시) → ③ **retexture 10크레딧**(같은 4면, 4K, PBR, 원래 UV) → ④ PBR 모델 디자인 검수 → 최종 검수(2D 나란히) → ⑤ Blender 크기·피벗·방향 → Roblox 재질. 합계 30/개(한 번에 `--texture --pbr`로 보내도 30; 흰 모델을 먼저 보려면 둘로 나눔).
- 사람(NPC)은 `--pose a-pose`.
- 매직 브러시·칠하기·다시 올리기 없음(그대로). 구멍·비침 = 떨어짐(그대로).

## 언제 쓰나
- A23-160: 돈 드는 생성은 사용자 "가" 뒤. 첫 시험 = 물건 1개(30크레딧) → Tripo 결과와 나란히 비교 시트 → 사용자 판단 → 10/20 뒤 뿔 마을부터 Meshy 또는 Tripo(품질로 정함).
- 명령 본보기: `py tools/meshy_api.py mesh NEW_Hedge --front …_front_ns.png --left …_left_ns.png --right …_right_ns.png --back …_back_ns.png --texture --pbr --res 4k --wait`
