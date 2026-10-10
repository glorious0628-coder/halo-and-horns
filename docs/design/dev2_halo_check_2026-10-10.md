# 빛 마을 점검표 — 개발 2 줄 (2026-10-10, 가지 `dev2-halo`)

근거: `docs/design/zone_check_halo_2026-10-10.md`의 개발 2 줄과 맨 위 검수 결정 #54·#71. 서버·Config만 고쳤어요(Studio 안 만짐).

| # | 무엇 | 고침 |
|---|---|---|
| 71 | 마을형 선택 B 보상이 A(주문서)보다 작음 | 마을형 8곳(H1·R1·N3·S6 두 곳·XR1·H2·R5) B = HP 물약 3 + **골드 220**(빛·뿔·중립 똑같음). 숲형(192)은 그대로 |
| 54 | 새싹 맹세가 1시간 넘게 한 사람에게 안 열림 | OathH·OathR: `Requires.Sprout` 뺌(M3_4 뒤 Lv15 그대로, 졸업한 사람도), 보상 `Gold = 2, XP = 2`(숲형, 칭호 그대로), Start·첫 대사·Finish에서 '방패가 아직 있다'는 말 뺌. 빛·뿔 똑같이 바꿈. `Requires.Sprout` 코드는 다른 퀘스트용으로 남김(시험 묶음 따로) |
| 18 | H3·H5 시작 알림 없음 | H3 "Sir Gleam needs help in Halo Citadel!", H5 "Bright needs a form signed. Find her in Halo Citadel!" |
| 35·36 (+56) | H2·H3·H6 선택이 들판에서 열림 | 선택 바로 앞에 돌아가기 단계: H2 "Bring the lantern home"(Enter HaloTown), H3 "Back to Sir Gleam"(Enter HaloTown), H6 "Back to the statues"(Near HeroStatue 16). 이 단계가 끝나면 선택 카드가 빛 마을 안에서 저절로 열려요. 옛 저장이 선택 단계(옛 3단계)에 있었으면 이제 돌아가기 단계라서 마을로 가면 열려요. 빛 전용 선택(H1·H2·H3·H5·H6·OathH)은 모두 브라이트 앞(Npc) 또는 돌아가기 단계 뒤 — 시험이 Config 전체를 훑어 확인 |
| 37 | H2 1단계 안내가 교차로 안에서 사라짐 | Guide = "Fountain" |
| 38 | H1 3단계 글자가 '숲 근처' | "Slime Princes in the meadow %d/%d" |
| 40 | 맹세가 Q 창 Side 탭 | `QuestTabs.ById` story:OathH / story:OathR = "Faction" |
| 42 | 마을 출발 광장에서 보호 테두리(Highlight)가 쓸모없이 켜짐 | 마을 안(`ZoneService.IsTown`)에서는 테두리를 안 붙이고, 보호 중에 마을 밖으로 나가면 1초 루프가 붙이고, 다시 들어오면 뗌. 보호(ForceField)·10초는 그대로 |
| 2 | 새 영웅상 자리가 Config 숫자와 어긋날 수 있음 | 아래 '랜드마크 표시' 계약. 표시가 없으면 지금 숫자 그대로라 오늘은 아무것도 안 바뀜 |

## 랜드마크 표시 계약 (#2, 이미지 생성 1·메인 반영 1 — 새 영웅상 놓을 때)
- workspace 안의 Model 또는 Part 하나에 CollectionService 태그 **`StoryLandmark`** + 속성 **`Spot = "HeroStatue"`**(문자열)를 붙이면, 서버의 이야기 퀘스트(H6의 '석상 보기·돌아가기', 처치 Near)가 그 자리(Model은 Pivot, Part는 Position, 평면 거리)를 써요. 석상 두 쌍의 가운데에 투명·Anchored·CanCollide false 파트 하나면 충분해요.
- 같은 방식으로 다른 랜드마크(예: `LavaCrack`, `MeadowArrival`)도 옮길 수 있어요. workspace 밖(ServerStorage 키트 복사본)이나 다른 Spot 값은 무시해요.
- 게시판(BoardService)·맵 만들기(MapBuilder)는 여전히 Config 숫자를 읽어요(이번 범위 밖).

## 다음 가지 (`dev2-halo2`, 검수 결정 2026-10-10)
- #34 빛 마을 물약 판(PotionMerchant 태그 상인 아무나), #39 선택 뒤 여운 신호 + 주민 반응 대사 Config(A23-64 ①②), 물 구조(마을 + 둘레 40스터드 물에 8초 넘으면 가장 가까운 땅).

## 시험
- `test_town_quests` 558개·변이 131/131(새 묶음 halo-check-data·h2·h3·h6·landmark + main의 send-all-subs), `test_sprout_oath` 79개·변이 33/33, `test_protect_glow` 51개·변이 16/16, 새 `test_kaiju_town`(#41) 17개·변이 5/5, `test_slime_prince` 변이 14/14(H1 글자).
- 최신 main(b7a8f855)과 합친 트리에서 오프라인 110개 중 108개 통과. 나머지 2개(`test_finisher` 무임승차, `test_intro_seen`)는 main에서도 같은 실패 → 가지 `dev2-testfix`에서 고침.

## #41 (사용자 결정 (b), 2026-10-10)
- 빛·뿔 진영 마을 안(Config.Zones Town + Faction)에 서 있는 빛 플레이어는 바깥 괴수(Active)를 못 때려요(`PvPService.CanAttack` 괴수 예외에 `not inFactionTown(attacker)`; 마을은 안전 지역이라 'SafeZone'). 교차로(진영 없는 마을)와 마을 밖은 그대로, 괴수가 어디 서 있는지는 상관없음.

## 맹세 글 (개발 3 #55와 합침)
- 제목·단계 글은 개발 3의 'Sprout Promise' 글, 조건·보상·Start는 #54, 마무리 줄 "Promise made! Keep it close, wherever you go."(검수).

## 랜드마크 표시: 서버·클라 한 규칙
- 공용 함수 `Util.TaggedSpot(tag, key)`(태그된 workspace 표시의 자리, 없으면 nil). 서버 = `Util.TaggedSpot(Config.StoryQuests.LandmarkTag, key) or Config.StoryQuests.Landmarks[key]`. 개발 1이 QuestTarget·HUD L.StoryTap을 같은 함수로 바꾸기 전에는 표시를 놓지 않아요(놓으면 마름모와 서버 판정 자리가 달라짐).
