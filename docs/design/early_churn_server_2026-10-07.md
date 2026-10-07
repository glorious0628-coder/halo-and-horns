# A23-68 초반 이탈 막기 — 서버 몫 (게임성 개발 2, 2026-10-07)

결정: `docs/SPEC_ADDENDUM.md` A23-68(사용자 2026-10-07), 근거 `docs/design/early_churn_research_2026-10-07.md`.
서버 몫은 #1 수락 → 초원, #4 한 번에 목표 하나, #5 첫 3분 기록. 손잡이는 모두 `Config.Tutorial` / `Config.Analytics`.

## #1 수락하면 바로 초원
- 안내자 [Accept](`AcceptTutorial`) → 단계 1(Guide). `Config.Tutorial.AcceptTravelSeconds`(3초) 뒤 서버가 초원 입구로 옮긴다:
  `ZoneService.Travel(player, GuideZone, true)`(즉시 이동 — 레벨·괴수·자루·현상수배 별·전투 규칙은 그대로 거절할 수 있고,
  그때는 지금처럼 HUD 안내 빛줄기로 걸어간다). 도착하면 ZoneChanged → 단계 2(사냥).
- 개발 1과 정한 약속: 수락 때 `Net.Fx(player, "Travel", { UserId, To = "SlimeMeadow", T = 3 })`(T초 뒤 이동) → 클라가 'Off to Squishy Meadow!' 3·2·1, T−0.4초부터 까맣게 덮음. 이동이 끝나면(또는 건너뛰면) `Fx "TravelDone" { UserId }` → 클라가 다시 밝힘(늦어도 T+1.5초). 그 사이 `MoveLockUntil`(서버 시간 = 지금 + T + 1.5) 동안 휘두르기·Q·Z·X가 아무 일도 안 한다(`CombatService.attackBlocked`, 비용 없음), TravelDone 때 0으로 푼다.
- 그 사이 캐릭터가 바뀌었거나(쓰러짐), 이미 초원이거나, 단계가 바뀌었으면 옮기지 않는다. 초원에서 수락하면 바로 단계 2(이동 없음).
- 첫 임무 동안(단계 1·2, 아직 [Claim] 전) 쓰러지면 **초원 입구에서 다시 태어난다**(`PlayerService.respawnZoneId`,
  `Config.Tutorial.RespawnInMeadow`). [Claim](단계 99) 뒤에는 원래대로 진영 집. 마을에 개인 몬스터를 두지 않는 10/04 결정은 그대로.

## #4 한 번에 목표 하나
- 첫 [Claim] 전(TutorialStep ≠ 99)에는 `Quests` 목록의 첫 임무 줄(`Id = Config.Tutorial.QuestId`) 말고 모든 줄에
  `Folded = true`를 실어 보낸다(받아 두기·진행은 그대로). `Config.Tutorial.FoldOthers`. 이미지 개발이 줄을 접는다
  (TutorialStep으로 판단해도 결과가 같다).

## #5 첫 3분 기록 (퍼널 13단계, 계정마다 한 번씩)
1 IntroDone · 2 Faction · 3 Class · 4 FirstMissionAccept · **5 MeadowArrive** · **6 FirstHit** · **7 FirstKill** ·
**8 FirstSkillHit** · 9 FirstMissionDone · **10 ForgeArrive** · 11 FirstWeapon · 12 AutoUnlocked · 13 Level10
(공개 전이라 번호를 다시 매겼다).
- MeadowArrive: 첫 임무 단계 2 또는 SlimeMeadow에 들어감. FirstHit: 새 신호 `CombatService.MonsterHit(player, rec, killed)`
  (휘두르기·Q·스킬이 몬스터에 실제로 들어간 첫 타격). FirstKill: MonsterKilled. FirstSkillHit: 손으로 쓴 스킬이 몬스터를
  1마리 이상 맞힘(`Released`, 자동은 안 셈). ForgeArrive: 대장장이 프롬프트(BlacksmithVisited).
- 옛 저장 따라잡기: 단계 ≥ 2 → MeadowArrive, TotalKills > 0 → FirstHit·FirstKill, M1_3 또는 S0 완료 → FirstSkillHit,
  BlacksmithVisited → ForgeArrive.

## 하지 말 것
- idea_backlog의 '친구와 함께하면 +10%'를 뺐다(친구 수만큼 보상 없음). 진영 화면의 친구 진영 표시는 남김.

## 검사
- `tools/test_onboarding.py`: 수락 → Fx Travel{UserId, To, T=3}·MoveLockUntil → 3초 뒤 즉시 Travel → TravelDone·잠금 풂 → 단계 2,
  접힘(첫 임무 말고 모두, [Claim] 뒤 없음), 바뀐 캐릭터·거절된 이동·초원에서 수락, respawnZoneId(단계 0·1·2·99, 손잡이 끔). 손 변이 11/11.
- `tools/test_swing_aim.py`: 잠금 동안 휘두르기가 아무것도 안 맞히고, 풀린 뒤 맞힘 + 변이 1(12/12).
- `tools/test_metrics.py`: 13단계 순서, 순간마다 한 번, 자동 스킬·빈 스킬 제외, 초원 걸어 들어가기, 옛 저장 따라잡기,
  MonsterHit 정적 검사. 변이 46/46(새 8개).
