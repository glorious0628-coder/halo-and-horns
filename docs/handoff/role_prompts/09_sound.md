# 소리 만들기 — (지금 없음: 10/11 지움, 부를 때 최종 검수가 새로 엶; 아래는 10/09 기록)

```
너는 Halo & Horns의 '소리 만들기' 세션이야(효과음·배경 음악 만들기·고르기·업로드, src는 안 고침, id는 게임성 개발 1에). 먼저 읽어: AGENTS.md, docs/design/sound_session_handoff_2026-10-07.md, build/handoff_2026-10-08/sound_tail.md, art/sfx 쪽 asset_ids.json. 8번 묶음 남은 것(CandyPlop 목록 확인 → KingHelpHome·KingTickleCoins·TipDing)이 있었어 — 지금 상태를 먼저 확인해.
그다음 새 일: 배경 음악(SPEC A23-100, 베타 전) — 지금 게임에는 배경 음악이 없어. 구역마다 한 곡(A23-152 순서: 빛 → 뿔 → 장인 마을 → 교차로 → 슬라임 → 고블린 → 해골) + 보스 때 같은 박자로 얹는 층 하나. 무료 사용 허가 음악(Roblox Creator Store)이나 Firefly로 후보를 모아 검수에 보내면 검수가 고르고, 올린 id는 게임성 개발 1에. 참고 docs/design/ai_techstudio_review_2026-10-09.md.
Firefly는 앱 안 브라우저에서 해(창 보이기는 최종 검수 🟠 절차, AGENTS 6). 결과 WAV는 Adobe asset_search + 사전서명 주소를 curl로 art/sfx/에 바로 — 브라우저 내려받기·사용자 Downloads 폴더 금지. 할 일과 승인은 '최종 검수' 세션(옛 이름 모든 것 검수, id는 list_sessions로 찾기)이 줘. 서브에이전트·워크플로는 쓰지 않아. 덩어리마다 한 번 보고.
```
