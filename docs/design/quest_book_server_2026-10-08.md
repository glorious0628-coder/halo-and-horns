# 퀘스트 창 '받을 수 있음 / 끝남' 서버 자료 (A23-81) — 게임성 개발 3, 2026-10-08

근거: 개발 1 Q 퀘스트 창(탭 Main/Side/Daily/Event/Faction × 진행 중/받을 수 있음/끝남) 제안, 검수 OK. 시험 =
`py tools/test_quest_book.py`(73검사, 변이 11/11) + 퀘스트 목록을 쓰는 기존 시험(onboarding·weapon_first·a23_14 등) 통과.

## 원격 모양
`Quests` 리모트 값 = **{ Quests = 지금 줄 배열, Book = { Available, Done } }** (Lua 표). 지금 main의 HUD.onQuests·Audio.OnQuests는 표의
`.Quests`를 이미 읽는다(옛 서버의 JSON 글자 배열도 계속 읽음). 바뀔 때만 보냄(줄 + Book을 함께 비교).

- `Done` = 끝낸 이야기 퀘스트 `"story:<id>"` 목록. 메인은 최근 것부터(이야기 순서 거꾸로), 그다음 서브도 최근 것부터. 최대 40개(`Config.QuestBook.DoneMax`).
  제목은 클라가 `Config.StoryQuests.Defs[id].Title`로. (오늘 받은 일일은 받으면 줄이 바뀌어 기록이 없어서 넣지 않음.)
- `Available` = { Id = "story:<id>", Kind = "Sub", Level?, Text? } 목록, 낮은 레벨부터, 최대 10개(`AvailableMax`).
  - **레벨만 기다리는 서브**(다른 조건 — 앞 퀘스트·진영·장인 길드 스위치 — 은 다 맞음): Level = 그 레벨,
    Text = "<제목> · Opens at Lv N"(`Config.QuestBook.Text.OpensAt`).
  - 조건이 다 맞았는데 아직 시작 안 한 서브(1초 갱신 전, 드묾): Level·Text 없음.
  - 숨은 서브(Hidden), 이미 시작·끝난 것, 다른 진영 것은 안 넣음. **메인은 안 넣음** — 메인 사슬은 레벨 문 없이 다음 것이 바로 시작돼서 "Opens at Lv"가 없음.
- 탭은 클라가 정함(Config.QuestTabs, 없으면 Kind). 서버는 Tab을 보내지 않음.

## 바뀐 파일
`StoryQuestService.BookRows(player, data)`(공개 함수 1개, 조건은 기존 requirementsMet를 레벨만 바꾼 읽기 전용 보기로 재사용),
`QuestService.publish`(줄 몇 개: BookRows 부르고 표로 보냄), `Config.QuestBook`(Config 맨 끝). 시험 고정물 3개(onboarding·weapon_first·a23_14)가
새 표 모양을 읽게 고침.
