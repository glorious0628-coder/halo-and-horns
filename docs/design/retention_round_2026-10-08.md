# 다시 오게 만들기 — 조사·순위 (검수 워크플로, 2026-10-08)
> 기록용(10/08 당시). 지금과 다른 점: 사용자는 A23-79의 5묶음만 베타 전에 고름(멈춤 카드 + Welcome back, My Way + 배지 8, 친구 초대(보상 0), 대왕 일기 + 사탕 단지, 알림 동의) — #2 유적 일일 띠는 고르지 않음(idea_backlog). 정기 업데이트는 매주 수요일 05:00 UTC, 첫 11/04 후보(A23-83). 게시판 Kind/Sneaky도 이제 Deeds 하루 6점(A23-86). 출석은 A23-77, 게임 패스는 main(a75ab917), PET-4 아기 슬라임 펫도 main(ae1fa582).
> 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

사용자: "게임성 관련해서도 어떻게 하면 사람들을 붙잡을지도 계속 생각해줘." 심리학 쪽은 `docs/design/psychology_retention_2026-10-08.md`. 이 문서 = 지금 게임 점검 + Roblox 조사 + 아이디어 2갈래(진영 대결·성장 고리) + 심판 순위. 규칙(A23-68·A23-75·A23-77) 어긴 안은 맨 아래 탈락.

## 순위 10 (효과 ÷ 품)

### 1. 친구와 같이 들어오기: 초대 + 'Go to friend' — 베타 전 가능
- 무엇: 정식으로 미뤄 둔 BB25 초대를 베타로 당겨요. 메뉴, Tab 목록, 거위·왕관전 승리 카드에 [Invite a friend]를 둬요(SocialService:CanSendGameInviteAsync → PromptGameInvite, ExperienceInviteOptions.LaunchData = 초대한 사람). 초대받은 새 친구는 오프닝, 진영, 첫 임무를 평소대로 해요. 초대한 쪽에는 'Your friend joined! [Go to friend]'가 떠서 고참이 새싹이 있는 초원으로 가요. 새싹을 고렙 구역으로 보내지 않아요. 이동 메뉴에도 [Go to friend]를 넣어요. 같은 서버에 있는 Roblox 친구의 구역 패드로 가고, Lv15 미만은 PvP 구역으로 못 가요. 전투 태그 중이거나 원한 자루를 들고 있으면 막아요. 친구가 다른 서버에 있으면 안내 한 줄만 띄워요. 초대로 들어오면 초대한 사람 서버로 가는지는 Roblox 문서로 확인해요. 서버 채우기 '최대' 설정(사용자 체크리스트)과 함께 해요.
- 언제 효과: 베타 전. 10/17 점검에서 필수 일이 끝나면 1순위예요. 첫날·첫 주
- 왜: 점검 #1에서 밖이나 친구와 이어지는 길이 0이었어요. 친구와 노는 날은 Roblox 추천에서 상위 신호예요. 거위, 왕관전, 괴수, PvP는 서버에 사람이 있어야 돌아가요. 친구와 같이 온 아이는 첫날을 혼자 헤매지 않아요. 계약(beta_basics:1506)이 이미 있어서 품이 작고, 베타 인원이 적을수록 효과가 커요.
- 품·담당: S, 약 1.0일. 개발2 0.5(초대 원격, LaunchData, 이동 검증) + 개발1 0.4(버튼, 카드) + 검수 0.1(문구). 새 그림 0장 / 게임성 개발 2(서버) + 게임성 개발 1(화면), 문구는 검수. BB25를 베타로 다시 넣는 것은 사용자 OK가 필요해요(일정).
- 규칙 확인: 초대 보상은 0이에요(A23-68 '친구 수만큼 보상 금지'). KO, 강화 실패, 구매 창 근처에는 초대 버튼을 두지 않아요. 초대 창은 Roblox 기본 창이라 13세 미만 설정을 Roblox가 지켜요. 친구에게 가기도 새싹 보호와 PvP 규칙을 그대로 따라요.

### 2. 유적 일일 띠: Lv25~49 숫자 벽 없애기 — 베타 전 가능
- 무엇: Config.Daily에 Woods(E12)와 같은 방식으로 'Ruins' 띠를 더해요. MinLevel 25, 위 제한은 없어요. 하루 3칸은 서로 다른 3분짜리 목표예요(예: Skeleton ×12, golden skeleton 1, 스킬로 해골 맞히기, 거위나 대왕 참여 1). PvP는 최대 1칸이고 Lv15 규칙 그대로예요. 보상은 HuntValue(lv,3), 상자는 HuntValue(lv,6)예요. 옛 'Defeat Skeleton ×50~60'은 더 나오지 않아요. M3_8 끝에는 'Chapter 4 is coming!' 한 줄을 넣어요. 날짜는 사용자 OK가 있을 때만 적어요. 이미 정한 '환생 무기 쳇바퀴' 수정은 Lv50까지 약 4시간이라 베타 전에 끝나 있는지만 일정에서 확인해요(새 일은 아니에요).
- 언제 효과: 베타 전. 첫째~둘째 날, 첫 주
- 왜: 기준 속도로 Lv25까지 약 95분이라 열심인 아이는 첫날이나 둘째 날 닿아요. 그 순간 일일이 25분짜리 숫자 벽으로 바뀌고(Config:3070, :3114) 메인 이야기도 끝나요(M3_8). 가장 오래 놀 아이가 가장 먼저 빠지는 절벽이에요(점검 #2). Woods 띠 코드를 다시 쓰고 Config 줄만 더하면 돼서 품에 비해 효과가 가장 커요.
- 품·담당: S, 약 0.5일. 개발2 0.4(Config 줄 + 오프라인 시험) + 검수 0.1(문구). 일일 창은 그대로 쓰고 그림은 0장 / 게임성 개발 2, 검수
- 규칙 확인: 사냥 고리는 그대로 두고 같은 숫자 벽만 없애요(GDD §0-1, 덜 갈되 0은 아님). 연속 출석이나 카운트다운이 없어요. 2배 패스는 기존 규칙대로 보상 크기에만 적용돼요. 4장 일부를 베타로 당기는 것은 사용자 결정이라 여기 넣지 않았어요.

### 3. 핼러윈 대왕 일기 + 사탕 단지 — 베타 전 가능
- 무엇: 채팅에만 나오던 9일 대왕 수다(Config:1976-1999)를 저널의 [King Diary] 책으로 옮겨요. 대왕을 함께 잡으면(RewardMinHits 그대로) 다음 쪽이 열리는데, 오늘 날짜 쪽까지만 열려요. 늦게 온 아이는 대왕을 잡은 만큼 지난 쪽을 몰아서 읽어요(연속 접속 필요 없음). 9쪽을 다 모으면 칭호 'Party Guest 2026'과 색종이를 한 번 줘요. 사탕 단지는 사탕을 칭호(예: 'Pumpkin Pal', 'Candy Keeper')로 바꿔 줘요. 지금 사탕은 5골드에 파는 것밖에 못 해요. 단지는 11/09 뒤에도 열려 있어요. 이미 정한 멈추는 카드(psych 5a)의 'Next time' 줄에 'Tomorrow: King Diary page 4'를 넣어요.
- 언제 효과: 베타 전. 10/31~11/09 핼러윈 9일, 첫날~첫 주
- 왜: 베타 9일이 바로 핼러윈이에요. 매일 바뀌는 이야기가 첫날부터 9일째까지 돌아올 열린 고리가 돼요. 글은 이미 있는데 아이들이 모를 뿐이에요(점검 §1). 사탕에 쓸 곳이 생겨서 사냥 보상도 다시 의미가 생겨요. 새 그림은 0장이에요.
- 품·담당: S, 약 1.2일. 개발2 0.6(쪽 수, 날짜 상한, 단지 교환, 시즌 끝 처리) + 개발1 0.5(기존 패널로 책과 단지) + 검수 0.1(9일째 %d 문구, IDEA-TITLE 대왕 칭호와 이름 겹침 확인) / 게임성 개발 2 + 게임성 개발 1, 검수
- 규칙 확인: 따라잡기가 있어서 연속 리셋이 없어요. 시간 숫자나 '곧 사라져요'는 쓰지 않아요. 사탕 교환은 시즌 뒤에도 열려 있어서 한정 압박이 없어요. 칭호는 번 것만 있고 팔지 않으며, 능력치는 0이에요. 색종이는 둥근 모양이고 빛살은 없어요.

### 4. 알림 동의를 베타 첫날부터 모으기 (정식 날 다시 부르기 준비) — 베타 전 가능
- 무엇: 13세 이상에게만, 기분 좋은 순간에 딱 한 번 물어요. 오늘 일일 3칸을 다 끝냈을 때나 대왕 일기 첫 쪽을 연 뒤에 ExperienceNotificationService 동의 창을 띄워요(CanPromptOptInAsync → PromptOptIn). 첫 10분, KO 직후, 강화 실패 직후, 구매 근처에서는 띄우지 않고, 거절하면 다시 묻지 않아요. 서버는 정식 날 보낼 베타 유저 UserId 목록을 남겨요. 보내기는 11/09 업데이트에서 Open Cloud 알림 API로 만들고, 키는 Secrets에 둬요. 알림 문구 틀(예: 'Chapter 4 is open!')은 사용자가 Creator Hub에서 만들어요. 13세 미만에게는 사용자가 만드는 Experience Event RSVP와 Experience Updates로 알려요. API 이름과 한도는 구현 전에 Roblox 문서로 다시 확인해요.
- 언제 효과: 베타 전에 동의만 모아요. 보내기는 11/09에 만들고 12/19 정식 날 써요. 첫 달 → 정식
- 왜: 정식 날 베타 유저를 다시 부를 길이 지금은 없어요(점검 §4). 동의는 나중에 거슬러 모을 수 없어서 베타 첫날부터 쌓아야 12/19에 쓸 수 있어요. 품이 아주 작아요.
- 품·담당: S. 베타 전 약 0.4일(개발1 0.2 동의 창 시점 + 개발2 0.2 대상 목록), 11/09에 보내기 0.5일, 그리고 사용자 Creator Hub 작업 / 게임성 개발 1 + 게임성 개발 2, 사용자(알림 문구, Open Cloud 키, 이벤트 만들기)
- 규칙 확인: 한 번만 묻고, 거절해도 잃는 것이 없어요. 진 직후가 아니고 압박도 없어요. 13세 미만은 Roblox가 막아요. 키는 Secrets에만 두고 채팅이나 커밋에 넣지 않아요(AGENTS 비밀 규칙).

### 5. 진영 주간 (Faction Week): 모두 받는 주간 고리 + 전 서버 진영 막대 — 베타 뒤
- 무엇: 왕관 주간, 진영 주문, 진영 모으기, 주제 주간, 이번 주 조각 길, 날짜 표 운영을 하나로 합쳤어요. 매주 개인 점수 30점을 넘긴 사람은 모두 Drive Chest(사냥 20분어치 + 30% 주문서 1장)를 받아요. 점수는 몬스터 10마리 1점, 큰 몬스터 1점, 일일 1칸 2점, 거위·왕관전 참여 3점, 자루 돌려주기·빼앗기 2점, 공정 PvP는 주 10점까지예요. 분수 게시판과 이벤트 칩에 전 서버 막대 'Knights' Drive 62% · Horns' Drive 48%'를 띄워요. 진영마다 목표가 따로 있고, 활동 인원당 %로 재고, 두 편 다 채울 수 있어요. 먼저 채운 편은 다음 주 하늘 왕관 빛과 분수 깃발이 자기 색이 돼요(모양만, 능력치 0). 30점을 넘긴 사람은 다음 주 주제 두 개 중 하나에 투표해요(Goose / Big King / Golden / Crown Week). 주제는 날짜 표로 숫자만 바꿔서 게시 없이 바뀌어요. 마을 벽에는 'Week 3 · Horns' 판이 쌓이고 0으로 돌아가지 않아요. 사용자 결정이 필요한 것: 상자에 명예·악명을 조금 넣어(하루 공통 상한 안) PvP를 안 하는 아이도 계급 3까지 갈 길을 열지.
- 언제 효과: 11/09 업데이트(첫 주제는 Goose Week로 미리 정해요). 첫 주~첫 달. 정식 첫날 'Launch Clash'는 이 합산 위에 검토해요.
- 왜: 점검 #3·#5: 진영 정체성이 접속과 접속 사이에 쌓이지 않고, 주간 보상은 1~3위만 받아요. GDD §0의 핵심을 주 단위로 키워요. 개인 30점은 사람이 적은 서버에서도 혼자 채울 수 있어요. 11/09~12/19의 빈 운영 달력도 게시 없이 메워요. 점수가 경험치가 아니라 행동 횟수라서 2배 패스로 진영 승부를 살 수 없어요.
- 품·담당: M, 약 2.5일. 개발2 1.5(MemoryStore 새로 들여오기, 60초 묶음 합산, 실패하면 pcall로 서버 합계, RankingService 주간 키·월요일 정산 재사용, 상자, 투표, 주제 표) + 개발1 0.5 + 이미지 개발 0.25 + 검수 0.25 / 게임성 개발 2 + 게임성 개발 1 + 이미지 개발, 검수(주제 표, 문구), 사용자(정산 시각: 월 00:00 KST면 미국 주말이 갈려요. 명예·악명 소량도 사용자 결정)
- 규칙 확인: 연속 출석이 없어요(주 1번, 30~40분이면 돼요). 카운트다운이나 한정 상점이 없고, 진 편 벌칙도 없어요. 개인 서버는 공동 막대에서 빼요(RankingService:281). 2배 패스는 상자 크기에만 적용되고 공동 점수에는 안 들어가요. 약자를 노린 PvP는 세지 않아요(PvPCreditOK만 셈). 하늘 왕관 빛은 둥근 빛이고 빛살은 없어요.

### 6. 무기고 + 모양 바꾸기 (골드 쓸 곳 + 모은 것 보여 주기) — 베타 뒤
- 무엇: 가방에 [Armory] 탭을 둬요. 지금 직업의 T1~T6과 젤리 왕관(T8)으로 'Armory 3/7'처럼 보여 주고, T7은 정식 때 더해요. 빈 칸은 실루엣과 'Drops from: Goblin Brute · 1 in 200'처럼 확률을 그대로 보여 줘요. 한 번 가진 무기는 팔거나 환생해도 칸이 남아요. 대장간 [Change Look]은 지금 무기를 모은 모양 중 하나로 바꿔 줘요. 힘은 그대로이고 값은 HuntValue(lv,3) 골드예요. 명예나 악명 계급 2부터 [Faction Glow](둥근 금빛/보라빛, 5분어치 골드)를 열 수 있어요. 숲과 유적에서는 이름표 옆에 진짜 등급 점을 띄워요.
- 언제 효과: 11/09 업데이트. 첫 주~첫 달
- 왜: T3 뒤로 골드 쓸 곳이 거의 없어요(ShopService:99, MaxSoldTier=3). 그래서 뿔 골드 특성, 뿔 거위 보상, 약탈 긴장이 다 약해져요. 모은 무기를 보여 주는 화면도 없어요(점검 §2·§6). '유적에서 수정 검 찾기' 같은, 아이가 스스로 고르는 목표가 생겨요.
- 품·담당: M, 약 1.5일. 개발2 0.6(ArmorySeen 저장·보유 목록에서 채우기, Look 원격·검증·골드 차감) + 개발1 0.6(탭, 대장간 줄, CharacterVisuals) + 이미지 개발 0.3. 무기 아이콘은 있는 것을 쓰고 없으면 대체 화면 / 게임성 개발 2 + 게임성 개발 1 + 이미지 개발
- 규칙 확인: Robux 판매는 없어요(골드 2배 패스는 골드를 빨리 모으게 할 뿐). 확률은 그대로 보여 줘요. 힘은 바뀌지 않고, 깡패 규칙과 Tab 전투력은 서버 CombatPower를 써요. 다른 직업 칸을 다 모으는 보상은 만들지 않아요(직업 변경권 구매 유도 방지). 나중에 파는 무기 모양은 번 모양과 확실히 다르게 해요. 빛살 없음.

### 7. 조각 길 (Shard Road): Lv5~50 다음 이정표 — 베타 뒤
- 무엇: 레벨이 오르면 알림 밑에 'Next on the Shard Road: Lv 15 · Woods PvP + title' 한 줄이 떠요. Hero 창 [Road] 탭에는 5레벨마다 칸이 있고, 다음 3칸만 또렷하게 보여요. 칸에 닿으면 자동으로 받지만 자동 장착은 안 해요(BB16). 칸 구성은 이래요. Lv10 'Woods Walker', Lv15 새싹 졸업 + 'Brave Sprout', Lv20 진영 칭호, Lv25 'Ruins Ready', Lv30 표식 둘레 금가루/불씨, Lv35 무기 꼬리 색, Lv40 진영 칭호, Lv45 발자국, Lv50 'Rebirth: Who will you be?'. Z·X 칸은 스위치가 켜졌을 때만 보여요. 칭호는 IDEA-TITLE의 TitleService로 줘요.
- 언제 효과: 11/09 업데이트. 레벨업 밑 한 줄만은 개발1에 여유가 있으면 베타 전에 넣어요. 둘째 날~첫 달
- 왜: Lv5 첫 스킬 뒤로 보이는 이정표가 없어요(점검 §3, Z·X 스위치 꺼짐). 짧은 목표와 긴 목표를 같이 주고, 레벨마다 몇 명이 멈춰 있는지 볼 수 있어요(LongRoad 퍼널). 같은 레벨이어도 빛과 뿔의 모습이 갈려서 GDD §0도 보여 줘요.
- 품·담당: S~M, 약 1.25일. 개발2 0.4(Config.Road, 레벨업 지급, 로그인 때 따라잡기) + 개발1 0.6(탭과 한 줄, 효과는 새 작은 모듈. Fx·HUD는 local 200 한도에 가까움) + 이미지 개발 0.25. 그림 0장(UIKit 대체), 정식 때 칸 아이콘 10장을 High로 약 50크레딧 / 게임성 개발 2 + 게임성 개발 1 + 이미지 개발
- 규칙 확인: 능력치는 0이고 길 보상은 팔지 않아요. 상점 치장(A23-75)이나 출석 치장(A23-77)과 모양이 겹치지 않아요. 먼 칸은 흐리게만 보여요. 효과는 둥근 반짝이뿐이고 빛살은 없어요.

### 8. 봉인된 무덤 (11/09 → 12/19 정식 날 다리) — 베타 뒤
- 무엇: 해골 유적 깊은 곳, M3_8 'Call of the Tombs'가 가리키는 자리에 봉인 3개가 걸린 문을 둬요. 11/09부터 모든 서버의 처치가 금을 내요. 초원·숲은 바깥 봉인, 유적은 안쪽 봉인이라 Lv1도 참여할 수 있어요. 문구는 'The Tomb opens on Dec 19! Every monster you beat adds a crack.'예요. 처치 수는 축제 크기만 정하고 문은 반드시 열려요. 봉인 3개가 다 깨지면 12/19~21 'Tomb Festival' 주말이 열려요. 11/09 뒤 100마리를 잡은 아이는 정식 날 'Seal Breaker'를 받아요. 놓친 아이는 정식 뒤 문지기를 한 번 잡으면 같은 칭호를 받아요. 사용자는 Experience Event 'The Tomb Opens'(Notify Me, 시작 장소 = 무덤 문)와 Experience Updates를 만들어요. #4의 알림 동의자에게 같은 날 알려요.
- 언제 효과: 11/09 시작 → 12/19 정식. 첫 달 → 정식
- 왜: 정식 날 베타 유저가 돌아올 이유와 연락 길이 함께 생겨요(#4와 짝). 새 소식 창은 고정 글이라 이 정도 연결이 없어요(점검 §4). 핼러윈 뒤 6주 동안 모든 처치에 함께 쌓는 의미를 줘요.
- 품·담당: M. #5와 같은 합산 도구를 쓰면 약 1.25일(개발2 0.75 + 개발1 0.5, 봉인 3단계 모습), 따로 만들면 1.75일. 문 3D는 키트에 있으면 0, 없으면 Tripo 1개(상시 OK 규칙) / 게임성 개발 2 + 게임성 개발 1, 이미지 생성 1(문 3D가 필요할 때), 사용자(이벤트 만들기, 게임 안에 'Dec 19'를 적어도 되는지)
- 규칙 확인: 날짜 한 줄만 쓰고 시계 숫자는 없어요. 문은 반드시 열려서 가짜 희소성이 아니에요. 상점과 묶지 않고 이벤트 안에서 판매 권유도 없어요. 놓친 아이에게도 칭호 길이 있어요. 12/19에 4장 첫 단계가 준비돼 있어야 해요.

### 9. 새싹 구조 신호 (Sprout SOS) — 베타 뒤
- 무엇: Lv15 미만 아이가 같은 몬스터에게 5분 안에 2번 쓰러지거나, 왕 슬라임과 싸우다 체력이 30% 아래로 내려가면 신호가 떠요. 같은 서버에서 그 아이보다 10레벨 이상 높은 사람에게 'A sprout needs help at Slime Pond! [Go]'를 60초 띄워요. 이름은 넣지 않아요. 도와서 이기면 'Sprout saved!', 명예 +1(하루 공통 상한 안), 칭호 Big Sibling(5/25/100번)을 받아요. 뿔 도우미에게는 'Not for free! …Okay, just this once.'가 떠요. 새싹 쪽에는 [Thanks!] 버튼이 떠요(psych 9a와 같은 버튼).
- 언제 효과: 11/09 업데이트(정식에 사람이 늘면 효과가 커요). 첫 판·첫 주
- 왜: 초반 이탈의 큰 이유인 '중요한 순간에 지기'를 KO 팁(psych 1b) 다음 단계로, 사람이 와서 풀어 줘요. 고렙에게는 초원에 다시 올 이유와 천사 쪽 행동이 생겨요. 같이 때린 사람은 모두 처치로 쳐서(killRecord) 처치를 뺏기지 않아요.
- 품·담당: S~M, 약 1.25일. 개발2 0.75 + 개발1 0.5(지도 별, 칩, [Go]) / 게임성 개발 2 + 게임성 개발 1, 검수(문구)
- 규칙 확인: 이름을 넣지 않아서 아이 안전을 지켜요. 일부러 죽어서 부르는 꼼수는 새싹당 하루 2번, 도우미 하루 5번으로 막아요. 점수는 공통 상한 안에서만 올라요. 숲·유적의 새싹 보호는 그대로예요. 보상은 판매와 무관해요.

### 10. 스쿼드 (Squad, 최대 4명) → 나중에 듀오 일감 — 베타 뒤
- 무엇: 플레이어 카드의 [Squad up]을 누르면 Roblox 친구는 바로 초대돼요. 친구가 아니면 10스터드 안에서 둘 다 눌러야 해요(채팅 없음). HUD에 'Squad (2/4)', 지도에 팀 점, 이동 메뉴에 'Go to squad'가 생겨요. 50스터드 안에서 팀원이 잡은 몬스터는 내 처치 퀘스트에도 세요(보상 배수는 없음). 팀원끼리는 PvP가 안 되고, 빛 동료 오라는 팀원부터 쳐요. 빛과 뿔이 섞인 팀은 이름표에 땋은 테두리를 받아요(번 치장). #1 초대로 들어온 친구는 바로 그 팀에 들어가요. 듀오 일감(빛+뿔 역할 퀘스트)은 일감 게시판이 켜지고 스쿼드가 생긴 뒤에 해요.
- 언제 효과: 12/19 정식. 둘째 날~첫 달
- 왜: 친구와 같이 노는 날이 추천 신호이고, Roblox도 30일 고리로 파티를 권해요. 같은 반 친구가 서로 다른 편을 골라도 갈라지지 않고 같이 놀 이유가 생겨요(GDD §0). 개인 서버(A23-75)가 팀의 집이 되기도 자연스러워요.
- 품·담당: M, 약 2.2일(Go to friend는 #1에서 이미 함). 개발2 1.25(SquadService, 원격 검증, 나갈 때 정리) + 개발1 0.75 + 이미지 개발 0.25 / 게임성 개발 2 + 게임성 개발 1 + 이미지 개발. 13세 미만이 친구 아닌 사람과 팀을 맺어도 되는지는 검수가 정하고, 필요하면 사용자에게 물어요(아이 안전).
- 규칙 확인: 같이 한다고 보상을 더 주지 않고, 친구 수만큼 주는 보상도 없어요. 팀 크기는 팔지 않아요. 친구가 아닌 사람과의 팀은 그 판에만 있고 저장하지 않아요. 13세 미만 기본은 친구만 허용하는 쪽을 추천해요.

## 베타에서 잴 것

베타 측정 계획 (개발2 약 0.5일, 10/24 전에 넣어야 베타 기록이 생겨요. Studio Play는 기록되지 않고, 비교 기준표는 하루 100명이 넘어야 생겨요.)

1) 보는 숫자
- Roblox Analytics의 코호트별 D1, D7(첫 코호트 D7은 11/07에 나옴), D30을 봐요. PC와 폰을 나눠 봐요.
- 아래 묶음을 나눠서 D1·D7을 비교해요. 인과가 아니라 참고용이에요.
  - 친구와 함께 온 아이(FriendMinutes>0 또는 초대로 들어옴) vs 혼자 온 아이
  - 첫 판에 Lv5 스킬을 배운 아이 vs 못 배운 아이
  - 멈추는 카드를 본 아이 vs 안 본 아이
  - 진영별
- 목표선은 우리가 정한 값이고 업계 공식 수치가 아니에요. 첫 주 실제 값을 기준선으로 잡고, 11/09 업데이트 뒤 오르는지로 판단해요.

2) 퍼널 (한도 10개 중 6개)
- ① 온보딩(있음): IntroDone → … → Level10, 13단계예요. 가장 크게 새는 단계를 먼저 고쳐요.
- ② LongRoad(한 번씩): Level15 → M3End(Lv25) → RuinsDaily1 → Level30 → Level40 → Level50 → Rebirth1
- ③ DailyVisit(반복, session=KST DayIndex): Join → AttendanceClaim → Daily1 → Daily3 → SetChest → StopCardSeen
- ④ Social(한 번씩): InviteSeen → InvitePrompt → InviteSent → InviteeJoined(LaunchData) → PlayedTogether10m
- ⑤ KingDiary: Page1 → Page3 → Page6 → Page9
- ⑥ PassShop(A23-75, session마다): ShopOpen → PassView → PurchasePrompt → Bought
- 11/09에 ⑦ Drive(session=주 번호): FirstPoint → 10 → 30 → Chest를 더해요.

3) 사용자 정의 이벤트 (한도 100)
- 칸 값은 정해진 짧은 목록만 써요. 이름, ID, 자유 글은 넣지 않아요.
- 목록
  - DaysPlayed: KST 하루 첫 접속. value=평생 날 수, f1=레벨 띠, f2=진영
  - ReturnGap: 6시간 미만 / 6~24시간 / 1~3일 / 3일 이상
  - WelcomeBackGo, NotifyOptIn(shown / accepted)
  - InviteSent, FriendJoin, GoToFriend
  - DiaryPage(value=쪽, f=따라잡기 여부), CandyTrade, RuinsDaily(f=목표 종류)
  - KOLeave60: KO 뒤 60초 안에 나감. f=구역
  - LeaveContext: PlayerRemoving 때 마지막 상황. Combat / KO / Shop / StopCard / DailyDone / Idle / Menu 중 하나, f2=판 길이 구간. '어디서 그만두는지'를 바로 보여 줘요.
  - PromptNearKO: KO나 강화 실패 30초 안에 구매 창이 뜸. 0이어야 하는 규칙 감시예요.
- 골드는 LogEconomyEvent로 옮겨서 Roblox 경제 대시보드에 보이게 해요.
  - 들어오는 곳: Monster, Daily, Quest, Attendance, Goose, War, Candy
  - 나가는 곳: Shop, Potion, LookChange
  - GoldOut/GoldIn 비율을 봐요.

4) 판단 날짜와 기준 (미리 정해 둠)
- 11/03, 첫 D1이 나온 뒤: 온보딩 퍼널에서 가장 큰 낙차와 KOLeave60이 많은 구역부터 고쳐요.
- 11/07~08, 첫 D7이 나온 뒤에 11/09 업데이트 내용을 정해요.
  - LongRoad Level25 → RuinsDaily1 또는 Lv25 → 30 전환이 60% 미만이면 유적 게시판과 4장 당기기를 사용자에게 물어요.
  - DailyVisit에서 SetChest까지 간 비율이 40% 미만이면 일일을 줄여요.
  - 친구 코호트의 D7이 혼자 코호트보다 높지 않거나, InviteSent가 D1 유저의 5% 미만이면 초대 위치를 바꿔요.
  - Rebirth1이 많으면 지난 삶 앨범을 당겨요.
  - PromptNearKO가 0보다 크면 바로 버그로 고쳐요.
  - GoldOut/GoldIn이 0.3 미만이면 무기고 모양 값을 손봐요.
- 11/14: Drive 30점 도달이 주간 활동자의 25% 미만이면 기준을 낮춰요. 성공은 한 판 길이보다 '다시 온 날 수'로 판단해요.

## 탈락·합침·보류

- 탈락(규칙): 초대 보상, 한 번만 주는 것도 포함(점검 #1). A23-68의 '친구 수만큼 보상 금지' 취지와 초대 강요 때문이에요. 초대는 보상 0으로 #1에 넣었어요.
- 탈락(규칙): 진영 마을 기금(골드를 내면 진영 마을이 꾸며짐, 점검 #2). 골드 2배 패스(A23-75)로 진영의 모습과 위신을 돈으로 사게 돼요. 골드 쓸 곳은 개인용 #6 무기고 모양으로 하고, '이긴 마을 기억하기'는 idea_backlog의 거위 승리 등불 안을 그대로 둬요.
- 탈락(규칙): 무기고에서 '다른 직업 칸 다 모으기' 보상. 직업 변경권(Robux)을 사게 만드는 고리라서 #6에서 뺐어요.
- 탈락(규칙): 펫 심부름을 더 하는 권리 판매, Drive나 진영 공동 점수에 2배 패스 적용. 돈으로 사는 자동 진행이고 공동 판의 공정을 깨요. 원안도 이미 피했어요.
- 탈락(규칙): 'Tomorrow' 줄, 무덤, 대결에 시계 숫자나 '곧 사라져요' 넣기. A23-68 카운트다운 금지라서 날짜 한 줄과 'tomorrow'만 써요.
- 합침(중복): 몬스터 스티커 책은 psychology_retention 11a 몬스터 도감과 같아요. '처음 잡음, 금색 잡음' 칸 아이디어는 11a에 의견으로만 넘겨요.
- 합침(중복): '쉬어도 돼요' 카드와 돌아오면 반겨 주기 줄(점검 #1)은 이미 psych 5a·5b(베타 전 6개 중 1번)에 있어요. 새로 낸 것은 'Tomorrow:' 줄의 내용(#3 대왕 일기)뿐이에요.
- 합침(중복): 배지(BB31)는 이미 psych 11b 배지 8개에 있어요. PET-4, IDEA-TITLE, IDEA-MARKGROW, 환생 무기 쳇바퀴 수정은 이미 정한 일이라 새 안으로 내지 않았어요. #2와 #7에는 일정 확인과 연결만 적었어요.
- 합침(중복): 왕관 주간, 진영 주문, 진영 모으기, 주제 주간, 이번 주 조각 길 5칸, 날짜 표 '이번 주 이야기'는 #5 진영 주간 하나로 합쳤어요.
- 합침: 내일의 선물(Thank-You Basket / Stash Pouch)을 따로 만들면 A23-77 출석과 같은 '다음 날 받기' 보상이 둘이 되고 경제가 부풀어요. 출석 받기 카드에 진영 NPC 한마디(어제 선택 기억)를 붙이는 문구 일로만 검수에 넘겨요.
- 보류(정식 뒤): 펫 심부름. PET-4가 아직 시작 전이고, 출석·일일·휴가에 '돌아와 받기'가 하나 더 생겨요. GDD v1.1 오프라인 수입과 함께 다시 봐요.
- 보류(정식 첫날 1번만 검토): 왕관 대결(주 2번, 전 서버 동시 15분). 약속 시간 장치는 Roblox 유저가 싫어하고(R-A2), 베타 인원이 적으면 빈 판이 돼요. #5 합산 위에 'Launch Clash'로만 검토해요.
- 보류: 친구 순위(Roblox 기본 순위판). 기능과 한도를 문서로 확인하지 못했고, 하나만 켤 수 있어요. #1 효과를 본 뒤 정식에 검토해요.
- 보류: 듀오 일감과 유적 게시판·일감 장부. 일감 게시판이 꺼져 있고(Enabled=false) 창이 없어요. 듀오는 스쿼드가 먼저이고 게시판 점수 0(A23-23 D1)도 바꿔야 해요. 숫자 벽은 #2가 먼저 메워요.
- 보류(정식, Rebirth1 수를 보고 당김): 지난 삶 앨범과 삶 목표.
- 사용자 결정으로 넘김: 4장 M4_1~3을 베타로 당기기(일정), 게시판 Kind/Sneaky 명예·악명 점수(A23-23 D1 변경). 후자는 #5 상자 소량 점수로 대신 물어요.

## 부록 A — 지금 게임 점검(요약 원문)

# 선악 키우기 리텐션 점검 (2026-10-08, 읽기만)

파일은 하나도 고치지 않았고 Studio와 git도 쓰지 않았어요. 공유 작업 트리만 읽었기 때문에 origin보다 늦은 내용일 수 있어요. 아래 경로는 모두 `C:\Users\glori\Documents\Roblox\Game\` 기준이에요. 워크트리 Game-dev2, imgdev, wtc 등도 찾아봤는데 알림, 초대, 게임패스, 배지 코드는 어디에도 없었어요.

표시: [켜짐] 코드가 있고 돌아감 · [꺼짐] 코드는 있지만 스위치가 꺼짐 · [문서] 계획만 있음 · [없음]

## 0. 요청한 세 가지 확인

**1. 퍼널 분석: [켜짐]**
- `src/ServerScriptService/TelemetryService.luau`가 `LogOnboardingFunnelStepEvent`로 13단계를 기록해요. 단계는 IntroDone부터 Level10까지예요(`Config.luau:3279`).
- 다시 들어온 사람은 지난 단계를 채우고, 새 단계는 바로 기록해요(`TelemetryService.luau:201-236`). A23-68 #5의 첫 3분 단계는 다 들어 있어요.
- 그 밖의 기록: SessionMinutes, ReturnAct, FriendMinutes, KillsWithFriend, GoldIn/GoldOut, EnhanceFailLeave, ServerPopulation.
- **빈 곳:** 퍼널이 Lv10에서 끝나요. 그래서 둘째 날과 첫 주 구간이 안 보여요(Lv15 PvP, Lv25 이야기 끝, 일일 세트 완료, 휴가 받기, 첫 환생, 플레이한 날 수).
- `LogEconomyEvent`와 `LogProgressionEvent`는 쓰지 않아요. 골드를 커스텀 이벤트로만 남겨서 Roblox 경제 대시보드에 안 뜰 수 있어요(확인 필요).

**2. Experience Notifications: [없음]**
- 코드에도 계획 문서에도 없어요. `early_churn_research`의 출처 메모에 "13세 이상·옵트인·하루 1개"라는 줄만 있어요.

**3. 친구 초대: [없음]**
- BB25 계약만 있어요(`CanSendGameInviteAsync` → `PromptGameInvite`, `docs/design/beta_basics_2026-10-05.md:1506`).
- `beta_board_2026-10-06.md:230`의 줄이기 계획이 BB25, BB26, BB30~36(코드·배지·출석·명예의 전당 포함)을 정식으로 미뤘어요.
- 친구 따라 들어가기, 초대한 친구 옆에서 시작하기, 파티, 플레이어 길드도 없어요.

## 1. 첫 접속이 끝날 때 (다시 올 이유)

**있는 것**
- 일일 퀘스트 3칸: 한국 시간 자정에 바뀌고, 다 받으면 상자(10% 확률로 직업 변경권)가 나와요. 추가 퀘스트와 바꾸기도 있어요(`QuestService.luau`, `Config.luau:3056-3142`). Lv1~9, Lv10~24는 짧은 일일로 나뉘어 있어요.
- "All done for today! You can rest now…" 문구가 나와요(`QuestService.luau:1132`, `Config.luau:4951`).
- 메인 이야기 M1~M3(19단계)가 늘 보이고, 서브 퀘스트가 30개쯤 있어요(`Config.luau:2174-2177`).
- 다음 목표 줄(`Config.luau:4866`), Lv5 첫 스킬, Lv10 숲 안내가 있어요.
- 오늘의 운(`Config.luau:1353`)이 하루 동안 유지되고, 응원별 5개를 모으면 다음 희귀가 확정이에요(저장됨).
- 한 판 안에서 붙잡는 힘은 강해요. 왕관전 10분, 거위 10분(5분 엇갈림), 호박 대왕·유령 대왕이 20분마다(10분 엇갈림) 와요.

**약하거나 없는 것**
- 접속을 끝맺는 카드와 "내일 새로 생기는 것" 한 줄이 없어요. 같은 문서 #7·#8(쉬어도 돼요 카드, 돌아오면 반겨 주기)은 계획만 있어요.
- 핼러윈 9일 대왕 수다(`Config.luau:1976-1999`)는 매일 바뀌는 좋은 고리예요. 그런데 채팅에만 나와서 아이들이 몰라요.
- 13세 미만은 알림을 못 받아요. 그래서 다음 접속 약속은 게임 화면에 있어야 하는데, 지금은 그런 화면이 없어요.

## 2. 둘째 날

**있는 것**
- 휴가 보너스: 못 온 날을 70%로, 최대 3일까지 채워 줘요(`Config.luau:3139`).
- 원한 골드 우편, 현상 별 저장과 감소(`PvPService.luau:901`), 월요일 순위 보상·무법자 시작 알림, 새 일일.

**약하거나 없는 것**
- 다시 들어오면 반겨 주는 줄이 없어요. "Welcome back"은 자동 전투 문구에만 있어요(`Config.luau:4921`).
- **골드 쓸 곳이 거의 없어요.** T2(150), T3(800) 무기와 물약(25)뿐이에요(`ShopService.luau:99`, `:298`, `Config.luau:242`의 MaxSoldTier=3).
  - Lv10쯤부터 일일·왕관·거위 골드 보상이 가벼워져요.
  - 뿔 진영 특성(골드 +25%)과 뿔 거위 승리(골드 위주)도 의미가 줄어요.
  - 약탈 긴장도 약해져요. GoldIn/GoldOut 기록으로 확인할 수 있어요.
- 출석(BB32)은 [문서]이고 정식으로 잡혀 있어요. 계약에 Streak 칸이 있어서 A23-68의 '연속 리셋 금지'와 부딪혀요(`beta_basics:1771`).

## 3. 첫 주

**있는 것**
- Lv15에 새싹 졸업 → 숲·유적 PvP, 원한 자루, 현상금, 괴수.
- 주간 랭킹 4판(명예·악명·장인·무단 PvP): 전 서버, 월요일 정산(`RankingService.luau`). 마을 게시판에 이 서버 TOP3와 수배.
- 무기 드랍 추적(T4~T6, `Config.luau:3727-3762`), 강화 +10 추적, 전설 대박 1/20000.

**약하거나 없는 것**
- **Lv25 절벽**
  - 메인 이야기가 M3_8 "Call of the Tombs"(Lv25)에서 끝나요(`Config.luau:2506`). 4장은 정식, 5장은 나중이에요(`story_depth:148`, `:175`).
  - Lv25~50 사냥터는 해골 유적 하나뿐이에요.
  - 계산(추측): 기준 속도(분당 12마리)로 Lv25까지 약 95분, Lv50까지 약 4.1시간이에요. 실제 수동 사냥은 더 느려요.
- Lv25 이상 일일은 옛 "Defeat Skeleton ×50~60"으로 돌아가요(`Config.luau:3070`, `:3114`). GDD §0-1의 '같은 숫자 벽 피하기'와 어긋나요.
- Z(Lv15)·X(Lv25) 스킬 스위치가 꺼져 있어요(`Config.luau:561-564`). 10/20 결정 전까지는 Lv5 뒤 새 스킬 이정표가 없어요.
- 일감 게시판은 꺼져 있어요(`Config.luau:3001`, Enabled=false).
- 주간 보상은 1~3위만 받아요(`Config.luau:5135`). 명예·악명 판은 공정 PvP 점수만 세요. 대부분의 아이에게는 주간 고리가 없어요.
- **후광·뿔 성장이 멈춰요.** 계급 기준은 10/50/200/1000점이에요(`Config.luau:872`). 이야기 선택은 대부분 +1이라 이야기 점수로는 계급 2까지예요(`story_depth:95`). 계급 3부터는 PvP가 필요해요. 점수마다 조금씩 커지는 IDEA-MARKGROW는 아직 시작 전이에요(`beta_board:379`).

## 4. 첫 달

**있는 것**
- 환생 Lv50(이후 +5씩), 영구 +25%/+40%, 타락·구원 표식, 오라 1/3/5/10, 회색 전설(`Config.luau:1378`).
- 베타 저장이 정식까지 이어지고 Beta Pioneer 칭호를 받아요.
- 장인 업데이트가 11월 말 목표예요(A23-57). 12/19 정식에 4장과 크리스마스가 들어가요.

**약하거나 없는 것**
- 핼러윈이 11/09에 끝나요(`Config.luau:1932`). 그 뒤 장인 업데이트 전까지 약 3주, 12/19 정식까지는 6주 동안 이벤트가 없어요.
- 사탕은 5골드에 파는 것밖에 쓸 곳이 없어요(`Config.luau:3690`).
- T7 진영 무기는 얻는 길이 없어요(상점은 T3까지, 드랍 표에도 없음).
- 환생 무기 쳇바퀴(+10 무기를 든 Lv1이 초원을 쓸어버림)는 '첫 Lv50 환생 전에' 고치기로 했어요(`idea_backlog:42`). 그런데 베타 안에 Lv50이 나올 수 있어요.
- 정식 날 베타 유저를 다시 부를 길이 없어요. 알림이 없고, Events RSVP는 사용자 질문으로 남아 있어요(`idea_backlog:46`).
- 새 소식 창은 Config에 고정된 글이라(`Config.luau:3613`) 바꾸려면 게시가 필요해요.

## 5. 사회·진영 경쟁

**있는 것**
- 덩치 저울, 깡패 규칙, 복수 화살표, 원한 자루와 유령 붙잡기, 수배·게시판, 괴수 레이드.
- 왕관전(하늘색, 축복 +25%, 상자), 거위 대결·함께 구조, 대왕 함께 잡기.
- 좋은 드랍 전체 채팅(`AnnounceService`), 기사 동료 공격 +5%(`Config.luau:770`), /t 진영 채팅, Tab 목록.

**없는 것**
- 왕관전은 서버마다 10분으로 끝나요. 진영 단위로 쌓이는 기록이 없어요. '서버끼리 합산하는 주간 왕관'과 '진영 마을 꾸미기'는 GDD 로드맵 v1.4에만 있어요(`docs/GDD.md:450`).
- 파티와 플레이어 길드가 없어요. 장인 길드는 진영이고 베타에서 꺼져 있어요.
- 명예의 전당과 석상은 정식이에요(BB26, `idea_backlog:45`).
- 사람이 적은 서버에서는 왕관전이 포위전, 거위가 함께 구조가 되고, 괴수와 PvP는 거의 생기지 않아요. 이 고리들이 돌려면 서버에 사람이 차야 해요(서버 채우기 설정은 사용자 체크리스트).

## 6. 모으기·펫·칭호

- **펫:** 빛·뿔 플레이어는 펫이 0이에요.
  - 펫은 장인 길드 조련사만 받아요(`PetService.luau:104`). 그런데 장인 진영이 베타에서 꺼져 있어요(`Config.luau:19`).
  - 모두에게 주는 PET-4 '길 잃은 아기 슬라임'은 베타 범위(A23-15 ②)인데 시작 전이에요(`beta_board:329`). 펫 종류는 1개예요(`Config.luau:5404`).
- **칭호:** 고를 수 있는 칭호가 2개뿐이에요(`Config.luau:3918`). 선택·대왕 칭호를 더하는 IDEA-TITLE은 시작 전이에요(`beta_board:378`).
- **도감·스티커·배지:** 없어요. 그림 도감은 미뤘고(`beta_basics:1899`), 펫 도감과 배지(BB31)는 정식이에요. 무기 등급·이름은 있지만 모은 것을 보여 주는 화면이 없어요.

## 7. 수익(A23-75)과의 관계

- 게임패스, VIP, 치장, 개인 서버 코드는 아직 없어요.
- 경험치 2배 패스는 Lv25 절벽에 두 배 빨리 데려다줘요. 팔기 전에 절벽부터 메우는 게 맞아요.
- 개인 서버는 랭킹에서 이미 빠져 있어요(`RankingService.luau:281`).
- VIP 이름 옆 왕관과 후원자 게시판은 사회적 지위 고리로 좋아요.

## 8. 가장 큰 빈칸 5개 (우선순위 순)

**1. 밖과 친구로 이어지는 길이 0이에요 (모든 기간에 곱해지는 문제)**
- 초대, 친구 따라오기, 알림, 배지, 코드, RSVP가 전부 없어요. 거위·왕관·괴수·PvP는 사람이 많아야 돌아요.
- 할 것:
  - BB25 초대를 베타로 다시 당겨요(S, 0.5일). ExperienceInviteOptions의 LaunchData로 초대받은 친구가 초대한 아이 옆에서 시작하게 해요(`early_churn` #6). 보상은 없거나 1번만이에요.
  - '쉬어도 돼요' 카드와 돌아오면 반겨 주기 줄(#7·#8)을 만들어요. 여기에 [새] "Tomorrow: new dailies · the Kings say something new (Day 3/9)" 한 줄을 넣어요. 시간 숫자는 넣지 않아요.
  - [새] Experience Notifications 옵트인: 일일을 다 끝낸 뒤 한 번만 물어요(13세 이상에게만 떠요). 보내기는 Open Cloud 알림 API를 쓰고, 키는 Secrets에 둬요. 키와 문구 만들기는 사용자 일이고, 문서로 다시 확인해야 해요. 예: 정식 날 베타 유저에게 "Chapter 4 is open".
  - 배지 4~6개(BB31)를 만들고, 코드(BB30)를 개발 일지 영상 설명과 묶어요.
  - 서버 채우기를 '최대'로 해요(사용자 체크리스트).

**2. 골드가 쓸모없어지고 Lv25~50이 비어 있어요 (첫 주, 가장 열심인 아이부터 빠짐)**
- 할 것:
  - [새] Lv25~49 일일 띠 'Ruins': E12 방식으로 3분짜리 다른 목표 3개.
  - 4장 M4_1~M4_3을 베타로 당길지 사용자에게 물어요. 기존 목표 종류와 기존 해골만 쓰고 글만 새로 써요.
  - 10/20 Z·X 결정을 '절벽' 관점에서도 봐요.
  - 환생 무기 쳇바퀴는 베타 전에 고쳐요.
  - [새] 진영 마을 기금: 우리 편 마을 등불·깃발에 골드를 넣으면 마을이 꾸며져요. 능력치는 없어요. GDD v1.4 '진영 마을 꾸미기'와 `idea_backlog:49`를 합친 거예요. 골드에 진영 의미가 다시 붙어서 뿔 골드 특성과 약탈 긴장이 살아나요.

**3. 진영 정체성이 접속 사이에 쌓이지 않아요 (GDD §0 핵심인데)**
- 할 것:
  - GDD:450 '주간 합산 왕관'을 아주 작게 앞당겨요. 10분 판 승리를 전 서버로 더해 분수와 HUD에 "This week: Halo 41 · Horns 37"을 띄워요. 인원 보정은 판마다 이미 있어요. 이긴 편은 다음 주 하늘·마을 장식만 받아요(능력치 없음).
  - IDEA-MARKGROW를 베타에 넣어요(S).
  - PvP를 안 하는 아이도 하루 공통 상한 안에서 명예·악명을 쌓게 해요. 오늘의 갈림길(`idea_backlog:48`)을 앞당기거나, 일감 게시판 Kind/Sneaky에 작은 점수를 줘요. 후자는 A23-23 D1의 '점수 0'을 바꾸는 거라 사용자 결정이 필요해요.

**4. 모을 것이 거의 없어요 (아이들의 긴 동기)**
- 할 것:
  - 베타 범위인 PET-4 '길 잃은 아기 슬라임'을 먼저 해요.
  - IDEA-TITLE로 칭호를 늘려요(S).
  - [새] 몬스터 스티커 책: 종류마다 '처음 잡음'과 '금색 잡음' 칸만 둬요. 처치 수 벽은 없어요. 한 쪽이 다 차면 칭호를 줘요. 기존 몬스터 아이콘을 써서 새 그림은 0장이에요.
  - [새] 사탕 단지: 사탕을 칭호(예: Pumpkin Pal)나 작은 치장으로 바꿔요. 시즌이 끝나도 바꿀 수 있고 내년에 다시 열어요. 한정 압박은 없어요.

**5. 11/09 뒤 6주 운영 달력이 비고, 주간 고리는 1~3위만 받아요 (첫 달)**
- 할 것:
  - [새] 날짜 표로 켜지는 '이번 주 이야기': 핼러윈 EndsAt처럼 서버 시간으로 켜져서 게시 없이 바뀌어요. 예: 거위 주간, 대왕 귀환 주말, 왕관 주간. 기존 시스템의 숫자만 바꾸고, 새 소식 창에 미리 알려요. 카운트다운 상점도 없고 놓쳐도 손해가 없어요.
  - [새] 주간 개인 목표 '이번 주 조각 길' 5칸(사냥·거위·선택·대왕·도움): 칸마다 바로 보상, 못 채워도 잃는 것 없음.
  - 장인 업데이트(11월 말)를 베타 중 큰 소식으로 알려요.
  - 작은 메모: 주간 정산 월 00:00 KST는 미국 일요일 오전이라 미국 주말이 두 주로 갈려요.

**계측 덧붙임 (S):** 퍼널에 Level15, 3장 끝(Lv25), 첫 환생을 더하고, DaysPlayed(한국 시간 날 수 저장), DailySetDone, VacationClaim, 패스 상점 퍼널을 넣어요. 그래야 베타 첫 주에 위 1~5 중 어디서 새는지 보여요.

**사용자 결정이 필요한 것:** BB25 베타 복귀, 알림(키·문구는 사용자 작업), 4장 일부 베타 반영, 게시판 점수 0 변경, 진영 마을 기금, 주간 정산 시각.

## 부록 B — Roblox 조사(원문)

**Roblox retention research, 2025–2026 (for Halo & Horns). Read-only: no files, Studio or git touched.**

Source tags: [OFF] Roblox docs, DevForum staff posts or SEC filings · [GA] GameAnalytics · [3P] press, wiki or guide sites · [TRK] third-party trackers (rough).

## A. What Roblox measures and pays for

1. **Discovery looks at 28 days now** [OFF]
   - Top-tier signals:
     - Play-through rate.
     - First-play bounce under 60 s and at 61–180 s (counts against you).
     - Play days per user, split into Day 1 / Days 2–7 / Days 8–28.
     - Playtime per user, capped at 60 minutes per user per game per day.
   - Second tier: intentional co-play days (friend join, invite or private server; matchmaking does not count), qualified sessions, spend days, Robux spent.
   - Users who arrived through friends are left out of the ranking stage.
   - Meaning: more separate days played counts for more than longer sessions, because time past 60 minutes a day earns nothing.
   - https://create.roblox.com/docs/en-us/discovery.md · https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575 · https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
   - Q2 2026 filing: co-play "drives a large share of playtime"; the 28-day change gave an "early positive lift" to long-term retention (no number given). https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm

2. **Roblox's own retention advice** [OFF] https://create.roblox.com/docs/en-us/production/analytics/retention.md
   - Day 7: short- and long-term goals, more content variety, track how many players sit at each progression level.
   - Day 30: small updates every 2–4 weeks, big features every 2–3 months, plus social systems (trading, parties, guilds, PvP, tournaments, leaderboards).
   - The monetization page says weekly updates are ideal.
   - It also says timers and appointment mechanics "are unpopular with Roblox users who take issue with their fun coming to a premature end."
   - No fake sales, no false scarcity, no countdowns that restart. With minors, use "View Item" instead of "GET IT NOW."
   - https://create.roblox.com/docs/en-us/production/monetization.md

3. **GameAnalytics 2025 Roblox report** [GA] https://www.gameanalytics.com/reports/2025-roblox-report
   - D1 median by average session length: 0–3 min 4.31% · 7–12 min 7.91% · 13–18 min 10.24% · 19–24 min 11.46% · 25+ min 10.76%.
   - D7 median: 1.61% at 19–24 min, 1.82% at 25+ min. The top 5% reach D7 about 7.9% and D30 about 1.9%.
   - Gains flatten above about 19 minutes per session.
   - Sessions per day: the median stayed at 2.02. The top players rose about 33% year on year (top 10%: 4.5 → 6.0; top 5%: 6 → 8).
   - The report credits:
     - "re-entry design": daily quests and micro-objectives of about 3–7 minutes;
     - offline progression: crafting, timers or NPC jobs that finish while the player is away;
     - friend co-play.
   - Spending per paying user, median: $0.48 for 0–3 min games, $2.12 for 25+ min games.

4. **Creator Rewards pays for daily returns** (replaced Premium Payouts on 2025-07-24) [OFF] https://create.roblox.com/docs/en-us/creator-rewards.md
   - Daily Engagement: 5 Robux per qualifying user per day.
     - The user must play at least 10 minutes that day (visits add up).
     - The game must be one of the first 3 experiences they open that day.
     - The user must be an "Active Spender": $9.99+ spent in the last 60 days.
   - Audience Expansion: 35% of the first $100 that new users, or users back after 60+ days away, spend in their first 60 days.
     - They must come through our Share Link, a direct link or a search by name, and play 10+ minutes.
     - The game needs an average of 100+ DAU for 60 days.
   - Meaning: a fun 10-minute daily visit plus Share Links directly earns money, with no in-game sales.

5. **Experience Notifications** [OFF] https://create.roblox.com/docs/en-us/production/promotion/experience-notifications
   - Only players aged 13+ who opted in. At most one per player per day. The game needs 100+ visits.
   - In-game opt-in: `ExperienceNotificationService:CanPromptOptInAsync()` then `PromptOptIn()`. The prompt text cannot be changed, and it is not shown again for 30 days after a player sees it.
   - Good messages are personal and suggest a next step ("You're 2 races away from completing the weekly challenge!", "Time for revenge?").
   - Banned: false time pressure, bait-and-switch, locking gameplay behind opting in.
   - The dashboard shows CTR and Turn Off rate. Roblox publishes no figure for how much notifications raise returns.
   - Under-13 players only get Experience Updates: 60 characters, at most once every 3 days.

6. **Experience Events (RSVP)** [OFF] https://create.roblox.com/docs/en-us/production/promotion/experience-events
   - "Notify Me" sends an inbox reminder (push optional) when the event starts. Up to 10 events can be live or upcoming.
   - An event can send attendees to a custom start place. https://devforum.roblox.com/t/introducing-custom-start-places-for-events/3864645
   - The Trending Events sort needs 1,000+ RSVPs and a start within the last 7 days.
   - Events can be submitted for off-platform featuring (app store event cards), judged on "trends and seasonal alignment." This fits a Halloween beta. https://devforum.roblox.com/t/introducing-off-platform-featuring-for-creator-events/4142230
   - Roblox's 2025 Halloween Spotlight ran 10/23–11/03. No 2026 creator sign-up info found. [3P]

7. **Invites and referral rewards** [OFF]
   - Games with an in-game invite prompt have 6x more players sending invites and 8x more invites overall. https://devforum.roblox.com/t/player-invite-prompts/2170724
   - `SocialService:PromptGameInvite`: call `CanSendGameInviteAsync()` first. `ExperienceInviteOptions` can carry launch data, read with `GetJoinData()`.
   - `ReferredByPlayerId` fills in automatically. Referral reward banners are set up in Creator Hub (live since 2025-04). https://create.roblox.com/docs/production/promotion/referral-system
   - Roblox warns that bait such as "free Robux" lowers invite conversion.

8. **Native leaderboards** (open beta 2026-08-26, full release 2026-09-16) [OFF] https://devforum.roblox.com/t/beta-add-persistent-friends-and-global-leaderboards-easily/4832224
   - Register an `OrderedDataStore` and get Global, Friends, Server and All-time views. Only one leaderboard can be active.
   - It "will soon show on other Roblox surfaces to draw players back in."
   - Common advice [3P]: add weekly or seasonal boards and boards split by level range, so early players do not own the board forever.

9. **Analytics limits** [OFF]
   - 10 funnels, 100 steps per funnel, 100 custom event names, 3 custom fields, 8,000 combined values before grouping into "Other."
   - Server-only, and only in published games. Studio test play logs nothing.
   - `LogOnboardingFunnelStepEvent` / `LogProgressionEvent` are available.
   - Benchmark scorecards need 100+ DAU. Since October 2025, D1/D7/D30 can be split by where players came from.
   - https://create.roblox.com/docs/en-us/production/analytics/event-types · https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157

10. **Chat and social for kids** [OFF/3P]
    - RDC 2026: creators can submit their own Quick Words phrase lists (moderator-reviewed), and a Friends chat tab follows players between games. Whether under-13 players can use Quick Words is not confirmed. https://gamesbeat.com/roblox-is-adding-emojis-custom-quick-words-and-voice-calling-to-its-in-game-chat-rdc-2026/
    - Q2 2026: 57% of daily users are age-checked, and 35% of those are under 13.
    - Meaning: features should work without chat. Pre-set phrases are the platform's route.

11. **Roblox's Engagement Rewards package conflicts with our rule** [OFF] https://create.roblox.com/docs/en-us/resources/feature-packages/engagement-rewards
    - Its Daily type counts *consecutive* logins (`requiredDaysVisitedStreak`).
    - Its Time type resets each session.
    - If we use it, change it to count total days collected; otherwise it breaks the "no streak reset" rule (A23-68).

12. **Badges** [OFF]: 5 free per game per day, then 100 Robux each. https://create.roblox.com/docs/en-us/production/publishing/badges.md. They are a cheap, kid-friendly milestone that shows on the player's profile. Legacy platform badges became wearable pins in 2026; game badges are unchanged. [3P]

13. **Revenue tools that fit us** [OFF]
    - Regional pricing: +4–10% Robux spend, +1–6% players and playtime, +43–52% pass purchases in cheaper regions.
    - Price optimization: median +4% earnings, but it needs about 60k transactions in 30 days (too big for us now).
    - Roblox Plus ($4.99, from 2026-04-30) opens subscription-based experiences.
    - Rewarded video ads need 100k+ DAU, so they are not for us.
    - Sources:
      - https://www.sec.gov/Archives/edgar/data/1315098/000131509825000117/ex992-q12025shareholderl.htm
      - https://devforum.roblox.com/t/managed-pricing-one-system-for-better-pricing-and-earnings-growth/4684738
      - https://create.roblox.com/docs/en-us/production/monetization/price-optimization.md
      - https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678

## B. How top games keep players (mechanic → why it works → kid-safe?)

- **Grow a Garden** (21.3M peak CCU, 2025-06) [3P/TRK]
  - Plants grow while the player is offline, so sessions can be 2 min or 2 h. → Safe.
  - Big update on a fixed weekly day (about every 5–7 days), plus "Admin Abuse": a 30-min to 3-h live event where devs spawn weather and stock and hand out items to everyone online. → The shared moment is safe; making some items available only during the event is FOMO.
  - The 2025-08-23 "Admin War" with Steal a Brainrot helped Roblox reach about 47.3M concurrent users.
  - Veterans gift seeds and tips to newcomers. → Safe.
  - Global shop restock every 5 minutes, and +10% per friend in the server. → Avoid (already on our "do not" list).
  - https://fortune.com/2025/07/30/roblox-video-game-grow-a-garden-viral-summer-hit/ · https://www.tubefilter.com/2025/08/25/roblox-grow-garden-steal-brainrot-admin-war-record/amp/ · https://www.sportskeeda.com/roblox-news/why-grow-garden-popular

- **Blox Fruits** [3P wiki] https://blox-fruits.fandom.com/wiki/Bounty_and_Honor_System
  - Two sides (Marines and Pirates) with separate Honor/Bounty scores. PvP bonus every 500k; titles at 10M ("Admiral") and 20M ("Fleet Admiral"); Saber V2 needs 1M.
  - NPCs stop giving score at 2.5M, so PvP becomes the only source. Only opponents within about 25% of your level count. At 4M+ you lose double.
  - "Player Hunter" NPC quests target players who turned PvP on.
  - Updates are big but irregular.
  - Lesson for us: a faction score shown as a rank with titles is a proven long-term hook. For kids, drop the forced-PvP cap and the harsh loss.

- **Pet Simulator 99** [3P wiki]
  - Update every Saturday at 17:00 GMT, with free "Hype Eggs" for players online then.
  - Clans: members donate to clan upgrades; clan battles last 1–2 weeks; prizes go to the top clan and to the top 3/top 10 contributors.
  - Critics say it mostly pulls play forward in time.
  - Kid-safe version: a whole-faction goal where every participant passing a threshold gets the reward, not only the top N.
  - https://pet-simulator.fandom.com/wiki/Clan_Battles_(Pet_Simulator_99)

- **Bee Swarm Simulator** [3P wiki]
  - Many quest NPCs with long chains (Science Bear: 16 + 15 quests).
  - Areas open at 10, 15 and 30 bees.
  - An endless repeatable quest machine with milestone rewards up to quest 1000; every 10th Honey Bee quest gives a rare item.
  - Lesson: long NPC chains, then an endless repeatable sink with milestones. Avoid its hourly "come back" quests (an appointment mechanic).
  - https://bee-swarm-simulator.fandom.com/wiki/Science_Bear · https://bee-swarm-simulator.fandom.com/wiki/Sticker-Seeker_Quest_Machine

- **Dress to Impress** [3P]
  - Theme → 5-minute build → runway → other players vote 1–5 stars → podium. Players earn currency both for voting and for being voted for.
  - Top complaint: spite-voting (giving everyone 1 star).
  - Lesson: short social rounds with peer recognition work; use positive-only votes ("likes") so they cannot be used to grief.
  - https://genalpha.substack.com/p/how-robloxs-dress-to-impress-is-signaling

- **Murder Mystery 2**
  - Hidden-role rounds, cosmetic collecting and trading, seasonal events. A summer 2026 event drove its all-time peak of about 1.35M CCU. [TRK]
  - Its crate unboxing is paid random items → avoid.
  - https://studiokrew.com/blog/top-roblox-games-august-2026/

- **99 Nights in the Forest** (14M peak CCU)
  - Co-op survival, up to 25 per server; the devs say it "thrives on the weekends" with friend groups.
  - Weekly updates, plus a 45-minute in-game "Update Party" with the devs before each one.
  - Halloween update came in 3 parts; event classes were unlocked by collecting candy.
  - [OFF spotlight] https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940

- **Arsenal / RIVALS** [3P]: Arsenal has 5–10 minute matches and a cosmetic-only pass earned by playing (a reward every 150 kills). RIVALS has a ranked ladder that resets each season. https://earnaldo.com/blog/arsenal-vs-rivals
- **Adopt Me** [3P]: fixed weekly update slots (Mon/Fri 11:05 ET). Its 30-day login count goes down when a day is missed → avoid. https://allthings.how/adopt-me-new-update-schedule/
- **SpongeBob Tower Defense** [3P]: 52 weekly updates in a row. Studios aim for the 90th percentile on D1, D7, 7-day playtime and co-play. https://www.deconstructoroffun.com/blog/how-to-build-a-real-business-on-roblox-in-2026

## C. What this means for us
"Exists" = already in idea_backlog or early_churn_research; "new" = not found there.

1. **Aim for more separate play days, not longer sessions.** Make a daily visit of about 10 minutes worth it with a 3–7 minute micro-goal; the 60-minute cap and Creator Rewards' 10-minute rule both favor this. Supports the existing "오늘의 갈림길"; turning the daily visit into a design goal is new.
2. **Progress while away** (new; check GDD first): for example, the blacksmith finishes a scroll or a pet finishes training while the player is offline, collected on return. It must not expire or punish missed days. The rested bonus already exists, so this would add to it.
3. **One fixed weekly update day plus a short in-game live moment** (new as a schedule): a 30-minute faction moment open to everyone online, with no items locked to that window. Announce it with Experience Updates (reaches under-13) and an RSVP event. The Halloween RSVP plus off-platform featuring submission is already a user question in the backlog; this adds that the Trending sort needs 1,000+ RSVPs.
4. **Faction score as titles and ranks** (Blox Fruits model, kid-safe): milestone titles for Honor and Infamy, a native Friends/Global leaderboard on a weekly key, and boards split by level band. Pairs with the existing statue idea. No forced PvP and no doubled loss.
5. **Whole-faction weekly goal where everyone who takes part gets the reward** (Pet Sim clans adapted): relates to the existing "시즌 저울" candidate; the threshold-for-everyone reward rule is new.
6. **Notification opt-in for 13+ at a natural moment**, such as after the King Slime or after the daily task, with personal, action messages ("Your scroll is ready"). New; `ExperienceNotificationService` is not in our docs yet.
7. **Invites:** BB25 already exists. New parts: turn on Creator Hub referral rewards (one-time, capped) and `ReferredByPlayerId`, and use our Share Link in devlogs and shorts, which also earns Audience Expansion revenue once we reach 100+ DAU.
8. **Use Quick Words custom phrases for the existing "silent signals" idea (P4)** once under-13 access is confirmed.
9. **Free private servers raise the co-play signal** (it counts private-server play). A paid VIP server is already in A23-75; consider a free option too.
10. **Badges for milestones** (5 free per day): first King Slime, first weapon, Chapter 1 done, first redemption or first revenge.
11. **Revenue without pressure:**
    - turn on regional pricing (data showed +4–10% Robux spend, up to +6% players/playtime);
    - a cosmetic track earned by playing (Arsenal model) next to paid halo/horn cosmetics;
    - no paid random items, no timers.
12. **If we use the Engagement Rewards package**, change Daily to count total days, not consecutive days.

**Caveats:** Retention ratios and CCU figures for individual games come from third-party trackers (rough estimates only). No official D1/D7 numbers exist for these specific games. Fan-wiki mechanics may be out of date.