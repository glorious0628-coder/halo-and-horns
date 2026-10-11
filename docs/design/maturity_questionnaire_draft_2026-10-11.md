# 등급 설문(Maturity & Compliance) 답안 초안 — 2026-10-11

SPEC A23-136: 사용자가 10/17 비공개 시험 전에 직접 제출합니다. 이 문서는 답안 초안입니다.
목표: **Mild** (Roblox Kids 5~8세도 할 수 있는 등급). 가챠 없음, 그림·자유 건축 없음, 어울림 공간 아님.

## 한눈에 보기

- **예상 등급: Mild.** 싸움이 게임의 중심이라 "Repeated mild violence"가 붙습니다. 그래서 Minimal은 안 되고 Mild가 됩니다.
- Mild면 Kids(5~8세)·Select(9~15세) 둘 다 됩니다. 단, 아이들에게 실제로 열리는 것은 평가(HEP 250명 등)를 통과한 뒤입니다(A23-136, `docs/design/roblox_publish_rules_2026-10-11.md`).
- 붙을 것 같은 설명 꼬리표(content descriptors): **Repeated Mild Violence**, **Mild Fear**. 아래 "Burp" 한 줄을 지우지 않으면 **Mild Crude Humor**도 붙습니다(등급은 그대로 Mild).
- 18세 이상(Restricted)이 될 답은 하나도 없습니다. 그래서 한국에서도 막히지 않습니다.
- 출처: 공식 문서 https://create.roblox.com/docs/production/promotion/content-maturity (2026-10-11 원문 확인), https://create.roblox.com/docs/production/publishing/kids-and-select
- **선택지 글은 공식 문서 기준입니다.** 실제 설문 화면 글은 조금 다를 수 있습니다(확인 못 함).

## 제출 방법 (사용자 직접)

1. Creator Dashboard(https://create.roblox.com/dashboard/creations) → 우리 게임 썸네일 클릭.
2. 왼쪽 **Configure → Questionnaire** → **Start**.
3. 아래 답대로 고르고 **Save and Continue**.
4. 마지막 **Questionnaire Preview** 화면에서 확인:
   - 등급이 **Mild**인지
   - "non-compliant"(막힌 나라) 목록이 비어 있는지
5. 둘 다 맞으면 **Submit**. 아니면 제출하지 말고 검수에 사진을 보냅니다.
   - 등급을 맞추려고 답을 바꾸면 안 됩니다. 거짓 답은 게임·계정 벌을 받을 수 있습니다(공식 문서 "Content maturity moderation").
6. 나중에 게임 내용이 바뀌면 설문을 다시 해야 합니다(아래 "다시 해야 할 때").

## 등급이 정해지는 방식 (공식 문서)

| 등급 | 들어갈 수 있는 내용 | 누가 하나 |
|---|---|---|
| Minimal | 가끔 나오는 약한 폭력, 가짜 같은 피 조금 | Kids(5~8)·Select(9~15)·16+ |
| **Mild** | **자주 나오는 약한 폭력**, 가짜 같은 피 많이, **약한 무서움**, 약한 지저분한 농담 | Kids·Select·16+ |
| Moderate | 중간 폭력, 진짜 같은 피 조금, 중간 무서움, 오줌 농담, 못 하는 도박 장면 | Select·16+ (Kids 빠짐) |
| Restricted | 강한 폭력, 진짜 같은 피 많이, 연애, 술, 욕 | 나이 확인한 18+만, 한국 불가 |

- 등급은 **플레이어가 볼 수 있는 가장 센 장면** 기준입니다. 해골 폐허, PvP, 괴수화까지 포함해서 답합니다.
- 어울림 공간·자유 그림·민감한 주제는 등급과 따로 **16세 이상 전용**이 됩니다. 셋 다 "No"여야 아이들이 할 수 있습니다.

---

## 질문별 답안

표시: ✅ 확실 / ⚠️ 위험 있음 / ❓ 확실하지 않음

### 1. 폭력 (Violence) — ✅ Mild 유지

- **Q1 "Does this experience depict violence and/or violent content?"** → **Yes**
- **Q2 "How intense is the violence?"** → **Mild** ("Implied or unrealistic depictions of violence, such as bodies disappearing the moment their health reaches zero.")
- **Q3 "How frequent is the violence?"** → **Repeated** ("Violence either occurs often…")
- 왜:
  - 몬스터·사람 싸움이 게임의 중심입니다(GDD §0-2, §4). 자주 일어나니 Repeated가 정직한 답입니다.
  - 몬스터가 쓰러지면 색 입자가 튀고, 잠깐 넘어진 뒤 작아져서 1.15초 만에 사라집니다. 피·상처 없음(`src/ServerScriptService/MonsterService.luau` 84~90줄, 1155~1221줄 `deathPop`, 1008줄 `BreakJointsOnDeath = false`).
  - 플레이어가 쓰러지면 "KO!" 화면 + 3초 뒤 다시 일어남. 소리는 "만화식 어지러움, 죽음 음악 없음"(`DeathScreen.luau` 1~8줄, `Config.luau` 5640줄, `RespawnTime = 3` 58줄).
  - 무기는 칼·활·지팡이. 총 없음. 아바타는 블록 모양이라 진짜처럼 보이지 않습니다.
- 위험:
  - ⚠️ **PvP(사람끼리 KO)**: 고블린 숲·해골 폐허 왕관 구덩이(GDD §5-2 205~211줄). 그래도 표현은 가짜 같고 피가 없어서 Mild입니다. 다만 아이 평가(Kids·Select 안전 검토)에서 볼 수 있습니다(추측).
  - ❓ 플레이어 아바타는 Roblox 기본 죽음입니다: 몸 조각이 흩어집니다(`BreakJointsOnDeath`를 플레이어에게는 바꾸지 않음 — `src/` 검색 결과 몬스터만 바꿈). 피도 없고 대부분 Roblox 게임과 같아서 Mild로 봅니다(추측).
  - 괴수화: 악당이 3배로 커져 발 구르기(체력 6%) — 만화식(GDD §5-3 230~240줄, `Config.luau` 1239~1250줄).

### 2. 피 (Blood) — ✅

- **Q1 "Does this experience depict any blood?"** → **No**
- 왜:
  - `src/` 전체에서 피 효과 없음. "blood"라는 글자는 세 곳뿐이고 모두 화면에 안 나오는 이름입니다:
    - `Config.luau` 1285줄 주석("blood-red mood"), `WarService.luau` 3줄 주석.
    - 아이콘 키 `IconBloodSword`(`Config.luau` 6280줄). 그림은 빨간 보석 칼 + 하트 보석입니다. 피가 없습니다(`art/ui/IconBloodSword.png` 직접 봄).
  - 뿔 진영 "흡혈"은 화면에 "steal HP"라는 글자로만 나옵니다(`Config.luau` 599~637줄, 6538줄).
- 위험: 뿔이 이긴 판의 밤 하늘 안개가 짙은 빨강입니다(`Config.luau` 1305줄 `FogColor = (90, 10, 20)`). 피가 아니라 하늘 색이라 답에는 안 들어갑니다.

### 3. 무서움 (Fear) — ⚠️ Mild

- **Q1 "Does this experience include scary elements that may trigger fear?"** → **Yes** (조심해서 "예")
- **Q2 "What level of scary elements are there?"** → **Mild** (Mild 예: "creepy-looking NPCs, jump scares, ominous music, and/or gameplay that builds suspense")
- **Q3 "How frequently do the scary elements occur?"** → **Repeated** 권장 ❓
- 왜:
  - 해골 폐허는 베타에 열려 있습니다(`Config.ZoneOrder` 1634~1635줄): 해골 병사·해골 궁수·해골 기사·보스 Captain Clatter(`Config.luau` 2016·2032·2036·2045줄). 그림체는 귀엽습니다(보라 눈, 웃는 얼굴 — `art/review/IconMonSkeleton_check.png`).
  - 괴수화 10초 사이렌 + 추격(`Config.Kaiju.SirenSeconds = 10`, 1241줄), 원한 자루 45초 카운트다운과 머리 위 반투명 유령(GDD §5-3). "긴장을 쌓는 플레이"에 해당합니다.
  - King Slime 착지 "쿵" + 카메라 흔들림(SPEC A23-99).
  - 공식 문서: "게임 일부라도 무서운 것이 자주 나오면 Repeated". 해골 구역은 늘 해골이 있으니 Repeated가 안전한 답입니다.
- 이미 낮춰 둔 것: 이야기 글 규칙 "nothing scary"(`Config.luau` 7442줄), 왕 목소리 0.85배 밑으로 안 낮춤("lower turns scary", 5601줄), 폐허 시안 "spooky-cute and calm"(`art/prompts/Concept_SkeletonRuins.txt`), 뿔 마을 그림에 "no skulls"(`art/prompts/HornsPart_*`).
- 등급 영향: Mild 등급 설명에 "mild fear-based content"가 있습니다. Repeated여도 Mild로 봅니다(추측 — 미리보기에서 확인).
- 숨긴 것: 호박밭·유령 숲(유령 3종)은 꺼져 있습니다(`Config.Halloween.Enabled = false`, 2465줄). 새 구역(산호 해안·수정 숲)도 꺼져 있습니다(`Config.NewZones.Enabled = false`, 2549줄). 켜면 설문을 다시 봅니다.

### 4. 지저분한 농담 (Crude humor) — ⚠️ 한 줄 때문에

- **Q1 "Does this experience depict, reference, or encourage crude humor?"**
  - 지금 그대로면 → **Yes**, **Q2 "What is the level of crude humor?"** → **Mild** ("Depicts and/or references burping, farting…")
  - 아래 줄을 지운 뒤면 → **No** (권장)
- 왜: 황금 몬스터 혼잣말 **"Burp. Shiny."** 이 있습니다(`src/ReplicatedStorage/Shared/Config.luau` 2327줄). 공식 정의상 "트림" 언급 = Mild 지저분한 농담입니다.
  - 이것 말고는 방귀·똥·토·오줌 글이 `src/`에 없습니다(검색 확인).
- 등급 영향: 없음(Mild 그대로). 꼬리표 하나가 더 붙을 뿐입니다. 그래도 부모가 보는 게임 페이지가 깔끔해지니 지우기를 권합니다.
- 위험: A23-132 영어 밈 말투(`docs/design/memes_en_2026-10-11.md` 아직 없음)에 화장실 농담(예: toilet·fart 밈)이 들어가면 이 답이 Yes가 됩니다. 오줌 농담은 **Moderate**라 Kids가 빠집니다. 밈 목록에서 빼야 합니다.

### 5. 못 하는 도박 장면 (Unplayable gambling content) — ✅

- **Q1 "Does this experience contain unplayable gambling content?"** → **No**
- 왜: 카지노·슬롯·룰렛·카드 장면이 없습니다(`Config.luau` 검색: casino·slot·roulette·dice·lottery·bet 0개).
- 위험(작음):
  - 슬라임 대박 드랍 알림 글이 "★ JACKPOT! …"입니다(`Config.luau` 5327줄, 확률 1/20000 5224줄). 무료 드랍이라 도박은 아니지만 도박 냄새가 나는 단어입니다.
  - 강화 주문서 성공률 10/30/70%(GDD §0-1). 돈으로 사지 않고 드랍·거래소(골드)로만 얻습니다. 카지노 장면이 아니라 이 질문과는 상관없다고 봅니다(추측).
  - 골드 → 로벅스 바꾸기는 뺐습니다(A23-127). 계속 빼 둡니다(넣으면 도박·환전 문제).

### 6. 욕 (Strong language) — ✅

- **Q1 "Do you depict and/or want to allow strong language in your experience?"** → **No**
- 왜:
  - 게임 글에 욕이 없습니다(`src/` 화면 글 검색 결과 0).
  - 플레이어가 쓰는 글은 닉네임 하나뿐이고, Roblox 필터를 거칩니다(`NicknameService.luau` 224~225줄 `FilterStringAsync` → `GetNonChatStringForBroadcastAsync`). 추가로 욕·혐오·종교 권유·개인정보 요구 말도 막습니다(같은 파일 40~60줄 근처 목록).
  - 채팅은 Roblox 기본 채팅(필터 포함)입니다(`ChatText.luau` 1~10줄).
- 할 일: 게임 설정의 "Allow strong language"는 끈 채로 둡니다(❓ Studio·Dashboard에서 따로 확인 안 함).

### 7. 연애·사적 공간·어른 장소 (Romantic themes) — ✅

- **Q1 "Does this experience depict or reference (including in the title) romantic themes and/or primarily take place in private spaces (e.g. shower stalls, hotel rooms) or settings intended for adults (e.g. clubs, bars)?"** → **No**
- 왜: 연애 글 없음(love·kiss·date 등 검색: "The kids love you!" 같은 말만). 게임 이름 "Halo & Horns"에도 연애 뜻 없음. 가족 이야기(King Slime 아빠, A23-85)는 연애가 아닙니다. 술집·클럽 없음.
- 위험: 건물 안 들어가기는 베타 뒤입니다(A23-132). 그때 침실·여관 방을 만들어도 "주로" 거기서 하는 게임이 아니면 괜찮습니다. 침대·욕실 같은 장소는 넣을 때 검수가 다시 봅니다.

### 8. 술 (Alcohol) — ✅

- **Q1 "Does this experience depict, reference, or include use of alcohol?"** → **No**
- 왜: 술·맥주·와인·술집 글 없음(검색 확인). 빛 마을 가게는 **주스** 가게입니다(`Config.luau` 7585~7596줄, "Fresh juice", "Orange or berry?"). 물약 가게는 색깔 물약입니다(7600~7605줄).
- 위험: 앞으로 마을 장식(나무 통·병·잔)이 술처럼 보이면 안 됩니다. 나무 통(`Kit_X_Barrel`)은 괜찮지만, 맥주잔·와인병·술집 간판은 넣지 않습니다.

### 9. 어울림 공간 (Social hangout) — ✅

- **Q1 "Is the primary theme or activity of this experience a social hangout?"** → **No**
- (Q2 "Does your experience include private spaces?"는 Q1이 Yes일 때만 나옵니다.)
- 왜: 중심 활동은 사냥·성장·진영 싸움입니다(GDD §4 코어 루프). 채팅은 곁가지입니다.
- 위험: 공식 문서 "제목이나 설명에 어울림 공간 말이 있으면 어울림 공간으로 분류". 게임 설명에 "hang out", "chill", "make friends and chat" 같은 말을 쓰지 않습니다.

### 10. 자유 그림·글 (Free-form user creation) — ✅

- **Q1 "Does this experience include free-form user creation?"** → **No**
- 왜: 그리기·칠하기·낙서·픽셀 판 없음. 플레이어 입력칸은 닉네임 하나뿐입니다(`Panels.luau` 1440줄 `NicknameInput`이 `src/`의 유일한 TextBox). 닉네임은 Roblox 필터를 거치니 공식 예외("goes through Roblox moderation")에 해당합니다.
- 위험: 앞으로 게시판 글쓰기, 간판 직접 쓰기, 그림 그리기 기능을 넣으면 **16세 이상 전용**이 됩니다. 넣지 않습니다. 거래소 물건 설명도 직접 쓰는 칸 없이 고르기만 하게 합니다.

### 11. 민감한 주제 (Sensitive issues) — ✅ (천사·악마)

- **Q1 "Is the primary theme of this experience a sensitive issue?"** → **No**
- 왜:
  - 공식 정의는 "지금 사회에서 크게 싸우는 정치·사회·종교 문제"(이민, 사형, 총기 규제 등)입니다. 우리 천사·악마는 판타지 진영입니다. 실제 종교 이야기가 아닙니다.
  - 공식 문서: 도시 안의 종교 건물 같은 것은 "알릴 필요 없음". 빛 마을 대성당도 이 경우입니다.
  - 실제 종교·정치인·국가를 쓰지 않는다는 규칙이 있습니다(SPEC A23 785줄).
  - 그림에 십자가를 넣지 않았습니다(`art/prompts/Town_Halo_Spawn.txt` 등 8개 "No cross shapes", 폐허·왕관 그림 다수 "No cross"). 오망성·666·사탄 같은 것은 `src/`·승인 그림 목록에 없습니다(검색 확인).
  - 닉네임에서 종교 권유("join my church" 등)·종교 혐오를 막습니다(`NicknameService.luau` 57~58줄, 40~51줄).
- 위험:
  - ⚠️ 계급 이름 "Saint", "Archangel", "Demon King"(`Config.luau` 910줄 근처, 7455줄)과 "angel side / devil side" 글(2777줄)이 있습니다. 판타지 말이라 괜찮다고 봅니다(추측). 다만 실제 성경 구절·기도·십자가·뒤집힌 십자가·오망성은 앞으로도 넣지 않습니다.

### 12. 유료 랜덤 아이템 (Paid random items) — ✅ 베타는 없음

- **Q1 "Does this experience contain paid random items?"** → **No**
- (Q2 "Does this experience respect the ArePaidRandomItemsRestricted policy API?"는 Q1이 Yes일 때만.)
- 왜:
  - 로벅스 상품은 모두 정해진 것입니다: 2배 경험치·2배 골드·VIP 패스(`Config.luau` 4142~4146줄), 후광·뿔 색 패스 4개(4199~4203줄), 개인 서버(A23-75). 랜덤 없음.
  - 직업·진영 변경권(4120~4123줄)은 베타에 안 팝니다(A23-28, `Id = 0`). 팔더라도 정해진 1장이라 랜덤이 아닙니다.
  - 뽑기(가챠)는 문서에만 있고 코드·상품이 없습니다(GDD §10-1 376~385줄, A23-75 585줄).
  - 랜덤 보상(일일 보너스 상자 10% 변경권, 거위 희귀, 드랍, 강화 주문서)은 모두 **무료**로 얻습니다. 공식 문서: 돈을 안 내고 행동으로 받는 것은 알릴 필요 없음.
  - 골드를 로벅스로 파는 상품이 없습니다(`Config.Products`에 변경권 2개뿐).
- 위험: `PolicyService`(`ArePaidRandomItemsRestricted`) 코드가 아직 없습니다(`src/` 검색 0). 가챠를 넣을 때 꼭 함께 넣고 설문을 다시 합니다.

### 13. 산 아이템 거래 (Paid item trading) — ✅ 지금은 없음

- **Q1 "Does this experience contain the ability for users to trade items that they paid for?"** → **No**
- 왜: 지금 코드에 거래 기능이 없습니다(`src/ServerScriptService/`에 거래소 서비스 없음). 계획된 거래소(A23-127·133)는 드랍·제작 물건을 **골드**로 사고팝니다. 로벅스로 산 패스·후광 색은 아이템이 아니라 거래할 수 없습니다.
- 위험: ⚠️ 거래소를 넣을 때(11/24 전) 로벅스로 산 것(변경권·치장)은 절대 올릴 수 없게 막아야 이 답이 계속 No입니다. 거래소가 들어가면 설문을 다시 확인합니다.

### 14. 미디어 (Media) — ✅

- **Q1 "Does your experience allow users to share media content (videos, images, text, audio, 3D models) from their gameplay that other users can see?"** → **No**
- **Q2 "Does your experience contain content feeds with continuous loading or audio/video that plays automatically?"** → **No** ❓
- **Q3 "Does your experience allow users to view content that was captured from other experiences on Roblox?"** → **No**
- 왜: 사진·영상 공유, 영상 화면(VideoFrame), 캡처 기능이 없습니다(`src/` 검색: CaptureService·VideoFrame 0개). 오프닝도 영상이 아니라 3D 장면입니다(A23-99). 친구 초대는 Roblox 기본 창입니다(`Invite.luau`).
- ❓ Q2: 베타 전에 구역 배경 음악을 넣을 예정입니다(A23-100). 이 질문은 "스크롤하면 계속 나오는 피드" 이야기라 게임 배경 음악은 해당 없다고 봅니다(추측).

### 15. 생성 AI (AI interaction) — ✅

- **Q1 "Does your experience allow users to interact with generative AI components?"** → **No**
- 왜: NPC 말은 모두 미리 쓴 글입니다(GDD §0-1 33줄 "실제 AI 대화 연결은 승인 안 됨"). AI 기술 스튜디오도 연결 안 함(A23-100). 게임에서 외부로 HTTP 요청을 하지 않습니다(`src/` 검색: RequestAsync·PostAsync 0개, place `HttpEnabled` false — 보안 점검 문서).
- 우리가 Firefly·Tripo로 그림을 만든 것은 이 질문과 상관없습니다(공식 문서: "개발에 AI를 쓴 것은 빼고 답함").

---

## 가장 위험한 답 3개

1. **무서움(Fear)**: 해골 폐허·괴수 사이렌·원한 유령 때문에 "Yes / Mild / Repeated". 등급은 Mild 그대로로 보지만 미리보기에서 꼭 확인합니다. 유령 숲(할로윈)을 다시 켜면 더 늘어납니다.
2. **지저분한 농담(Crude humor)**: "Burp. Shiny." 한 줄. 지우면 No, 두면 Mild 꼬리표. 앞으로 밈 말투에서 화장실 농담이 들어오면 위험합니다(오줌 = Moderate → Kids 빠짐).
3. **폭력(Violence)의 PvP·약탈**: 사람끼리 KO, "Rob %d Knights of Light"(`Config.luau` 3990~3991줄), "Rob the Knights…"(836줄), 괴수 발 구르기. 표현이 가짜 같아서 Mild지만, 아이 평가의 안전 검토에서 "훔치기·괴롭히기" 주제로 볼 수 있습니다(추측).

## Mild를 지키기 위한 게임 안 바꾸기 (필요하면)

| # | 바꿀 것 | 왜 | 담당 | 크기 |
|---|---|---|---|---|
| 1 | `Config.luau` 2327줄 `Idle = { "Burp. Shiny." }` → 예: `"Shiny shiny~"` | 지저분한 농담 답을 No로 | 게임성 개발 2 (글 = 검수) | 1줄, **제출 전 권장** |
| 2 | 영어 밈 목록(A23-132)에서 화장실·방귀·오줌 밈 빼기 | 오줌은 Moderate | 검수 | 문서 규칙 1줄 |
| 3 | "JACKPOT!" → 예: "LEGENDARY DROP!"(`Config.luau` 5327줄, 319줄) | 도박 냄새 줄이기 | 검수 글 + 게임성 개발 2 | 2줄, 선택 |
| 4 | 플레이어 쓰러질 때 몸 조각 흩어짐 끄기(`BreakJointsOnDeath = false`) + 작은 반짝 사라짐 | 몬스터와 같은 부드러운 KO | 게임성 개발 2(서버) + 게임성 개발 1(효과) | 작음, 선택 |
| 5 | "Rob" → 예: "Raid"(`Config.luau` 836·3990~3991줄) | 아이 평가에서 훔치기 느낌 줄이기 | 검수 글 + 게임성 개발 2 | 3줄, 선택(사용자 승인 디자인 말투라 사용자 확인 필요) |
| 6 | 거래소 만들 때 로벅스로 산 것 거래 금지 | 산 아이템 거래 No 유지 | 게임성 개발 2 | 거래소 설계에 포함 |
| 7 | 가챠를 넣을 때 `PolicyService` 확인 + 확률 표시 | 유료 랜덤 아이템 규칙 | 게임성 개발 2 | 그때 |
| 8 | 아이콘 키 `IconBloodSword` → 예: `IconRubySword` | 이름만 피 | 이미지 개발 | 다음 새 그림 올릴 때만(지금 쓰는 그림은 손대지 않음 규칙) |
| 9 | 게임 설명 글에 hangout·chill·date 같은 말 안 쓰기 | 어울림 공간·연애로 분류 막기 | 검수(설명 글) | 0 |

## 설문을 다시 해야 할 때

공식 문서: 답이 바뀌는 업데이트를 내면 **반드시 다시 제출**해야 합니다.
- 호박밭·유령 숲(유령 3종)을 다시 켤 때 → 무서움 다시 봄.
- 새 구역(산호 해안·수정 숲) 켤 때, 새 보스·새 몬스터가 들어올 때.
- 거래소가 들어올 때 → 산 아이템 거래 다시 확인.
- 가챠·확률 상품을 팔 때 → 유료 랜덤 아이템 Yes + PolicyService.
- 건물 안(실내)이 열릴 때 → 사적 공간 다시 확인.
- 영어 밈 말투가 들어올 때 → 지저분한 농담 다시 확인.
- 글을 쓰거나 그리는 기능, 사진 공유, AI NPC를 넣을 때.

## 확실하지 않은 것

- 실제 설문 화면의 선택지 글이 공식 문서와 똑같은지 모릅니다. 문서에 없는 질문이 더 있을 수 있습니다.
- "Mild 무서움 + Repeated"가 미리보기에서 Mild로 나오는지: 문서 표로는 Mild로 보입니다(추측).
- 플레이어 아바타가 흩어지는 Roblox 기본 죽음을 Roblox가 Mild로 보는지: 흔한 기본 동작이라 그렇게 봅니다(추측).
- Dashboard의 "Allow strong language" 설정 상태는 직접 보지 않았습니다.
- "Rob/steal" 같은 훔치기 주제는 설문 질문에는 없습니다. 아이 평가 안전 검토에서 어떻게 볼지는 모릅니다.
