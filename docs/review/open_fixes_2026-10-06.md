> **2026-10-06 오후 갱신(검수):** 이 목록은 오전 기준이다. 지금 열린 일·다음 순서·새 시작 프롬프트는 `docs/handoff/next_account_2026-10-06.md`, 검수 결과는 `docs/review/review_2026-10-06_backlog.md`(1·2차)를 본다. 3차 검수(294ae07 등)는 멈춰서 새 검수가 다시 돈다.

# 열린 수정 목록 (검수 세션, 2026-10-06 — 세션 교체 인계용)

메시지로 보낸 수정 지시를 한곳에 모았다. 새 세션은 각 세션의 `docs/handoff/*_status_2026-10-06.md`와 맞춰 보고, 끝난 것은 지운다.

## 게임성 개발 (1)
### A. 사용자 신고 "몬스터가 떠 있는 느낌이 어색" (최우선)
- 이미 고침(동기화, 커밋 전일 수 있음): 황금 몬스터 Highlight Fill 0.5→0.25(`Config.CustomModels.GoldenFillTransparency`), Fx WOBBLE '깊이=너비' 늘리기 제거.
1. 발밑 그림자(블롭 섀도): 카메라 근처 몬스터마다 몸 폭 타원, 투명도 ~0.5, 땅 위 +0.05. 뛸 때 작고 옅게, 착지 때 원래대로. 유령도 작게. CanCollide/CanQuery/CanTouch false, CastShadow false, 정리 포함.
2. 슬라임 통통 높이: 몸 높이 15%, 최대 0.6스터드. 착지 squash + 먼지 3~5개 0.3초.
3. 슬라임류 보이는 몸을 약 0.1 내려 틈(0.09~0.17) 없애기.
4. 고블린·해골 걷기 클립 발 닿음 캡처 확인.
5. 같은 자리 전·후 사진 → `docs/art/verification_2026-10-06/` 새 이름 → 검수가 사용자에게 보여 줌.

### B. 27246d1 검수 (BB1·BB2) — 코드는 끝났고 검사 보강 중이라고 보고됨
1. [중] Keybinds.luau:127 Interact 비우기 금지, 기본 프롬프트가 그리는 키만 허용(글자·숫자·F1-F8·Ctrl·Alt). Studio에서 CapsLock/Num1/비우기 확인.
2. [중] 러너들이 변이를 안 돌리면 status를 'passed'로 쓰지 않기("mutationsSkipped": true). 변이 포함 보고서로 커밋.
3. [중] loot_offline에 BullyStacks=1 사례(대박·황금·줄 ×0.5, 첫 주문서 보장) + 변이 2개.
4. [하] BullyPenaltyEnd: AutoCombatUnlocked가 아니면 자동 문구 없는 문장(KO/EN).
5. [하] Keybinds.ShowsKeys() 하나로 키 안내 판정 통일(HUD L.KeyDevice, VitalsUI, GrudgeGhost, QuestText).
6. [하] beta_basics_offline:538 PvPNote 완성 문장 직접 검사 + 변이, test_beta_basics.py:350 계약 문구(자동 선택 없음).
7. [보류] 폰 전투력 줄 겹침 → 이미지 개발의 HUD v2에서 정리.
- 안전망·대왕 새싹 보호 오프라인 검사도 이 묶음에 넣기로 함.

### C. 1614575 핼러윈 검수 (규칙은 SPEC A23-27)
1. [중] 대왕 새싹 안전: 진영 무관 Level<5 또는 플레이<600초면 노리지도 때리지도 않음(PvP Rookie 속성 쓰지 않기). Config 주석·균형 메모 수정.
2. [중] 보상 자격: 직접 3번 이상 + 최대 HP 0.5% 이상(자동 타격 포함).
3. [중] Lv8 미만 대왕 XP는 XPToNext까지만.
4. [중] 무기 줄은 Level≥MinLevel일 때만(아니면 사탕 3개). 장착에도 MinLevel 확인.
5. [중] 대왕 주문서: Enh70 25% · Enh30 8% · Enh10 2% · Move70 8%.
6. [중] apply_studio_state.py FRONT_FIX를 모든 CustomModels에 매번(멱등).
7. [하] MonsterMotion.luau:125 M.State 누수(약한 키 또는 청소).
8. [하] Panels:2379 드랍 줄 N>1이면 '×N'(KO/EN).
9. [하] TelemetryService:208 CrownTrialMiss → Config.QuestKind.
10. [상] 대왕 targetable() 오프라인 검사·변이, test_halloween contract 문구(동쪽 구석 + 안전 규칙), HalloweenService 주석, --no-mutations 'passed' 금지(모든 러너), studio_halloween_2026-10-06.json + 캡처.

### D. 그다음 순서
개발2 5f52534(BB37·BB12) 병합 → 동기화·2명 확인 → BB13 → BB3 → BB6 → BB7 → BB9 → BB8 → BB11 → BB15 → BB14 화면 → BB38. (진행판 `docs/design/beta_board_2026-10-06.md`)

## 이미지 개발
1. ART-DEL1 결정: empty_id_key 78 + 로그 35 지움, orphan_log 103 + other 5 지움, id_but_unreferenced 9(FactionE 6, FactionTitle_FreshTyped, IconLock ui·out)는 남김(묶음 2·13 적용 뒤 지움). asset_ids 'deleted' 표시, 결과를 art_cleanup2 json에.
2. HUD v2(SPEC A23-26, `docs/design/hud_layout_v2_2026-10-06.json`): HudLayout.luau → 왼쪽 위 얼굴+HP·MP+Lv·전투력+경험치(얼굴/C → 큰 상태판, BB8 전 임시 창) → 오른쪽 위 [펫][가방][전체 지도][메뉴] + 퀘스트 판 → Roblox PlayerList 끄고 우리 Tab 목록 → PC 채팅 왼쪽 아래 → 실시간 지도 MiniMap.luau → 전투 묶음 이동. 목표 10/10까지 1~5, 10/12까지 나머지.
3. [중] EventHUD 대왕 알약 최소폭(글자 폭 맞춤), HUD v2에서 칩/고정 알림으로 이동.
4. [하] asset_ids.json 새 키 12개의 'UIP_' 접두사 빼기(파일 이름과 같게).
5. 받을 그림: 묶음 3 특성 아이콘 10장(2da3a4d+e7aff22), 이후 묶음 6 얼굴 링·미니맵 틀 등.

## 게임성 개발 2
- 결정 D1~D6은 `docs/design/ranking_service_plan_2026-10-06.md` §12. 무법자 바닥 3점(A23-23). 다음: BB10 RankingService → 주간 정산·무법자·보상 → BB14 서버 → 펫 서버 → WPN-3 → GOOSE-Q → A23-18 검사.

## 검수가 다시 돌릴 것
- 묶음 검수(중단됨): 이미지 개발 a62c6e8·bff00df·3cd1795·d6264bc·3b24812·aebf974, 이미지 생성 bd5f456·79ccaae·2da3a4d·e7aff22, ART-DEL1 33fccfa(+지우기 커밋), 개발2 5f52534, c6d31ec의 F10-4 부분(QuestService·Config 자동 지급 60초).
- 사용자에게 보여 줄 것: 게임성 개발의 '땅에 붙는 느낌' 전·후 사진. 사용자 답 대기: 스타일 보드(이미지 생성 채팅).
