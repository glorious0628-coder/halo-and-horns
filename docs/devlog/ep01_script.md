# 개발 일지 1편 대본 (촬영 편집, 2026-10-06) — 검수 확인 전

- **제목(안):** I Made a Roblox Halloween Game with 7 AI Teammates #1
- **길이 목표:** 약 5분 30초(영어 내레이션 약 700단어, MeloTTS EN-US). 장면마다 2~4초 컷, 정지 그림은 천천히 확대·이동.
- **말투:** 만든 사람(사용자) 1인칭 "I", 팀은 "my AI teammates". 짧은 문장, 아이도 알아듣는 쉬운 영어. 영어 자막은 화면에 굵은 외곽선으로, 한국어 자막은 따로 `.srt`.
- **영어 이름(용어 표가 아직 없어 임시):** Halo & Horns, Knights of Light(빛의 기사단), Horn Legion(뿔 군단), Artisan Guild(장인 길드), Pumpkin King, Pumpkin Patch, square slime. 검수 용어 표(`glossary_en`)가 생기면 그대로 맞춘다.
- **사실 확인:** 대사 속 기능은 지금 코드·문서에 있는 것만 넣었다(왕관 조각 정화/삼킴 = StoryQuestService, 수배 별 = CharacterVisuals, 호박 대왕 20분마다·5분·Lv5 미만 보호·11/9 끝 = Config.Halloween, Tripo 6종 하룻저녁 = 1ccddb7→bfcba1b, B안 = A23-40). 없는 기능은 "다음 편"으로만 말한다.
- **빼는 것:** 계정 이름·이메일·ID, 옛 계정 정지 이야기, 거절된 그림(장인 궁수), 오프닝 연출(다시 만들 예정), 다른 게임 이름, 돈·크레딧 숫자.
- **화면 칸 표시:** 🎥 = FilmSet Studio 녹화(Play 중 게임 장면), 🖼 = 이미 있는 그림·캡처, 🧊 = Tripo GLB를 Blender로 돌려 찍은 회전 영상, ✏️ = 편집에서 만드는 글자·도표.

---

## 0. 첫 장면 (0:00–0:20)
화면: 🧊 호박 대왕 회전 → 🎥 슬라임 사냥 짧게 → 🖼 직업 그림 → ✏️ 큰 글자 "25 DAYS TO HALLOWEEN BETA"

| # | English (narration = on-screen subtitle) | 한국어 뜻 |
|---|---|---|
| 0-1 | This is the Pumpkin King. | 이건 호박 대왕이에요. |
| 0-2 | In twenty-five days, he has to be ready to fight real players. | 25일 뒤엔 진짜 플레이어랑 싸울 준비가 돼 있어야 해요. |
| 0-3 | The problem? I'm a beginner. I'm new to Roblox Studio. | 문제는? 저는 초보예요. 로블록스 스튜디오가 처음이에요. |
| 0-4 | So I built a team of seven AI teammates. | 그래서 AI 팀원 일곱 명으로 팀을 만들었어요. |
| 0-5 | Let's see if we can make it in time. | 시간 안에 해낼 수 있는지 봐요. |

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
| 2-7 | But be a bully, and you get wanted stars. Then the good guys come to catch you! | 대신 깡패 짓을 하면 수배 별이 붙고, 착한 편이 잡으러 와요! |
| 2-8 | Even the auto-battle button is a choice. | 자동 전투 버튼마저 선택이에요. |
| 2-9 | A big slime swallowed a piece of a magic crown. | 큰 슬라임이 마법 왕관 조각을 삼켰어요. |
| 2-10 | Get it back, and the shard watches how you fight. | 되찾으면 조각이 내가 싸우는 법을 지켜봐요. |
| 2-11 | Then you decide: purify it... or eat it! | 그리고 정해요: 정화할까… 삼킬까! |
| 2-12 | Angel or devil. Either way, you unlock auto-battle. | 천사든 악마든, 어느 쪽이든 자동 전투가 열려요. |

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
| 4-3 | Here's the square slime. Picture... and 3D! | 네모 슬라임이에요. 그림… 그리고 3D! |
| 4-4 | Then the pumpkin slime, the bat goblin, the little ghost... | 그다음 호박 슬라임, 박쥐 고블린, 꼬마 유령… |
| 4-5 | ...and a baby slime pet that follows you around. | …그리고 나를 따라다니는 아기 슬라임 펫. |
| 4-6 | Six new monsters in one evening! | 하룻저녁에 새 몬스터 여섯! |
| 4-7 | The bat goblin even came with moves: walk, slash, hurt and fall. | 박쥐 고블린은 동작까지 있어요: 걷기, 베기, 맞기, 쓰러지기. |

## 5. 화면 배치 A/B (3:05–3:45)
화면: 🖼 `hud_compare_AB` (한국어 글자 위에 ✏️ 영어 이름표 "A" "B"를 덮음) → ✏️ B에 동그라미

| # | English | 한국어 뜻 |
|---|---|---|
| 5-1 | Then we had to decide where every button goes. | 그다음엔 버튼마다 어디에 둘지 정해야 했어요. |
| 5-2 | My teammate drew two gray-box layouts: A and B. | 팀원이 회색 상자로 배치 두 개를 그렸어요: A와 B. |
| 5-3 | A puts the health bars at the top left. B puts them at the bottom, with a round map in the corner. | A는 체력 바가 왼쪽 위. B는 아래쪽, 그리고 구석에 둥근 지도. |
| 5-4 | I picked B. It looks like the games I love to play. | 저는 B를 골랐어요. 제가 좋아하는 게임들 같거든요. |
| 5-5 | Gray boxes first, pretty pictures later. That way we never waste art on the wrong spot. | 회색 상자 먼저, 예쁜 그림은 나중에. 그래야 엉뚱한 자리에 그림을 낭비하지 않아요. |

## 6. 호박 대왕 (3:45–4:40)
화면: 🖼 호박밭 콘셉트 그림 → 🧊 호박 대왕 회전 → 🎥 호박밭(게임) → ✏️ "every 20 min · 5 min to win · Lv 1–4 safe"

| # | English | 한국어 뜻 |
|---|---|---|
| 6-1 | And now... the star of Halloween. | 그리고 이제… 핼러윈의 주인공. |
| 6-2 | The Pumpkin King! | 호박 대왕! |
| 6-3 | He lives in the Pumpkin Patch, and he shows up every twenty minutes. | 호박밭에 살고, 20분마다 나타나요. |
| 6-4 | You have five minutes to beat him. | 5분 안에 물리쳐야 해요. |
| 6-5 | Hit him enough, and you get Halloween candy. | 충분히 때리면 핼러윈 사탕을 받아요. |
| 6-6 | And a kind rule: he never attacks brand-new players. Under level five, you're safe. | 그리고 착한 규칙: 완전 새 플레이어는 절대 공격 안 해요. 레벨 5 아래면 안전해요. |
| 6-7 | The Halloween event runs until November ninth. | 핼러윈 이벤트는 11월 9일까지 해요. |

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
| 7-11 | If a teammate finds a bug, it tells the Reviewer, and the Reviewer sends it to the right teammate. | 팀원이 버그를 찾으면 검수에게 말하고, 검수가 맞는 팀원에게 보내요. |

## 8. 끝 (5:35–6:00)
화면: 🎥 초원에서 슬라임 사냥 → ✏️ 끝 화면 "BETA · OCT 31 · HALLOWEEN" + "Devlog #2 soon"

| # | English | 한국어 뜻 |
|---|---|---|
| 8-1 | Twenty-five days left. | 25일 남았어요. |
| 8-2 | Next time, we play the first ten minutes like a real new player, and fix everything that feels boring. | 다음 편엔 진짜 새 플레이어처럼 처음 10분을 플레이해 보고, 지루한 건 다 고쳐요. |
| 8-3 | And we find out if the Pumpkin King is too strong. | 그리고 호박 대왕이 너무 센지 알아봐요. |
| 8-4 | The beta opens on Halloween, October thirty-first. | 베타는 핼러윈, 10월 31일에 열려요. |
| 8-5 | Subscribe so you can play it with us. See you next time! | 같이 플레이하려면 구독해 주세요. 다음에 봐요! |

---

## 검수에게 물을 것
1. 1인칭 "I"(사용자 목소리처럼)로 말해도 되는지, 아니면 "we"로 바꿀지.
2. 영어 이름(Knights of Light / Horn Legion / Artisan Guild / Halo and Horns) 이대로 써도 되는지.
3. 7-2 "Claude AI"처럼 도구 이름을 영상에 말해도 되는지(Adobe Firefly·Tripo 이름도 나옴).
4. 6-6은 실제 규칙(Lv5 미만 **또는** 플레이 10분 미만이면 안전)을 쉽게 줄인 말. 괜찮은지.
5. 0-2·8-1 "25일" = 10/6 기준. 올리는 날이 늦어지면 숫자를 바꿔 다시 만든다.
