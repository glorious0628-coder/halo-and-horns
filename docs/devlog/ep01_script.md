# 개발 일지 롱폼 1편 대본 v2 (촬영 편집, 2026-10-06) — 검수 OK(2026-10-06, 답 3개 + 3D 도구 결정 반영)
> 기록용(10/06 v2 당시). 지금과 다른 점: 세션은 10개('eight'), 장인 길드·펫 조련사는 베타에서 빠짐(A23-57, 3-4·6-3), 자동 전투는 Lv5 첫 스킬 뒤(A23-71, 3-6~3-8), 화면은 PC·폰 같은 틀(A23-74, 6-2).
> 10/11 추가: 이 대본의 "베타 10/31(핼러윈)"·호박 대왕·호박밭·유령 숲·{DAYS} 계산(10/31까지)은 낡음 — 베타는 12/1 11:00 KST(A23-119), 호박밭·유령 숲은 내년 10월까지 숨김, 장인 길드는 베타에 포함. 한국어는 같은 게임 안 모드(A23-111). 다시 만들 때 대본을 새로 쓴다.
> 다시 만들 때 고칠 줄은 `docs/devlog/reshoot_2026-10-07.md` §3에 있고, 고친 초안은 다시 찍은 장면을 본 뒤 검수 OK를 받아 넣는다. 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

> 순서(검수·사용자 2026-10-06): 쇼츠 먼저(`shorts01_plan.json`), 이 롱폼은 **게임 화면이 영어만(A23-48) 메인에 들어간 뒤** 찍는다. v1(검수 OK)의 사실·용어는 그대로 두고, 그 뒤 사용자 결정(자기소개 훅, A23-39·40·45·46·47·48)과 쇼츠에서 잘 된 장면(팀 카드, 몬스터 얼굴 공개)을 넣었다.

- **제목(안):** I Can't Code or Draw, So I'm Making a Roblox Game with 7 AI Teammates (Devlog #1)
- **길이 목표:** 약 5분(영어 내레이션 약 630단어, MeloTTS EN-US 1.1배 ≈ 말 4분 + 공개 박자·전환). 컷 1~3초, 정지 그림은 늘 확대·이동. 중요한 순간에만 쇼츠식 큰 네온 단어.
- **말투:** 감독 = 사용자 1인칭 "I", 팀 = "my AI teammates / we". 짧고 쉬운 영어, 웃기게, 진짜처럼. 한국어 뜻은 줄마다(사용자 확인용 .srt).
- **영어 이름:** `docs/design/glossary_en_2026-10-06.md`. 게임 이름은 영어 **Halo & Horns**만.
- **{DAYS}:** 빌드하는 날(KST)부터 2026-10-31 11:00까지 남은 날, 자동.
- **도구 이름:** Claude·Adobe Firefly·Tripo는 사실대로, 로고는 크게 쓰지 않음, 설명란 "Not sponsored." + "Sound effects: Kenney (kenney.nl, CC0)".
- **사실 규칙:** 지금 게임에 있는 것은 현재형, 만드는 중인 것은 "we're building / coming soon"으로만. 아래 [사실] 칸에 근거.
- **빼는 것:** 계정 이름·이메일·ID, 옛 계정 정지 이야기, 돈·크레딧 숫자, 다른 게임 이름, 사람 얼굴(사용자 아바타는 OK, 이름은 안 보이게), 오프닝 연출(10/15~17 다시 만든 뒤 2편 이후).
- **화면 칸:** 🎥 FilmSet 녹화(영어 화면) · 🖼 승인 그림·캡처 · 🧊 Tripo GLB 회전(Blender) · ✏️ 편집 글자·도표 · ⭐ 쇼츠 장면 재사용.

---

## 0. 훅 — 감독 자기소개 (0:00–0:25)
화면: ⭐ 코드 + 빨간 X → ⭐ 낙서 + 빨간 X → 🎥 초원 사냥 + 하트 → ⭐ 동전 비 → 🎥 호박 대왕 정면 → ✏️ "{DAYS} DAYS"

| # | English | 한국어 뜻 |
|---|---|---|
| 0-1 | I can't code. I can't draw. | 저는 코딩도 못 하고, 그림도 못 그려요. |
| 0-2 | But I LOVE games! | 하지만 게임을 너무 좋아해요! |
| 0-3 | I spent way too much money on games... | 게임에 돈을 너무 많이 썼어요… |
| 0-4 | So I decided to make my own, with eight AI teammates. | 그래서 직접 만들기로 했어요, AI 팀원 여덟 명과 함께. |
| 0-5 | This is the Pumpkin King. In {DAYS} days, he has to be ready for real players. | 이건 호박 대왕이에요. {DAYS}일 뒤엔 진짜 플레이어를 맞을 준비가 돼야 해요. |
| 0-6 | Let's see if we make it. | 해낼 수 있는지 봐요. |

## 1. 제목 (0:25–0:28)
✏️ "HALO & HORNS · DEVLOG #1" (휙, 내레이션 없음)

## 2. 팀 소개 (0:28–0:55)
화면: ⭐ 팀 카드 여덟 장(소리 만들기 SOUND 포함, 2026-10-07) 0.3초씩 → 카드마다 그 세션 작업 장면 1초(검수 = 체크 시트, 개발 = Studio 코드, 그림 = Firefly 시트, 이미지 개발 = HUD, 촬영 = 이 영상 타임라인)

| # | English | 한국어 뜻 |
|---|---|---|
| 2-1 | My team is eight Claude AI sessions. Each one has one job. | 제 팀은 클로드 AI 세션 여덟이에요. 각자 할 일이 하나씩. |
| 2-2 | A boss, two builders, two artists, an art dev, a sound maker, and a film crew! | 대장 하나, 만드는 사람 둘, 그리는 사람 둘, 그림 넣는 사람 하나, 소리 만드는 사람 하나, 그리고 촬영 담당! |
| 2-3 | The boss checks everything before I see it. | 대장은 제가 보기 전에 모든 걸 확인해요. |
| 2-4 | And me? I'm the director. I play, I pick, and I say yes or no. | 그럼 저는? 감독이에요. 플레이하고, 고르고, 좋다 싫다를 말해요. |
| 2-5 | When I find a bug, I tell the boss, and the boss sends it to the right teammate. | 버그를 찾으면 대장에게 말하고, 대장이 맞는 팀원에게 보내요. |

## 3. 게임 소개 (0:55–1:45)
화면: 🖼 빛·뿔 직업 그림 → 🎥 교차로·분수 → 🎥 진영 고르기(영어) → 🖼 수배 별 아이콘 → 🎥 큰 슬라임 → ✏️ PURIFY / DEVOUR 네온

| # | English | 한국어 뜻 | [사실] |
|---|---|---|---|
| 3-1 | Our game is called Halo and Horns. | 우리 게임 이름은 Halo & Horns예요. | 용어 표 |
| 3-2 | One big rule: everything you do pushes you toward angel... or devil. | 큰 규칙 하나: 모든 행동이 천사… 아니면 악마 쪽으로 기울어요. | GDD §0 |
| 3-3 | When you join, you pick a side. The Knights of Light get a halo. The Horn Legion gets horns. | 들어오면 편을 골라요. 빛의 기사단은 후광, 뿔 군단은 뿔. | FactionService |
| 3-4 | Don't want to fight other players? Join the Artisan Guild. No player fights at all. | 플레이어끼리 싸우기 싫어요? 장인 길드로 가요. 싸움이 아예 없어요. | GDD §5-8 |
| 3-5 | Rob other players as the Horn Legion, and you get Wanted stars. Then the Knights come to catch you! | 뿔 군단으로 털면 수배 별이 붙고, 기사단이 잡으러 와요! | CharacterVisuals·검수 고침 |
| 3-6 | Even the Auto Battle button is a choice. A big slime swallowed a piece of a magic crown. | 자동 전투 버튼마저 선택이에요. 큰 슬라임이 마법 왕관 조각을 삼켰어요. | StoryQuestService |
| 3-7 | Get it back, and the shard watches how you fight. Then you decide: purify it... or devour it! | 되찾으면 조각이 내 싸움을 지켜봐요. 그리고 정해요: 정화할까… 삼킬까! | A23-2 |
| 3-8 | Angel or devil. Either way, you unlock Auto Battle. | 천사든 악마든, 자동 전투가 열려요. | A23-2 |

## 4. 그림: Firefly (1:45–2:35)
화면: 🖼 직업 그림·안내자 초상 시트 → 🖼 아이콘·버튼 → 🖼 안내자 창 전·후(devlog/05) → 🖼 땅 타일 3×3 → 🖼 2D 시안 → 물건 하나씩 2D

| # | English | 한국어 뜻 | [사실] |
|---|---|---|---|
| 4-1 | Next problem: art. I can't draw, remember? | 다음 문제: 그림. 저 그림 못 그리잖아요? | |
| 4-2 | So two teammates make pictures with Adobe Firefly. One draws the big world. The other draws icons, buttons and characters. | 그래서 팀원 둘이 Adobe Firefly로 그려요. 하나는 큰 세계, 하나는 아이콘·버튼·캐릭터. | A23-31 |
| 4-3 | Every character wears full, kid-friendly clothes, and the boss checks every picture up close. | 모든 캐릭터는 단정한 옷, 대장이 그림마다 크게 확대해 봐요. | Hard rule 1 |
| 4-4 | Look at the guide. Before: no face. After: a real character! | 안내자를 봐요. 전: 얼굴 없음. 후: 진짜 캐릭터! | devlog/05 |
| 4-5 | Our trick: no words in the pictures. The game writes the words itself. | 비법: 그림엔 글자를 안 넣어요. 글자는 게임이 직접 써요. | A23-35 |
| 4-6 | Now every new place starts as one big picture... then every object in it gets its own drawing. | 이제 새 장소는 큰 그림 한 장에서 시작하고… 그 안의 물건마다 따로 그림을 그려요. | A23-47 |

## 5. 그림 → 3D: 몬스터 얼굴 공개 (2:35–3:30)
화면: ⭐ Monster Face Reveal 흐름(게임 3D + 큰 이름 → 원래 그림 "AI DRAWING") — 슬라임 → 호박 슬라임 → 호박 대왕 → 박쥐 고블린 → 꼬마 유령(가족별 컷) → 🧊 회전 → ✏️ 6종 격자(한 줄에 한 가족)

| # | English | 한국어 뜻 | [사실] |
|---|---|---|---|
| 5-1 | But monsters can't be flat. They need to walk around. | 그런데 몬스터는 납작하면 안 돼요. 걸어 다녀야 하니까요. | |
| 5-2 | So a tool called Tripo turns each drawing into a 3D model. | 그래서 Tripo라는 도구가 그림을 3D 모델로 바꿔요. | A23-47 |
| 5-3 | Want to see what my monsters look like in real life? | 제 몬스터들의 실제 모습, 볼래요? | |
| 5-4 | Slime! ... Pumpkin Slime! ... Pumpkin King! ... Bat Goblin! ... Little Ghost! | 슬라임! … 호박 슬라임! … 호박 대왕! … 박쥐 고블린! … 꼬마 유령! | 1ccddb7→bfcba1b |
| 5-5 | Six new 3D models in one evening, plus a Baby Slime pet, coming soon! | 하룻저녁에 새 3D 모델 여섯, 그리고 곧 나올 아기 슬라임 펫! | 펫 = 아직 |
| 5-6 | One problem: the eyes. The AI paints them a little blurry, so the boss fixes them by hand. Before... after! | 문제 하나: 눈. AI가 눈을 살짝 흐리게 칠해서, 대장이 손으로 고쳐요. 전… 후! | A23-47, 🖼 devlog/2026-10-06/17_review_eyefix_pumpkin.png(왼쪽 원본·오른쪽 고친 눈) |

## 6. 감독의 결정들 (3:30–4:35)
화면: 🖼 화면 배치 A/B → ✏️ B에 동그라미 → 🖼 펫 조련사 그림(devlog/04) → 🖼 유령 가족 아이콘·3D → 🖼 눈 확대 비교 → 🖼 마을 시안('concept art') → 🎥 영어 화면
각 결정마다 ✏️ "DIRECTOR'S CALL" 도장 + 사용자 한마디(영어 자막, 짧게)

| # | English | 한국어 뜻 | [사실] |
|---|---|---|---|
| 6-1 | Being the director means making the calls. Here are some of mine. | 감독이니까 결정을 내려요. 제 결정 몇 개를 볼까요. | |
| 6-2 | Call one: where the buttons go. My team drew layout A and layout B in gray boxes. I picked B, because it looks like a game I showed them. | 결정 1: 버튼 자리. 팀이 회색 상자로 A와 B를 그렸어요. 저는 B. 제가 보여 준 게임 같아서요. | A23-40 |
| 6-3 | Call two: "Wait, didn't I say NO Artisan Archer?!" So the Artisan Guild is getting a Pet Tamer instead, with a baby slime that fights for you. | 결정 2: "잠깐, 장인 궁수 없애자고 했잖아?!" 그래서 장인 길드엔 펫 조련사가 와요, 아기 슬라임이 대신 싸워요. | A23-39 (만드는 중). 화면엔 펫 조련사 그림만(거절 그림 안 보임) |
| 6-4 | Call three: no mixing families! Goblins with goblins, pumpkins with pumpkins, ghosts with ghosts. | 결정 3: 가족 섞지 마! 고블린은 고블린끼리, 호박은 호박끼리, 유령은 유령끼리. | A23-45 |
| 6-5 | So the ghosts are getting their own spooky Haunted Hollow, with a Ghost King boss. | 그래서 유령들은 자기만의 으스스한 유령 숲과 유령 왕을 갖게 돼요. | A23-45 (만드는 중; 촬영 때 없으면 시안 + 작은 'concept art') |
| 6-5b | Call four: which 3D tool? I zoomed in on the monster eyes myself and compared two tools. My pick: Tripo, and the boss fixes the eyes. | 결정 4: 3D 도구는? 제가 직접 몬스터 눈을 확대해 두 도구를 비교했어요. 제 선택: Tripo, 눈은 대장이 고쳐요. | A23-47 "그냥 TRIPO로 작업하고 너가 수정하는 쪽으로 하자" |
| 6-6 | Call five: "This town is too small!" So we're making the towns bigger and full of stuff, with villagers who give you quests. | 결정 5: "마을이 너무 작아!" 그래서 마을을 크고 꽉 차게, 퀘스트 주는 마을 사람도. | A23-46·47 (만드는 중; 없으면 시안 + 'concept art') |
| 6-7 | And call six: the game is in English only. Easy English, so kids everywhere can play. | 결정 6: 게임 글자는 영어만. 쉬운 영어로, 어디 사는 아이든 할 수 있게. | A23-48 |

## 7. 호박 대왕 (4:35–5:25)
화면: 🎥 실제 호박밭(호박 가족만) → 🧊 대왕 회전 → 🎥 대왕 정면 → 🎥 싸움·쓰러짐·사탕 → ✏️ 칩 "every 20 min · 5 minutes · new players safe"

| # | English | 한국어 뜻 | [사실] |
|---|---|---|---|
| 7-1 | And now, the star of Halloween. The Pumpkin King! | 그리고 이제, 핼러윈의 주인공. 호박 대왕! | |
| 7-2 | Every twenty minutes, he shows up in the Pumpkin Patch. | 20분마다 호박밭에 나타나요. | Config.Halloween |
| 7-3 | You have five minutes to beat him. Team up, and everyone who helps gets candy! | 5분 안에 물리쳐야 해요. 힘을 모으면 도운 사람 모두 사탕! | A23-27 |
| 7-4 | And a kind rule: brand-new players are safe from him. | 착한 규칙: 새로 온 플레이어는 호박 대왕에게서 안전해요. | Lv5 미만 또는 첫 10분 |
| 7-5 | The Halloween fun lasts into early November. | 핼러윈 이벤트는 11월 초까지. | EndsAt 11/9 00:00 KST |

## 8. 끝 (5:25–6:00)
화면: 🎥 초원 사냥 → ✏️ "BETA · OCT 31" 끝 화면(호박 가족만) → 첫 장면(코드 + X)으로 이어지는 마지막 컷

| # | English | 한국어 뜻 |
|---|---|---|
| 8-1 | {DAYS} days left. | {DAYS}일 남았어요. |
| 8-2 | Next time: I play the first ten minutes like a brand-new player, and we fix everything that feels boring. | 다음 편: 진짜 새 플레이어처럼 첫 10분을 플레이하고, 지루한 건 다 고쳐요. |
| 8-3 | And we find out if the Pumpkin King is too strong. | 그리고 호박 대왕이 너무 센지 알아봐요. |
| 8-4 | The beta opens on Halloween, October thirty-first. Subscribe so you can play it with us! | 베타는 핼러윈, 10월 31일. 같이 하려면 구독해 주세요! |

---

## 촬영 목록 (영어 화면이 메인에 들어간 뒤, FilmSet, 검수 "전달함, 시작" 뒤)
1. 진영 고르기 화면(영어) 5초 · 2. 교차로·분수 회전 · 3. 초원 사냥(HUD 영어) · 4. 큰 슬라임 + 왕관 조각 퀘스트 화면(정화/삼킴 선택 창) · 5. 호박밭 실제·대왕 정면·싸움(가족만) · 6. 영어 HUD B안 전체 5초 · 7. (만들어지면) 유령 숲·유령 왕, 큰 마을 — 없으면 시안 그림으로.
쇼츠에서 그대로 쓰는 것: 0번 훅, 팀 카드, 몬스터 얼굴 공개.

## 검수 답(2026-10-06) → 반영함
1. 6-3 장인 궁수 이야기 OK — 거절 그림은 안 보이고 펫 조련사 그림만, 사용자 말은 웃기게 한 줄.
2. 만드는 중 표현 "is coming / we're making" 그대로, 촬영 때 없으면 시안 그림 + 작은 'concept art' 표시.
3. 5-6 눈 손보기 넣기 — 전·후 사진 `docs/devlog/2026-10-06/17_review_eyefix_pumpkin.png`.
4. 추가: 6-5b 3D 도구 결정(사용자가 직접 눈 확대 비교 → "Tripo로 하고 대장이 고친다"). 결정은 이제 6개.
