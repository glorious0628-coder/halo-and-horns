# 로블록스 성공 조건 vs 우리 게임 (2026-10-11, 검수 조사 워크플로)

사용자가 공유한 글(해외 밈·아이들이 좋아하는 것·귀엽고 예쁜 그림·로블록스다운 UI·수수료·광고비) 기준으로 조사 4갈래(아이들 취향·UI/그림·돈·밈) → 우리 게임과 비교. 아래 숫자·규칙은 조사 에이전트가 찾은 출처 기준이며, 게시·나이 규칙은 roblox-policy-check 워크플로로 다시 확인 중(확인 전에는 결정에 쓰지 않음). 사용자 결정 표시된 것은 검수가 물어봄.

## 우리 게임이 이미 잘 맞는 것 (근거)
- **한 줄로 설명돼요.** "모든 행동이 천사 아니면 악마 쪽으로 기운다"(GDD §0). 내 아바타 위에 후광이나 뿔이 떠요. 히트작은 모두 10초 안에 설명되는 게임이에요(Grow a Garden "심고, 기다리고, 팔기"). 후광·뿔은 작은 아이콘에서도 알아볼 수 있는 대표 모양이에요.
- **서버 전체가 같은 시계를 봐요.** 왕관 쟁탈전과 황금 거위가 각각 10분마다 엇갈려 열려서, 5분마다 뭔가 있어요(GDD §2·§4). 황금 알 줍기(A23-131)는 아무도 다치지 않는 모두의 행사예요. Grow a Garden의 5분 재입고, Admin Abuse 행사와 같은 원리예요.
- **무료로도 다 할 수 있어요.** 능력치는 팔지 않아요(A23-75). 강화해도 무기가 부서지지 않아요. 뽑기는 문서에만 있어요. Sailor Piece는 "무료로 다 됨"으로 Blox Fruits를 앞질렀어요(약 344K 대 289K).
- **잃어도 조금이고, 되찾을 수 있어요.** 원한 돈자루 45초 동안 기사단이 잡으면 120%로 돌려줘요. 금고·무기·레벨은 뺏기지 않고, 초보 보호도 있어요. Steal a Brainrot의 훔치는 재미에서 아이가 우는 부분만 뺀 셈이에요.
- **쉬어도 벌이 없어요.** 휴가 보너스 70%, 출석은 모은 날 수(A23-77), 일기는 늦게 와도 몰아 읽기(A23-79). Adopt Me의 15시간 받기 창보다 너그러워요.
- **업데이트 요일이 정해져 있어요.** 매주 수요일 05:00 UTC(A23-83). 오래 가는 게임은 모두 요일이 고정돼 있어요(Grow a Garden 토, Adopt Me 금, Sailor Piece 수).
- **희귀 단계가 눈에 보여요.** 황금 몬스터 4%, 슬라임의 전설 대박 드롭, 회·초·파·보·금 등급 색. 펫도 있고(아기 슬라임, 조련사), 펫 장비도 생겨요(A23-133).
- **거래가 안전해요.** 서버가 확인하는 거래소만 있고 1:1 거래는 없어요(A23-127·133). 어린이 사기를 막기에 좋아요.
- **플랫폼 규칙을 이미 알고 있어요.** Kids·Select 보증금 계획(A23-82), 알림 동의는 13세 이상만(A23-79), 옷 규칙, 빛살 무늬 금지, 밈 금지어 방향(A23-132)이 있어요.
- **UI 바탕이 좋아요.**
  - 모든 UI 그림이 `Config.UIArt` 한 곳에 있어요(그림 ID 445개).
  - UIStroke 테두리와 Back 튀는 움직임(21곳)을 써요.
  - 글꼴은 옛 Gotham·Fredoka 대신 Denk One과 Montserrat을 써요.
  - 언어별 글꼴 칸(`FONT.Sets`)도 이미 있어요.
- **베타가 영어와 한국어 둘 다예요**(A23-133). Standout Games 추천은 번역이 된 게임을 좋게 봐요.
- **일부러 안 따라 하는 것도 맞아요.** 남의 밈 캐릭터(브레인롯은 저작권 소송 중), 크게 잃는 약탈, 영상 보면 주는 보상(2026-08 금지), 지금 당장 유료 뽑기.

## 모자란 것 → 할 일 (20개)
| # | 할 일 | 왜 (성공 포인트·근거) | 담당 세션 | 크기 | 베타 전/후 |
|---|---|---|---|---|---|
| 1 | 11월 중순 "조용한 공개" + 신분증 나이 확인 + 2단계 인증 + 보증금 1,000 R$ | 12/1에 처음 공개하면 8~15세는 못 봐요. 나이 확인된 16세 이상 "열심히 하는" 사람의 고유 플레이 250회(60일 안)를 넘어야 열려요. 공개 계정은 2025-12-17부터 신분증 확인이 필요해요 | 사용자(클릭·결제) + 검수(체크리스트) | S | 전 **(사용자 결정)** |
| 2 | 성숙도 설문을 "Mild"에 맞추는 사전 점검: 피, 실제 종교 기호(십자가·오각별), 화장실 농담, 연애 말투가 없는지 | Kids(5~8세)는 Minimal·Mild 게임만 봐요. 연애 주제가 있으면 18세 이상 전용이 돼요 | 검수 | S | 전 |
| 3 | 상점 가격을 고정 숫자 대신 `GetProductInfo`로 읽기(`ShopUI.luau` 40~43줄) | 지역 가격(기본 켜짐, 최저 30%)과 Plus 할인 때 상점 글과 구매 창 가격이 달라져요. 가격 시험 도구도 못 써요. Roblox는 지역 가격으로 사는 사람이 +26%라고 해요 | 게임성 개발 1 | S | 전 |
| 4 | 한국어 글꼴 세트: `FONT.Sets.ko` 추가, Studio에서 한글 글꼴 직접 확인, 옛 이름(GothamBold, `Config.Fonts`) 정리 | Denk One·Montserrat에는 한글이 없어요. 베타는 영어와 한국어 둘 다예요 | 이미지 개발 | S | 전 |
| 5 | 썸네일 3~5장 + 아이콘 + 30~60초 영상 | 썸네일을 여러 장 돌리면 평균 +8.5%(최대 +50%). 진짜 게임 화면, 3단어 이하, 아래 15%는 비우기, 아이콘은 150px에서도 보이게. 예: 반은 후광, 반은 뿔인 아바타 + "PICK A SIDE" | 이미지 생성 2 + 촬영 편집 1 | M | 전 |
| 6 | 이름 고정 + 정직한 태그 하나("[WINTER] Halo & Horns"), 영·한 설명, Roblox 행사 "Public Beta 12/1 11:00 KST" + 외부 소개 신청, 커뮤니티 열기, 직접 링크 | 행사에는 "Notify Me" 버튼이 있어요. 직접 링크나 이름 검색으로 온 새 손님이 처음 쓰는 $100의 35%를 받아요(평균 DAU 100 필요). 가짜 태그는 규칙 위반이에요 | 검수(글) + 사용자(Creator Hub) | S | 전 |
| 7 | 채팅 없이 노는 신호: 짧은 신호 버튼(고마워·도와줘·같이 가자) + 진영 이모트 2개(10초 이하) + VIP 이모트 | Kids 계정은 채팅이 없어요. VIP 패스를 팔기 전에 VIP 이모트가 있어야 해요(A23-75-2). 쇼츠 장면으로도 좋아요 | 게임성 개발 1 + 이미지 생성 3 | M | 전 |
| 8 | 코드 입력 버튼 + 출시 코드 1개(BB30을 베타 전으로), 보상은 물약·장식만 | 코드를 내면 몇 시간 안에 접속이 늘고, 일주일쯤 걸려 내려가요. Rivals는 좋아요 5만 개마다 코드를 줘요. 코드가 없을 땐 버튼을 숨겨요 | 게임성 개발 2 + 게임성 개발 1 | S | 전 |
| 9 | "찍고 싶은 순간" 연출: 희귀 드롭·레벨업·KO·진영 변신에 둥근 빛·반짝이·종이꽃·소리. 팝업은 한 번에 하나 | 2025년 여름 게임 관련 TikTok 5개 중 1개가 Roblox 이야기였어요. 빛살 무늬 금지는 그대로 지켜요 | 게임성 개발 1 + 이미지 개발 | M | 전 |
| 10 | 영어 밈 문서 `docs/design/memes_en_2026-10-11.md` 쓰기(A23-132에서 약속했는데 아직 없음): "Aura" 중심, 금지어 목록, 한국어 속어 점검 | "Aura"는 2026년에도 쓰이는 아이 안전한 밈이고 후광과 잘 맞아요. 브레인롯 밈은 만든 사람들이 2025-12에 "끝났다"고 했어요 | 검수 | S | 전 |
| 11 | 베타 숫자판: 첫 화면 통과율, D1·D7, 한 번 노는 시간, 사는 사람 %, 광고 1플레이 값을 매일 보기 | 목표: D1 12% 이상(중앙값 10~11.5%), 한 번 19분 이상. Home 추천은 28일 동안 남는 비율을 봐요 | 게임성 개발 2 + 검수 | S | 전 |
| 12 | Lv25 이후 할 일(F-1)을 "미정"에서 "필수"로(게시판·일일로 채우기) | 고수는 금방 Lv25에 닿아서 D7이 떨어져요. Roblox는 오래 남는 게임에 노출을 더 줘요(2026 Q2) | 게임성 개발 2(API) | L | 전 |
| 13 | 광고 A: "Engagement" 목표, 조용한 공개와 같은 때 | 250회 문턱을 빨리 넘기기. 13세 미만에게는 광고가 아예 안 나가요 | 사용자(결제) + 검수 | S | 전 **(사용자 결정)** |
| 14 | 광고 B(13세 이상, 7일) + 작은 크리에이터 5~10명(직접 링크) | 베타 첫 주 데이터를 얻어요. 한 개발자는 손님 90%가 추천, 10%가 영상으로 왔어요 | 사용자 + 검수 + 촬영 편집 1 | S | 베타 주 **(사용자 결정)** |
| 15 | 매주 고정 시간 진영 행사 "Team Halo vs Team Horns": 1시간, 무료 진영 아이템 1개, 진영 합계 막대 | Grow a Garden의 "팀 그린빈" 행사 날 Roblox 동시 접속이 47.4M으로 최고를 찍었어요 | 게임성 개발 2 + 1 | M | 후(12/12~) **(시간 = 사용자)** |
| 16 | 겨울 행사: 놀아서 받는 눈 후광·석탄 뿔, 연속이 끊겨도 괜찮은 로그인 선물 달력 | Dress to Impress 겨울 달력(15칸), Steal a Brainrot 크리스마스 한정 | 게임성 개발 2 + 1 + 이미지 생성 2 | M | 후(12월 둘째 주) |
| 17 | 자리를 비운 동안 쌓이는 천사 제단·악마 대장간(최대 8시간, GDD-13-2) | 들어오면 늘 뭔가 받아요(Grow a Garden 작물, Steal a Brainrot 초당 수입) | 게임성 개발 2 | M | 후 |
| 18 | 놀아서 얻는 펫 알 + 4개를 1개로 합치는 Glowing/Shadowed 장식판 | Adopt Me의 4개→Neon→Mega 사다리, Steal An Egg(2026)의 부화 | 게임성 개발 3·4 + 이미지 생성 2 | L | 후 |
| 19 | Standout Games 추천 신청 | 새 모양, 번역, 영상, 썸네일을 봐요. 영·한과 천사/악마 주제가 잘 맞아요 | 검수(글) + 사용자(제출) | S | 후(베타 안정 뒤) |
| 20 | DevEx 준비: W-8BEN 세금 서류, 첫 30,000 R$ 전에 등록 | 첫 지급은 약 10영업일 걸려요 | 사용자 | S | 후 |

## 돈

**수수료와 우리 몫 (사실)**
- 패스와 개인 서버를 팔면 우리 몫은 70%예요.
- DevEx(현금으로 바꾸기)는 1 R$당 $0.0038이에요(2025-09-05부터). 최소 30,000 R$ = $114, 한 달에 한 번, 13세 이상, 세금 서류 W-8이 필요해요.

| 상품 | 사는 사람이 내는 돈(약) | 우리 R$ | 우리 $ | 원(₩1,400) |
|---|---|---|---|---|
| 치장 99 | $1.24 | 69 | $0.26 | ₩370 |
| 골드 2배 149 | $1.86 | 104 | $0.40 | ₩550 |
| 경험치 2배 199 | $2.48 | 139 | $0.53 | ₩740 |
| VIP 249 | $3.11 | 174 | $0.66 | ₩930 |
| 개인 서버 100/월 | $1.25 | 70 | $0.27 | ₩370 |

- 가족이 낸 돈의 약 21%가 우리에게 와요. 폰에서는 로벅스가 최대 25% 비싸서 더 적어요.

**계산 예**
- 첫 $114를 받으려면 경험치 2배 패스가 약 216개 팔려야 해요.
- 하루 1,000명이 놀고 그중 1.25%가 산다고 해 봐요(Roblox 전체 평균이고, 우리 숫자는 아니에요).
  - 하루 12.5명 × 139 R$ ≈ 1,740 R$
  - 한 달 약 52,000 R$ ≈ $198 ≈ ₩28만
- 다른 수입도 있어요.
  - Creator Rewards: "돈 쓰는 사람"이 10분 넘게 놀면 그 사람당 하루 5 R$. 그날 처음 연 게임 3개 안에 들어야 해요.
  - 게임 안에서 Plus 가입이 생기면 250 R$ × 3달.
- 하지 말 것: 로벅스를 사서 광고 크레딧으로 바꾸기. 가치의 약 35%만 남아요.

**광고비 — 사용자 결정 필요**
- 13세 미만에게는 광고가 안 나가요. 어린 아이들은 Home 추천, 검색, YouTube로 와요.
- 1플레이 값은 포럼 기준 $0.002~0.005면 좋고, 비싸면 $0.02예요.
- 첫 판에서 파는 돈은 1플레이당 약 $0.0066(추정)이에요. 그래서 광고는 돈을 버는 용도가 아니에요. 250회 문턱을 넘고, 추천에 첫 데이터를 주는 용도예요.

| 항목 | 언제 | 적게 | 넉넉히 |
|---|---|---|---|
| 보증금 1,000 R$(돌려받음) | 조용한 공개 날 | ~$12 | ~$12 |
| 광고 A Engagement(1플레이 $0.05~0.20 추정) | 11월 중순 | $50 | $100 |
| 광고 B Plays 13세 이상, 7일 | 12/1~12/7 | $70 | $140 |
| 작은 크리에이터 | 베타 주 | $50 | $200 |
| 여분(D1 10~12% 이상이고, 1플레이 수입이 광고값보다 클 때만) | 12월 | $0 | $300 |
| **합계** | | **≈$180 (₩25만)** | **≈$750 (₩105만)** |

- 결제는 사용자가 직접 해요(카드는 18세 이상, 첫 결제 $5). Claude는 결제하지 않아요.

## 사용자에게 물을 것 (3개)
1. **11월 중순에 조용히 공개하고, 그날 보증금·신분증·2단계 인증을 할까요?**
   - 추천: 예. 11/10~11/17 사이에 검수가 첫 10분이 안정된 걸 확인한 날로요.
   - 원래(A23-82)는 10/31 베타 날 하기로 했는데, 베타가 12/1로 밀려서 다시 묻는 거예요.
   - 안 하면 12/1 베타 첫 손님은 16세 이상뿐이에요.
2. **광고비는 얼마로 할까요?** 0 / 적게 ₩25만 / 넉넉히 ₩105만.
   - 추천: 적게. 숫자가 좋으면 12월에 여분을 써요.
3. **매주 진영 행사 시간을 토요일 11:00 KST로 할까요?** 미국 기준 금요일 18:00 PST, 21:00 EST예요.
   - 추천: 예, 12/12부터.
   - 업데이트 요일은 그대로 수요일이에요.

**출처:** [Claude for Startups](https://claude.com/programs/startups) · [Kids & Select](https://create.roblox.com/docs/production/publishing/kids-and-select) · [DevEx](https://create.roblox.com/docs/production/monetization/developer-exchange) · [Roblox Plus](https://create.roblox.com/docs/en-us/production/monetization/roblox-plus) · [Creator Rewards](https://create.roblox.com/docs/creator-rewards) · [Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager) · [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) · [Regional pricing](https://create.roblox.com/docs/en-us/production/monetization/regional-pricing) · [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) · [RoWatcher Blox Fruits vs Sailor Piece](https://rowatcher.com/news/blox-fruits-vs-sailor-piece-which-anime-rpg-is-actually-growing-faster-in-2026) · [Tubefilter Admin War](https://www.tubefilter.com/2025/08/25/roblox-grow-garden-steal-brainrot-admin-war-record/amp/) · [Incorpx: Anthropic startup credits](https://www.incorpx.io/grants/perks/anthropic-for-startups-claude-api-credits)

**읽은 파일(수정 없음):** `C:\Users\glori\Documents\Roblox\Game\docs\GDD.md`, `C:\Users\glori\Documents\Roblox\Game\docs\SPEC_ADDENDUM.md`(A23-75·77·79·82·83·127~135), `C:\Users\glori\Documents\Roblox\Game\docs\RELEASE_PLAN.md`, `C:\Users\glori\Documents\Roblox\Game\docs\design\gameplay_remaining_2026-10-11.md`, `C:\Users\glori\Documents\Roblox\Game\docs\design\golden_egg_2026-10-11.md`, `C:\Users\glori\Documents\Roblox\Game\docs\design\launch_ops_checklist.md`, `C:\Users\glori\Documents\Roblox\Game\docs\website\README_handoff_2026-10-08.md`, `C:\Users\glori\Documents\Roblox\Game\docs\website\UPLOAD_KO.md`, `C:\Users\glori\Documents\Roblox\Game\docs\website\index.html`, `C:\Users\glori\Documents\Roblox\Game\src\StarterPlayer\StarterPlayerScripts\ShopUI.luau`, `C:\Users\glori\Documents\Roblox\Game\src\StarterPlayer\StarterPlayerScripts\UIKit.luau`, `C:\Users\glori\Documents\Roblox\Game\tools\api_agent.py`. `docs/design/memes_en_2026-10-11.md` 파일은 아직 없어요.
