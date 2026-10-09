# 베타 이스터 에그 — 서버 계약 (게임성 개발 3, 2026-10-10)

근거: `docs/design/story_depth_2026-10-06.md` (나) 표 + SPEC A23-52(어른도 재미있게), 검수 10/10("새 모델 없이 되는 것만": EG01·02·03·04·14 + EG05·06). 정식 몫(EG07~13)은 새 모델·4장이 필요해서 안 했어요.
서버는 끝났어요. 화면(클라)과 월드 배치는 아래 몫으로 나뉘어요.

## 서버가 한 것
**숨은 서브 5개** (`Config.StoryQuests.Defs.EG01~EG04·EG14`, 모두 `Kind = "Sub"`, `Hidden = true`, `Requires = M2_3 끝`, 진영 상관없이 모두): 시작 알림·줄·마커 없음. 자리 근처에 가면 대화창이 **저절로** 열리고(대화 상대 NPC 없음) 그때부터 줄이 보여요. 끝나면 **칭호만**(능력치·골드·XP 없음).
| Id | 자리(`Config.StoryQuests.Landmarks`) | 내용 | 칭호 |
|---|---|---|---|
| EG01 Terms of Fate | `TermsScroll` (0,0,51) = 운명의 제단(0,0,45) 뒤, 반경 6 | 카드 "TERMS OF FATE (page 1 of 4,000)" [Read it all] / [I agree](0점, 장인은 A/B 같은 글) → 고른 쪽 글 | 읽음 = **Actually Read It**, 동의 = **Didn't Read It** |
| EG02 Patch Note | `PatchNote` (-52,0,0) = 현상수배 게시판 앞쪽 쪽지, 반경 6 | "Patch 0.0.1: The crown is broken." / "Known issue. We are looking into it." | **Bug Reporter** |
| EG03 Goose Fan | `GooseNest` (-30,0,30) = 거위 횃대(`Config.Goose.Position`), 반경 6 | "The Golden Goose has 0 followers. She has never been happier." / "Also, she saw who broke the Crown. Honk." | **Goose Fan** |
| EG04 Sky Watcher | `Fountain` (분수), 반경 12 안에서 **한 번에 30초** | "Sky Crown: Stop staring. I'm broken, not famous." | **Sky Watcher** |
| EG14 Bench Detective (폰 이름 Bench clue) | `KidsBench` (18,0,18), 반경 6 | "Under the bench: two small handprints in old paint." / "One gold. One purple. Side by side." | **Bench Detective** |
- 칭호 6개는 `Config.TitleDefs` + 칭호 고르는 순서(`TitleOrder`)에 들어갔어요. 끝낸 서브는 퀘스트 창 '끝낸 것' 목록에 보여요(못 찾은 것은 어디에도 안 보임).
- EG01 선택은 점수 0(가운데 "그림자가 빛/어둠 쪽으로 기울었어요" 한 줄만, 명예·악명 안 변함).

**EG05 농담 팁** (쓰러짐 화면): `Config.Death.Fun = { Every = 15, SkipFirst = 3, Lines = 4줄 }`. CombatService가 쓰러질 때마다 `data.KOs`(저장, 새 칸 `Config.Data.Defaults.KOs = 0`)를 올리고, **그 계정의 4번째 쓰러짐부터 15번에 1번쯤** `Net.Fx "KO"` 꾸러미에 `Tip = "Tip: …"`를 넣어요(없으면 칸 자체가 없음). 고르기는 `Config.FunTip(koCount, roll, pick)`(순수).
**EG06 고블린 쪽지**: `Config.GoblinNotes = { Title = "Goblin Notes", Lines = 3줄 }`, `Config.GoblinNote(dayIndex)` = 그 주(KST 7일) 줄 하나, 3주마다 한 바퀴(음수·이상한 값은 첫 줄).

## 개발 1에게 (클라, 작아요)
1. **쓰러짐 화면**: KO fx의 `Tip`이 문자열로 오면 상황 팁(`Config.Death.Tips[…]`) 자리에 **그대로** 보여 주기(없으면 지금처럼).
2. **새 소식 창**: 맨 아래에 따로 한 줄(색 다르게, 제목 `Config.GoblinNotes.Title`) = `Config.GoblinNote(Config.DayIndex(os.time()))`.

## 월드 배치 (메인 반영 1 / 월드 도구, 작아요 — 없어도 서버는 돌아요)
- 보이는 소품은 선택: 제단 뒤 두루마리 표지판(EG01), 현상수배 게시판 앞 쪽지(EG02)를 `TermsScroll`·`PatchNote` 좌표에 Part + SurfaceGui 글로. 거위 횃대·분수·벤치는 이미 있어요. 마커·'!'는 달지 않아요(찾는 재미).
- 소품이 모델이 아니라 Part·글이라 새 모델 승인은 필요 없어요.

## 시험
`py tools/test_town_quests.py` 609검사·변이 136/136(묶음 "easter-eggs": 데이터·자리가 교차로·M2_3 전엔 안 시작·시작해도 숨음·80/10스터드 밖은 그대로·3스터드에서 대화 저절로·칭호 한 번만·EG04 30초 한 번에·EG01 4가지 선택·점수 0), `py tools/test_ko_screen.py`(EG05, 변이 30/30), `py tools/test_goblin_notes.py` 29검사·변이 13/13.
