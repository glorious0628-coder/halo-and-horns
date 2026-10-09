# 걸어서 대장간 + 순간이동은 퀘스트로 배움 — 서버 계약 (게임성 개발 3, 2026-10-09)

SPEC A23-88(사용자 2026-10-09 "처음에 순간이동 안 시키면 좋겠어. 무기 상점으로 가라고 하고, 순간이동도 가능하다는 것을 퀘스트로 알려주자"). 서버는 끝났고, 길 빛·패드 빛·말풍선은 **개발 1(클라)** 몫이에요.

## 서버가 바꾼 것 (QuestService)
- **[I'm In!] 뒤 저절로 옮기는 것이 없어요.** `AcceptTutorial` → 맨손이면 step 3(`TutorialStep = 3`), 무기가 있으면 step 1. `Fx "Travel"` / `"TravelDone"`, `MoveLockUntil`, 모루 앞 착지, 3초 뒤 초원 이동(`Forge.TravelDelay`), 줄을 눌러 대장간 이동(`RequestTutorial` at step 3)은 모두 없앴어요. `Config.Tutorial.AcceptTravelSeconds`와 `Forge.Landing/Back/Lift/TravelDelay`도 없어요(`Forge = { Near = 24 }`만).
- **step 3 줄** = `Config.Tutorial.Text.Forge` = "Go to Otto's Forge" (ShortName "To the Forge"). **끝나는 때**: 모루에서 오토가 첫 무기를 줄 때(`QuestService.ForgeGift`, 모루 프롬프트 — 예전과 같음). 모루가 없는 월드면 바로 무기를 주고 넘어가요(갇히지 않음).
- **step 1 줄(무기 뒤)** = `Config.Tutorial.Text.Travel` = "Travel to Squishy Meadow — step on the glowing travel pad (or Map → Travel)" (ShortName "To the meadow"). **끝나는 때**: 초원에 닿을 때 — 이동 판, 지도 이동(`ZoneService.Travel`), 걸어서 가도 똑같이 `ZoneChanged`로 step 2(사냥)가 돼요. 오토의 한 줄은 "…Here's your first weapon! The Squishy Meadow is next."
- **옛 저장**: step 3에 있던 사람은 그대로 step 3(집에서 시작해 걸어요, 줄 글자만 새것). step 1에 있던 사람은 새 줄을 보고 판/지도로 가면 돼요. 서버가 데려가는 일이 없으니 "이동이 실패해 step 3에 갇힘"이 생기지 않아요. KO 때 부활 자리는 그대로(step 1·2는 초원 입구, 그 밖은 집).
- **퍼널(측정)**: 걸어서 모루 24 studs 안에 처음 선 순간(그 접속에서 [I'm In!]을 누른 사람만) `QuestService.ForgeReached(player, 초)` → `TelemetryService`의 Custom 이벤트 `ForgeWalk`(값 = 걸린 초, 정수). 기존 퍼널 단계(`ForgeArrive` = 오토를 만남, `FirstWeapon`, `MeadowArrive`)는 그대로예요. 이벤트 이름 한도(100)는 지켜요.

## 개발 1에게 (클라 계약)
1. **길 빛 + 미니맵 표시**: `TutorialStep == 3`일 때 내 위치에서 모루(`ShopService.Anvil`, 교차로)까지 땅 위 길 빛, 미니맵 점. 줄을 눌러도 같은 안내(이동은 없음). 마을 안전 구역이라 싸움 없음. 걸어서 약 20~40초(집 마을 ~ 교차로 약 330~410 studs, 걷기 속도로 20~26초) — 길이 막히지 않고 빛이 끊기지 않는지 메인 Play에서 확인.
2. **이동 판 빛**: `TutorialStep == 1`일 때 가까운 `TravelTo` 판을 빛나게 하고, **처음 한 번만** 짧은 말풍선. 판을 밟거나 지도 → Travel로 초원에 가면 서버가 step 2로 넘겨요(걸어가도 끝은 같음). 판이 없는 곳이면 줄의 "(or Map → Travel)"이 길잡이.
3. 더 이상 안 오는 것: `Fx "Travel"`/`"TravelDone"`(첫 임무용). `FirstSteps.luau`의 가림막(fade)과 `Audio`의 `TravelDone` 소리 연결은 첫 임무에서는 쓰이지 않아요(지도 이동 등 다른 Travel Fx가 있다면 그대로).
4. 멀면 길 빛 + 한 줄 'Otto is just past the fountain!'(A23-88).

## 시험
`py tools/test_weapon_first.py`(105 검사, 변이 40/40 — 걷기·도착 지표·옛 이동 없음), `py tools/test_onboarding.py`(847), `tools/test_beta_metrics.py`(ForgeWalk, 변이 66/66), unarmed_start·beta_basics 그대로 통과.
