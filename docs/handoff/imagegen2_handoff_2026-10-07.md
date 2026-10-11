# 이미지 생성 2 인계 — 2026-10-07 저녁 (계정 옮김, 주간 한도)

> 기록용(2026-10-09 검수): 10/07 계정 정리 기록이에요. 큐·잔액은 그날 것이고, 지금 할 일은 `docs/handoff/role_prompts/07_img2.md`예요.

다음 계정의 '이미지 생성 2'가 이 파일 하나로 이어 할 수 있게 적었다. 지난 기록: `docs/handoff/image_gen2_status_2026-10-07.md`(오전~오후 4), 역할 문서 `docs/design/image_gen2_session_handoff_2026-10-06.md`.

## 역할·규칙 (그대로)
- 자잘한 그림 전부(UI 부품·아이콘·아이템·무기·옷·NPC·안내자 그림·몬스터 콘셉트·작은 3D 소품 2D)를 Adobe Firefly(GPT Image 2.5 Sunburst)로 그리고 안을 고른다.
- **시안 = 중간(0크레딧), 고른 최종 = 전부 고급(5크레딧).** 시트마다 쓴 크레딧 + Firefly 남은 크레딧을 적는다.
- 고르기·허락은 **검수에게만** 보낸다(사용자에게 직접 묻지 않음). 사용자에게는 한국어로 짧게.
- 사람 그림은 어깨·몸통·다리 가림(얼굴·손만). 소품·건물에 얼굴 금지. 남의 그림(스톡 워터마크 사진 등)은 Firefly 참조로 올리지 않고 말로만 묘사.
- **git(공유 폴더): `git commit` 하지 말고 `py tools/push_paths.py -m "제목" <경로들>`**(AGENTS f27ca7e). 다른 세션의 `reset --keep`이 내 로컬 커밋을 지운 일이 있었음(81077c1 빈 커밋 사고).

## 오늘 끝난 것
| 일 | 결과 | 해시 |
|---|---|---|
| 고급 다시 그리기 26(게임에 들어간 중간 최종) | 25장 art/ui 같은 이름·캔버스 + approved.json, 이미지 개발이 올리고 Config 반영 | 4ceaabf → 5b76009 |
| 세계 지도 고급 + 얼굴 고침(+5) | 뿔 요새 탑 얼굴 느낌 없앰, 유적 돌 가면 → 왕관 메달, 해안선 차이 0.9px | 1d58f6c (업로드는 다음 이미지 개발) |
| 보상 팝업 부품 | 시안 18 → 검수 고름 → 고급 9 art/ui(RewardPanelHalo/Horns, RewardRibbonHalo/Horns, …Straight 2, RewardSlot, RewardGlow, RewardSparkle) | bdf4ab1 → 1d58f6c, 이미지 개발 큐 de9096b |
| 해골 유적 작은 소품 13 시안 | 검수 통과(돌무더기만 다시) | 70c5739 |
| 숲 모닥불 | 불 없는 C/D 취소 → 불 붙은 4안 → 검수 **B2** → 고급 1장 → 이미지 생성 1 Tripo | 143f131 → 이번 push |
| 도구 | `tools/img2/hq_fit.py`, `measure_slice.py`, `lum_alpha.py`, `cut_solid.py`(+`--min-piece`), `firefly_helpers.js` | ba2186e, 70c5739, 이번 push |

## 다음 큐 (순서대로)
1. **돌무더기 다시(중간 0):** `art/prompts/KIT_Ruins_Rubble_B.txt`에 "No flat slab with a raised border, only chunky rough stone blocks and broken rock pieces." 를 넣어 다시 → 시트 → 검수. (테두리 있는 넘어진 판석이 묘비처럼 보임.)
2. **유적 3D 후보 8개 고급(40크레딧, 검수 확정):** PillarA_B · PillarB_B · PillarFallen_B · StoneMarker_C · SpiritBowl_B · StoneLantern_B · SignPost_B · CrownPieces_B.
   - 참조 = 각 중간 원본 `art/out/kit/ruins/<이름>_src.png`(Firefly 자산 id 아래 표), 문구는 숲 고급처럼 "Same object as the attached reference image, cleaner and more detailed, keep its exact shape, colors and parts: …" + 유적 머리말(천 없는 _B 머리말) + "Bare stone only: no cloth".
   - 결과 `art/out/kit/ruins/<이름>_HQ_src.png`(회색 바탕 = Tripo 입력) + 누끼 `cut_solid.py` → 시트 → 이미지 생성 1 Tripo(HD 55).
3. **숲 E12·PvP 작은 UI 아이콘:** 목록이 문서에 없음 → 검수에게 무엇을 그릴지 먼저 물어보기.
4. **Firefly 남은 크레딧:** 창이 보일 때 새로고침해서 숫자를 검수에 알리기.

### 유적 중간 원본의 Firefly 자산 id (urn:aaid:sc:AP: 뒤)
PillarA_B 74318858-bb35-405b-bcbd-31515b8b68b8 · PillarB_B 08bf8d8a-ee3c-4ef3-90e9-e8515d5807c1 · PillarFallen_B b8ac8010-c3a9-4e8f-85a0-1e63dcfe298c · StoneMarker_C ef7db212-b74b-4b75-8519-c35620f62cd0 · SpiritBowl_B 57531ef7-576a-4207-b80d-4051a47c20a5 · StoneLantern_B 8699083e-df87-4525-b800-21f76c5da1c4 · SignPost_B 93a66ae1-09de-48ab-b0a9-0be5d18d3804 · CrownPieces_B 64d57873-4fc1-4882-a881-b9a71760756a · Rubble_B e35918bc-73b4-455c-8f59-b1830c132370.
`asset_get_presigned_urls`(sourceType acp)로 downloadUrl을 받아 페이지에서 참조로 올린다. 안 되면 로컬 파일을 `asset_initialize_file_upload` → `curl -L -X PUT` → `asset_finalize_file_upload`로 올려 쓴다.

## Firefly 잔액
- 고급 27장 그리기 전 표시 **9410/10000**(오전). 그 뒤 이 세션 고급: 고급 다시 27(135) + 보상 9·지도 1(50) + 모닥불 B2(5) = **190** → 지금 **9220 이하**(다른 세션 사용분은 빠짐). 창이 숨겨져 있어 새로고침을 못 했음.
- 오늘 이 세션 고급 합계: 숲 소품 8(40) + 190 = **230**.

## Firefly 쓰는 법 (요령)
- 내장 브라우저 탭에 Firefly(사용자 로그인). **창이 한 번은 보여야 함**(검수에게 사용자 Ctrl+Shift+B 부탁) → `resize_window 1440×900` → `tools/img2/firefly_helpers.js` 붙여 넣기 → 그 뒤엔 창을 숨겨도 계속 그림(한 장 30~60초). 숨김에서 새로고침 금지.
- 모델 GPT Image 2.5 Sunburst(`openai:firefly:colligo:gpt-image-2.5-prism`), 품질 `medium`/`high`, 비율 '와이드 (3:2)'·'정사각형 (1:1)'·'긴 (2:3)'. 문구 1000자 미만.
- 결과 받기: `asset_search`(GenAIAsset, createDate 내림차순, mediaType 이미지) → 문구 앞부분 + 내가 누른 시각 바로 뒤 순서로 짝짓기(이름 끝 숫자는 바뀜) → `asset_get_presigned_urls` downloadUrl → curl.
- 고급 다시 그리기(참조 1장 + "Redraw the attached reference image as the same game interface piece…")는 모양 겹침 0.94~1.00으로 잘 맞음. 다만 **중요한 세부가 빠질 수 있음**(로고 왕관 금 간 자국이 사라졌던 일) → 2배 확대로 꼭 비교.
- 고급이 끝나면 `__s2_pick('medium')`으로 되돌려 둔다.

## 주의할 점
- 공통 머리말의 색 단어가 물건에 번진다: 유적 머리말의 'faded purple cloth' → 돌마다 보라 천. 돌 소품은 천을 빼고 "Bare stone only: no cloth, no drapes.", 꽃·풀은 머리말을 따로.
- 연보라·회색 돌 그림자가 회색 바탕과 같아 누끼에 구멍·자국이 남 → `tools/img2/cut_solid.py`(틈을 원래 색으로 메우고 큰 진짜 틈만 투명). 떠 있는 불씨 방울 같은 작은 조각은 `--min-piece 0.0005`.
- 휜 리본은 늘리면 깨짐(크기 고정). 빛 휜 띠는 날개 때문에 글자 칸이 56%라 폰에서 긴 제목이 작아짐 → 이미지 개발에 숫자 전달함, 필요하면 곧은 띠.
- 9조각: 알약은 (끝 폭, H/2-1, W-끝 폭, H/2+1), 판은 모서리 장식이 모서리 칸 안(`measure_slice.py --blur 3 --tol 9`).
- 2D 시안 수정은 숲처럼: 둥근 머리 판 모양 돌은 묘비로 보임(돌 이정표 → 둥근 기둥 C), 테두리 판석도 묘비 느낌.
