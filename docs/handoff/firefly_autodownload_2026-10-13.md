# Firefly 결과를 PC로 받는 법 (이미지 생성 2, 2026-10-13)
Adobe `asset_search`가 새 생성물을 못 찾을 때(색인 지연)나 한꺼번에 많이 받을 때 쓴다. 앱 브라우저의 Firefly 탭(로그인된 상태, `resize_window` 1440×900)에서:
1. `tools/firefly_autodl_helpers.js` 전체를 `javascript_exec`로 한 번 붙여 넣는다(새로고침하면 사라짐). 앞면 참조 그림은 Adobe MCP로 올려(`asset_initialize_file_upload` → curl PUT → `asset_finalize_file_upload`) 나온 `presignedAssetUrl`(at.adobe.com)을 `ref`에 쓴다. localhost 서버는 막혀서 못 쓴다.
2. 항목 `[{k, ref, front, desc}]`을 만들어 `__runItems(items)`(앞 → 뒤·왼·오른, 뒤 3장은 새 앞면 blob을 ref로). 한 장 약 50초, 모델 GPT Image 2.5 high(5크레딧). 로그 `__qLog`, 멈춤 `__stopList = true`.
3. 결과는 `<a download>`로 `C:\Users\glori\Downloads\*.tmp`(랜덤 이름)에 저장된다. 같은 순서의 대상 경로 JSON을 만들어 `py tools/ff_watch.py targets.json`(백그라운드)로 돌리면 순서대로 옮겨 이름을 붙인다. **한 번에 한 세션만**(Downloads 공용, 파일 이름이 랜덤이라 섞임). 모든 파일은 눈으로 확인.
4. 첫 다운로드에서 데스크톱에 '저장' 창이 한 번 뜰 수 있음(최종 검수가 사람에게 누르게 함). 이후 자동.
5. 결과 PNG는 1024×1024(Codex 1254와 다름). 옆면 고침은 `tools/_chunk_sidefix.py`.
