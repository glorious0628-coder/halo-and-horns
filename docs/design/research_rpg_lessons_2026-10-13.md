# 잘된 RPG에서 배울 것 — 첫 10분·성장·다시 오기·선악 (조사 2026-10-13)

- **왜 썼나:** 10/17~20 기술 시험과 11/7~10 '첫 10분 시험'(A23-161) 앞에서, 잘된 게임들이 첫 10분을 어떻게 만드는지 다시 봤어요.
- **안 겹치게:** `rpg_success_analysis_2026-10-08.md`(45개 게임, 제안 17개)와 `roblox_success_gap_2026-10-11.md`(할 일 20개)는 지난 기록이에요. 거기 있는 것(토요일 업데이트, 코드 칸, 마무리 카드, 보스 큰 공격 예고, 5~8분 던전, 계급 할인, 전직 갈래, 펫 모양, 진영 쏠림 규칙)은 다시 안 내요. 이 문서는 **첫 10분과 '세션 2'**에만 집중해요.
- **돈:** 뽑기·상자·힘 팔기는 제안하지 않아요(A23-75). 아래 10개는 전부 0원 코드·글 작업이에요.
- **출처 주의:** 로블록스 게임 쪽은 공식 분석이 거의 없어서 공략·위키·포럼이 출처예요. 숫자는 '그렇다고들 한다' 수준이에요. 추측은 (추측)이라고 적었어요.

## 1. 게임별 표

| 게임 | 첫 10분 장치 | 성장·목표 보이기 | 다시 오게 하는 것 | 돈 | 단점 |
|---|---|---|---|---|---|
| **Blox Fruits** | 스폰 옆 NPC가 Lv0 퀘스트, 주먹(1번 키)으로 바로 때림, 퀘스트 반복이 곧 레벨 | 나침반이 빨개지면 다음 섬, 레벨 사다리가 김 | 과일이 60분마다 나무 밑에 스폰(20분 뒤 사라짐), 2배 XP 코드(시간 누적, 접속 끊으면 멈춤), 셧다운 뒤 선물 섬 | 2배 패스·치장, 코드로 무료 2배 | 20분 만에 그만두는 애가 많다는 포럼 글(초반이 '무지성 노가다'), 복제품 많음 |
| **Pet Simulator 99** | 바로 부수기 → 코인 → 첫 알(80% 흔한 펫이어도 전부 데미지에 더해짐), 튜토리얼 퀘스트가 펫·재화를 줌 | 오른쪽 '랭크 목표' 판이 늘 보임, 다음 구역 문에 가격 | 매주 토요일 업데이트, 한정 행사 펫, 거래 | 알·행운 판매(우리는 안 함) | 끝이 없음, 후반은 시간이나 돈, 거래 사기 |
| **Dungeon Quest** | 던전 하나가 10분 제한, 첫 판부터 70킬, 끝 보스가 가장 좋은 장비 | 난이도마다 입장 레벨(1/6/12/20/27)이 다음 목표 | 짧은 판 반복, 친구와 하면 빠름, 하드코어는 매번 상위 드롭 | 2배 이벤트 | 콘텐츠를 다 해 버림, 개발 멈춤(부활 청원) |
| **Deepwoken** | 처음부터 어렵고 죽으면 캐릭터가 사라짐 → 매 싸움 긴장 | 목숨 3개가 늘 보임 | 고수가 새싹('freshie')을 구해 주는 문화, 혁신상 | 로벅스 부활(힘을 돈으로 되돌림) | 캐주얼은 바로 떠남, 괴롭힘·텃세 |
| **Anime Defenders** | 처음은 쉬움, 요약 소환 → 유닛 | 벽이 뚜렷함(유닛·진화 재료) | 코드로 젬, 배틀패스 시즌 | 소환 0.25%, 400회 천장, 행운 패스 1,299 | 페이투윈·리롤 문화 → 우리가 피할 모양 그대로 |
| **King Legacy** | Blox Fruits와 같음 | 레벨 5,450 벽 | 코드 | 젬(Lv100 뒤 열매 뽑기) | '초반이 느리다'는 글이 공식 쪽에도 있음, 복제품 천장 |
| **Arcane Odyssey** | 바다·배 판타지 | 섬 점령 | 큰 업데이트 하나 | 치장 | 업데이트 공백(한 달이 '빠른' 편), 6GB RAM 요구, 최고 7K → 지금 수백 명 |
| **Doors / The Mimic** | 복도와 문 하나, 목표가 10초 만에 이해됨, 문마다 '열까 말까'가 선택 | 문 번호 = 진행(100까지) | 죽어도 Knobs를 받음 → 다음 판 상점, 일일 런 | Knobs·부활 로벅스 | 돈으로 부활, 멀티 욕설(Mimic은 출처 약함) |
| **MapleStory** | 초보 단계는 죽어도 경험치 안 잃음, 전직하면 잃음 → 전직이 첫 '진짜 순간' | 전직 레벨(8/10)이 첫 목표, 가볍고 웃긴 그림 | 옷·결혼(힘 안 팔고 꾸미기) | 꾸미기 | 전직 전엔 버튼 하나, 반복 |
| **Genshin 첫 1시간** | 전투·퍼즐·수집·성장이 1시간 안에 다 나옴, 연출과 튜토리얼이 섞여 끊기지 않음 | 언덕·절벽마다 "올라가면 뭔가 있다" | 일일, 6주 업데이트 | 뽑기(우리는 안 함) | 몇 시간 뒤 레진·돈 벽, 처음 20시간만 좋다는 평 |
| **Zelda BotW 대평원** | 탑에 오르면 지도가 열리고, 신전이 멀리서 보여서 '저기 가고 싶다', 신전 4개 뒤 패러글라이더(상) | 보이는 것이 곧 목표 | — (싱글) | — | 글 설명 거의 없음 → 아이에겐 헤맴 가능(추측) |
| **Stardew 첫날** | 침대 옆 상자에 파스닙 씨앗 15개 + '심고 거둬라' 퀘스트, 에너지·가방이 모자라 고를 수밖에 없음 | 4일 뒤 수확 = 돌아올 이유, 작은 일이 계속 생김 | '하루만 더' | — | 첫 시도에 밤 몬스터·조작으로 당황한 글 |
| **Pokémon 첫 15분** | 엄마 집 → 풀밭 막힘 → 박사 → 스타터 고르기 → 라이벌이 상성 유리 포켓몬을 집고 바로 대결 → 이기면 $175 | 스타터 = 평생 정체성, 벽 지도가 다음 마을 예고 | 두 버전이 달라 친구가 필요 | — | 첫 대결에서 질 수 있음(의도) |

## 2. 우리 게임에 가져올 것 10개 (위가 먼저)

| # | 무엇 | 왜 (출처 게임) | 우리 어디에 | 크기 | 돈 |
|---|---|---|---|---|---|
| 1 | **목표 3층 칩:** HUD에 '지금'(있음, 1줄) + '이번 판'(예: Lv5에 첫 스킬) + '큰 것'(다음 왕관전 시각) 3줄을 늘 보이게 | Roblox 온보딩 문서: 짧은·중간·긴 목표를 눈에 보이는 곳에. BotW: 보이면 가고 싶음 | HUD 퀘스트 줄 밑, `Config` 글 표 | S | 0 |
| 2 | **세션 2 약속:** 첫 판 10분쯤(또는 Lv5)에 '내일 오면 받는 것' 카드 1장(출석 2일째 칸 미리 보기), 돌아온 사람에게 안내자 대사가 달라짐("You're back!") + 자리 비운 동안 소식 1줄(거위·왕관전 결과) | RoWatcher: 이탈은 세션 2에서 일어남, '돌아와야만 뜻이 있는 순간'이 필요. Stardew: 4일 뒤 수확 | 출석 창(1-A #5)과 안내자 글 표 | S | 0 |
| 3 | **첫 30분 무료 2배 XP 타이머**(접속 끊으면 멈춤, 1인 1회) | Blox Fruits 코드 2배(시간 누적·끊으면 멈춤)가 돌아올 이유. Roblox 문서: 초반 XP 문턱은 낮게 | `Config.Levels` + HUD 작은 칩. 2배 패스(영구)와 다른 상품이라 패스 값은 안 흐려짐 — 최종 검수가 정함 | S | 0 |
| 4 | **'보이는 곳엔 꼭 뭔가' 규칙:** 빛 마을 높은 곳 3곳(종탑·성벽·폭포 위)에 올라가면 상자 1개(물약·강화 주문서 1장) | Genshin·BotW: 언덕마다 비밀이 있어서 올라감 | 빛 마을 6단계 파트 뼈대, `Config` 상자 표 | S | 0 |
| 5 | **'떨어진 별'(1시간마다 스폰, 20분 뒤 사라짐, 혼자여도 됨):** 줍고 나서 제단에 바치기(빛·명예) / 챙기기(뿔·골드) 선택 | Blox Fruits 과일 스폰: 서버에 1명이어도 도는 '돌아올 시계'. 우리 왕관전·거위는 사람이 적으면 빈 행사(gameplay_plan 1-B) | 모든 구역 서버, 선택 카드 창(2-A #3) 재사용 | M | 0 |
| 6 | **또래 라이벌 NPC 1명(반대 진영):** 진영 고르면 반대편 아이가 "나도 지금 시작했어"라며 같은 첫 사냥을 먼저 하고 있고, 첫 10분 끝에 연습 대결 1회(져도 잃는 것 없음, 이기면 150골드와 별개로 칭호 한 줄) | Pokémon: 라이벌이 상성 유리를 집고 바로 대결 → 첫 싸움에 이야기가 생김 | 오프닝·첫 임무 글 표, 임시 기본 NPC 몸(A23-6) | M | 0 |
| 7 | **패배·퇴장 화면 '이번 판에 얻은 것':** 죽어도 XP·골드·도감 진행이 요약으로 뜨고 다음 목표 1줄 | Doors: 죽어도 Knobs를 받으니 '한 판 더' | 사망 화면, 멈춤 카드 | S | 0 |
| 8 | **진영 선택 화면에 '고르면 바뀌는 것 3개':** 내 마을·머리 위 모양·안내자(그림 없이 글 3줄 + 기존 승인 UI) | Pokémon 스타터 = 평생 정체성. Fable 리부트 논쟁: 보이는 신호가 사라지면 아쉬워함 | 진영 선택 UI 글 표 | S | 0 |
| 9 | **새싹 지킴이:** Lv15 이상이 초원에서 새싹(Lv1~5) 옆에서 같은 몹을 잡으면 새싹 XP는 그대로, 지킴이는 명예 +1(하루 5회 상한) | Deepwoken 'freshie' 구해 주기 문화, FFXIV 멘토 보상은 일부러 작게 | 초원 서버 `LootService` 기여 계산 | S | 0 |
| 10 | **첫 스킬(Lv5) 기쁨의 순간 1회:** 안내자 축하 말풍선 + 둥근 빛·종이꽃 + 다음 목표 1줄(빛살 없음) | Roblox 문서: 온보딩은 '기쁨의 순간'으로 끝내라. MapleStory: 전직이 첫 진짜 순간 | Lv5 레벨업 연출(A23-154로 멈춘 '찍고 싶은 순간' 중 이것만 먼저) | S | 0 |

- 3번은 성장 숫자 조정이라 최종 검수가 정해요(새 돈 종류 아님). 나머지는 세션이 정해도 돼요.
- 순서 근거: 1·2·7은 시험에서 '그만두는 곳'을 바로 줄여요. 3·4·10은 첫 10분을 짧고 기쁘게 해요. 5·6·8·9는 선악과 사람을 첫 10분에 넣어요.

## 3. 우리 게임의 약점 5개 (참고 게임과 견줘서)

1. **첫 10분이 길어요.** 계산으로 Lv10까지 18~23분(`gameplay_plan_2026-10-13.md` 1-A #4). Pokémon은 10분 안에 스타터·대결·돈까지 끝나고, Roblox 문서도 초반 XP 문턱을 낮추라고 해요. EarlyMult 0.35와 위 3·10번이 답이에요.
2. **선악 선택이 화면에 거의 없어요.** `gameplay_plan` 2-A #3이 "GDD §0의 가장 큰 구멍"이라고 적었어요. 왕관 조각 정화/삼키기는 Lv5 뒤예요. Fable·inFAMOUS는 첫 싸움부터 행동이 선택이에요 → §4의 1·5번.
3. **세션 2 약속이 없어요.** 출석 창이 없고(1-A #5), '다음 초기화' 칩도 없고(2-A #8), 돌아온 사람을 알아보는 대사가 없어요. RoWatcher는 이탈이 세션 2~5에서 난다고 해요 → 2번.
4. **골드 쓸 곳이 물약뿐이에요.** `gameplay_plan` 2-A #7. Pet Sim 99는 코인이 바로 '다음 구역 문'이고 Stardew는 씨앗이에요. 골드 쓸 곳이 생기기 전엔 150골드 보상이 가벼워요 → 4번 상자에 '주문서' 넣기, 2-A #7은 그대로.
5. **혼자일 때 서버 행사가 비어요.** `gameplay_plan` 1-B "1명일 때 왕관전·거위가 끝까지 가는지"가 아직 미확인이고, 12/15 초반 서버는 1~4명일 거예요. Blox Fruits의 과일 스폰은 혼자여도 돌아요 → 5번.

(덧: 성장이 운에만 달린 문제(T3 중간값 170마리, 2-A #6)는 Dungeon Quest의 '보스 = 확정 좋은 장비'가 답인데, 이미 계획(첫 브루트 T4 확정)에 있어서 약점 수에 안 넣었어요.)

## 4. 선악 선택이 '진짜'로 느껴지게 하는 장치 5개 (빛 vs 뿔, 어린이용, 피 없음)

1. **행동이 곧 선택 (inFAMOUS 2·Undertale ACT):** 사냥 중 가끔 '지친 몬스터'(HP 10% 아래, 별 표시)가 나와요. 마무리하면 뿔(골드 조금 더), 놓아주면 빛(재료 조금 더). XP는 같아요. 버튼 두 개가 아니라 '때리기 / G키 놓아주기'로 손이 고르게 해요. 착한 길이 손해면 '착한 척'만 하는 Undertale 교훈.
2. **마을 사람이 나를 알아봐요 (Fable):** NPC 인사말을 계급·기울기로 3단계(새싹/빛·뿔 낮음/높음). 뿔 아이가 빛 마을에 오면 상인이 "Hey, no pranks in my shop!" 같은 장난 톤, 설교·수치심 없음. 글 표만 바꾸니 0원.
3. **내 것이 나를 닮아요 (Black & White):** 무기 궤적 빛 색(금빛 반짝 / 보라 연기)과 펫 아기 슬라임 표정이 기울기로 바뀌어요. 빛살 없음. 파티클 색만이라 0원.
4. **게임이 기억해요 (Undertale Flowey·KOTOR):** 왕관 조각을 정화했는지 삼켰는지를 나중에 안내자·도감 카드 뒷면·보스 마무리 카드가 한 줄씩 언급해요. 되돌리기는 돈이 아니라 행동(착한 일·장난)으로만.
5. **버튼 색 대신 결과 한 줄 (inFAMOUS Second Son 비판):** 선택 카드의 두 단추에 파랑/빨강 대신 '이러면 이렇게 돼요' 한 줄(예: "Give it back → the kid smiles, +Honor" / "Keep it → +40 gold, +Mischief"). 둘 다 맛있게: 뿔 쪽도 바로 보이는 재미(골드·웃긴 연출)가 있어야 Mass Effect처럼 92%가 한쪽으로 쏠리지 않아요. 비율은 기록해요.

## 5. 출처

- Roblox 온보딩 문서: https://create.roblox.com/docs/en-us/production/game-design/onboarding
- Roblox 퍼널 이벤트: https://create.roblox.com/docs/en-us/production/analytics/funnel-events
- RoWatcher 세션 2~5 이탈: https://rowatcher.com/news/why-your-roblox-game-bleeds-players-between-sessions-2-and-5
- RoWatcher 장르별 유지율(RPG 없음, 참고만): https://rowatcher.com/news/retention-benchmarks-by-roblox-genre-what-good-actually-looks-like
- Blox Fruits 초보 가이드: https://www.pcgamesn.com/blox-fruits/guide , https://www.keengamer.com/articles/guides/a-roblox-beginners-guide-to-playing-blox-fruits/
- Blox Fruits 과일 스폰·2배 코드: https://www.sportskeeda.com/roblox-news/roblox-blox-fruits-codes-free-boost-beli-august-2022 , https://pcgamesn.com/blox-fruits/codes
- Blox Fruits '20분 만에 그만둠' 포럼: https://forum.arcaneodyssey.dev/t/why-is-blox-fruits-popular/85075
- Pet Simulator 99 초보·랭크: https://www.rpgstash.com/blog/roblox-pet-simulator-99-beginners-guide , https://progameguides.com/roblox/how-to-rank-up-fast-in-pet-simulator-99-roblox/ , https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)
- Dungeon Quest: https://www.sportskeeda.com/roblox-news/beginner-s-guide-roblox-dungeon-quest , https://www.sportskeeda.com/roblox-news/dungeon-quest-dungeon-types-enemies-and-more , https://www.change.org/p/support-the-revival-of-dungeon-quest-on-roblox
- Deepwoken: https://progameguides.com/roblox/what-is-roblox-deepwoken-beginner-tips-and-tricks/ , https://knowyourmeme.com/memes/subcultures/deepwoken-roblox , https://forum.arcaneodyssey.dev/t/a-review-of-deepwoken/73730
- Anime Defenders: https://www.pockettactics.com/anime-defenders/codes , https://earnaldo.com/blog/anime-fighters-simulator-vs-anime-defenders
- King Legacy: https://www.pcgamer.com/roblox/king-legacy-codes , https://gamewith.net/roblox/57439
- Arcane Odyssey: https://rowatcher.com/games/1180269832/arcane-odyssey , https://forum.arcaneodyssey.dev/t/arcane-odyssey-update-timeline-ript-controversy-discussion/160260
- Doors Knobs·상점: https://doors-game.fandom.com/wiki/Knobs , https://breezewiki.discard.no/doors-game/wiki/Shops
- MapleStory 첫인상·안내: https://www.engadget.com/2008-08-15-first-impressions-maple-story.html , https://massivelyop.com/2021/05/12/choose-my-adventure-how-guidance-made-all-the-difference-in-maplestory/
- Genshin 온보딩: https://uxdesign.cc/games-ux-building-the-right-onboarding-experience-a6e99cf4aaea , https://odr.chalmers.se/items/208425d7-7e28-4386-88a7-56edbd4ab554
- BotW 대평원: https://en.wikipedia.org/wiki/Great_Plateau , https://uxdesign.cc/user-onboarding-lessons-from-the-legend-of-zelda-breath-of-the-wild-8d22abec8342 , https://www.zeldadungeon.net/wiki/Sheikah_Tower
- Stardew 첫날: https://stardewvalleywiki.com/Parsnip_Seeds , https://gamerempire.net/stardew-valley-beginners-guide/ , https://nintendowire.com/features/impressions-first-spring-stardew-valley/
- Pokémon 오프닝: https://gbstudiocentral.com/?p=2241 , https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Red_and_Blue_1
- Fable 선악: https://www.henryjenkins.org/blog/2007/08/fable_and_other_moral_tales_a.html , https://gamecritics.com/thom-moyles/2567/ , https://www.inkl.com/news/fable-drops-the-original-games-good-and-evil-binary-for-a-subjective-and-multifaceted-reputation-system-which-is-why-you-dont-have-horns-or-halos , https://gamingbolt.com/?p=642395
- Undertale: https://mechanicsofmagic.com/2026/05/15/critical-play-world-building-undertale/ , https://media.gdcvault.com/GDC+2022/Game+Narrative+Poster+Review/Casserly+Paper.pdf , https://undertale.wiki/w/Reset
- Overlord: https://en.wikipedia.org/wiki/Overlord_(2007_video_game) , https://www.gamebanshee.com/news/83239-overlord-interview-v15-83239.html
- inFAMOUS 카르마: https://blog.us.playstation.com/2011/02/11/what-goes-around-comes-around-more-on-the-infamous-2-karma-system/comment-page-1/ , https://www.psu.com/news/infamous-second-son-karma-powers-will-change-based-on-your-choices-switch-alignment-whenever-you-like/ , https://whatculture.com/gaming/infamous-second-son-7-reasons-sadly-system-seller?page=4
- Black & White: https://en.wikipedia.org/wiki/Black_%26_White_(video_game) , https://gamedeveloper.com/design/postmortem-lionhead-studios-i-black-white-i-
