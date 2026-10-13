# Firefly 결과를 PC로 받는 법 (이미지 생성 2, 2026-10-13, 최종 검수 승인)
**브라우저 다운로드·저장 창·Downloads 폴더·로컬 서버(127.0.0.1은 앱 브라우저가 막음)는 쓰지 않는다.** Adobe `asset_search`는 새 생성물을 못 찾는다(자동 저장이 아님).
Firefly 페이지는 결과를 사전서명 S3 주소(`pre-signed-firefly-prod.s3-accelerate.amazonaws.com/images/<id>?x-resource-length=<바이트>&X-Amz-…`, 24시간 유효)에서 가져온다. 그 주소를 모아 PC에서 `curl`로 받는다 = 데스크톱 변화 0.
1. 앱 브라우저 Firefly 탭(로그인 상태, `resize_window` 1440×900)에 `tools/firefly_autodl_helpers.js` 전체를 `javascript_exec`로 한 번 붙인다(새로고침하면 사라짐). 이 순간부터 `__s3`가 S3 주소를 모은다(**생성 전에 붙일 것** — 놓친 주소는 못 되찾음, 결과 blob만 `__all`에 남음).
2. 앞면 참조 그림은 Adobe MCP로 올려(`asset_initialize_file_upload` → curl PUT → `asset_finalize_file_upload`) 나온 `presignedAssetUrl`(at.adobe.com)을 `ref`에 쓴다. 항목 `[{k, ref, front, desc}]` → `__runItems(items)`(앞 → 뒤·왼·오른, 뒤 3장은 새 앞면 blob을 ref로). 한 장 약 50초, GPT Image 2.5 high(5크레딧). 로그 `__qLog`, 멈춤 `__stopList = true`.
3. 끝나면 `JSON.stringify(__urlMap())`(label → 주소, 크기로 짝지음)을 읽어 `map.json`으로 저장 → `py tools/ff_fetch.py map.json --out art/out/... --pattern "HaloChunk_{label}_ns.png"`.
4. 결과 PNG는 1024×1024(Codex 1254와 다름). 모든 파일 눈으로 확인. 옆면 고침은 `tools/_chunk_sidefix.py`.
