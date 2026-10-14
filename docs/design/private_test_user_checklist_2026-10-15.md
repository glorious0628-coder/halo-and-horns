# 비공개 시험 전 사용자 체크리스트 (10/15·10/16) — 최종 검수 2026-10-13, SPEC A23-161·160·156

> **A23-161(10/13 저녁):** 10/17~20은 **기술 시험**(사용자 + 1~2명, 동결 없음, 재미 판정 없음). 보는 것 = 폰 프레임·메모리, 저장·재접속, 패스 9개 실제 구매 + 재접속 혜택, 퍼널. 진짜 첫 10분 시험은 11/7~10. 아래 할 일은 그대로예요.

한 장. 위에서부터 순서대로. 끝낸 줄은 저(최종 검수)에게 한 줄로 알려 주세요("패스 9개 ID 보냄" 등). 게시(Publish) 버튼은 사용자만 누릅니다.

## 10/15 (수) — 패스 9개 만들기 (약 30분)
Creator Hub(create.roblox.com) → 만들기 → 체험 "Halo & Horns"(장소 81671223175574) → **수익 창출 → 패스**. 아이콘은 `art/ui/PassIcon*.png`(없는 것은 비워 둬도 됨, 시험이라 OK).

| # | 이름(그대로) | 가격 R$ | 설명(붙여 넣기; `Config.PassInfo`) |
|---|---|---|---|
| 1 | 2x XP | 199 | Get 2x XP from everything you do, so you level up 2x faster. It only speeds up leveling. No stats are for sale. |
| 2 | 2x Gold | 149 | Earn 2x gold from hunting, quests and rewards. Gold you take from other players is not doubled. No stats are for sale. |
| 3 | VIP | 249 | A crown by your name, a VIP tag in chat, and your name on the village Supporters board. No stats are for sale. |
| 4 | Sticker Pack | 99 | 13 more stickers to pop over your head: hearts, a crown, Nice!, GG and more. 5 basic stickers are free for everyone. No stats are for sale. |
| 5 | Bubble Pack | 99 | Show off when you chat: every fancy chat bubble skin. Your side's own bubble is free for everyone. No stats are for sale. |
| 6 | Ice Halo | 99 | A new color for your halo or horns. It only changes how you look: the shape still shows your rank. No stats are for sale. |
| 7 | Gold Halo | 99 | (6과 같은 글) |
| 8 | Lava Horns | 99 | (6과 같은 글) |
| 9 | Shadow Horns | 99 | (6과 같은 글) |
| 10 | Fast Travel | 149 | Teleport to any zone you have unlocked from the menu. No stats are for sale. |

- 만든 뒤 **패스 9개의 ID 숫자**(주소 끝 숫자)를 이름과 함께 저에게 보내 주세요. → 개발 2가 `Config.GamePasses`·치장 Looks 표에 넣고 동결판에 포함합니다(10/15 18:00 전이면 좋음, 늦으면 10/16 오전).
- **판매 켜기(On Sale)는 지금 켜 두세요.** 시험 동안 초대한 사람만 들어오고, 패스마다 한 번씩 사 보고 다시 접속해 혜택이 남는지 봅니다(A23-156 ③). 실제 로벅스가 듭니다(작은 금액).
- 같은 화면에서 **개인 서버(Private Servers) 켜기**, 월 100 R$.
- (아직이면) 게임 아이콘 넣기: Creator Hub → 체험 → 기본 설정 → 아이콘 = `art/out/s2/gameicon/GameIcon_C_512.png`. 등급 설문(Maturity & Compliance)도 아직이면 답안 `docs/design/maturity_questionnaire_draft_2026-10-11.md`로 제출.

## 10/16 (목) 저녁 — 비공개 게시 (약 15분, 제가 "게시판 준비됨"이라고 말한 뒤)
1. 메인 반영 1이 그날 main을 메인 Studio에 넣고 저장까지 끝내면 제가 알립니다(동결은 없음, A23-161). 그 전에는 게시하지 마세요.
2. 저장: Studio 메인 창 → **File → 새 이름으로 활성 로컬 파일 저장** → `build\GoodEvil.rbxlx`, 형식 **Roblox XML 플레이스 파일(*.rbxlx)** 덮어쓰기 → 저에게 "저장했어"(메인 반영 1이 확인·place push). Ctrl+S는 클라우드/.rbxl로 가서 우리 파일이 안 바뀝니다(10/13 밤 확인).
3. 게시: **Alt+P**(File → Publish to Roblox, 같은 체험·같은 장소 81671223175574로). Ctrl+S는 게시가 아닙니다. 다른 체험을 새로 만들지 않습니다.
4. Creator Hub → 체험 → **접근 권한(Access)** = **비공개(Private)** 그대로 두고, 시험할 친구는 **협력자(Collaborators)** 또는 친구 초대로 넣습니다(비공개 체험은 초대·협력자만 들어감).
5. Creator Hub → 체험 → 기본 설정 → **API 서비스 접근(Enable Studio Access to API Services)** 켜짐 확인(저장·Health 기록이 쌓이려면 필요).
6. 저에게 "게시함" 한 줄. → 개발 2가 만든 **시험용 스위치 하나**(Z 스킬 켬·거위 10분·패스 판매 켬, A23-156)는 코드 안 값이라 사용자가 만질 것 없음. 시험 뒤 되돌리는 것도 코드.
7. 시험 4일(10/17~20, 기술 시험): 폰과 PC로 한 번씩 들어가 **패스 9개를 하나씩 사고 다시 접속해 혜택이 남는지**, 저장이 이어지는지만 보세요. 재미 판정은 11/7~10 시험에서. 막히거나 이상한 곳은 사진 1장 + 한 줄이면 됩니다. 숫자판(첫 화면 통과율·10분 완주율·패스 구매)은 개발 2가 Creator Hub 분석과 서버 기록에서 뽑아 제가 보고합니다.

## 사용자가 안 해도 되는 것
- 패스 ID를 코드에 넣기, 스위치 켜고 끄기, 서버 기록 읽기, place 커밋 — 전부 세션 몫. (저장 Save As만 사용자: 화면 제어 팝업을 안 쓰기로 함, 10/13 밤)
- 게시 뒤 "모든 서버 종료"는 저장 형식이 바뀐 판을 올릴 때만 제가 따로 부탁드립니다.
