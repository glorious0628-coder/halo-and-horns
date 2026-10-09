# 성공한 RPG·MMORPG 분석 — 왜 됐나, 무엇이 싫었나, 우리에게 무엇을 옮기나 (검수 워크플로, 2026-10-08)
> 기록용(10/08 당시). 지금과 다른 점: 업데이트 박자는 매주 수요일 05:00 UTC = 14:00 KST, 첫 11/04 후보(A23-83 — 제안 6·결정 2의 '토요일' 아님). Kids·Select는 보증금을 10/31 베타 때 사용자가 냄(A23-82). 마무리 카드는 새 King Slime·Captain Clatter에 붙어 main에 들어감(A23-84, `Config.Finisher`). 색만 바꾼 모델 금지(A23-96, 제안 12의 '색만 바꿔서 0').
> 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

검증: 2026-10-08 사실 확인 + 우리 규칙 확인 두 번 거쳐 고침(검수 워크플로).

사용자: "지금까지 성공했던 RPG, MMORPG들 모두 다 분석하고 그것들의 장점고 단점 가져와줘. 그리고 왜 성공했을지도 우리꺼에는 어떻게 이식할지도"

- **범위:** 다섯 묶음, 대표 게임 45개. 서양 MMO 6 · 아시아 MMO 9 · 액션 RPG·라이브 게임 8 · Roblox RPG 12 · 아이용 게임과 선악 게임 10. '모두'를 다 볼 수는 없어서 오래 살아남았거나 크게 실패한 대표만 골랐어요.
- **숫자 규칙:** 숫자는 출처가 있는 것만 썼어요. 출처는 맨 아래 [번호]에 있어요. 회사 주장이나 팬 자료는 **(미확인)**이라고 적었어요.
- **이미 정한 것은 다시 내지 않아요.** 이미 있거나 계획된 것은 §4-2에 따로 모아 두고 새 제안 수에 넣지 않았어요. 함께 본 문서: `psychology_retention_2026-10-08.md`, `retention_round_2026-10-08.md`, `mmorpg_painpoints_ideas_2026-10-05.md`, `creative_ideas_2026-10-07.md`, `idea_backlog.md`, SPEC A23-75~81, 그리고 `src/`.

> **가장 급한 발견 (게임 규칙이 아니라 게시 규칙이에요)**
> 2026-06-16부터 Roblox는 **16세 미만 계정(Kids 5~8세, Select 9~15세)이 '평가를 통과한 게임'만 할 수 있게** 했어요. 새 게임은 먼저 **나이 확인된 16세 이상에게만** 보여요 [127][128].
> 아이들이 들어오려면 만드는 사람 쪽에서 네 가지가 필요해요.
> - 본인 나이 확인: 18세 이상은 정부 신분증
> - 2단계 인증
> - 게임마다 **1,000 Robux 보증금**(자격이 생기고 90일 뒤 돌려받아요) 또는 Plus/Premium 2달 연속 [133]
> - 성숙도 설문. Kids는 Minimal·Mild 등급만, Select는 Moderate까지 돼요 [130].
>
> 그다음 '열심히 하는 플레이어' 기준을 넘어야 해요. 문서는 60일 동안 250회, 6/16 포럼 공지는 처음 들어가는 기준 500명이라고 해서 숫자가 달라요. 7/16 갱신은 유지 기준을 100→25명으로 낮췄어요 [127][128].
> 이 검수가 2026-10-08에 두 출처를 직접 열어 확인했어요. 그런데 `launch_ops_checklist.md`에는 아직 이 줄이 없어요.
> **뜻:** 10/31 베타의 첫 손님은 16세 이상이에요. 베타에서 13~15세 친구를 초대해도(A23-79 #3) 자격이 생기기 전에는 들어오지 못해요. → §4 제안 1, §6 결정 1.

---

## 1. 한 줄 요약 + 성공 공식 7개

**한 줄 요약:** 오래 살아남은 게임에는 다섯 가지가 있었어요. 빨리 재밌고, 남이 방해꾼이 아니라 도움이고, 내가 누군지 한눈에 보이고, 정해진 날마다 새것이 오고, 돈으로 힘을 팔지 않았어요. 반대로 무너진 게임은 확률을 몰래 바꾸거나, 산 것을 빼앗거나, 오래 아무 소식이 없었어요.

| # | 성공 공식 | 이렇게 한 게임 | 반대로 해서 다친 게임 | 우리 지금 |
|---|---|---|---|---|
| 1 | **첫 재미는 빠르게, 깊이는 천천히** | WoW: 들어오고 5분 안에 퀘스트를 받고 싸워요 [7]. Wizard101: 체력·공격부터 보여 주고 하나씩 더해요 [115]. Pokémon: 몇 분이면 배워요. | EVE: 새로 온 사람의 절반 넘게 2시간 안에 떠났어요(CCP 2016 발표) [24]. PoE: 튜토리얼을 늘려도 남는 사람이 거의 그대로였어요 [72]. | 첫 10분 작업 중(A23-68·74), 스킬은 Lv5부터(A23-71) |
| 2 | **남이 '도움'이 되게 만든다** | GW2: 도운 사람은 모두 전부를 받아서 처치를 뺏을 일이 없어요 [19]. Toontown: 전투가 끝날 때 있던 사람 모두 보상 [110]. MH: SOS 한 번으로 낯선 사람이 와서 도와요. | EVE: 다른 사람이 먼저 챙긴 새 플레이어는 2배 더 남았어요(CCP 인터뷰, 상관관계) [25]. 혼자 두면 떠나요. | 15초 안에 때린 사람 모두 보상 = 있음 |
| 3 | **친구 사이 벽을 없앤다** | ESO: 모든 지역 레벨을 맞추고 PvE 진영 벽을 없앴어요 [29]. FFXIV: 레벨 맞추기로 고참과 새싹이 같이 해요. | WoW: 다른 진영 친구와 던전에 가기까지 약 17년 반이 걸렸어요(2022-05, 9.2.5) [5]. | 스쿼드는 후보(A23-79 베타 뒤 후보, 사용자 선택 전). 빛·뿔 친구가 PvE를 같이 할 길이 아직 약해요 |
| 4 | **내가 누군지 보이고, 그게 놀이를 바꾼다** | Fable: 착하면 후광, 나쁘면 뿔이 돋아요 [119]. MU: 날개 [60]. Aion: 흰 날개와 검은 날개. MapleStory: 옷과 결혼식이 5만 건을 넘었어요 [41]. | Fable: 모양만 바뀌고 놀이는 덜 바뀐다는 비판을 받았어요 [120]. 2027 리부트는 후광·뿔 대신 지역별 평판으로 바꿨어요 [121]. | 계급마다 후광·뿔 R1~R5 = 있음. '놀이를 바꾸는' 부분은 약해요 |
| 5 | **정해진 박자로 새것이 온다** | PS99: 매주 토요일 [105]. AQW: 매주 금요일 [118]. Club Penguin: 매달 파티 [112]. PoE: 3~4개월마다 리그. | Arcane Odyssey: 출시 첫날 95,364(2023-02)에서 지금 수백 명. 그 뒤 큰 업데이트 사이가 1년 넘게 비었어요(팬 기록) [96][97]. WoW: 확장팩 출시 뒤 첫 큰 콘텐츠 패치까지 217일 걸렸어요 [6]. | 업데이트 요일 약속 없음 → 제안 6 |
| 6 | **약속된 시간의 편 대결 + 작고 진짜인 상** | Lineage 공성, RO 길드 공성(성 보물 상자), Aion 요새 1시간 창 | Lineage: 성 세금에 상한이 없어서 큰 혈맹이 작은 혈맹을 짓눌렀어요(미확인) [34] | 10분 왕관전, 이긴 편 축복 25% = 있음 |
| 7 | **믿음: 힘은 안 팔고, 확률·변경은 미리 공개, 실수는 인정** | PoE: 힘을 안 파는 상점으로 10년 넘게 믿음을 지켰어요. FFXIV: 실패를 공개로 인정하고 다시 만들었어요 [9]. OSRS: 플레이어 투표 [16]. | MapleStory: 확률을 몰래 낮춰서 과징금 116억 원 부과(소송 중) [43][135]. Lineage M: 갑자기 바꾸고 되돌렸어요 [39][134]. D4: 1.1 패치로 유저 점수가 4.8에서 3.7로 떨어졌어요 [68]. | 능력치 판매 금지(A23-75), 확률 표 = 있음 |

**우리 성적:** 7개 중 ②⑥⑦은 이미 단단해요. ④는 반쯤 돼 있어요. 약한 곳은 셋이에요.
- ③ 빛 친구와 뿔 친구가 같이 놀 길
- ⑤ 업데이트 박자
- ④ '후광·뿔이 놀이를 바꾸는가'

§4 제안은 대부분 이 셋을 메워요.

---

## 2. 게임별 표 (45개)

칸은 짧게 썼어요. 숫자 뒤 [n]은 §7 출처예요. Roblox 게임의 '지금' 숫자는 2026-10-08 rolimons 기록이에요.

### 2-1. 서양 MMO

| 게임 | 왜 성공했나 | 장점 | 단점(사람들이 싫어한 것) | 우리에게 한 줄 |
|---|---|---|---|---|
| **World of Warcraft** (2004) | 5분 안에 첫 퀘스트 [7]. 두 진영이 정체성을 줌. '쉬면 경험치가 깎임'을 '쉬면 보너스'로 바꿔 말함 [8]. 구독 1,200만(2010) [1] | 목표가 늘 분명함. 레벨 벽이 없음. 작은 진영에 +20% 보너스(Call to Arms) [3] | 진영 쏠림. 2019 명예의 전당이 호드 100 대 얼라이언스 12 [4]. 다른 진영 친구와 파티까지 약 17년 반(2022-05, 9.2.5) [5]. 얻은 힘을 확장팩마다 뺏음. 첫 큰 콘텐츠 패치까지 217일(어둠땅→9.1) [6]. 2015년 550만 뒤로 숫자 공개를 멈춤 [2] | 빛 친구와 뿔 친구를 PvE에서 갈라놓지 말기 |
| **Final Fantasy XIV** (2.0, 2013) | 1.0 실패를 인정하고 약 2년 8~9개월 만에 다시 만듦 [9]. 감독 생방송. 무료 체험 Lv70까지 [10] | 새싹 표시와 멘토. 멘토 보상은 **일부러 작게** [13]. 레벨 맞추기로 옛 던전에도 사람이 있음 | 초반 이야기가 지루함. 출시 날 대기열(2021에는 판매를 멈춤 [12]). 7.0에서 주인공이 밀려남. 체험 계정은 거래 불가. 등록 3,000만은 '등록' 숫자예요 [11] | 새싹 돕기를 가장 쉬운 천사 행동으로. 보상은 작게 |
| **RuneScape / OSRS** (2001/2013) | 무료, 브라우저, 학교 컴퓨터에서도 됨. 스킬 숫자가 조금씩 오름. OSRS는 2013년 투표(449,351표)로 시작했고 [15], 지금도 투표 70~75%를 넘어야 내놓음 [16]. 누적 매출 30억 달러 넘음 [14] | 시작이 쉬움. 투표로 믿음이 생김. 결투 판돈(도박)을 2022년에 없앰 [17] | 2012 유료 돌림판(Squeal of Fortune)이 2014 Treasure Hunter로 커졌다가 12만 표 넘는 투표로 2026-01-19에 없어짐 [18]. 전투 대개편으로 사람들이 갈라짐. 봇과 골드 장사 | 뽑기를 나중에 하더라도 꾸미기만, 확률 공개, 결투에 걸 수 없게 |
| **Guild Wars 2** (2012) | 이벤트를 도운 사람 모두 전부를 받음, '처치 뺏기 없음' [19]. 누구나 누구든 일으켜 세움. 구독 없음. 2주 만에 200만 장, 서버를 지키려고 판매를 이틀 멈춤 [20] | 낯선 사람이 늘 도움. 힘이 크게 안 불어서 돌아오기 쉬움 | "장비 쳇바퀴 없다" 약속을 깬 Ascended 장비(사과) [21]. 확장팩 값. 환전 최소량을 올렸다가 되돌림 [22]. 랜덤 상자 | 한번 약속한 규칙(파괴 없음 등)은 절대 뒤집지 않기 |
| **EVE Online** (2003) | 서버 하나에 모두가 있는 우주. 진짜 잃어서 진짜 이야기가 생기고 뉴스가 홍보해 줌. 플레이어가 뽑은 의회. 구독 50만(2013) [23] | 남이 먼저 말 건 새 플레이어는 2배 더 남음(CCP 인터뷰, 상관관계) [25]. 처음 배를 잃으면 직원이 알아보고 도와줌 [26] | 시작이 매우 어려움. 새 가입자 절반 넘게 2시간 안에 떠남(CCP 2016 발표) [24]. 비싼 외눈 안경과 유출 메모 때문에 직원 약 20% 감원 [27]. 사기와 학살 허용 = 아이용 아님 | 처음 진 순간을 설명하고 사람이 도와주기(계획됨) |
| **Elder Scrolls Online** (2014) | 의무 구독을 없애자 접속이 "하룻밤 사이 두 배" [28]. 콘솔 출시. One Tamriel: 모든 지역 레벨 맞춤, 순서 자유, PvE 진영 벽 없앰 [29]. 누적 약 20억 달러 [28] | 어느 레벨이든 친구와 같이 놂. 고참은 장비·기술 우위를 지킴. 플레이어 2,400만 [30] | 2014 출시 실패(구독, 버그, 진영에 잠긴 지역). Crown Crates는 '도박 상자'라고 불림 [31]. PvP 렉 | 빛·뿔 갈림은 PvP와 랭킹에만 두고 PvE는 같이 |

### 2-2. 아시아 MMO

| 게임 | 왜 성공했나 | 장점 | 단점 | 우리에게 한 줄 |
|---|---|---|---|---|
| **Lineage** (1998) | PC방 붐. 요금은 PC방이 냄. 군주가 약해서 혈맹이 꼭 필요함. 공성에 이기면 성주가 세금을 정함. 이런 MMO 중 처음으로 구독 200만을 넘음 [32] | 길드의 긴 목표. 성향(라우풀·카오틱)이 세상에 보임 | 안전 지대 밖에서 아무나 PK. 세금 상한 없음(미확인) [34]. 서양 서버는 2011년에 닫음 [33] | 이긴 편 혜택은 작고 상한이 있게(이미 축복 25%) |
| **Lineage II** (2003) | 그때 앞선 3D. 카르마: 먼저 치면 보라 이름, 싸우지 않는 사람을 죽이면 빨간 이름. 공성. 모바일 2M은 3개월에 1억 5,200만 달러 [35] | PvP 상태가 한눈에 보임. 몬스터를 잡아 카르마를 회복함. 카오틱이 아니면 죽어도 아이템을 안 떨굼 | 봇이 사람을 죽임. 노가다. 사용자 수가 출처마다 1,400만과 61만으로 달라요(미확인) [36] | 현상수배 별·되갚기 길 = 있음. '아이템 안 떨굼'은 유지 |
| **Lineage M / W** (2017) | 1998년 플레이어가 어른이 되어 돌아옴. 자동 사냥. 큰손 경쟁. 하루 130억 원(한국 모바일 하루 기록) [37] | 첫날 수요가 컸음 | 2021 문양 업데이트(성장을 싸게)를 4일 만에 롤백하고 다이아로 환불 → 불매와 트럭 시위(4/5~9) [134]. 안드로이드 MAU 약 20% 감소(2월 233,937 → 3월 187,822) [39]. 매출 89.5%가 한국 [38]. 회사 매출 80%가 IP 하나 [40] | 유료 상품 효과는 7일 전에 알리고, 산 사람에게 불리하게 소급하지 않기 |
| **MapleStory** (2003) | 저사양 귀여운 2D. 무료에 옷·결혼 상품. 북미 13~17세가 50%이고 절반 넘게 카드가 없어서 선불카드를 팜 [41]. 등록 9,200만(2009) [42] | 꾸미기가 돈을 불렀고, 힘은 안 팔았음. 결혼 5만 건 넘음 [41]. 사과·소통 뒤 PC방 점유가 20% 대로 돌아옴 [45] | 큐브 확률을 몰래 낮춤. 2011년에는 '변경 없음'이라고 공지함 → 공정위 과징금 116억 원 부과(2024-01, 넥슨이 취소 소송 중이고 2026-10 기준 판결 전) [43][135]. 소비자원 조정으로 약 80만 명에게 219억 원 보상(2024-09) [44]. 트럭 시위 | 확률과 실패 결과를 버튼에 쓰고, 바뀌면 날짜로 남기기 |
| **Ragnarok Online** (2002) | 귀여운 그림과 포링 마스코트. 전직 나무(13 → 50개 넘는 직업) [46]. 길드 공성 보상. 필리핀 680만·동시 57,000(2005) [47] | 낮은 문턱. 직업 고르기로 다시 할 이유가 생김. 매주 정해진 길드전. 모바일 후속작도 크게 성공(회사 주장, 미확인) [49] | Lv99 노가다(미확인). 2,500만 명은 회사 주장(미확인) [48]. 필리핀 서비스는 2015년에 끝남 | 전직(정식 뒤)을 빛 갈래·뿔 갈래로 |
| **Black Desert** (2015) | 손맛 액션. 캐릭터 만들기. 낚시·농사 등 싸우지 않는 길. 누적 20억 유로 넘음·등록 5,500만 [50] | 싸움이 싫어도 할 게 있음. 여러 기기로 오래 커짐 | 실패하면 하락. 확률을 올리는 아이템과 하락을 막는 아이템을 팜. 펄 상점 물건을 시장에 팔게 해서 항의를 받음 [51] | 확률 올리기·하락 막기는 절대 안 팔기(이미 규칙) |
| **Lost Ark** (2018/2022) | 전투 손맛이 먼저. 스트리머. 스팀 무료. 동시 1,325,305 [52] | 보스와 레이드. 감독이 직접 소통 | 재련 확률. 아이템 레벨 1370 벽 [132]. 초반 엔드게임 10개를 너프 [54]. 첫 달에 봇 100만 계정 넘게 정지 [53]. 숙제 | 메인 이야기를 장비 점수로 막지 않기 |
| **Aion** (2008) | **천사 대 악마**(흰 날개·검은 날개). 비행. 1시간 요새전. 한국 오픈베타 동시 17만 [55]. 아이온2는 출시 이틀 만에 평균 DAU 150만(회사 발표), 46일 만에 매출 1,000억 원 [56] | 진영이 한눈에 보임. 제3세력(발라우르)이 요새를 많이 가진 편을 노림 [57] | 2009 북미 서버 14개 중 3개만 균형 [58]. 2011년에는 보너스로 사람을 '모셔 옴' [59]. 2년 안에 서양 인구가 빠짐 | 우리와 가장 닮음 → 이기는 편을 노리는 '욕심 젤리'(제안 12) |
| **MU Online** (2001) | 이른 3D. 반짝이는 +강화와 천사·사탄 날개. 단순한 루프. 등록 5,600만(2009) [60] | 성장이 눈에 보임. 자랑하기 좋음 | +10 강화에 실패하면 아이템이 부서짐 [62]. 날개 만들기에 실패하면 재료를 다 잃음. 웹젠 매출 77%가 MU [61] | 계급 후광·뿔이 커지는 것 = 있음. 파괴 없음 유지 |

### 2-3. 액션 RPG·라이브 게임

| 게임 | 왜 성공했나 | 장점 | 단점 | 우리에게 한 줄 |
|---|---|---|---|---|
| **Diablo II** (2000) | 색깔 등급 랜덤 드롭이라 매번 작은 기대. Battle.net 무료 협동. 짧은 반복. 2001년 8월까지 400만 장 [63] | 드롭이 한눈에 읽힘. 래더를 새로 시작해 모두 같이 출발 | 아이템 복사와 봇으로 경제가 무너짐. 출시 서버 장애. 처음엔 다시 찍기 없음 | 경매장은 올릴 때 먼저 맡기고 거래 장부를 남기기(무기 번호·출처는 2단계, 제안 15) |
| **Diablo III** (2012) | 큰 브랜드와 손맛. 첫 주 630만 [64] | 빌드를 자유롭게 바꿈 | 경매장을 월 약 300만 명 중 대부분이 써서 '잡아서 얻기'가 망가짐 [65] → 2014년에 닫음 [66]. 혼자 해도 늘 온라인 | 사는 것이 사냥보다 나으면 안 돼요 |
| **Diablo IV** (2023) | 어두운 분위기로 돌아감. 열린 세계 이벤트. 5일에 6억 6,600만 달러 [67] | 무료 시즌 길. 개발자 소통 | 1.1 패치로 힘과 경험치를 깎음 → 메타크리틱 PC 유저 점수 4.8→3.7 [68], "재미없다" 인정 [69]. 70달러 게임 안에 25달러 옷 | 2배 패스가 있으니 경험치·골드를 몰래 줄이지 않기. 약한 쪽을 올려 맞추기 |
| **Path of Exile** (2013) | 힘을 안 파는 무료. 3~4개월 리그(새 규칙 + 새 경제). 스팀 동시 229,337 [70]. PoE2 첫날 100만 [71] | 공정한 상점에 대한 믿음. 리그 때마다 모두 같이 돌아옴 | 새 플레이어에게 어려움 [72]. 창고 칸이 '선택인데 필수'처럼 느껴짐. 화면이 복잡함 | 깊이는 레벨로 천천히. 편의 상품이 필수처럼 느껴지지 않게(가방 판매 금지 유지) |
| **Genshin Impact** (2020) | 무료·여러 기기·고품질. 언덕마다 비밀. 6주 업데이트. 첫해 모바일 약 20억 달러 [73] | 무료 캐릭터로도 끝까지 감. 탐험 보상 | 5성 0.6%, 천장 90 [75]. 레진은 8분에 1개라 하루 진행이 막힘 [76]. 숙제. 연 모바일 매출이 2022년 뒤 크게 줄었다는 추정(미확인) [74] | '그만 놀아' 제한 금지. 비밀 조각(후보)으로 탐험 보상 |
| **Monster Hunter** (World 2018) | 보스가 배울 수 있는 퍼즐. 레벨 대신 보스 재료로 장비. SOS 신호. World 2,500만 넘음 [77]. Wilds 3일 800만 [78] | 사냥 → 재료 → 제작 → 더 센 보스 | 시작이 느림. 희귀 재료 노가다. SOS 때문에 모임 장소가 비었음 [80]. Wilds 스팀 약 118만 → 약 15만 [79] | 보스 큰 공격을 미리 보여 주고 빈틈 주기 |
| **Destiny 2** (2017) | 최고 사격 손맛. 레이드. 랜덤 무기 옵션. 무료 전환 때 스팀 동시 약 22만 [81] | 순간 손맛과 이벤트 | 돈 주고 산 캠페인을 지움(Content Vault) [83]. 새 플레이어가 헷갈림. 시즌 FOMO. 2026년 6월 라이브 개발 종료 [82] | 이미 한 것과 산 것은 절대 지우지 않기 |
| **Pokémon** (1996~) | 모으고 바꾸기. 두 버전에 다른 포켓몬이 있어서 친구가 필요함 [86]. 첫 스타터가 평생 정체성. 관련 소프트 4억 8,000만 장 넘음 [84]. S/V 3일 1,000만 [85] | 배우기 쉬움. 모으는 목표가 끝없음. 친구와 같이 | S/V 프레임·버그(평론 76, 유저 약 3) [87]. 포켓몬 일부 삭제 반발 | 진영 고르기를 '스타터 고르기'처럼 소중하게 |

### 2-4. Roblox RPG

| 게임 | 왜 성공했나 | 장점 | 단점 | 우리에게 한 줄 |
|---|---|---|---|---|
| **Blox Fruits** | 2명이 포기하지 않고 업데이트(첫해 하루 동시 2만 미만) [89]. 열매 고르기. 유튜버 미리보기와 2배 코드. 2배 경험치 등 패스. 최고 동시 2,781,531(2024-12-31) [88] | 긴 레벨 사다리. 거래. 조합 깊이 | 최고 레벨까지 80~120시간 [90]. 패스 전부 약 5,500 Robux. 거래 사기. 튜토리얼 없음. 큰 업데이트가 2~3달 간격이라 매주 내는 경쟁작에 2026년 3월 한때 동시 접속에서 밀림 [91] | 업데이트마다 빛 것 1 + 뿔 것 1 + 영상용 코드 |
| **Grand Piece Online** | 희귀 열매 쫓기. 매주 금~일 2배. 배틀로얄. 최고 231,039 → 지금 14,307 [92] | 주말 이벤트가 돌아올 이유 | 힘이 랜덤과 긴 타이머에 묶임. 열매 찾기 2만 Robux(미확인). 프리미엄은 타이머가 짧음 | 첫 힘은 확정 보상으로(= Lv5 첫 스킬, 있음) |
| **King Legacy** | 블록스 프루츠와 거의 같은 놀이. 최고 151,379 [93] | 열매 44개 | 레벨 상한 5,450 벽. '복제품'이라 천장이 1위의 약 5% | 따라 하면 천장이 낮음. 선악 기울기는 우리만 가진 것 |
| **Deepwoken** | 하드코어 팬. 목숨 3개 뒤 영구 죽음의 긴장. 최고 62,422, 2022 혁신상 [94][95] | 싸움마다 긴장 | 영구 삭제. Robux 부활 = 잃은 것을 돈으로 되돌림. 10대·어른용 | 악마 짓의 결과는 남기되, 되돌리기는 퀘스트로만(돈 절대 안 됨) |
| **Arcane Odyssey** | 전작 팬의 기대. 얼리액세스 첫날 95,364 [96] | 바다·배 판타지 | (미확인) 미완성 출시. 업데이트 공백 최대 약 15개월(2024-09 → 2025-12, 팬 기록) [97]. 지금 388 | 큰 업데이트 하나보다 정해진 작은 박자 |
| **Swordburst 2** | 일찍 나온 '진짜 RPG'. Xbox 소개. 기록된 최고 5,245(옛 기록 빠짐, 미확인) [98] | 층마다 보스, 같이 사냥 | 보스 없는 층을 냄 | 구역은 보스와 함께 내기 |
| **Dungeon Quest** | 짧은 던전 반복. 친구와 쉬움. 운영사가 2배 이벤트와 A/B 시험. 최고 24,002 → 지금 약 100 [99] | 폰에 맞는 짧은 판 | 콘텐츠를 다 해 버림 | 5~8분짜리 던전 하나(정식 뒤) |
| **World // Zero** | 열린 세계 + 던전으로 방향을 바꿈. 매달 길드 시즌. 공정한 상점. 최고 64,763 [100] | 좋아요 94.7% | 콘텐츠가 빨리 바닥남. 높은 레벨 상한이 새 플레이어를 겁줌 [101] | 주간판은 레벨이 아니라 이번 주 행동(= 명예·악명·PvP 주간판, 있음) |
| **Vesteria** | 인큐베이터와 유명 개발자. 기록된 최고 6,778 [102] | 고전 MMO 느낌 | 2020에 멈추고 다시 만들다가 버림 [102] | 베타~정식 사이 갈아엎지 말고 지금 코드에서 고치기 |
| **Bee Swarm Simulator** | 곰 NPC 퀘스트가 늘 다음 목표. 벌 모으기. 매년 Beesmas. 출시 7년 뒤 최고 264,505(2025-12-29) [103] | 좋아요 95.6% | 혼자 개발이라 막힘(2023 Beesmas 없음). 긴 침묵 | 해마다 같은 날 축제 |
| **Pet Simulator 99** | 전작 펫을 옮겨 옴. **매주 토요일** 업데이트 [105]. 펫 3,000종 넘음. 최고 732,936 [104] | 약속 시간에 모두 접속 | 행운·알 판매(최대 14,500 Robux) [106]. 거래 사기. 자동 농사 패스 | 업데이트 요일. 행운 판매 금지(Robux 알·뽑기는 GDD §10-1대로 사용자가 설계할 때까지 안 만듦) |
| **Fisch** | 낚시 손맛 하나. 엄청난 수집. 페이투윈을 걷어내고 회복. 최고 1,273,618 [107] | 폰·PC 쉬움. 도감 | 인수 뒤 P2W와 품질 저하로 떠남. 두 번째 바다를 통째로 지움 [108] | 손맛 먼저. 한정 시간 판매 자체를 안 함(A23-68) |

### 2-5. 아이용 게임과 선악 게임

| 게임 | 왜 성공했나 | 장점 | 단점 | 우리에게 한 줄 |
|---|---|---|---|---|
| **Toontown Online** (2003) | 협동이 가장 이득(전투 끝에 있던 모두 보상). 싸움 대신 파이 던지기. 정해진 말만 쓰는 채팅 [110]. 약 10년, 월 9.95달러 [109] | 낯선 사람이 기본으로 도움. 아이와 어른이 다 웃는 농담 | 무료 구역이 좁음. 필터 우회. 구독 모델이라 닫힘. 팬 서버 등록 200만 넘음 [111] | 걸어 들어와 같이 싸우기(= 공동 보상, 있음) |
| **Club Penguin** (2005) | 안전 최우선(사람 감시자 200명 [113], 신고 버튼). 미니게임 → 코인 → 옷·집. 매달 파티. 디즈니가 3억 5,093만 달러에 삼, 유료 70만 [112] | 꾸미기가 곧 성장. 정해진 행사 박자 | 90%는 돈을 안 냄. '회원 계급 사회' 비판, 회원 전용 방 [112]. 후속작 평점 2.3, 종료 [114] | 번 후광·뿔은 무료·유료 똑같이. 공개 서버 안 유료 전용 방 금지 |
| **Wizard101** (2008) | 'Pixar 방식'(아이·어른 둘 다 웃음). 카드 턴제. 응답한 어른 68%가 가족과 함께 함 [116]. 등록 2,000만(2011) [115] | 손이 빠르지 않아도 됨. 부모가 채팅을 정함 | 구역마다 따로 사고 값이 오름. '무료는 데모' [115]. 2021 매출 3,200만 달러(예상치) [117] | 구역 판매 금지. 시스템은 층층이 열기 |
| **AdventureQuest Worlds** (2008) | **매주 금요일** 새 콘텐츠. 이벤트 때 개발자도 같이 접속. 브라우저 무료. 선·악 평판 | 매주 새것. 커뮤니티 | 농사와 회원 압박(아이 리뷰). 금요일 13일 이벤트 20초 만에 모든 게임이 다운 [118] | 큰 이벤트 전 몰림 시험 |
| **Fable** (2004) | **착하면 후광·나비, 나쁘면 뿔·파리.** 마을 사람이 환호하거나 도망침. 작은 선악 행동이 어디에나 있음. 약 300만 [119] | 몸에 보이는 선악. NPC 반응 | 과대 약속(사과). 마을 학살이 '작은 한 걸음'이고 현상금은 10분이면 사라짐 [120]. 2027 리부트는 후광·뿔을 빼고 지역 평판으로 바꿈(원작자는 아쉬워함) [121] | 후광·뿔이 값·대사·문·기술을 바꿔야 함 |
| **KOTOR** (2003) | 선택마다 빛·어둠 점수, 점수가 힘 비용을 바꿈. 어두워지면 눈과 피부가 변함. 4일 25만, 320만(2007) [122] | 기울기가 놀이에 영향 | 너무 흑백. 정답이 뻔함. 결말이 마지막 선택 하나로 정해짐 | 기울기가 기술을 바꾸게(전직 갈래). 장마다 끝이 다르게 |
| **Mass Effect** (2007) | 대화 바퀴로 빠른 선택. 높은 점수가 특별 대사를 열어 줌. 3편까지 이어짐 | 성격으로서의 선택 | **약 92%가 착한 쪽(미확인: 전 개발자 트윗 추정, 출시 직후 데이터)** [123]. 중간은 쓸모없음. 점수 채우기 놀이. '강아지 걷어차기' 대사 | 빛·뿔 비율을 첫날부터 재기, 보상을 같게 |
| **inFAMOUS** (2009) | 카르마가 전투 자체를 바꿈(선 = 정밀, 악 = 파괴). 시민이 돕거나 돌을 던짐. 약 200만 [124] | 평소 싸움 중에도 선악이 생김 | 이분법. 중립이면 기술이 잠김. 버튼 색(파랑·빨강)만 보고 고름 | 버튼 색이 아니라 행동 자체가 선택 |
| **Undertale** (2015) | 안 죽이기가 전투 시스템. 게임이 내 선택을 기억. 킥스타터 51,124달러(목표 5,000), 500만 장 넘음 [125] | 착함이 재밌는 놀이 | 평화 길은 경험치가 0이라 어려움. 팬이 스트리머를 괴롭힘 | '달래기' 마무리는 처치와 같은 보상. 뿔을 나쁜 아이로 몰지 않기 |
| **Black & White** (2001) | 땅·음악·신전이 선악 따라 변함. 쓰다듬고 때리며 가르치는 크리처. PC 약 250만(2006) [126] | 내가 키운 것이 나를 닮음 | 잔손질이 많고 목표가 흐림. 과대 홍보 | 내 펫이 기울기 따라 저절로 변하게(돌봄 숙제 없이) |

---

## 3. 실패와 반발에서 배울 것 → 우리 규칙과 연결

| 함정 | 실제로 다친 게임 | 우리에게 이미 있는 규칙 | 더 할 것 |
|---|---|---|---|
| **돈으로 힘** | BDO(확률 올리기·하락 막기 판매) [51], GPO(프리미엄 타이머), Diablo Immortal(한 캐릭터를 다 키우는 데 약 11만 달러, 추정) [131] | 능력치 판매 금지(A23-75), 확률 강화·자동 진행 판매 금지(A23-68) | 2배 패스가 있으니 **경험치·골드를 몰래 낮추지 않기**(D4 교훈) → §5 |
| **확률 숨김·뽑기** | MapleStory 과징금 116억 원 부과(소송 중) [43][135], RuneScape 돌림판 14년 [18], ESO 상자 [31], PS99 행운 판매 [106] | 뽑기는 나중, 문서만(GDD §10-1). 몬스터별 드롭 확률 표(P7, 있음). 주문서 창 확률·실패 결과(있음, Panels.luau:2240, 2515). Roblox는 유료 랜덤 아이템 확률을 합 100%로 공개하게 함 [129] | 확률이 바뀌면 News 'Odds changes'에 날짜로 기록(제안 2) |
| **갑자기 바꾸기·소급** | Lineage M(MAU 약 -20%) [39], D4 1.1 [68], GW2 Ascended [21], WoW 빌린 힘 | 없음 | 유료 상품은 7일 전에 알리고 소급하지 않기(제안 16, 결정 3) |
| **숫자 벽·노가다** | King Legacy Lv5,450, Blox Fruits 80~120시간 [90], Lost Ark 아이템 레벨 벽 [132], Genshin 레진 [76] | "노가다는 덜 지루하게"(GDD §0-1). 유적 일일 띠(계획) | 레벨 상한을 부풀리지 않기. 메인 이야기를 장비 점수로 막지 않기 |
| **약자 사냥·독한 PvP** | Lineage PK, EVE 학살·사기, Deepwoken 영구 삭제 | 깡패 규칙, 새싹 보호(Lv15/60분), 졸업 유예 60초, 대담함 배율, 원한 자루 120%, 우편 | 지금 규칙으로 충분해요. **아이템 떨굼·영구 삭제는 앞으로도 금지** |
| **진영 쏠림·빈 서버** | WoW(명예의 전당 100 대 12) [4], Aion(14개 서버 중 3개만 균형) [58] | 덩치 저울(작은 편 1.0~1.6배), 처음 약한 편을 고르면 300골드, 환생 약자 보너스 40%, 서버 진영 인원 기록(ServerPopulation) | 비율을 매일 보고 **작은 편을 올리는 방향으로만** 맞추기(제안 4). 이기는 편을 노리는 중립 몬스터(제안 12) |
| **업데이트 공백·갈아엎기** | Arcane Odyssey 1년 넘는 공백(팬 기록) [97], Vesteria 재작성 [102], Bee Swarm 침묵, WoW 첫 큰 패치까지 217일 [6] | 없음(내부 토요일 보고만 있음) | 업데이트 요일 약속(제안 6, 결정 2). 베타 뒤에 엔진을 다시 짜지 않기 |
| **산 것·한 것 지우기, 가짜 한정** | Destiny Content Vault [83], Fisch 두 번째 바다 삭제·재고 다시 풂 [108] | 핼러윈 "매년 돌아와요"(P10), 사탕 단지는 시즌 뒤에도 열림, 한정 시간 상점 없음(A23-68), 오프닝 다시 보기(A23-9) | 산 것은 지우지 않고 효과를 몰래 줄이지 않기. 날짜가 박힌 기념 칭호·배지는 예외 → §5 |
| **돈으로 친구 나누기** | Club Penguin 회원 전용 방 [112], Wizard101 구역 판매 [115], Toontown 좁은 무료 구역 | 번 모양 ≠ 산 모양(A23-75), 가방 칸 판매 금지(A23-72) | VIP 혜택은 A23-75 목록(이름 옆 왕관·채팅 VIP 표시·전용 감정 표현·후원자 게시판)까지만. 개인 서버(A23-75 ⑤)는 사용자 결정대로 둠. **공개 서버 안 유료 전용 구역은 절대 안 됨** |
| **큰 행사 날 서버 붕괴** | AQW(20초 만에 다운) [118], D3 Error 37, PoE2 대기열 | 여러 명 테스트(베타 필수 8) | 핼러윈 첫날 몰림 시험 + DataStore 예산 로그(제안 3) |
| **과대 약속** | Fable(사과) [119], Black & White '가장 과대평가된 게임' [126] | 없는 보상 안내 금지(AGENTS) | 개발 일지 영상과 게임 설명에도 **아직 없는 기능은 약속하지 않기** |

---

## 4. 우리 게임에 옮기기 (가장 중요)

### 4-1. 선악이 보이게 — Fable·KOTOR·inFAMOUS·Undertale·Mass Effect·Black & White가 가르쳐 준 것

1. **보이기만 하면 얕아요(Fable).** 후광·뿔 계급은 이미 커져요. 그런데 모양만 바뀌어서는 오래 못 가요. 값·대사·기술·이야기 중 하나는 바뀌어야 해요. → 제안 8·11·17
2. **버튼 색으로 고르게 하지 말고 행동으로 고르게(inFAMOUS).** 선택 카드 말고도 사냥하는 손이 곧 선택이 되게 해요. → 제안 9
3. **안 죽이는 길도 같은 보상(Undertale).** 착한 길이 손해면 아이들은 '착한 척'만 해요. → 제안 9
4. **두 편의 보상을 같게, 다르게(Mass Effect 약 92%, 전 개발자 추정).** 아이들은 더 이득인 쪽으로 몰려요. 비율을 재고 작은 편을 올려요. → 제안 4·5
5. **결과는 남기고, 되돌리기는 행동으로(KOTOR·Deepwoken).** A23-58(자기 편답지 않은 선택은 감점)과 계급이 내려가면 착한 일로 되찾기 = 이미 있어요. 돈으로 되돌리기는 영원히 금지예요.
6. **내 것이 나를 닮게(Black & White).** 펫처럼 내가 가진 것이 저절로 기울기를 보여 줘요. → 제안 10
7. **뿔은 '나쁜 아이'가 아니라 '장난꾸러기 라이벌'(Undertale 팬 괴롭힘, Mass Effect 강아지 대사).** 문구에 설교와 수치심이 없어야 해요. → §5

### 4-2. 이미 있거나 계획된 것 (새 제안 수에 넣지 않아요)

| 다른 게임에서 배울 점 | 우리 상태 |
|---|---|
| 함께 때린 사람 모두 보상(GW2·Toontown) | **있음.** 15초 창, 몬스터가 내 근처에 다시 생김(A7-1) |
| 작은 진영 보너스(WoW Call to Arms·Aion) | **있음.** 덩치 저울, 약한 편 가입 300골드, 환생 약자 40% |
| 카르마 이름 색·되갚기(Lineage II) | **있음.** 현상수배 별, 3별부터 빨간 빛, 깡패 규칙, 원한 자루 120%·우편·유령 붙잡기 |
| 약속 시간 편 대결(Lineage·RO·Aion) | **있음.** 10분 왕관전, 이긴 편 축복 25%, 거위, 괴수화 |
| 커지는 날개·후광(MU·Fable) | **있음.** 계급 R1~R5(A23-54) |
| 새싹 표시(FFXIV) | **있음.** 이름표 'Sprout Shield / Grace' |
| 파괴 없는 강화(MU 반대) | **있음.** 하락은 최대 1단계(A23-11) |
| 드롭 확률 공개(MapleStory 반대) | **있음.** 몬스터별 드롭 표(P7) |
| 주문서 창 확률·실패 결과(MapleStory 반대) | **있음.** Panels.luau:2240, 2515(성공 확률, 실패 때 한 단계 하락 확률, "Weapons never break!"), 도움말 Scrolls 주제 |
| 강화 직후 나가기 지표 | **있음.** EnhanceFailLeave(TelemetryService.luau:17) |
| 실패 쌓기(BDO) | **계획.** skills_weapons_pets §1 정식 '운 나쁠 때 보장(기운 %)'. 수치 제안 1개당 +2%, 최대 +10%. A23-11이 바뀌므로 EnhanceFailLeave 지표를 본 뒤 사용자에게 물음. 화면 이름은 'Luck Charge'처럼 Ember가 아닌 것으로(R5 불씨 효과·R2 'The Ember Thief'와 겹치지 않게) |
| 게임 안 '이번 주 새것'(PS99·AQW 박자) | **있음.** News 'New this week'(Config.luau:3624) |
| 쉬면 보너스(WoW 휴식 경험치) | **있음.** 휴가 보상 |
| 끊겨도 0 안 되는 출석(Genshin·Lineage 숙제 반대) | **계획.** A23-77 |
| 멈춤 카드·Welcome back·배지 8개·친구 초대·대왕 일기·알림 동의 | **계획.** A23-79 |
| 진영 주간·무기고·조각 길·봉인된 무덤·**새싹 구조 신호**(EVE·FFXIV)·스쿼드 | **후보.** A23-79 베타 뒤 후보, 사용자 선택 전(retention_round 5~10) |
| 마을 사람 눈치·선택 잔광(Fable 마을 반응) | **계획.** A23-64 ①② |
| 구조 방울 = 쓰러진 친구 일으키기(GW2) | **계획.** creative #5(정식) |
| 반반 젤리·약속 끈·다 같이 쿵 = 빛·뿔 협동(Swordburst·Pokémon) | **계획.** creative #3·9·10(정식) |
| 별자리 망원경 = 내 선택 기록(Mass Effect·Black & White) | **계획.** creative #8(정식) |
| My Way 이름(KOTOR 정체성) | **계획.** A23-79 |
| 처음 겪는 순간 안내: 첫 쓰러짐·첫 PvP(EVE 첫 손실) | **계획.** BB24 |
| 말 없는 신호 6개(Toontown 정해진 채팅) | **계획.** P4 |
| 보스 재료 제작(Monster Hunter) | **계획.** GDD §0-1, 장인 업데이트 |
| 개인 자원(GW2) | **있음(설계).** gathering_2026-10-06 §1 나만의 쿨다운 180초, §5 재료 빼앗기 없음, 장인 업데이트 |
| 펫이 기울기를 닮음(Black & White) | **계획.** 저장에 펫 Lean 있음(PetService.luau:2). skills_weapons_pets §2 [보살펴요]/[내 졸개로 삼아요], 정식 Lv10 진화 모습(천사·악마·균형)·PetForm. 앞당기기는 제안 10 |
| 성숙도 설문 답안(Roblox 게시 규칙) | **계획.** RELEASE_PLAN 41·73줄(답안은 세션이 준비, 제출은 사용자). 제안 1과 일부 겹침 |
| 비밀 조각 12개(Genshin) | **후보.** psych 6a. A23-76 땅을 다시 만들 때 자리만 비워 두기를 추천 |
| 몬스터 도감(Fisch·Pokémon) | **후보.** psych 11a |
| 경매장 안전 규칙(D3·PS99 사기) | **계획.** 정식, painpoints §4 |

### 4-3. 새 제안 17개

번호는 처음 판 그대로 둬요. 14·19는 이미 있거나 계획된 것이라 §4-2로 옮겼어요. 2는 §4-2 '주문서 창 확률(있음)'에 붙는 News 한 줄이라 수에 넣지 않아요.

크기: S = 1일 이하, M = 2~3일, L = 4일 이상. 수치는 모두 **제안값**이에요. 언제: **베타 전**(10/24 기능 마감 전, 작은 것만. 시험은 10/25~30) / **베타 후~정식**(11/01~12/19) / **정식 뒤**.

| # | 무엇(게임 안 모습) | 어디서 왔나 | 왜 우리에게 맞나(선악 핵심) | 언제 | 담당 | 크기 |
|---|---|---|---|---|---|---|
| 1 | **Roblox Kids·Select 문 열기:** 사용자가 본인 나이 확인(신분증), 2단계 인증, 1,000 Robux 보증금 또는 Plus/Premium 2달, 성숙도 설문(Minimal·Mild 목표)을 하고 베타 게시 날부터 평가 시계를 시작해요. 게시 체크리스트에 줄을 더해요 | Roblox 2026-06-16 규칙 [127][128][133] | 선악 기울기를 느낄 9~15세가 들어올 **유일한 문**이에요. 없으면 16세 이상만 들어와요 | 베타 전 | 사용자(인증·돈), 검수(체크리스트·설문 답안) | S |
| 2 | **News 'Odds changes' 한 줄(수에 안 넣음):** News 창(Config.Help.News, Config.luau:3625)에 'Odds changes' 칸 1개(바뀐 날짜·전→후). 도움말 Scrolls는 4줄 상한이라 건드리지 않음. 주문서 창 확률·실패 결과는 이미 있음(§4-2) | MapleStory 큐브 [43], Roblox 확률 공개 [129] | 강화는 '욕심' 순간이에요(왕관을 깬 것도 욕심, A23-55). 숨기지 않아야 믿어요 | 베타 전 | 검수(문구), 게임성 개발 1(Config.Help.News) | S |
| 3 | **핼러윈 첫날 몰림 시험:** 다인 시험 + DataService 저장과 대왕·거위·왕관 보상 지급 때 DataStore 예산 로그(RankingService.luau:123 방식) + 서버 최대 인원 확인. 로그 코드는 10/24 전에 병합하고, 시험은 10/25~30 | AQW 20초 다운 [118], D3 Error 37, PoE2 대기열 | 거위 구조·대왕처럼 두 편이 함께하는 순간이 첫인상이에요. 그때 저장이 막히면 핵심을 못 느껴요 | 베타 전(10/25~30 시험 주) | 게임성 개발 3(로그·예산), 게임성 개발 1(메인 Studio 시험) | S |
| 4 | **진영 쏠림 규칙:** 매일 새 진영 선택 비율과 계급 분포를 하나의 표로 봐요(ServerPopulation 기록은 있음). 한쪽이 3일 연속 70%를 넘으면 **작은 편 혜택만 올리고** 큰 편은 깎지 않아요. 숫자를 바꿀 때는 사용자 확인. 게임성 개발 3: 커스텀 이벤트 FactionPick(필드: Halo/Horns, 처음 고름/제단/환생)과 RankDist(ServerPopulation과 같은 5분 틀)를 10/24 전에 넣음. 표는 Creator Hub Analytics에서 검수가 매일 읽음 | Mass Effect 약 92%(미확인) [123], WoW [4], Aion [58] | '천사냐 악마냐'는 두 편이 다 살아 있어야 재밌어요 | 베타 전(이벤트), 베타 중(판단) | 게임성 개발 3(이벤트), 검수(표 읽기·판단) | S |
| 5 | **업데이트마다 빛 1 + 뿔 1(장인 업데이트 뒤에는 + 장인 1).** A23-54·A23-46·A23-75의 '같은 무게' 관행을 규칙으로 적음 | Blox Fruits(새 힘), Mass Effect(한쪽만 보상) | 어느 편을 골라도 손해가 아니라는 느낌을 지켜요 | 베타 후~정식(규칙, 0일) | 검수 | S |
| 6 | **토요일 업데이트 박자:** 베타 뒤 매주 토요일 11:00 KST(베타 공개 시각과 같음)에 퀘스트·게시판 일·물건·고친 것 중 1~2개(새 몬스터는 3D 승인이 끝난 것만). 이미 있는 News 'New this week' 칸을 갱신. 같은 내용으로 짧은 개발 일지. 시계 숫자와 카운트다운은 없어요. 핼러윈 종료는 서버가 11/09에 자동으로 함(HW-13). 그래서 A23-79 #5 묶음을 11/14(토)로 옮길지 결정 2와 함께 사용자에게 물음 | PS99 토요일 [105], AQW 금요일, Club Penguin 매달, Arcane Odyssey 공백 [97] | 진영 대결은 '다음 주에 또 뭔가 온다'가 있어야 이어져요 | 베타 후~정식 | 검수(달력), 촬영 편집(영상), 모든 세션 | S(운영) |
| 7 | **코드 칸:** 설정에 'Codes'를 둬요. 업데이트 영상마다 코드 1개. 코드는 끝나지 않음(지난 코드도 계속 됨, 1인 1회). 보상은 물약 3 + Enh70 1(경험치 배수와 능력치는 없음). 코드 이름은 빛·뿔 짝(예: HALOHUG / HORNSGRIN)이고 받는 것은 같아요. 게임 안에 YouTube를 가리키는 문구는 넣지 않고, News 창에 '이번 주 코드'도 적어서 영상을 못 보는 아이도 받게 함 | Blox Fruits 코드 = 홍보 [89] | 개발 일지(사용자 이야기)를 보고 온 아이가 바로 쓸 선물이에요. 두 편이 똑같이 받아요 | 베타 후~정식 | 게임성 개발 3(확인·저장), 게임성 개발 1(입력 칸), 촬영 편집 | S |
| 8 | **계급이 값을 바꾼다:** 교차로 물약 상인이 계급 R2/R3/R4/R5에 3/5/8/10% 깎아 줘요(상한 10%, 대장간 무기 값은 그대로). 빛에게는 "For a real %s!"(내 계급 칭호, Config.GetTitle), 뿔에게는 "Ooh, a real %s! Rascal price for you!"(겁먹은 상인이 아니라 팬). 두 편 숫자는 같아요 | Fable(모양만이면 얕음) [120], Lineage(상한 없는 혜택 반대) | 후광·뿔이 '세상이 나를 대하는 방식'이 돼요. A23-64 ① 눈치(말풍선)에 값을 붙여요 | 베타 후~정식 | 게임성 개발 2(가격), 게임성 개발 1(가격 표시), 검수(문구) | S |
| 9 | **마무리 카드(달래기 / 간질이기):** 왕 슬라임이 쓰러지면(HP 0, 모두에게 같은 처치) 직접 때린 기여자마다 나만 보는 카드 1장: 'The King Slime is dizzy!' [Help it hop home](젤리 선물) / [Tickle out its coins](골드). 보상 크기는 같음. 무릎 꿇기·떨기 연출은 없고, 몬스터는 모두에게 똑같이 '퐁' 사라짐. 고르든 안 고르든 처치로 세어 A23-2·A23-12 보장·퀘스트·퍼널은 그대로. 자동 전투로만 때린 사람에게는 카드 없음. 명예·악명은 하루 공통 상한(P9) 안이고, A23-58 반대 편 감점은 그대로예요 | Undertale(안 죽이기), inFAMOUS(평소 싸움 속 선악) | 사냥하는 손이 곧 선악 선택이 돼요. 착한 길도 손해가 없어요 | 정식 | 게임성 개발 2(판정·보상), 게임성 개발 1(버튼), 소리 만들기 | M |
| 10 | **PetForm 앞당기기:** 펫 자신의 Lean(Care → R1 은고리 후광, Minion → R1 작은 혹 뿔)을 0.35배로 다시 씀(새 그림 0). 의존: A23-15 P1 아기 슬라임 퀘스트 먼저 | Black & White 크리처 [126] | 기울기가 내가 가진 것에 저절로 보여요 | P1 뒤 | 게임성 개발 1(펫에 붙이기), 이미지 개발(크기·자리) | S |
| 11 | **전직 = 빛 갈래 / 뿔 갈래:** 전직(GDD §0-2 후속) 때 직업마다 빛 갈래(지키기·치유·정밀)와 뿔 갈래(광역·넉백·흡혈) 중 하나를 골라요. 세기는 같고 노는 법이 달라요. 전향 환생 때 갈래도 바꿀 수 있고, 이미 얻은 것은 잠기지 않아요 | RO 직업 나무 [46], KOTOR 힘 비용 [122], inFAMOUS 잠김 반대 | 기울기가 오래 가는 '내 플레이 방식'이 돼요 | 정식 뒤 | 검수(설계), 게임성 개발 2, 이미지 생성 2(아이콘), 이미지 개발(효과) | L |
| 12 | **욕심 젤리:** 한 편이 왕관전을 3판 연속 이기면 하늘 왕관 조각에서 회색 '욕심 젤리'가 떨어져요(몬스터라 사람을 털지 않아요). 교차로 분수 옆(안전 지대)에 떨어져서 새싹도 같이 싸움. 두 편 누구나 같이 때리면 모두 상자. 3분 안에 못 잡으면 '젤리가 축복을 먹어' 다음 판 이긴 편의 +25% 축복이 없음(두 편 같음). 몬스터 포위전(Siege)이나 Idle 판은 연승으로 세지 않음 | Aion 발라우르 [57] | 이야기(A23-55: 욕심이 왕관을 깼다)와 딱 맞는 따라잡기 장치예요. 벌 대신 같이 싸울 이유가 생겨요 | 정식 | 게임성 개발 1(스폰 자리, A23-45 방식), 게임성 개발 2(왕관전 판정·몬스터), 이미지 생성 1(큰 슬라임 색만 바꿔서 0), 소리 만들기 | M |
| 13 | **스쿼드 안 레벨 맞춰 올리기:** 스쿼드(A23-79 베타 뒤 후보, 사용자 선택 먼저) 팀원이면 친구 여부와 상관없이, 새 PvE 섬(A23-53)과 Shard Vault(제안 18)에서만 낮은 쪽이 몬스터 상대로 그 구역 권장 레벨까지 올라가요. 보상·드롭 배수 없음. PvP 힘·구역 레벨 제한은 그대로 | ESO One Tamriel [29], FFXIV 레벨 맞추기 | 빛 친구와 뿔 친구, 언니와 동생이 같이 놀 이유가 생겨요 | 정식 뒤 | 게임성 개발 2, 게임성 개발 1 | L(스쿼드 포함) |
| 15 | **경매장 맡김·장부:** 경매장 1단계(재료·주문서): 올리는 순간 판매자 저장에서 UpdateAsync로 먼저 빼서 맡겨 두고, 정산은 원자적으로 한 번에 하고, 거래 장부(무엇·몇 개·언제)를 남김. 크기 M. 무기 일련번호·출처는 무기를 올리는 2단계에서 Data v4와 함께 함(L) | Diablo II 복사 [63] | 털고 되찾는 선악 경제가 복사로 망가지지 않게 지켜요 | 정식 전(경매장 전) | 게임성 개발 2 | M(1단계), L(2단계) |
| 16 | **유료 상품 바뀜 규칙 + 'Changes' 줄:** 2배 패스·VIP·치장의 효과나 값이 바뀌면 7일 전 뉴스에 적어요. 이미 산 사람에게 불리하게 소급하지 않고, 불리하면 보상해요 | Lineage M [39], D4 1.1 [68], GW2 [21] | 돈을 낸 아이와 부모의 믿음을 지켜요(규칙 = 돈 → 결정 3) | 베타 전(규칙), 베타 후(뉴스 줄) | 검수(규칙), 게임성 개발 1(뉴스 줄) | S |
| 17 | **보스 큰 공격 미리 보이기:** 대상: 왕 슬라임·고블린 우두머리·해골 기사(호박 대왕은 내년 핼러윈). 바닥 원 표시 1개(2초, 둥근 원, 빛살 없음). 피하면 3초 '빈틈'이 생겨 더 아프게 맞아요. 지금 몬스터 공격 예고(0.28초)는 그대로 두고, 보스용 큰 공격만 더해요. 큰 공격은 기존 Slash를 느리고 크게 재생하거나 새 동작 1개(이미지 생성 1, 크레딧 먼저) | Monster Hunter, Lost Ark | 빛은 치유로 친구를 지키고, 뿔은 빈틈을 노려요. 편마다 역할이 생겨요 | 베타 후~정식 | 게임성 개발 2, 게임성 개발 1, 이미지 개발(바닥 원), 이미지 생성 1(새 동작일 때) | M |
| 18 | **5~8분 던전 'Shard Vault':** 쉬움·보통·어려움. 주문서와 무기가 떨어져요. 가운데 갈림길: 우리에 갇힌 아기 거위 풀어 주기(빛) / 잠긴 보물 상자 자물쇠 따기 경주(뿔). 아기 거위는 어느 쪽을 골라도 결국 스스로 나와 둥지로 가요(아무도 다치지 않음). 보상 크기는 같음 | Dungeon Quest [99], World // Zero | 폰에 맞는 '한 판 더' 고리에 선악 선택이 들어가요 | 정식 뒤 | 게임성 개발 2, 게임성 개발 1, 이미지 생성 1 | L |
| 20 | **장마다 끝이 기울기 따라 갈림:** 4장부터 장 마지막 대사와 보상 모양이 내 My Way 이름(True Knight·Rebel Angel·Proud Rascal 등)에 따라 2~3갈래로 달라져요. 의존: A23-79 #2 My Way 이름 먼저(아직 src에 없음) | KOTOR 마지막 선택 하나 문제 [122] | 지금까지 한 일이 이야기에 남아요(A23-52 이야기 깊어짐) | 정식 | 검수(문구), 게임성 개발 2(데이터), 게임성 개발 1(NPC·연출), 이미지 생성 2(보상 모양 그림) | M |

**베타 전: 1·3(시험+로그)·4·16 + #2 News 한 줄.** 모두 작고, 대부분 규칙·글자·시험이에요. 기능 마감(10/24)을 밀지 않아요. 11/14(토) 후보: 7·8. #10은 P1 펫 뒤.

---

## 5. 하지 말 것 5개

1. **능력치(공격·체력·스탯 포인트)와 확률(확률 올리기·하락 막기·행운)은 Robux로 팔지 않기**(A23-75, A23-68). 2배 패스는 속도 상품이고 레벨·랭킹에 그대로 들어간다(A23-75). 게임 설명·영상에 'no pay-to-win'이라고 쓰지 않는다. Robux 알·뽑기는 GDD §10-1대로 사용자가 설계할 때까지 만들지 않고, 만들 때는 확률 공개·PolicyService·무료로 얻는 길을 지킨다. 가방 칸 판매 금지(A23-72).
2. **몰래 바꾸거나 소급하지 않기.** 확률이나 패스 효과를 바꾸면 미리 알려요. 2배 패스를 판 뒤 경험치·골드 비율을 낮추면 아이들은 "패스 사라는 거네"로 읽어요(D4 1.1). 맞추고 싶으면 약한 쪽을 올려요. MapleStory 과징금 부과(소송 중), Lineage M 트럭 시위가 그 결과였어요. (돈 규칙이라 §6 결정 3에서 A를 고르면 규칙이 됨. 그 전까지는 검수 추천.)
3. **산 것은 지우지 않고 효과를 몰래 줄이지 않기.** 시즌 몬스터·사탕 칭호는 P10대로 해마다 돌아온다. 날짜가 박힌 기념 칭호·배지(Beta Pioneer, Halloween 2026, Party Guest 2026)는 그때 함께한 사람의 기념이라 예외다. 한정 시간 상점은 아예 없다(A23-68). 오프닝 다시 보기(A23-9)는 계속 둔다.
4. **돈이나 진영으로 친구를 가르지 않기.** 공개 서버 안의 유료 전용 방, 구역 판매, 다른 편 친구와 PvE를 못 하게 막기가 다 해당돼요(Club Penguin, Wizard101, WoW 약 17년 반). 개인 서버(A23-75 ⑤, Roblox 기본 기능)는 사용자 결정대로 둔다. 금지는 '공개 서버 안의 유료 전용 구역·방·NPC'뿐. VIP 혜택은 A23-75 목록(이름 옆 왕관·채팅 VIP 표시·전용 감정 표현·후원자 게시판)까지만. 규칙: 번 모양 ≠ 산 모양(A23-75).
5. **뿔을 '진짜 나쁜 아이'로 만들거나 약자 사냥이 이득이 되게 하지 않기.** 뿔 행동은 장난, 경쟁, 되갚을 수 있는 털기까지예요. 약한 NPC 괴롭히기, 무서운 장면, 설교와 수치심이 담긴 문구는 쓰지 않아요(Mass Effect '강아지 걷어차기', Undertale 팬 괴롭힘, EVE 학살). 규칙: 깡패 규칙, 새싹 보호, A23-58의 가벼운 문구, AGENTS 아이 안전.

---

## 6. 사용자가 고를 것 (3개)

**1. Roblox 아이 계정 문 열기 — 돈 + 일정**
- 할 일: 사용자 본인 나이 확인(신분증)과 2단계 인증이 필요해요. 그리고 아래 셋 중 하나를 골라요.
  - A) 1,000 Robux 보증금. 자격이 생기고 90일 뒤 돌려받아요. 자격을 못 받아도 낸 날로부터 90일 뒤 돌려받아요 [133].
  - B) Roblox Plus/Premium을 2달 연속 유지(무료 Plus 6개월을 이미 받았다면 유지하는 동안 수수료 없음) [133]
  - C) 안 함. 이러면 16세 이상만 들어와요.
- **추천: 이미 Premium이 있으면 B, 없으면 A.** 베타 게시 전에 끝내야 평가 기간이 베타 동안 흘러요. 빠른 심사비는 출처마다 5만 또는 10만 Robux라서 추천하지 않아요.
- 알아 둘 것: 자격이 생길 때까지 13~15세 친구는 초대해도 못 들어와요. 그래서 베타 첫 홍보(쇼츠)는 16세 이상을 보고 만드는 게 맞아요.

**2. 업데이트 박자 — 일정**
- A) 베타 뒤 **매주 토요일 11:00 KST에 작은 업데이트**(퀘스트·게시판 일·물건·고친 것 중 1~2개)
- B) 2주마다
- C) 정하지 않음
- **추천: A.** 매주 내는 Sailor Piece가 2026년 3월 한때 동시 접속에서 Blox Fruits를 앞질렀고(rowatcher) [91], 오래 쉰 게임은 무너졌어요. 게시 OK는 매주 사용자가 해요. 작게 내서 부담을 줄여요.
- 같이 물을 것: 핼러윈 종료는 서버가 11/09에 자동으로 해요(HW-13). 그래서 A23-79 #5 묶음(11/09 월)을 토요일 박자에 맞춰 11/14(토)로 옮길까요? (제안 6)

**3. 유료 상품을 바꿀 때의 약속 — 돈**
- A) "2배 패스·VIP·치장의 효과나 값을 바꾸면 7일 전에 게임 안에서 알리고, 이미 산 사람에게 불리하게 소급하지 않으며, 불리하면 보상한다"를 규칙으로 정함
- B) 그때그때 정함
- **추천: A.** 돈을 낸 아이와 부모의 믿음은 한 번 깨지면 오래 가요. Lineage M은 안드로이드 MAU가 한 달 새 약 20% 줄었고, D4는 유저 점수가 4.8에서 3.7로 떨어졌어요.

---

## 7. 출처

(미확인) = 회사 주장, 팬 자료, 검색 미리보기, 또는 출처끼리 숫자가 다른 것.

1. WoW 구독 1,200만(2010-10-07): https://investor.activision.com/node/18936
2. WoW 550만 뒤 숫자 공개 중단: https://gamespot.com/articles/blizzard-will-no-longer-report-world-of-warcraft-s/1100-6431943/
3. War Mode·Call to Arms +20%: https://warcraft.wiki.gg/wiki/War_Mode
4. 2019 명예의 전당 호드 100 / 얼라이언스 12: https://blizzardwatch.com/2019/11/18/post-mortem-wows-raiding-hall-fame-need-cross-faction-pve/
5. 진영 넘는 던전 9.2.5(2022): https://worldofwarcraft.blizzard.com/en-us/news/23761709/
6. 어둠땅 출시에서 9.1까지 217일: https://gamespot.com/articles/wow-shadowlands-patch-9-1-chains-of-domination-finally-arrives-june-29/1100-6493052/
7. 5분 안 첫 퀘스트(Pardo 2006): https://www.engadget.com/2006-09-07-rob-pardos-keynote-at-the-austin-game-conference.html
8. 휴식 경험치를 보너스로: https://www.gamedeveloper.com/pc/gdc-blizzard-s-core-game-design-concepts
9. FFXIV 다시 만들기: https://gdcvault.com/play/1032358/Behind-the-Realm
10. 무료 체험 Lv70: https://fullcleared.com/news/final-fantasy-xivs-free-trial-is-expanding-to-include-stormblood/
11. 등록 3,000만(등록 기준): https://techraptor.net/gaming/news/final-fantasy-xiv-passes-30-million-players-as-xbox-open-beta-gets-tentative-release
12. 2021 판매 중단: https://automaton-media.com/en/news/20211216-7635/
13. 멘토 보상 일부러 작게: https://blog.playstation.com/?p=169035
14. RuneScape 누적 30억 달러: http://www.pocketgamer.biz/runescape-surpasses-3bn-in-lifetime-revenue-as-jagex-marks-25th-anniversary/
15. OSRS 투표 449,351표: https://oldschool.runescape.wiki/w/Old_School_RuneScape
16. 투표 기준 75%→70%: https://oldschool.runescape.wiki/w/Update:Warding_Poll_Results
17. 결투 판돈 제거(2022): https://oldschool.runescape.wiki/w/Emir's_Arena
18. Treasure Hunter 제거 12만 표 넘음(2026-01-19): https://www.jagex.com/news/the-players-have-spoken-runescape-treasure-hunter-microtransactions-to-be-removed-january-19th
19. GW2 이벤트 전원 보상: https://wiki.guildwars2.com/wiki/Event
20. GW2 2주 200만·판매 중단: https://www.pcgamer.com/uk/guild-wars-2-sells-2-million
21. Ascended 장비 사과: https://www.engadget.com/2012-11-26-guild-wars-2-staff-tackles-the-ascended-gear-controversy-head-on.html
22. 환전 최소 400젬: https://kotaku.com/guild-wars-2-players-angry-over-currency-exchange-chang-1649519173
23. EVE 구독 50만(2013): https://shacknews.com/article/78020/eve-online-passes-500000-subscribers
24. EVE 신규 절반 이상 2시간 안 이탈: https://destructoid.com/?p=206617
25. EVE 챙겨 준 신규 2배 잔류: https://primagames.com/featured/how-eve-online-is-solving-its-new-player-problem-ccp-interview
26. EVE 첫 배 손실 알림: https://techraptor.net/gaming/news/ccp-games-announce-eve-online-grief-counseling-for-new-players-losing-first-ships
27. EVE 2011 감원 약 20%: https://www.mcvuk.com/ccp-staff-cuts-were-my-responsibility-says-ceo/
28. ESO 접속 두 배·누적 약 20억 달러: https://mein-mmo.de/en/elder-scrolls-online-war-einst-ein-flop-das-brachte-die-wende,1112804
29. One Tamriel: https://www.pcgamesn.com/the-elder-scrolls-online-tamriel-unlimited/teso-one-tamriel%20
30. ESO 2,400만: https://insider-gaming.com/elder-scrolls-online-24-million-players/
31. Crown Crates: https://massivelyop.com/2016/12/07/tamriel-infinium-elder-scrolls-online-juggles-making-money-and-making-content-with-crown-crates/
32. Lineage 첫 200만 구독: https://www.gamedeveloper.com/business/beyond-lineage-jake-song-goes-xl
33. Lineage 북미 종료 2011: https://en.wikipedia.org/wiki/Lineage_(video_game)
34. (미확인, 팬 위키) 세금 상한 없음: https://breezewiki.discard.no/gamicus/wiki/Lineage
35. 리니지2M 3개월 1억 5,200만 달러: https://www.pocketgamer.biz/lineage-2-m-152-million-usd-in-three-months
36. (미확인, 숫자 충돌) Lineage II 1,400만 vs 61만: https://www.engadget.com/2010-06-27-looking-back-at-six-years-of-lineage-ii.html
37. 리니지M 하루 130억 원: https://www.koreatimes.co.kr/www/tech/2017/07/134_233409.html
38. 매출 89.5% 한국: https://sensortower.com/blog/lineage-mobile-games-revenue-4-billion
39. 안드로이드 MAU 233,937→187,822(약 -19.7%, 기사 본문의 25%는 계산 오류): https://cm.asiae.co.kr/en/article/2021041409341275394
40. NC 매출 80% 리니지: https://www.koreajoongangdaily.com/business/lineage-w-tops-game-charts-though-response-remains-mixed/10661017
41. 메이플 13~17세 50%·선불카드·결혼 5만: https://www.gamedeveloper.com/game-platforms/agdc-nexon-s-min-kim-on-the-power-of-microtransactions
42. 메이플 등록 9,200만(2009): https://www.animenewsnetwork.com/press-release/2009-08-19/nexon-america-announces-record-breaking-july-increases-revenues-35-percent-over-july-2008
43. 큐브 과징금 116억 원 부과(2024-01-03): https://www.kedglobal.com/newsView/ked202401030012
44. 보상 219억 원·약 80만 명: https://www.koreajoongangdaily.com/business/nexon-to-pay-16m-to-compensate-maplestory-players-for-rigging-loot-boxes/12373947
45. PC방 점유 20% 대: https://www.invenglobal.com/articles/22072/nexon-strengthens-maplestory-ip-appoints-kim-chang-seop-as-deputy-director
46. RO 직업 13→50+: https://en.wikipedia.org/wiki/Ragnarok_Online
47. RO 필리핀 680만·동시 57,000: https://gameindustry.ph/article/philippine-ragnarok-online
48. (미확인, 회사 홍보) RO 2,500만: https://gameindustry.ph/reference/oy43xl/show
49. (미확인, 회사 주장) 라그나로크M 월 최대 5,000만 달러: https://www.pocketgamer.biz/southeast-asia-powered-gravitys-ragnarok-m-to-50-million-a-month
50. BDO 20억 유로·5,500만: https://gamedeveloper.com/business/black-desert-online-nets-2-billion-and-55-million-players
51. BDO 펄 상점 항의: https://techraptor.net/content/black-desert-online-players-protest
52. 로스트아크 스팀 1,325,305: https://newsroom.smilegate.com/eng/1644972999
53. 로스트아크 봇 100만+ 정지: https://www.nme.com/news/lost-ark-surpasses-20million-global-users-3178152
54. 초반 엔드게임 너프: https://gamespot.com/articles/lost-ark-early-endgame-content-is-being-nerfed/1100-6501240/
55. 아이온 오픈베타 동시 17만: https://www.engadget.com/2008-11-14-aion-tower-of-eternity-breaks-all-beta-test-records-in-korea.html
56. 아이온2 46일 1,000억 원: https://sports.khan.co.kr/en/article/202601071101497 · DAU 150만(회사 발표, 2025-11-21): https://www.ddaily.co.kr/page/view/2025112115521118444
57. 발라우르가 우세 진영 공격: https://www.engadget.com/2009-10-08-exclusive-interview-with-aion-producer-brian-knox.html
58. 북미 14개 중 3개 균형: https://www.engadget.com/2009-11-13-aion-live-server-numbers-crunched.html
59. 2011 균형 보너스: https://www.engadget.com/2011-06-27-wings-over-atreia-bribing-for-balance.html
60. MU 등록 5,600만: https://www.engadget.com/2009-04-20-global-mu-online-begins-season-4-beta-testing-with-webzen.html
61. 웹젠 매출 77% MU: https://mmos.com/?p=166869
62. MU +10 실패 파괴: https://muonline.webzen.com/en/gameinfo/guide/detail/32
63. 디아블로2 400만: https://gamesfirst.com/articles/2001/diablo-ii-lord-of-destruction-shatters-sales-records-worldwide-with-over-1-milli/
64. 디아블로3 첫 주 630만: https://investor.activisionblizzard.com/node/20231
65. 경매장 대부분 사용: https://www.engadget.com/2013-03-28-diablo-iiis-auction-house-really-hurt-the-game.html
66. 경매장 폐쇄 2014: https://bit-tech.net/news/gaming/pc/diablo-iii-auction-house/1/
67. 디아블로4 5일 6억 6,600만 달러: https://newsroom.activisionblizzard.com/p/diablo-iv-launch-sales-record
68. 1.1 패치 유저 점수 4.8→3.7: https://www.dexerto.com/diablo/diablo-4-metacritic-review-bombing-patch-1-1-2218201/
69. "not fun" 인정: https://www.nme.com/news/diablo-4-developer-on-patch-1-1-0-we-know-it-is-not-fun-3472361
70. PoE 스팀 229,337: https://sportskeeda.com/mmo/path-exile-hit-new-all-time-high-steam-player-count-july-26-update
71. PoE2 첫날 100만: https://gameworldobserver.com/?p=27229
72. PoE 튜토리얼로 잔류 안 변함: https://primagames.com/featured/path-of-exile-betrayal-interview/3
73. 원신 첫해 약 20억 달러: https://sensortower.com/blog/genshin-impact-mobile-two-billion-revenue
74. (미확인, 2026-10-08에 403으로 못 엶) 원신 연 매출 감소: https://businessofapps.com/?p=88495
75. 5성 0.6%·천장 90: https://afkgaming.com/gaming/genshin-impact/what-is-pity-in-genshin-impact-and-how-does-it-work
76. 레진 불만: https://www.keengamer.com/articles/news/genshin-impact-players-arent-happy-with-resin-update/
77. MH World 2,500만+: https://www.businesswire.com/news/home/20240312682212/de
78. Wilds 3일 800만: https://www.videogameschronicle.com/news/monster-hunter-wilds-is-the-fastest-selling-capcom-game-ever/
79. Wilds 스팀 감소: https://automaton-media.com/en/news/monster-hunter-wilds-is-losing-players-faster-than-predecessors-but-upcoming-content-update-may-be-what-puts-it-back-on-track/
80. SOS 때문에 모임 장소가 빔: https://game.info.intel.com/gaming-access/an-exclusive-chat-with-capcoms-ryozo-tsujimoto-about-monster-hunter-worlds-pc-debut
81. 데스티니2 무료 전환 약 22만: https://gamingbolt.com/destiny-2-enjoys-impressive-steam-debut-with-peak-concurrent-player-count-of-220k
82. 데스티니2 라이브 개발 종료: https://gamedeveloper.com/business/destiny-2-s-active-development-will-end-in-june
83. Content Vault: https://mein-mmo.de/en/destiny-2-cuts-2-years-of-content-that-players-have-paid-for,539665
84. 포켓몬 소프트 4억 8,000만+: https://www.tweaktown.com/news/91618/pokemon-franchise-has-sold-over-480-million-games-to-date/index.html
85. S/V 3일 1,000만: https://www.businesswire.com/news/home/20221123005476/en/Global-Sales-of-Pokémon-Scarlet-and-Pokémon-Violet-for-Nintendo-Switch-Surpass-10-Million-in-First-Three-Days
86. 두 버전 전용 포켓몬: https://bulbapedia.bulbagarden.net/wiki/Pokémon_Red_and_Green_Versions
87. S/V 평론 76 vs 유저 약 3: https://automaton-media.com/en/news/20221124-16898/
88. Blox Fruits(rolimons): https://www.rolimons.com/game/2753915549
89. Blox Fruits 교훈(naavik): https://naavik.co/digest/blox-fruits-lessons/
90. Blox Fruits 80~120시간: https://rowatcher.com/news/is-blox-fruits-worth-playing-in-2026-an-honest-review
91. 매주 내는 Sailor Piece와 비교: https://rowatcher.com/news/blox-fruits-vs-sailor-piece-which-anime-rpg-is-actually-growing-faster-in-2026
92. GPO(rolimons): https://www.rolimons.com/game/1730877806
93. King Legacy(rolimons): https://www.rolimons.com/game/4520749081
94. Deepwoken(rolimons): https://www.rolimons.com/game/4111023553
95. Roblox 혁신상 2022: https://about.roblox.com/newsroom/2022/09/roblox-innovation-awards-2022-complete-winners-list
96. Arcane Odyssey(rolimons): https://www.rolimons.com/game/3272915504
97. (팬 기록) 업데이트 공백: https://forum.arcaneodyssey.dev/t/arcane-odyssey-update-timeline-ript-controversy-discussion/160260
98. (미확인, 옛 기록 빠짐) Swordburst 2: https://www.rolimons.com/game/659222129
99. Dungeon Quest(rolimons): https://www.rolimons.com/game/2414851778
100. World // Zero(rolimons): https://www.rolimons.com/game/2727067538
101. World // Zero 인터뷰(naavik): https://naavik.co/podcast/launching-original-ip-on-roblox/
102. Vesteria 재작성 포기: https://devforum.roblox.com/t/vesteria-open-source/842436
103. Bee Swarm(rolimons): https://www.rolimons.com/game/1537690962
104. PS99(rolimons): https://www.rolimons.com/game/8737899170
105. PS99 매주 토요일: https://www.ginx.tv/en/?p=58102
106. PS99 행운·알 가격: https://screenwiseapp.com/media/pet-simulator-99-game
107. Fisch(rolimons): https://www.rolimons.com/game/16732694052
108. Fisch 회복과 문제: https://rosenberryrooms.com/roblox-fisch-fishing-comeback/
109. Toontown 10년·월 9.95달러: https://massivelyop.com/2017/11/05/the-game-archaeologist-disneys-toontown-online/
110. Toontown 포스트모템: https://www.gamedeveloper.com/disciplines/postmortem-disney-online-s-toontown
111. Toontown Rewritten 200만+: https://kidscodecs.com/disney-pulled-the-plug-on-this-game-in-2013-a-group-of-teens-kept-it-alive/
112. Club Penguin(인수·유료·90% 무결제): https://en.wikipedia.org/wiki/Club_Penguin
113. 감시자 200명: https://disneygeek.com/news/releases/2014/2014_02_06_clubpenguin_safety.php
114. Club Penguin Island 2.3: https://www.gameskinny.com/culture/club-penguin-islands-not-doing-a-good-job-replacing-the-original/
115. Wizard101(등록·구역 구매): https://en.wikipedia.org/wiki/Wizard101
116. Wizard101 가족 68%: https://www.engadget.com/2011-05-09-researchers-reveal-initial-wizard101-findings.html
117. KingsIsle 2021 예상 매출: https://investors.verve.com/regulatory-news/media-and-games-invest-plc-closing-of-the-acquisition-of-kingsisle-kingsisle-represents-new-strike-zone-2/
118. AQW 금요일 13일 다운: https://www.tentonhammer.com/news/adventurequest-worlds-pulls-off-major-friday-the-13th-event-despite-technical-problems
119. Fable(판매·후광·뿔): https://en.wikipedia.org/wiki/Fable_(2004_video_game)
120. Fable 도덕 시스템 비판: https://gamedeveloper.com/design/morality-systems-in-video-games-a-flawed-design-
121. Fable 리부트에서 빠짐: https://gamingbolt.com/fable-lacking-the-classic-morality-system-is-a-real-shame-says-peter-molyneux
122. KOTOR: https://en.wikipedia.org/wiki/Star_Wars:_Knights_of_the_Old_Republic_(video_game)
123. (미확인, 전 BioWare 디자이너 2020 트윗) Mass Effect 약 92% 착한 쪽: https://www.techspot.com/news/84131-most-mass-effect-players-chose-play-good-guy.html
124. inFAMOUS: https://en.wikipedia.org/wiki/Infamous_(video_game)
125. Undertale: https://en.wikipedia.org/wiki/Undertale
126. Black & White: https://en.wikipedia.org/wiki/Black_%26_White_(video_game)
127. **Roblox Kids·Select 문서(2026-10-08 검수 확인):** https://create.roblox.com/docs/production/publishing/kids-and-select
128. **Roblox DevForum 공지(2026-06-16, 7/16 갱신, 2026-10-08 검수 확인):** https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717
   - 평가 기준: 문서는 60일 동안 열심 플레이어 250회, 포럼 6/16 본문은 처음 들어가는 기준 500명이라 숫자가 달라요(미확인). 7/16 갱신은 유지 기준을 100→25명(60일)으로 낮춘 것이에요.
   - 빠른 심사비: 문서는 5만, 포럼은 10만 Robux예요(미확인).
129. Roblox 유료 랜덤 아이템 확률 공개: https://create.roblox.com/docs/production/monetization/paid-random-items
130. Roblox 성숙도 라벨: https://create.roblox.com/docs/production/promotion/content-maturity
131. (추정) Diablo Immortal 약 11만 달러: https://www.videogameschronicle.com/news/maxing-out-a-diablo-immortal-character-could-reportedly-cost-up-to-110000
132. 로스트아크 아이템 레벨 1370 벽: https://sportskeeda.com/esports/lost-ark-developers-confirm-upcoming-roadmap-new-classes-honing-rates-stay-unchanged-now
133. 1,000 Robux·90일 환불·Plus 6개월 무료 예외: https://devforum.roblox.com/t/alternate-publishing-requirements-for-roblox-kids-and-select/4630944
134. 리니지M 문양 롤백·다이아 환불·트럭 시위(보조 출처): https://www.inews24.com/view/1355714
135. 넥슨 과징금 취소 소송 진행(2026-10 기준 판결 전): https://news.mtn.co.kr/news-detail/2026072215222126966

원자료: 이번 워크플로의 조사 JSON 다섯 묶음(western-mmo, asian-mmo, arpg-live, roblox-rpg, kid-and-morality). [127]·[128]은 이 보고서를 쓰며 다시 열어 확인했고, [133]~[135]는 2026-10-08 사실 확인 때 더했어요. 나머지는 조사 묶음의 출처 그대로예요.
