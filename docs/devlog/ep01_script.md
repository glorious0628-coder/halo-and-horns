# 개발 일지 1편 대본 (촬영 편집, 2026-10-06) — 검수 OK(2026-10-06, 고칠 줄 반영) · 0번 장면 = 사용자 자기소개 훅(검수 전달 2026-10-06)

> 순서(검수·사용자 2026-10-06): **쇼츠 먼저**(`shorts01_plan.json`), 이 긴 판은 채널 인증 뒤에.

- **제목(안):** I Made a Roblox Halloween Game with 7 AI Teammates #1
- **길이 목표:** 약 5분 30초(영어 내레이션 약 700단어, MeloTTS EN-US). 장면마다 2~4초 컷, 정지 그림은 천천히 확대·이동.
- **말투:** 만든 사람(사용자) 1인칭 "I", 팀은 "my AI teammates". 짧은 문장, 아이도 알아듣는 쉬운 영어. 영어 자막은 화면에 굵은 외곽선으로, 한국어 자막은 따로 `.srt`.
- **영어 이름:** `docs/design/glossary_en_2026-10-06.md`(검수 용어 표)를 따른다: Halo & Horns, Knights of Light, Horn Legion, Artisan Guild, Wanted, Crown Shard, Purify / Devour, Auto Battle, Slime, Pumpkin Slime, Little Ghost, Bat Goblin, Baby Slime, Pumpkin King, Pumpkin Patch.
- **남은 날 수 `{DAYS}`:** 빌드하는 날 기준으로 2026-10-31 11:00 KST까지 남은 날을 자동으로 넣는다(`tools/devlog_build.py`, 영어 낱말로 읽음).
- **도구 이름:** Claude·Adobe Firefly·Tripo는 사실대로 말한다. 로고는 크게 쓰지 않고, 설명란에 "Not sponsored.".
- **사실 확인:** 대사 속 기능은 지금 코드·문서에 있는 것만 넣었다(왕관 조각 정화/삼킴 = StoryQuestService, 수배 별 = CharacterVisuals, 호박 대왕 20분마다·5분·Lv5 미만 보호·11/9 끝 = Config.Halloween, Tripo 6종 하룻저녁 = 1ccddb7→bfcba1b, B안 = A23-40). 없는 기능은 "다음 편"으로만 말한다.
- **빼는 것:** 계정 이름·이메일·ID, 옛 계정 정지 이야기, 거절된 그림(장인 궁수), 오프닝 연출(다시 만들 예정), 다른 게임 이름, 돈·크레딧 숫자.
- **화면 칸 표시:** 🎥 = FilmSet Studio 녹화(Play 중 게임 장면), 🖼 = 이미 있는 그림·캡처, 🧊 = Tripo GLB를 Blender로 돌려 찍은 회전 영상, ✏️ = 편집에서 만드는 글자·도표.

---

## 0. 첫 장면 (0:00–0:25) — 감독(사용자) 자기소개 훅 (검수 전달, 사용자 2026-10-06)
사용자 원문: "나는 코드의 '코' 자도 모름, 디자인의 '디' 자도 모름! 하지만 게임을 너무 좋아함! 게임을 너무 많이 하면서 돈을 너무 소비하니까 현타가 와서 '내가 만들자'가 된 거!" — 돈 숫자·계정·이름·얼굴은 넣지 않는다.
화면: ✏️ 코드 글자 위에 빨간 X → ✏️ 낙서 그림 위에 빨간 X → 🎥 초원 사냥 + 하트 → ✏️ 동전 비 → ✏️ AI 팀 일곱 칸 → 🧊 호박 대왕 → ✏️ 큰 글자 "{DAYS} DAYS"

| # | English (narration = on-screen subtitle) | 한국어 뜻 |
|---|---|---|
| 0-1 | I can't code. I can't draw. | 저는 코딩도 못 하고, 그림도 못 그려요. |
| 0-2 | But I LOVE games! | 하지만 게임을 너무 좋아해요! |
| 0-3 | I spent way too much money on games... | 게임에 돈을 너무 많이 썼어요… |
| 0-4 | So I decided to make my own, with seven AI teammates. | 그래서 직접 만들기로 했어요, AI 팀원 일곱 명과 함께. |
| 0-5 | This is the Pumpkin King. In {DAYS} days, he has to be ready to fight real players. | 이건 호박 대왕이에요. {DAYS}일 뒤엔 진짜 플레이어랑 싸울 준비가 돼 있어야 해요. |
| 0-6 | Let's see if we can make it in time. | 시간 안에 해낼 수 있는지 봐요. |

## 1. 제목 (0:20–0:24)
화면: ✏️ "HALO & HORNS · DEVLOG #1" (내레이션 없음, 짧은 휙 전환)

## 2. 게임 소개 (0:24–1:15)
화면: 🖼 빛·뿔 직업 카드 → 🎥 교차로·분수 → 🎥 진영 고르는 화면 → 🖼 수배 별 이름표 → 🎥 큰 슬라임

| # | English | 한국어 뜻 |
|---|---|---|
| 2-1 | Our game is called Halo and Horns. | 우리 게임 이름은 헤일로 & 혼즈(선악 키우기)예요. |
| 2-2 | It has one big rule: everything you do pushes you toward angel... or devil. | 큰 규칙 하나: 모든 행동이 천사… 아니면 악마 쪽으로 기울어요. |
| 2-3 | When you join, you pick a side. | 들어오면 편을 골라요. |
| 2-4 | The Knights of Light get a halo. | 빛의 기사단은 머리 위에 후광이 생겨요. |
| 2-5 | The Horn Legion gets horns. | 뿔 군단은 뿔이 돋아요. |
| 2-6 | Don't want to fight other players? Join the Artisan Guild. No player fights at all. | 다른 플레이어랑 싸우기 싫어요? 장인 길드로 가요. 플레이어끼리 싸움이 아예 없어요. |
| 2-7 | Rob other players as the Horn Legion, and you get Wanted stars. Then the Knights come to catch you! | 뿔 군단으로 다른 플레이어를 털면 수배 별이 붙고, 기사단이 잡으러 와요! |
| 2-8 | Even the auto-battle button is a choice. | 자동 전투 버튼마저 선택이에요. |
| 2-9 | A big slime swallowed a piece of a magic crown. | 큰 슬라임이 마법 왕관 조각을 삼켰어요. |
| 2-10 | Get it back, and the shard watches how you fight. | 되찾으면 조각이 내가 싸우는 법을 지켜봐요. |
| 2-11 | Then you decide: purify it... or eat it! | 그리고 정해요: 정화할까… 삼킬까! |
| 2-12 | Angel or devil. Either way, you unlock Auto Battle. | 천사든 악마든, 어느 쪽이든 자동 전투가 열려요. |

## 3. Firefly 그림 (1:15–2:15)
화면: 🖼 직업 그림·안내자 초상 시트(장인 궁수 칸은 잘라냄) → 🖼 메뉴 칸·HUD 부품·아이콘 → 🖼 `devlog/05` 안내자 창 전·후 → 🖼 땅 타일 3×3

| # | English | 한국어 뜻 |
|---|---|---|
| 3-1 | Next problem: art. I can't draw. | 다음 문제: 그림. 저는 그림을 못 그려요. |
| 3-2 | So two of my teammates make pictures with Adobe Firefly. | 그래서 팀원 둘이 Adobe Firefly로 그림을 만들어요. |
| 3-3 | One draws the big world: grass, sky and stone roads. | 한 명은 큰 세계를 그려요: 풀밭, 하늘, 돌길. |
| 3-4 | The other draws the small stuff: icons, buttons and characters. | 다른 한 명은 작은 것들: 아이콘, 버튼, 캐릭터. |
| 3-5 | Every character wears full, kid-friendly clothes. We check every picture before it goes in the game. | 모든 캐릭터는 단정한 옷을 입어요. 게임에 넣기 전에 그림을 하나하나 확인해요. |
| 3-6 | Look at the guide. Before: no face. After: a real character! | 안내자를 봐요. 전: 얼굴 없음. 후: 진짜 캐릭터! |
| 3-7 | Here's a trick: we draw the panels with no words on them. | 비법 하나: 판에는 글자를 안 그려요. |
| 3-8 | The game writes the words itself, so it works in English and Korean. | 글자는 게임이 직접 써요. 그래서 영어와 한국어 둘 다 돼요. |
| 3-9 | And ground tiles must repeat with no lines. We test them by putting nine side by side. | 땅 그림은 이어 붙여도 선이 없어야 해요. 아홉 장을 나란히 놓아 시험해요. |

## 4. Tripo 3D 몬스터 (2:15–3:05)
화면: 🖼 네모 슬라임 그림 → 🧊 네모 슬라임 회전(나란히) → 🧊 호박 슬라임·박쥐 고블린·꼬마 유령·아기 슬라임 펫 회전 → 🎥 게임 속 네모 슬라임

| # | English | 한국어 뜻 |
|---|---|---|
| 4-1 | Pictures are flat. But monsters need to walk around. | 그림은 납작해요. 그런데 몬스터는 걸어 다녀야 하죠. |
| 4-2 | So we turn a picture into a 3D model with a tool called Tripo. | 그래서 Tripo라는 도구로 그림을 3D 모델로 바꿔요. |
| 4-3 | Here's our new Slime. Picture... and 3D! | 새 슬라임이에요. 그림… 그리고 3D! |
| 4-4 | Then the Pumpkin Slime, the Bat Goblin, the Little Ghost... | 그다음 호박 슬라임, 박쥐 고블린, 꼬마 유령… |
| 4-5 | ...and a Baby Slime pet, coming soon! | …그리고 곧 나올 아기 슬라임 펫! |
| 4-6 | Six new 3D models in one evening! | 하룻저녁에 새 3D 모델 여섯! |
| 4-7 | The Bat Goblin even came with moves: walk, slash, hurt and fall. | 박쥐 고블린은 동작까지 있어요: 걷기, 베기, 맞기, 쓰러지기. |

## 5. 화면 배치 A/B (3:05–3:45)
화면: 🖼 `hud_compare_AB` (한국어 글자 위에 ✏️ 영어 이름표 "A" "B"를 덮음) → ✏️ B에 동그라미

| # | English | 한국어 뜻 |
|---|---|---|
| 5-1 | Then we had to decide where every button goes. | 그다음엔 버튼마다 어디에 둘지 정해야 했어요. |
| 5-2 | My teammate drew two gray-box layouts: A and B. | 팀원이 회색 상자로 배치 두 개를 그렸어요: A와 B. |
| 5-3 | A puts the health bars at the top left. B puts them at the bottom, with a round map in the corner. | A는 체력 바가 왼쪽 위. B는 아래쪽, 그리고 구석에 둥근 지도. |
| 5-4 | I picked B, because it looks like a game I showed my team. | 저는 B를 골랐어요. 제가 팀에게 보여 준 게임 같거든요. |
| 5-5 | Gray boxes first, pretty pictures later. That way we never waste art on the wrong spot. | 회색 상자 먼저, 예쁜 그림은 나중에. 그래야 엉뚱한 자리에 그림을 낭비하지 않아요. |

## 6. 호박 대왕 (3:45–4:40)
화면: 🖼 호박밭 콘셉트 그림 → 🧊 호박 대왕 회전 → 🎥 호박밭(게임) → ✏️ "every 20 min · 5 min to win · new players safe"

| # | English | 한국어 뜻 |
|---|---|---|
| 6-1 | And now... the star of Halloween. | 그리고 이제… 핼러윈의 주인공. |
| 6-2 | The Pumpkin King! | 호박 대왕! |
| 6-3 | He lives in the Pumpkin Patch, and he shows up every twenty minutes. | 호박밭에 살고, 20분마다 나타나요. |
| 6-4 | You have five minutes to beat him. | 5분 안에 물리쳐야 해요. |
| 6-5 | Hit him enough, and you get Halloween candy. | 충분히 때리면 핼러윈 사탕을 받아요. |
| 6-6 | And a kind rule: brand-new players are safe from him. | 그리고 착한 규칙: 새로 온 플레이어는 호박 대왕에게서 안전해요. |
| 6-7 | The Halloween fun lasts into early November. | 핼러윈 이벤트는 11월 초까지 해요. |

## 7. AI 팀 일곱 (4:40–5:35)
화면: ✏️ 일곱 칸 도표(칸마다 영어 이름 + 아이콘, 한 칸씩 켜짐) → 마지막에 가운데 "DIRECTOR: me"

| # | English | 한국어 뜻 |
|---|---|---|
| 7-1 | So, who's on the team? | 그래서, 팀엔 누가 있을까요? |
| 7-2 | Seven Claude AI sessions. Each one has one job. | 클로드 AI 세션 일곱. 각자 할 일이 하나씩 있어요. |
| 7-3 | The Reviewer is the boss. It checks everyone's work and keeps the plan. | 검수는 대장이에요. 모두의 일을 확인하고 계획을 지켜요. |
| 7-4 | Game Dev One builds the game in Roblox Studio. | 게임성 개발 1은 로블록스 스튜디오에서 게임을 만들어요. |
| 7-5 | Game Dev Two writes the server code, the part you can't see. | 게임성 개발 2는 눈에 안 보이는 서버 코드를 써요. |
| 7-6 | The World Artist paints the big world and builds 3D props. | 이미지 생성 1은 큰 세계를 그리고 3D 소품을 만들어요. |
| 7-7 | The Small Artist makes icons, buttons and characters. | 이미지 생성 2는 아이콘, 버튼, 캐릭터를 만들어요. |
| 7-8 | The Art Dev puts the pictures into the game and moves the buttons around. | 이미지 개발은 그림을 게임에 넣고 버튼 자리를 잡아요. |
| 7-9 | And the Film Crew... made this video! | 그리고 촬영 편집은… 이 영상을 만들었어요! |
| 7-10 | And me? I'm the director. I play, I pick the pictures, and I say yes or no. | 그럼 저는? 감독이에요. 플레이하고, 그림을 고르고, 좋다 싫다를 말해요. |
| 7-11 | When I find a bug, I tell the Reviewer, and the Reviewer sends it to the right teammate. | 제가 버그를 찾으면 검수에게 말하고, 검수가 맞는 팀원에게 보내요. |

## 8. 끝 (5:35–6:00)
화면: 🎥 초원에서 슬라임 사냥 → ✏️ 끝 화면 "BETA · OCT 31 · HALLOWEEN" + "Devlog #2 soon"

| # | English | 한국어 뜻 |
|---|---|---|
| 8-1 | {DAYS} days left. | {DAYS}일 남았어요. |
| 8-2 | Next time, we play the first ten minutes like a real new player, and fix everything that feels boring. | 다음 편엔 진짜 새 플레이어처럼 처음 10분을 플레이해 보고, 지루한 건 다 고쳐요. |
| 8-3 | And we find out if the Pumpkin King is too strong. | 그리고 호박 대왕이 너무 센지 알아봐요. |
| 8-4 | The beta opens on Halloween, October thirty-first. | 베타는 핼러윈, 10월 31일에 열려요. |
| 8-5 | Subscribe so you can play it with us. See you next time! | 같이 플레이하려면 구독해 주세요. 다음에 봐요! |

---

## 검수 답(2026-10-06) → 반영함
1. 제목 "I Made…", 내레이션은 "I"(감독 = 사용자) + "my AI teammates / we".
2. 영어 이름은 용어 표대로. "square slime" → "Slime".
3. Claude·Adobe Firefly·Tripo 이름은 사실대로, 로고 크게 쓰지 않기, 설명란 "Not sponsored.".
4. 6-6 → "brand-new players are safe from him." (실제: Lv5 미만 또는 첫 10분)
5. 남은 날 수는 빌드 날짜로 자동 계산(10/31 11:00 KST).
6. 2-7 고침: 수배 별은 뿔 군단이 털거나 쓰러뜨릴 때, 깡패는 약한 상대 괴롭힘 벌칙(다른 규칙).
- 촬영 편집이 4~8장 사실 다시 확인하며 고친 줄: 4-6 "몬스터 여섯" → "3D 모델 여섯"(아기 슬라임은 펫), 5-4 "좋아하는 게임들" → "팀에게 보여 준 게임"(A23-40), 6-7 "11월 9일까지" → "11월 초까지"(끝은 11/9 00:00 KST = 미국은 11/8), 7-11 버그 신고는 사용자 → 검수 → 팀원, 4-5 펫은 아직 게임에 없어서 "coming soon"(따라다니는 장면은 찍지 않고 모델만 제자리 회전).
