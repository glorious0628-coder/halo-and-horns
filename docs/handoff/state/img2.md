# 이미지 생성 2 — 인계 (2026-10-11 낮, 옛 세션 → 새 세션)
## 지금 상태 한 줄
빛 성 2차(F1~F4)는 **안 그림**(받았지만 인계 지시로 중단). 나머지 큐는 아래. 보고는 '모든 것 검수' 세션(id는 list_sessions로 찾기). **(검수 10/11 오후 갱신: 빛 성은 C2 확정·장식 4면 통과 (기록 11b, 승인 근거 재확인 필요) — 아래 큐 1은 끝난 옛 항목. 지금 큐는 조감 A3 2차 → 새 집 7채·무기고 2D → 4면 큐(등불 A~E → 화분·토피어리·나무 → 벤치 → 이유 소품 14 → 몬스터 → 무기), 최신 review_handoff §2·review_handoff_2026-10-11e §4·§5.)** **(검수 10/11 저녁 고침: 11c에서 무기 디자인이 큐 맨 앞 — 9종 × T1~T3 시트 Medium → 검수 고름 → 4면 High → Tripo. 그다음 위 큐. 실제 진행·후보 존재는 11d §4대로 먼저 확인.)**
## 끝낸 것 (전부 푸시됨, 시트 art/review/s2/)
- 스킬 Q·Z·X 아이콘 18개: `art/out/s2/skills_final/Skill_<Class>_<Q|Z|X>_<Halo|Horns>.png` — 이미지 개발이 올려 연결 끝(ae9be2a, aef108a).
- 빛 마을 '이유 소품' 14 + 꽃 화분 5 + 꽃 덤불 3 + 생울타리 2 = 24종 고급 앞면 → 이미지 생성 3에 전달(표 `docs/design/halo_reason_props_handoff_2026-10-10.md`). 이미지 생성 3의 대기 메시지 2건(표 다시 보기, 덤불 5)은 그쪽이 깨면 처리.
- 빛 성 1차(돔 있음, `art/out/s2/halo/castle/`)는 버림 예정. 1차-돔없음(성당 조사) 4장 `art/out/s2/halo/castle2/HaloCastleCath_{A,B,C,D}.png`, 시트 `halo_castle_cathedral_concepts.jpg` — 사용자 "사진처럼 현실적, 판타지 아님"이라 2차 요청. 확정본에서 십자가(A 박공·C 문루)는 빼고 별·후광·날개로, 장난감 느낌 더 세게(검수 메모).
- 새 구역(A23-119): 수정 동굴 숲 + 산호 해안 = 베타(숨긴 두 구역 자리), 사탕 골짜기·바람 협곡/열기구 고원 = 그다음 후보. 시안 세트(고급 12) `art/out/s2/zones_set/{crystal,coral}/`, 몬스터 시트 4장 `art/out/s2/zones_set/monsters/`(검수 선택 대기), 콘셉트들 `art/out/s2/zones_new/`.
## 다음 큐 (순서)
1. ~~**빛 성 2차 F1~F4 (Medium 4)**~~ (끝: C2 확정) — 옛 프롬프트 `docs/design/halo_castle_cathedral_directions_2026-10-11.md` 맨 아래 '2차' F1~F4 그대로(참조 이미지 없이 `__runNoRef`, 각 950자 미만). 확인: 돔 0·빛살 0·십자가 0·땅 높이 큰 문과 마당·장난감 그림체. 탑 꼭대기 100% 확대 확인 후 시트 → 검수. 뽑힌 1장은 옆·뒤·위(평면) 시안(같은 그림체) → 부품(본관·탑·성문·성벽).
2. 새 구역 몬스터: 마리별 **앞·뒤·좌·우 4면**(A23-122) → 이미지 생성 3(Tripo). 슬라임은 없다(A23-123): 수정 동굴 = 수정 도마뱀·빛 버섯·박쥐 B·골렘 B(+ 이야기 펫 수정 고슴도치), 산호 해안 = A(게·해파리·소라게). 4면 2D는 통과함 (기록 11b, 승인 근거 재확인 필요).
3. 빛 마을 조감 시안 1~2장 + 새로 생기는 건물 종류 2D 앞면(SPEC A23-121, 이미지 생성 1의 새 구역 지도가 나온 뒤; `docs/design/halo_restart_2026-10-11.md`).
4. 대기: 수정 동굴·산호 해안 나머지 부품 시안(검수 요청 시), 뿔 성(A23-112 대칭 콘셉트가 나온 뒤).
## Firefly / 도구 상태
- 내장 브라우저 탭 id `seed`, https://firefly.adobe.com/generate/image. **사용자가 Adobe 로그인 완료**(10/11). 새 턴마다 `mcp__Claude_Browser__resize_window` 1440x900 먼저(안 하면 레이아웃 깨짐). 페이지를 다시 열면 `tools/_firefly_helpers.js`를 javascript_exec에 붙여 넣어 도우미를 다시 심기. 한 번에 한 루프만(두 루프 = 중복 생성). JS 호출은 ≤40초(`__sleep(36000)`).
- 프롬프트 <1000자(넘으면 조용히 실패). 후보 = Medium(0), 확정 = High(5). 고른 후보를 High로 다시 그릴 땐 그 Adobe 생성 파일의 `previewUrl`(asset_get_presigned_urls)을 참조로 쓰면 모양 유지.
- 받기: `asset_search`(entityScope GenAIAsset, sortBy createDate, limit) → 시간순 매핑(생성시각 ≈ 클릭 로그 −수 초; 로그 시각은 UTC) → `asset_get_presigned_urls`(sourceType acp) → `py tools/_dl_urls.py <폴더> <접두사>`(폴더의 `urls.txt` = '이름 토큰' 줄). 참조 업로드: `asset_initialize_file_upload` → curl -L PUT → `asset_finalize_file_upload` → presignedAssetUrl(몇 시간 유효). 10/11 낮 Adobe 커넥터가 몇 분 서버 오류였음(재시도로 복구).
- 누끼: `tools/cutout_flat.py`(cutout tol40 soft10 holes + edge_fix) — 둥근 배지 아이콘은 이걸로 충분.
- 푸시: 공유 트리라 `py tools/push_paths.py -m "제목" <경로들>`(느리면 백그라운드로 돌리고 `HEAD`가 찍힐 때까지 기다림). `art/prompts` 같은 폴더 통째 푸시 주의(남이 고친 파일도 같이 올라감).
- 크레딧: 오늘 High 약 330장 이상 사용(페이지에서 잔액 못 읽음). 잔액은 검수에 따로 알린 적 없음 — 500 근처면 검수에 알림.
## 막힌 것
- 없음. (로그아웃되면 사용자가 브라우저 판에서 Adobe 로그인 — 내가 입력하면 안 됨; 창이 최소화돼 있으면 페이지가 안 그려짐.)
