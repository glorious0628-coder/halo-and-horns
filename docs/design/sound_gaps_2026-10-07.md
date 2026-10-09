# 소리 빠진 사건 대조 — 2026-10-07 밤 (소리 만들기, 읽기만)

> 기록용(10/07 당시). 지금과 다른 점: 여기 적힌 소리 키 다수(SwingArrow·HitCrit·Jump·Equip·Spend·RankUp·SkillLearn·SkillReady·KingDefeat·Loot 등)는 그 뒤 `Config.Audio`에 연결됨(ab708339, 남은 이벤트 10개 f78959ce) — 남은 것은 `sound_play_check_2026-10-07.md`로 Play에서 확인(10/08 결과 `docs/art/verification_2026-10-08/sound_play/sound_play_table_2026-10-08.md`)(최신: SPEC A23-67). 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

검수 요청: 설계서 `docs/design/sound_spec_2026-10-07.md` §4-2·§5와 코드(`Audio.luau`, `Config.Audio`, 서버 `Net.Fx`·`Net.Notify` 호출)를 대어 보고 소리가 없거나 틀린 사건을 모은다. 코드는 origin/main(1f7113e 무렵)을 읽기만 했다. `src/`는 고치지 않았다. 고칠 사람: 개발 1(클라이언트 Audio·Config.Audio), 개발 2(서버 필드).

## A. 파일은 생겼는데 게임에 연결이 안 된 것 (업로드 id가 오면 개발 1)
| # | 지금 게임 | 바꿀 것 |
|---|---|---|
| A1 | **궁수 공격이 무음**(`Files.SwingArcher = ""`) | SwingArrow 한 발, 대상 2 이상이면 +0.068 s에 1.10배·0.85볼륨 한 번 더(설계서 4-2 #5) |
| A2 | 마법사 = 옛 SwingMage 하나 | 시전자 진영으로 SwingMageHalo / SwingMageHorns (4-2 #3) |
| A3 | HitHeavy1/2, HitSoft1/2 무작위 | HitHeavy, HitSoft 한 파일씩 + **HitCrit** 층(첫 대상 치명, Gap 1.5 s, 4-2 #6) |
| A4 | PowerUp = LevelUp 파일 1.12배(Config 주석) | PowerUp 파일 |
| A5 | HurtBig = HitHeavy2 파일 | HurtBig 파일 |
| A6 | 두 왕 = KingBell 한 파일 | PumpkinKing / GhostKing 따로, Speed {1,1} |
| A7 | GooseActive 켜짐 → GooseHonk | GooseArrive. GooseHonk는 거위를 때렸을 때만(이미 planHits에 있음) |
| A8 | 서버가 Notify Sound로 **Equip**(LootService:532)·**Spend**(ShopService:289)·**RankUp**(StoryQuestService:308)을 보내는데 `Config.Audio.Sounds`에 그 키가 없어 무음 | Sounds에 세 키 추가(볼륨 picks_r4.json) |
| A9 | SkillBar가 "SkillLearn"을 부르고 실패하면 PowerUp(SkillBar:667) | Sounds에 SkillLearn 추가. Lv5·15·25에서는 LevelUp 소리 뒤 약 1.1 s에 |
| A10 | 스킬 쿨다운 끝 소리 없음 | SkillReady (4-2 #12) |
| A11 | 점프 소리 없음 | Jump(사용자 요청 새 키) |
| A12 | 정화 한 파일 | Purify / Purify_b 번갈아 |
| A13 | ScrollSuccess 옛 파일 | 새 파일(4번 묶음 1-4) |

## B. 사건 신호는 있는데 소리를 안 듣는 것 (Audio가 듣기만 하면 됨, 파일은 4번 묶음에 있음)
| # | 신호(코드) | 소리 | 메모 |
|---|---|---|---|
| B1 | Fx "KO" → 나에게만(CombatService:1270) | KO | 다시 나타날 때(KO 뒤 CharacterAdded) **Respawn** |
| B2 | Fx "Plunder" 모두에게(PvPService:700) / 피해자에게(GrudgeService:372) | Plunder(당한 사람만) | PvPService 패킷은 `{From, To, Amount}`뿐이라 **누가 당했는지 모름** → 개발 2가 VictimId(또는 피해자에게 따로 보내기) 필요 |
| B3 | Fx "GooseEnd" 모두에게(GooseService:665) | GooseEnd | 카메라 가까이일 때만(설계서). 보상은 GoldPickup |
| B4 | Fx "Stomp" 모두에게(KaijuService:474) | KaijuStomp | 60 studs 안, 15 studs 안 1.0 → 60에서 0 |
| B5 | GameState `KaijuPhase` → "Siren"(KaijuService:128) | KaijuSiren | 뒤이어 CountTick |
| B6 | 전쟁 한 판 끝 `Net.NotifyAll(WarWin[winner])`(WarService:348), Sound 없음 | CrownHalo / CrownHorns | 개발 2가 Sound 필드를 넣거나 클라가 판 끝을 봄. 비김은 소리 없음, 상자 보상은 1.5 s 미룸 |
| B7 | GameState `WarRoundEndsAt` | WarFinal30(30 s 남음, 판마다 1번) + CountTick(3-2-1) | 서버 신호 없음 → 클라 타이머 |
| B8 | 몬스터 `Golden` 속성 / Fx "Reward" `Golden=true`(ProgressionService:463) | GoldenSpot(처음 50 studs·화면 안, 몬스터마다 1번) / GoldenKill = GoldenSpot 재사용, 동전 0.1 s 뒤 | |
| B9 | 내 `ZonePvP` false→true | ZoneEnterPvP | 스폰·순간이동 뒤 3 s 제외, Gap 10 s, 나갈 때 없음 |
| B10 | 남의 Jackpot·FirstMax 알림(AnnounceService → Announce.luau) | JackpotOther | RareWeapon 제외, 30 s에 1번 |
| B11 | 왕 쓰러뜨림: HalloweenService `finish(b, true)`는 채팅 한 줄뿐 | KingDefeat | 신호 필요(개발 2: Fx 또는 GameState). 기여자는 KillPop·동전 0.25 s 뒤 |
| B12 | 진영 고르기 확정(FactionPicker는 Click만) | SkillHalo / SkillHorns 재사용(설계서 §5 P0) | 업로드 없음 |
| B13 | Fx "Skill"(SkillService:280, Z·X 시전) | SkillCast + 진영 층 + 타격 | `Audio.Plan`은 Swing/Release만 봄 → **Z·X는 시전·타격 소리가 없음**. 지금은 Studio 시험용(ZEnabled/XEnabled)이지만 10/20 결정 전에 연결 |
| B14 | Fx "Loot" 내 드롭(LootService:418) | **Loot — 아직 소리 없음** | 설계서 §5 P0 "베타 전에 꼭 확인". 소리 만들기가 만들 수 있음(키 설계 → 후보 → 검수) |
| B15 | Fx "Rebirth"(ProgressionService:432) | Rebirth | 베타 뒤(설계서) |

## C. 틀린 소리가 나는 것 (경로표 §4-2와 다름)
| # | 지금 | 설계서 | 고칠 곳 |
|---|---|---|---|
| C1 | Notify kind "reward"에 Sound가 없으면 **QuestDone**이 남(Audio.NotifySound). 무기 줄(LootService:275·288·291·296·315·318), 펫(PetService:124·149), PvP(PvPService:460·671·703·729), 자루(GrudgeService:335·383), 장인(RankingService:479), 구매(MonetizationService:52), 환생(ProgressionService:433)이 모두 QuestDone | QuestDone은 퀘스트·이야기·일일·게시판 완료만 | 개발 2가 각 줄에 Sound: 무기 → Equip, 첫 무기 → None(HUD가 PowerUp을 냄, 지금은 PowerUp + QuestDone 겹침), PlunderGain → GoldPickup, 나머지 → None 또는 GoldPickup |
| C2 | Fx "Upgrade"(LootService:265, ShopService:113) → GoldPickup | Equip | 개발 1 Audio.Plan |
| C3 | 괴롭힘으로 자동 전투가 강제로 꺼질 때 Notify "bad"(CombatService:1375) → Deny + AutoOff 둘 다 | 이때 Deny 끔(4-2 #11) | 개발 2 Sound "None" 또는 개발 1 |

## D. 소리 만들기가 더 만들 것
- **Loot**(B14, P0): 첫 주문서·전리품이 떨어질 때. 설계 → 후보 → 검수 → 업로드.
- 베타 뒤: Rebirth, 전사 충격파 '쿵', LevelUp·창 진영 층, TalkBlipHorns, SwingTamer.
