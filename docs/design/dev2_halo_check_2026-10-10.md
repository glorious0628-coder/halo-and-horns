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

## 검수가 정할 것 (이 가지에 안 넣음)
- #34 빛 마을 물약 상인(M): 넣을지 정해 주면 ShopService·MapBuilder 쪽을 만들어요.
- #39 선택 뒤 반짝임·주민 반응(M, A23-64 ①②): 베타 여유 일에서 앞당길지.
- #41 마을 안에서 바깥 괴수 때리기: 사용자 답 기다림(검수 추천 (b)).

## 시험
- `test_town_quests` 538개(새 묶음 halo-check-data·h2·h3·h6·landmark), `test_sprout_oath` 79개·변이 33/33, `test_protect_glow` 51개·변이 16/16. 변이·전체 결과는 커밋 메시지에.
