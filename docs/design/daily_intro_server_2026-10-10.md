# 일일 퀘스트 소개 퀘스트 — 서버 (게임성 개발 3, 2026-10-10, A23-104)

사용자: "일일퀘스트도 다짜고짜 하는 게 아니라 이것도 퀘스트로 알려주는 게 좋겠어. 이것 때문에 창이 처음부터 늘어나는 것 같오" → 새 플레이어는 처음부터 일일 줄 3개를 받지 않고, 짧은 소개 퀘스트를 끝낸 뒤에 열린다.

## 규칙
- **언제 여나:** 첫 장 끝(M1_4) 뒤. M1_4가 끝나면 서브 **D0 'Daily Jobs'**(`Config.StoryQuests.Defs.D0`)가 저절로 시작하고(대화가 튀어나오지는 않음, 줄로 보임), 줄을 눌러 안내자 대화 한 장("Every day I have 3 small jobs for you. Do all 3 for a daily chest!" / "Look in your Quests window. New jobs come every morning.")을 끝내면 열린다. 마지막 줄 "Daily jobs are open!", 보상은 사냥 1분어치(골드·XP). M1_4는 대략 5분째라 첫 10분 안에 새싹 일일(Lv1~9)이 열려 있다. Lv3 같은 다른 시점은 `Requires`만 바꾸면 된다.
- **그 전에는:** QuestService가 일일을 만들지도, 보여 주지도, 세지도 않는다(처치·골드·스킬·거위·털기·헌트, 리롤, 환생·진영 바꿈, 휴가 보상, 하루 넘김 모두). `Quests` 페이로드에 `DailyLocked = true`가 붙는다(개발 1: Q창 Daily 탭 잠금).
- **열리면:** `StoryQuestService.QuestDone(player, "D0")` → `QuestService.OpenDailies`: 저장 `data.DailyIntro = true`, 그날 세트를 바로 만들고 바로 보낸다(페이로드의 `DailyLocked`가 사라짐).
- **이미 일일을 돌린 저장**(`DailyDay > 0`)은 처음부터 열려 있고, D0는 시작하지 않고 끝난 것으로 표시된다(`Story.Done.D0`).
- **끄기:** `Config.Daily.IntroGate = false` → 모두 처음부터 열림(옛 규칙). 소개 퀘스트 id는 `Config.Daily.IntroQuest`, 저장 기본값 `Config.Data.Defaults.DailyIntro = false`(데이터 버전 3 그대로).
- 공개 API: `QuestService.DailiesOpen(player)`, `QuestService.OpenDailies(player)`, `QuestService.DayCheck(player)`.

## townOffer 순위 (검수 3a2111a0)
`StoryQuestService.SubRows`: 아직 받지 않은 마을 NPC 제안(townOffer)이 진행 중인 서브보다 앞에 서서(순위 2) SendAllSubs 꺼진 기본에서 진행 중 줄이 3줄 밖으로 밀리던 문제 → 순위 **2.5**(진행 중 2 아래, 다른 제안 3 위). **SendAllSubs도 켬**(`Config.StoryQuests.SendAllSubs = true`, 개발 1의 HUD가 More 줄을 건너뛰고 퀘스트 창 'In progress'가 다 보여 줌): 활성 서브는 모두 보내고 MaxSubs(3) 밖은 `More = true`. town_quests 시험 묶음은 기본으로 끈 채(townWorld) 3줄 규칙을 보고, send-all-subs 묶음이 켠 채를 본다(진짜 Config 기본값이 true인지도 확인).

## 시험
- `test_a23_14` "daily-intro (A23-104)": 설정, D0 정의, 새 저장은 아무것도 없음(처치·골드·스킬·환생·진영·사흘 부재·하루 검사·보상·리롤·클레임), 다른 퀘스트 끝은 안 엶, D0 끝 → 세트 생김·페이로드 열림, 두 번째 신호 무시, 낡은 줄은 안 보임·안 셈, 옛 저장은 열림 + D0 끝남 표시, IntroGate=false. 변이 21개.
- `test_town_quests` "daily intro quest (A23-104)": M1_4 전에는 안 줌, 뒤에는 줄로 시작(팝업 없음), 눌러서 대화, 말하면 끝·QuestDone·소액 골드·"Daily jobs are open!", 세 진영 모두, 다시 안 줌. townOffer 순위 시험 묶음 고침 + 변이.
