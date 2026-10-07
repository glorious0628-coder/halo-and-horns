# 소리 연결표 — 4차 51개 (2026-10-07, 소리 만들기 → 게임성 개발 1)

Creator Hub 업로드 끝(Darugi_S2, 비공개, 이름 'HH SFX <키>'). id 원본은 `art/sfx/asset_ids.json` "ids", 출처·sha256·볼륨은 `art/sfx/picks_r4.json`. 볼륨은 설계표(`tools/sfx_spec.json`) 값이고 파일은 모두 K가중 −17 LUFS로 맞춰 둠. 옛 id("old")와 `art/sfx/*.ogg`는 새 id를 연결하고 Play로 확인한 뒤에 지움(소리 만들기가 지움). 어디서 틀지는 `docs/design/sound_gaps_2026-10-07.md`(A·B·C 표)와 같은 번호.

| 키 | id | 볼륨 | 언제 / 바꾸는 것 |
|---|---|---|---|
| SwingArrow | `rbxassetid://76900813038959` | 0.25 | 궁수 휘두름(지금 무음). 대상 2 이상이면 +0.068 s에 1.10배·0.85볼륨 한 번 더 |
| SwingMageHalo | `rbxassetid://101498441090410` | 0.28 | 마법사 휘두름·SkillCast, 시전자 진영 Halo |
| SwingMageHorns | `rbxassetid://139514092831666` | 0.28 | 마법사 휘두름·SkillCast, 시전자 진영 Horns |
| HitHeavy | `rbxassetid://95463530376920` | 0.36 | 단단한 몬스터·플레이어 타격(HitHeavy1/2 대신 한 파일) |
| HitCrit | `rbxassetid://78018534821425` | 0.38 | 치명타: 재질 타격 위에 얹는 층(첫 대상, Gap 1.5 s, Max 1) |
| ComboCoin | `rbxassetid://132925998560879` | 0.29 | 처치 동전(지금 Combo 음계 그대로) |
| HitSoft | `rbxassetid://96440842663562` | 0.32 | 슬라임·유령·호박 타격(HitSoft1/2 대신). 폰 -5.1 dB → 폰 흉내 Play로 확인 |
| PowerUp | `rbxassetid://118952858498086` | 0.6 | 첫 무기(HUD L.FirstWeapon, 지금 LevelUp 1.12배 대신) |
| Jump | `rbxassetid://119789949243782` | 0.25 | 점프(새 이벤트, 사용자 요청) |
| GoldPickup | `rbxassetid://119243238199900` | 0.45 | 은행·택배(0.6배)·거위 보상·전쟁 상자·괴수 몫·현상금 |
| QuestNew | `rbxassetid://123199271616228` | 0.5 | 새 퀘스트 |
| QuestDone | `rbxassetid://131457371135343` | 0.65 | 퀘스트·이야기·일일·게시판 완료만 |
| WindowClose | `rbxassetid://86085176622331` | 0.42 | 창 닫기 |
| Deny | `rbxassetid://124536292557880` | 0.45 | 거절된 내 입력(No 별칭) |
| RankDown | `rbxassetid://81421593114766` | 0.32 | 내 진영 점수 내려감 |
| ScrollFail | `rbxassetid://124525939049830` | 0.4 | 강화 실패 |
| SkillHalo | `rbxassetid://75898672312875` | 0.36 | 스킬 진영 층 Halo(Q/Z/X 모두) |
| SkillHorns | `rbxassetid://110780992455213` | 0.36 | 스킬 진영 층 Horns(Q/Z/X 모두) |
| Purify | `rbxassetid://126260420453106` | 0.55 | 선택 Good(Fx Choice) — Purify_b와 번갈아 |
| Purify_b | `rbxassetid://75155843966047` | 0.55 | Purify 둘째 버전(번갈아) |
| Devour | `rbxassetid://118262766439187` | 0.55 | 선택 Evil(Fx Choice) |
| Potion | `rbxassetid://133789691162407` | 0.4 | 물약 마심 |
| AutoOn | `rbxassetid://90300088723425` | 0.5 | 자동 전투 켬 |
| AutoOff | `rbxassetid://128226305896103` | 0.45 | 자동 전투 끔 |
| TalkBlip | `rbxassetid://94593126133806` | 0.25 | 대화 글자(BarkPop은 0.8~1.5배로 재사용) |
| Equip | `rbxassetid://132294814566104` | 0.45 | 무기 구매·장착(서버 Notify Sound 'Equip' 이미 보냄, Fx Upgrade도 Equip으로) |
| SkillReady | `rbxassetid://99319219774246` | 0.25 | 스킬 쿨다운 끝(SkillBar) |
| HurtBig | `rbxassetid://73666772845621` | 0.36 | 크게 맞음(지금 HitHeavy2 대신) |
| PumpkinKing | `rbxassetid://112500082253148` | 0.7 | 호박 왕 등장(KingBell 대신, Speed {1,1}) |
| GhostKing | `rbxassetid://100319357258743` | 0.7 | 유령 왕 등장(KingBell 대신, Speed {1,1}) |
| GooseArrive | `rbxassetid://113800368972766` | 0.65 | GooseActive 켜짐(지금 GooseHonk 대신) |
| GooseHonk | `rbxassetid://115693307820380` | 0.4 | 거위를 때렸을 때만 |
| CrownHalo | `rbxassetid://123752635254582` | 0.7 | 전쟁 한 판 Halo 승리(서버 신호 필요, 개발 2) |
| CrownHorns | `rbxassetid://131150435186247` | 0.7 | 전쟁 한 판 Horns 승리(서버 신호 필요, 개발 2) |
| KingDefeat | `rbxassetid://115530599858312` | 0.65 | 왕 쓰러뜨림(서버 신호 필요, 개발 2) |
| WarFinal30 | `rbxassetid://102592807006385` | 0.5 | 전쟁 30 s 남음(WarRoundEndsAt, 클라 타이머) |
| CountTick | `rbxassetid://96016194154678` | 0.4 | 3-2-1(1.0/1.12/1.26배) |
| GooseEnd | `rbxassetid://103362677938359` | 0.5 | Fx GooseEnd(카메라 가까이일 때) |
| KaijuSiren | `rbxassetid://110447360461794` | 0.7 | KaijuPhase 'Siren' |
| KaijuStomp | `rbxassetid://82058880758348` | 0.45 | Fx Stomp, 60 studs 안(15 안 1.0 → 60에서 0) |
| ZoneEnterPvP | `rbxassetid://104461336219672` | 0.45 | ZonePvP false→true(스폰·순간이동 뒤 3 s 제외, Gap 10 s) |
| GoldenSpot | `rbxassetid://128057879317544` | 0.4 | 황금 몬스터 처음 보임 + GoldenKill(Reward Golden=true) 재사용 |
| ScrollSuccess | `rbxassetid://116061752455414` | 0.7 | 강화 성공(옛 파일 대신) |
| Spend | `rbxassetid://80768400627761` | 0.35 | 물약 구매(서버 Notify Sound 'Spend' 이미 보냄) |
| RankUp | `rbxassetid://84902463002053` | 0.32 | 새 칭호·진영 점수 오름(서버 Notify Sound 'RankUp' 이미 보냄) |
| KO | `rbxassetid://137556643487651` | 0.4 | Fx KO(나에게만) |
| Respawn | `rbxassetid://128867123359602` | 0.4 | KO 뒤 다시 나타남 |
| Plunder | `rbxassetid://74602898707411` | 0.4 | 주머니 뺏김(당한 사람만; 패킷에 피해자 id 필요, 개발 2) |
| JackpotOther | `rbxassetid://99814762304779` | 0.4 | 남의 Jackpot·FirstMax 알림(30 s에 1번) |
| SkillLearn | `rbxassetid://113535664889883` | 0.6 | 새 스킬 배움(SkillBar가 이미 부름). Lv5·15·25에서는 LevelUp 소리 뒤 약 1.1 s |
| Loot | `rbxassetid://114739645345413` | 0.45 | Fx Loot에 주문서(Enhance·Transfer)나 무기가 있을 때만. 무기는 0.92배. 재료·물약은 소리 없음(글자만) |

새 Config.Audio.Sounds 키가 필요한 것: Jump, PowerUp(파일만 바꿈), Equip, Spend, RankUp, SkillLearn, SkillReady, HitCrit, GooseArrive, CrownHalo, CrownHorns, KingDefeat, WarFinal30, CountTick, GooseEnd, KaijuSiren, KaijuStomp, ZoneEnterPvP, GoldenSpot, KO, Respawn, Plunder, JackpotOther, Loot (+ Purify_b, 두 왕 분리).

## 7번 묶음 — 옛 파일이던 6개 새로 (2026-10-07 밤, 검수 고름 eef5072)
Config.Audio.Files의 **같은 키에 id만 바꾸면 됨**(새 이벤트 없음). 옛 id는 `asset_ids.json` "old"로 옮겼다(연결·Play 확인 뒤 소리 만들기가 정리). 업로드는 크롬 연결이 끊겨 1/6에서 멈춤 — 나머지 id는 올리는 대로 이 표와 asset_ids.json "ids"에 채운다("pending" = 아직 안 올린 것).

| 키 | id | 볼륨 | 언제 / 바꾸는 것 |
|---|---|---|---|
| SwingWarrior | `rbxassetid://114585478722203` | 0.30 | 전사 휘두름(설정 그대로: Speed 0.92~1.05). 공기만 '휙' 0.16 s, 금속·음정 없음 |
| KillPop | 올리는 중 | 0.39~0.40 | 내 처치 '뽕' 800→940 Hz(설정 그대로). 설계서 버그 메모: 타격 시각(ContactDelay + 0.04 s)에 틀기 |
| ComboMilestone | 올리는 중 | 0.45 | 콤보 x10·25·50·100. 끝음 C8 4.2 kHz — 단계마다 높일 때는 **최대 1.15배**(끝음 4.8 kHz, 설계서 '5 kHz 아래') |
| LevelUp | 올리는 중 | 0.85 | 레벨업(설정 그대로). 폰 몸통 523 + 785 Hz가 들어 있음, 1.09 s |
| Tap | 올리는 중 | **0.46**(지금 0.42) | 모든 UIKit 버튼. TalkBlip보다 +3 LU 커야 해서 볼륨을 올림(설계서 범위 0.42~0.50) |
| WindowOpen | 올리는 중 | 0.45 | 창 열기 1080→1730 Hz(새 WindowClose 1550→1000 Hz의 거울) |
