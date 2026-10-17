# NPC 대화 상자 계획 (A23-229, 게임성 개발 1, 2026-10-18)

사용자: 메이플 대화창 사진 + "npc랑 하는 대화는 이미지처럼 왼쪽에 npc 얼굴 있고 대사 이런 식으로".
목표: **말 걸어서 하는 대화**를 화면 아래 대화 상자 하나로. 머리 위 말풍선(지나가며 하는 말)은 그대로.

## 1. 지금 NPC가 말하는 길 (조사: 클라 = 개발 1, 서버 = 개발 2)
| # | 길 | 지금 모습 | 여는 것 | 상자로? |
|---|---|---|---|---|
| A | 이야기 카드 Panels "Story" (Panels.luau STORY·BUILDERS.Story 3160) | 가운데 창, 왼쪽 초상(PortraitFrame)·타자기 글·[Next]·[Got it]/[Later]·선택 2단추 | 서버 OpenPanel("Story",{Id,St,Var}), 줄 탭, NPC Talk | **옮김** |
| B | 부탁 받기 Panels "Offer" (3516) | 가운데 창, 상황 줄·초상·글·보상 줄·[Sure!]/[Not now] | OpenPanel("Offer",{Id,Npc,Reward}) | **옮김** |
| D | 안내자 Welcome (Hallie/Magpie/Kit, 1393) | 가운데 창, 큰 그림·글·[I'm In!]·▶ | OpenPanel("Welcome"), 안내자 Talk | **옮김** |
| G | 스승 기술 수업 줄 (SkillBar LEARN.Teach) | 스승 머리 위 말풍선 줄줄이 | Fx SkillLearned(Talk 뒤) | **옮김**(말 걸어서 나오는 것) |
| H | 상점 인사 (Fizzby·Otto) | 상점 창 맨 위 글 한 줄 | 상점 프롬프트 | 그대로(상점 창). 원하면 나중에 '인사 상자 → [Shop]' |
| C | 모양 맞추기·타이밍·강화 | 그 단계 전용 창 | 대화 다음 | 그대로(상자 닫히고 열림) |
| E | 이야기 Find 말풍선·단계 끝 줄·Clatter 장면 | 머리 위 말풍선, 시간으로 넘어감 | Fx StoryScene | 그대로(지나가며 보는 장면) |
| F | 마을 사람 지나가며 하는 말 (TownReact) | 머리 위 말풍선 | 가까이 가면 | 그대로 |
| - | 오프닝 해설·몬스터 말·선택 카드·왕 일기 | NPC 대화 아님 | - | 그대로 |

## 2. 상자 모양 (승인 부품 + UIKit 대체, 새 그림 없음)
- 자리: 화면 아래 가운데, 폭 min(900du, 화면 92%), 높이 약 200du(폰 가로 = 화면 높이 40% 이하). 뒤 검은 막 없음(세상은 보이고 움직임 가능).
- 판: `DialogBox`(양피지 9-slice, 승인) — 글은 짙은 잉크색. 대체 = UIKit 판.
- 왼쪽 칸: **NPC 상반신 3D**(ViewportFrame: workspace.Map.NPCs 의 그 NPC 몸 복사, 머리~가슴, HUD 초상·도감 방식) → 몸이 없으면 승인 초상 그림(PTR_*·Portrait*) → 없으면 이름 첫 글자. 이름은 얼굴 밑(`Chip`/`StatusPlate`).
- 오른쪽: 대사(타자기 38자/초 + Audio.Talk, 누르면 끝까지), 쪽 수 없음.
- 오른쪽 아래: [Next] → 마지막 줄: [Got it] / 선택 2개(BtnKind·BtnSneaky, 지금과 같은 그림) / 부탁 [Sure!]·[Not now](보상 줄은 대사 아래 작게, 지금 보상 칸 그대로).
- 왼쪽 아래: [Bye] = 닫기(Story = 지금의 [Later], Offer = 대답 안 함 = 다음에 다시 말 걸면 나옴).
- 키: 상호작용 키(G)·Enter = [Next]/끝 줄 기본 단추, Esc = [Bye]. NPC에서 15칸 넘게 멀어지면 [Bye]처럼 닫힘.
- 한 카드에 말하는 사람이 여럿("Bright: …" / "Hallie: …")이면 줄마다 왼쪽 얼굴·이름이 바뀜(지금 StoryNpcs.SpeakerOf 규칙).
- 글: Config.ClientText.DialogBox(Bye 하나 새로) + 기존 Config.StoryQuests.Text(Next·Got it·Sure!·Not now). 배너·설명 띠 없음.

## 3. 만드는 법 (개발 1, 서버 변경 없이 1차)
1. 새 모듈 `DialogBox.luau`(ScreenGui 하나, Show(spec)/Close/IsOpen): spec = { Speaker(NpcId), Lines, Before?, Reward?, Buttons(Next/Ok/Choice/Accept), OnPick }.
2. Panels의 Story·Offer·Welcome 빌더가 가운데 창 대신 DialogBox.Show 호출. **바쁨 규칙·대기 줄(STORY.Busy/Pending)·HUD 줄 반짝은 그대로**(currentId == "Story" 검사를 DialogBox.IsOpen()으로). 보내는 원격(StoryAction Talk/Choose/Accept/Decline, AcceptTutorial) 그대로.
3. 스승 수업 줄(G)은 상자로(줄마다 [Next], 끝 [Got it]) — 말풍선 경로는 Talk 없이 올 때만 남김.
4. 상자 열려 있는 동안 TownReact 조용(지금 Panels 창과 같은 규칙), 공격 입력은 막지 않음(움직임 자유, 싸움 중에는 지금처럼 대기 줄로).
5. 시험: test_dialog_box.py(줄 넘김·선택·Bye·여러 화자·폭/폰 크기·바쁨 대기) + 기존 Panels story/offer/welcome 시험 고침 + Studio 사진(PC·폰 가로, 빛·뿔·중립 안내자, Otto 부탁, 선택 단계).

## 4. 개발 2와 나눌 곳 (서버 대사 데이터)
- 1차는 서버 그대로 동작함(Speaker = def.Speaker / Offer.Npc / 줄 앞 "Name:").
- 부탁하고 싶은 것(2차, 작게): ① OpenPanel("Story") 짐에 `Npc`(말 건 NPC id) 넣기 — 줄에 이름 없을 때 얼굴을 정확히 ② 줄 모양을 `{ Who = npcId, Text = … }`로도 받게(지금 "Name: words" 문자열과 둘 다 허용) ③ 몸 없는 화자(Shard·Fountain·Clatter)의 얼굴 = 승인 그림 키 표(Config.StoryQuests.Portraits 보강).
- 그림 없음 NPC(Gleam·Rex·Folk·Pip/Dibs/Grabbo·Clatter)는 3D 상반신이라 새 그림 필요 없음.

## 5. 순서
① DialogBox + Story/Offer/Welcome 옮김(시험·사진) → ② 3D 상반신 얼굴 → ③ 스승 수업 줄 → ④(선택) 상점 인사 상자. 각 단계 작은 가지, 최종 검수 확인 뒤 다음.
