# 이미지 생성 2 상태 (2026-10-06)

규칙·할 일 순서: `docs/design/image_gen2_session_handoff_2026-10-06.md`. 크레딧: 지금까지 0(Firefly GPT Image 2.5 Sunburst, 중간만).

## 브라우저
- 내 Firefly 탭은 내장 브라우저 **tabId "tab-1"**. "seed"는 이미지 생성 1의 탭이라 절대 건드리지 않는다(11:27~11:40 KST에 실수로 같이 쓴 적 있음, 양쪽 결과물 이상 없음 확인).
- tab-1 JS 함수는 `window.__s2_*` 접두어만 쓴다: `__s2_run(queue)`(항목 `{tag, a: 비율 라벨, t: 문구}`, 진행 원·pending이 사라진 뒤 누름), `__s2_Q`(대기열, 돌면서 push 가능), `__s2_log`, `__s2_stop=true`(멈춤).
- 비율 라벨: '정사각형 (1:1)', '와이드 (3:2)', '긴 (2:3)'. 모델·품질은 탭을 새로 열 때마다 확인(Sunburst = value `gpt-image-2.5-prism`, 품질 `medium`).
- 다운로드: `asset_search`(GenAIAsset, createDate desc) → 이름 첫머리 + 시간으로 내 것 찾기 → `asset_get_presigned_urls` → `curl -sL` → `art/out/s2/<Key>_<안>_src.png`.

## 끝난 것 (모두 검수 OK, 이미지 개발에 파일·키 전달)
- 묶음 2 진영 화면 9장 — 5d16034, `art/review/s2/b2_faction_sheet.png` (글자 칸 분수 = approved.json `layout`).
- 묶음 4·5 공통 창·HUD 14 + 아이콘 4 — 7a7d26e, `art/review/s2/b45_common_ui_sheet.png` (9조각 = `slice`).
- 묶음 7 가방 등급 칸 6(어두운 안쪽, A23-32) + 글리프 7 — f03d940, `art/review/s2/b7_slots_glyphs_sheet.png`. SlotRare는 크림 마스터를 같은 키로 대체(옛 기록 `SlotRare_CreamMaster`).
- 묶음 8·9 아이콘 8 + 퀘스트 마커 2(A23-36, IconQuestMarker/Arrow) — 7b4fe91, `art/review/s2/b89_items_marker_sheet.png`.
- 이미 끝나 있어 다시 안 그린 것: 주문서(IconScrollEnh/Move + Band), 젤리, 사탕, 아기 슬라임, 특성 아이콘 묶음 3.
- 취소: A23-35 그림 글자(사용자 정정 — 모든 글자는 TextLabel). make_title·글꼴 4개 지움.

## 진행 중 (tab-1 대기열 `__s2_Q3`)
- 묶음 14 Q 스킬: 전사·마법사 고름(art/ui/Skill_Warrior_Q·Skill_Mage_Q, 커밋 전), 궁수는 '진짜 화살'로 다시 뽑는 중.
- 묶음 10 직업 그림 8(빛 전사 마스터는 b1에 있음, 사용자 확인 대기) — 사람 그림: 한 장씩 단정함 확인 → 사용자에게 먼저.
- 11a 안내자 초상 3, 묶음 12·13 추가 HUD·창 20.

## 작업 도구 (scratchpad, 공용 도구는 안 고침)
- `cut_keep.py`(비율 유지 누끼, tools/cutout_flat의 cutout·edge_fix 사용), `cut_icon.py`(정사각 아이콘 + 떨어진 조각 제거 `--keep-r`), `measure_card.py`(카드 글자 칸 측정), `zoom4.py`(4배 확대 검사). 필요하면 이미지 생성 세션에 공용 도구로 넣어 달라고 부탁.
- 안 고른 원본(`art/out/s2/*_src.png` 중 커밋 안 된 것)은 로컬에만 둔다.
