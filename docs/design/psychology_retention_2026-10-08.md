# 심리학으로 오래 붙잡기 — 우리 게임 기능으로 (검수 조사, 2026-10-08)
> 기록용(10/08 당시). 지금과 다른 점: 사용자가 고른 베타 전 묶음은 A23-79의 5개(멈춤 카드 + Welcome back, My Way 이름 + 배지 8, 친구 초대, 대왕 일기 + 사탕 단지, 알림 동의). 아래 '베타 전 6개' 중 Almost there 막대·Ready?·KO 팁·Thanks 하트는 고르지 않음(idea_backlog), 친절 알림·팁은 줄이는 쪽(A23-99).
> 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

사용자: "게임성 관련해서도 어떻게 하면 사람들을 붙잡을지도 계속 생각해줘." / "심리학 관련한 것도 넣어야 할듯 그래야 오래 플레이하지 않을까?" / "끊기면 0되면 안 돼."
목표는 "오늘 밤 못 끊음"이 아니라 **"내일 또 오고 싶음"**이에요. Roblox 추천은 28일 동안 다시 오는지를 보고, 60초·3분 안에 나가면 깎아요(early_churn [1][2]). 기분 좋게 끝난 판이 다음 방문을 만들어요.

**부모 시험(모든 아이디어에 적용):** ① 규칙·확률이 다 보인다 ② 나가도 잃는 게 없다 ③ 플레이어가 고른 목표를 돕는다 ④ 근처에 Robux 버튼이 없다 ⑤ 그만두기가 계속하기만큼 쉽다.

## 원리 → 기능
| 원리(근거) | 우리 게임 기능 | 언제 | 크기·담당 |
|---|---|---|---|
| 자율·유능·관계(Ryan·Rigby·Przybylski 2006) | 1a 퀘스트 [Pin] — 고른 퀘스트가 맨 위 줄·지도 표시 / 1b "Ready?" 표시(구역 Lv·내 Power 초록·노랑·빨강) + 같은 몬스터에 2번 쓰러지면 KO 화면 한 줄 팁(물약·대장간·초원 먼저) | 첫 판·둘째 날 | S, 개발 1·2 |
| 정체성·표현(Weaver & Lewis 2012) | 2a "My Way" 이름(True Knight·Rebel Angel·Proud Rascal·Soft-Hearted Devil·Balance Walker), 바뀔 때 2초 알림 / 2b 번 치장(R4·R5·계급 빛)과 산 치장(99 R$)은 모양이 확실히 다르게 | 둘째 날 | S |
| 숙달·몰입·손맛(GameFlow 2005, Juicy 2019) | 3a 마법사·궁수도 가벼운 멈칫 타격감, 왕 슬라임 3대마다 "Wobble!" / 3b 8대 넘게 3분 → "Upgrade at the Forge"(2배 패스 권유 절대 없음) | 첫 판·주 | S, 개발 1 |
| 목표 가까움·먼저 채워 준 진행(Kivetz 2006, Nunes & Drèze 2006) | 4a 다음 목표 줄에 작은 막대 "Iron Sword 620/800", 80%에 "Almost there!" / 4b 왕관 조각 퀘스트가 "1/5 ✓ The shard found you!"로 시작(인트로에서 본 일) | 첫 판 | S |
| 열린 고리 → 다시 이어하기(Ghibellini & Meier 2025, Masicampo & Baumeister 2011) | 5a 멈추는 카드 "Saved! ✓ Next time: King Slime (2 of 3)" [Keep playing]·[OK] 같은 크기 / 5b 6시간 뒤 돌아오면 "Welcome back! Next: … [Go]" / 5c 장 끝 예고 "Chapter 2 — Who broke the Crown? Opens at Lv 10." | 첫 판·둘째 날 | S, 개발 1·2 |
| 궁금증(Loewenstein 1994) | 6a 비밀 조각 12개(구역마다 2개: 폭포 뒤·언덕 위·호박밭), 만지면 왕관 이야기 한 줄, "Secrets 3/12", 다 모으면 칭호 — **지금 A23-76 장소 다시 만들 때 자리를 같이 놓기** / 6b 황금 몬스터 나타나면 구역 알림 + 미니맵 별 30초 | 주·첫 판 | M·S |
| 변하는 보상(정직하게)(Zendle & Cairns 2018) | 7a 드롭 보이는 곳마다 확률 표시 / 7b 슬라임 대박 '운 상한'(잡을수록 오름, 대박이면 처음으로) / 슬롯 돌림·"아깝다!" 연출 금지, 주문서·운 판매 금지 | 주 | S·M |
| 사회적 증거·소속(Cialdini 2008, Depping & Mandryk 2017) | 8a 좋은 소식 띠 4초("A knight returned stolen gold!") — 도둑질 수·구매 소식은 절대 안 띄움 / 8b 서버 조각 항아리(두 진영 같이, 차면 60초 "Shard Shower!") / 진영 화면에 "대부분 Horns" 같은 숫자 안 띄움 | 첫 판·주 | S·M |
| 돕기·보답(Weinstein & Ryan 2010) | 9a [Thanks!] 하트(치료·돈 돌려줌·왕 슬라임 도움 뒤 8초, 고정 문구, 하루 상한) + "Kind Hearts" 수·칭호 / 9b 돌려받은 사람에게 "Sir Leo got your gold back! +120%" [Thanks!] | 둘째 날 | S–M |
| 라이벌(Kilduff 2010) | 10a 나만 보는 라이벌 카드 "Rival: DarkFang · 1–2" / 10b 악마 행동마다 되갚을 길이 보여야 함(규칙) | 주 | S |
| 모으기(Hamari 2017) | 11a 몬스터 도감(실루엣 → 10/100/1000 별, 드롭 확률) / 11b Roblox 배지 8개(진영 고름·첫 슬라임·도시락·Stronger!·첫 스킬·조각 선택·Rank 2·Halloween 2026) | 첫 판~주 | M·S, 배지 아이콘 Firefly 40 |
| 쉬어 가기(Hiniker 2018, UK ICO 13) | 12a 멈추는 카드를 장 끝·일일 3개·왕관 전쟁 끝에도, 다음 대화가 저절로 이어지지 않음 / 12b 2시간 연속이면 한 번 "Stretch break? Everything is saved." (끌 수 있음) | 늘 | S |

## 베타 전 6개(효과 ÷ 품, 모두 작음, 합계 약 3일)
1. 멈추는 카드 "Next time" + "Welcome back [Go]" (5a·5b·12a) — 둘째 날 돌아오기
2. 목표 막대 "Almost there!" + 조각 퀘스트 먼저 채워 시작 (4a·4b)
3. "Ready?" 표시 + KO 팁 (1b)
4. 좋은 소식 띠 + 돌려받은 돈 [Thanks!] (8a·9b)
5. "My Way" 이름 (2a) — GDD §0 핵심을 내 것으로
6. Roblox 배지 8개 (11b) — 게시 때 사용자가 배지 만들기(하루 5개 무료 → 이틀에 나눠 0 R$)

## 규칙으로 더할 것(0일)
- "Almost there"·KO·강화 실패·멈추는 카드 근처에는 구매 버튼 금지(2배 패스 포함).
- 번 치장 ≠ 산 치장.
- 이벤트 카운트다운은 이벤트 칩에만, 멈추는 카드·"Don't leave!" 금지.

## 베타에서 잴 것
1. 새 플레이어 1일·7일 다시 오기 — 멈추는 카드 본 사람 vs 안 본 사람, Welcome back [Go] 누른 비율, Roblox 첫 판 유지 그래프.
2. 80% 넘은 목표 완료율 vs 멈춘 목표, 진영 → 첫 무기·Lv5 스킬·S0 끝까지 걸린 시간, KO 뒤 60초 안에 나간 비율(팁 전/후).
3. 하트·돈 돌려주기는 늘고, 괴롭힘 KO·강화 실패 뒤 나가기는 줄어야. 한 판 길이보다 다시 온 날 수를 성공으로.

근거 링크: Ryan 2006, Weaver & Lewis 2012, Hicks 2019, Kivetz 2006, Nunes & Drèze 2006, Ghibellini & Meier 2025, Masicampo & Baumeister 2011, Loewenstein 1994, Zendle & Cairns 2018, Goldstein·Cialdini 2008, Depping & Mandryk 2017, Weinstein & Ryan 2010, Kilduff 2010, Hamari 2017, Hiniker 2018, Roblox badges 문서 (원문 요약 기준, 숫자는 요약에서).
