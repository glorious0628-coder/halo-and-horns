# 소리 Play 확인 결과 (2026-10-08, 게임성 개발 1)

> 기록용(2026-10-09 검수): 2026-10-08 Play 기록이다. 3절 할 일 1·2·5는 f78959ce에서 했고, 스킬·상호작용·창 키는 그 뒤 A23-78(스킬 Z·X·C, 상호작용 G, 가방 I)로 바뀌었다.

메인 Studio(build/GoodEvil.rbxlx, main c54e0a5 sync), 내 테스트 Play 3번: PC 두 번(`pc_run1` = 서버 명령 이름 오류로 뒤 절반 못 띄움, `pc` = 다시), 폰 흉내 한 번(`phone`, 749x361). 새 저장(StudioFreshSave, 진짜 저장 안 건드림).
도구: `tools/play_sound_check.py pc|phone` — 클라이언트에서 SoundService 아래 모든 Sound의 `Played`를 걸어 이름(`Sfx_<키>_<n>` / `Fx_<이름>`)·id·Volume·PlaybackSpeed·SoundGroup 볼륨(낮춤)을 시간과 함께 적고, 장면마다 표시 줄을 넣는다. 마우스·키보드 없음(리모트·Keybinds.Dispatch·ProximityPrompt·DebugCommand).
원자료: `pc/sounds.json`, `phone/sounds.json`, `*/log.txt`, 사진 `*/0N_*.png`. 볼륨 = Config 값 × 설정(1) 그대로 찍힌 값.

**표시:** 됨 = 그 장면에서 그 소리가 실제로 재생됨 · 미연결 = 코드가 아직 안 냄(다음 묶음) · 못 봄 = 이번 길로는 그 장면을 못 만듦(이유 적음)

## 1. 처음 10분
| # | 장면 | 결과 | 찍힌 값 / 메모 |
|---|---|---|---|
| 1 | 버튼 '톡' (Tap) | 못 봄 | 버튼은 진짜 클릭이 있어야 눌림(시험 길 없음). 코드: 버튼 → Fx.PlaySound("Click") → Audio가 Click을 Tap id로 바꿔 둠 |
| 2 | 창 열기/닫기 | 됨 | 안내 창 열림 WindowOpen 0.449 / 닫힘 WindowClose 0.419, Help 창(H)도 같음. **창 키 G·C·K·L·J는 안 먹음**(Panels에 그 창이 등록 안 됨 — 가방은 'Items'로 등록) → 아래 '찾은 것' ③ |
| 3 | 안내자 말 | 됨 | TalkBlip 0.25, 속도 1.06~1.14, 약 2.1 s 동안 34번(0.05~0.1 s 간격) |
| 4 | 퀘스트 받기 | 됨 | QuestNew 0.5(직업 고른 뒤·거위 등장 뒤 거위 줄). **QuestDone 뒤 0.30 s에 QuestNew**(PC 2회차) — '0.6 s 띄움' 규칙이 아직 없음 → 다음 묶음 |
| 5 | 점프 | 됨 | Jump 0.25 |
| 6 | 휘두르기 | 됨(전사) | SwingWarrior 0.30, 속도 0.92~1.05. 궁수·마법사·펫은 이번에 안 해 봄 |
| 7 | 때리기 | 됨 | HitSoft 0.319(슬라임 3마리 한 번에 0.399 = ×1.25), HitCrit 0.379. HitHeavy(고블린)는 안 해 봄. 폰 흉내도 같은 값 — 크기 느낌은 귀로 |
| 8 | 처치·콤보 | 됨 | KillPop 0.40, ComboCoin 0.289 속도 0.80 → 0.897 → 1.007(처치마다 오름, 4 s 지나면 0.80으로). x10 ComboMilestone은 안 감 |
| 9 | 첫 임무 [Claim] | 됨 | QuestDone 0.649 |
| 10 | 골드 받기 | 됨 | GoldPickup 0.449(PC: 서버 명령 Gold +500 직후, 폰: 사냥 중 은행 골드 150→162 때 — 어느 알림 줄인지는 안 적힘). 택배 0.6배는 안 해 봄 |
| 11 | 대장간 첫 무기 | 됨 + 겹침 | **Equip 0.449(서버 Fx Upgrade) → 0.43 s 뒤 PowerUp 0.60(HUD 첫 무기 순간)** 두 소리. QuestDone은 같이 안 남(서버 C1 OK) → 첫 무기면 Equip 빼기(다음 묶음) |
| 12 | 물약 사기 / 마시기 | 됨 | Spend 0.349 / Potion 0.40 |
| 13 | 레벨업 / Lv5 | 됨(일부) | 처치로 Lv2: LevelUp 0.85 + 그동안 전투 소리 묶음 0.5로 낮춤. SkillLearn 0.60은 배움 순간에 남. 서버 명령 Level 5는 LevelUp Fx를 안 보내서 'LevelUp → 1.1 s → SkillLearn' 간격은 못 봄 |
| 14 | 스킬 Q / 쿨다운 끝 / MP 부족 | 일부 | MP 0 → Deny 0.449 됨. **Q 시전 소리 못 봄:** 서버 명령 Level 5는 서버 SkillSlots를 안 올림(LeveledUp 신호 때만 catchUp) → 서버가 Q 'Locked'. 진짜 레벨업이면 정상 길 → 다음 창에서 진짜 레벨업으로 SkillCast·SkillHalo·SkillReady 확인 |
| 15 | 자동 전투 켬/끔 | 됨 | AutoOn 0.50 / AutoOff 0.449 |
| 16 | 도시락 선택·점수 내림·칭호 | 일부 | 명예 내림 → RankDown 0.319 됨. 명예 오름은 소리 없음(설계: Purify·Devour는 선택 Fx 'Choice' 때만). Choice·RankUp은 이번에 못 만듦 |
| 17 | 크게 맞기 | 못 봄 | HurtBig — 고블린에게 맞는 장면 없음 |
| 18 | 전리품·주문서 | 됨 | Loot 0.449(첫 주문서 드롭, 폰 회차), ScrollSuccess 0.699 / ScrollFail 0.40 속도 0.90 |

## 2. 세계 사건
| # | 장면 | 결과 | 찍힌 값 / 메모 |
|---|---|---|---|
| 19 | 거위 | 일부 | GooseArrive 0.649 됨(그 뒤 0.93 s에 거위 퀘스트 줄 QuestNew), 거위 때림 GooseHonk 0.40 됨. **GooseEnd 미연결** |
| 20 | 왕 등장 / 처치 | 일부 | PumpkinKing 0.699, GhostKing 0.699 됨. KingDefeat는 왕을 쓰러뜨려야 해서 못 봄 |
| 21 | 전쟁 판 끝 · 30 s 전 · 3-2-1 | 미연결/못 봄 | CrownHalo/Horns는 판 끝을 못 만듦(NotifyAll Sound 길은 시험에서 확인됨). **WarFinal30·CountTick 미연결** |
| 22 | 괴수 | 미연결 | **KaijuSiren·KaijuStomp 미연결**(서버 신호 KaijuPhase / Fx Stomp 있음) |
| 23 | PvP 땅·쓰러짐·부활·약탈 | 미연결/못 봄 | **ZoneEnterPvP·KO·Respawn 미연결**(신호 ZonePvP / Fx KO 있음), Plunder는 2명 필요 |
| 24 | 황금 몬스터 | 미연결 | **GoldenSpot 미연결**(몬스터 속성 Golden, Reward Golden 있음) |
| 25 | 다른 사람 대박 알림 | 미연결 | **JackpotOther 미연결**(Announce 리모트, Self 아닌 Jackpot·FirstMax) — 명령 Announce는 내 알림(Self)이라 원래 안 남 |

## 3. 찾은 것 → 할 일
1. 첫 무기 Equip+PowerUp 겹침 → 맨손에서 첫 무기(WeaponTier 0→1)면 Fx Upgrade의 Equip을 뺀다.
2. QuestNew가 QuestDone 0.30 s 뒤에 남 → QuestDone 뒤 0.6 s까지 미룬다(사양 §4-2 11).
3. 창 키 G(가방)·C·K·L·J가 안 먹음: Config.Keybinds의 Window가 Panels에 없는 id(Bag·Character·Skills·Ranking·Journal). 가방은 'Items'로 있음 → 검수 판단 대기.
4. 스킬 Q·SkillReady·LevelUp→SkillLearn 간격: 다음 Studio 창에서 진짜 레벨업(Level 4 + 처치)으로 다시.
5. 남은 소리 10개 연결(KO·Respawn·GooseEnd·KaijuStomp·KaijuSiren·WarFinal30·CountTick·GoldenSpot·ZoneEnterPvP·JackpotOther) + QuestDone/LevelUp ±0.4 s 규칙.
