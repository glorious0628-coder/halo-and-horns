# 소리 연결 뒤 Play 확인 목록 (2026-10-07, 소리 만들기)

> 기록용(10/07 당시). 이 목록이 가리키던 붙여 넣기 문서(`sound_wiring_onepass_2026-10-07.md`)는 연결이 끝나(ab708339) 기록으로만 남김 — 지금 값은 `Config.Audio`. 10/08 Play 확인 결과는 `docs/art/verification_2026-10-08/sound_play/`. 새 소리 확인 목록은 `sound_gaps_2026-10-10.md`.

`sound_wiring_onepass_2026-10-07.md`를 넣은 뒤, 메인 Studio Play(PC + 폰 흉내)에서 위에서부터 확인한다. 소리가 안 나면 먼저 `py tools/sfx_wiring_check.py`(옛 id 0·빈 칸 0인지), 그다음 그 이벤트 연결을 본다. 빨리 띄우기 = 서버 Command Bar `game.ServerScriptService.DebugCommand:Invoke("Player1", "<키>", 값)`(Studio 전용, Main.server.luau).

## 1. 처음 10분 (가장 먼저)
| # | 해 볼 것 | 들려야 할 소리 (키) | 확인 |
|---|---|---|---|
| 1 | 진영 고르기·버튼 누르기 | '톡' (Tap) | 모든 버튼 같은 소리, 말소리(TalkBlip)보다 조금 큼 |
| 2 | 창 열기/닫기(가방·지도) | 올라가는 '쏙' / 내려가는 '쏙' (WindowOpen / WindowClose) | 열림·닫힘이 귀로 구별됨 |
| 3 | 안내자 대화 | 글자마다 '톡톡' (TalkBlip) | 귀가 안 아픔, 몬스터 말풍선은 같은 파일 0.8~1.5배 |
| 4 | 퀘스트 받기 | 종이 '팔락' + '띠링?' (QuestNew) | QuestDone 바로 뒤면 0.6 s 띄움 |
| 5 | 점프 | '폴-짝' (Jump) | |
| 6 | 전사 / 궁수 / 마법사(빛·뿔) / 펫 휘두르기 | 휙 (SwingWarrior) / '슉' 화살, 2마리 이상이면 '슉-슉' (SwingArrow) / '슝'·'푸슉' (SwingMageHalo / Horns) / 휘파람 (SwingTamer) | **궁수 무음이면 안 됨**, 줄 '팅' 없음 |
| 7 | 슬라임·유령 때리기 / 고블린 때리기 / 치명타 | '말랑' (HitSoft) / '퍽' (HitHeavy) / '팡' 층 (HitCrit) | **폰 흉내에서 HitSoft가 작지 않은지**(-5.1 dB) |
| 8 | 처치·콤보 | '뽕' + 동전 '짤-랑'이 한 음씩 올라감 (KillPop + ComboCoin), x10 (ComboMilestone) | 콤보 끝음이 째지지 않음(최대 1.15배) |
| 9 | 첫 임무 [Claim] | '짜잔' (QuestDone) | |
| 10 | 골드 받기(은행·택배) | 동전 3개 '짤랑' (GoldPickup) | 택배 0.6배 |
| 11 | 대장간 첫 무기 / 다음 무기 사기·끼기 | 반짝 '짠!' (PowerUp) / '착' (Equip) | 첫 무기에 QuestDone이 같이 나면 서버 C1 미해결 |
| 12 | 물약 사기 / 마시기 | 동전 두 개 '짤-랑↓' (Spend) / '뽁 보글' (Potion) | |
| 13 | 레벨업 / Lv5 `Level 5` | '빠-바-밤' (LevelUp) / LevelUp 뒤 약 1.1 s '뽁! 샤라락 티잉~' (SkillLearn) | 두 소리가 안 겹침 |
| 14 | 첫 스킬(Lv5 뒤, PC 키 Z — A23-71·A23-78) (빛·뿔) / 쿨다운 끝 / MP 부족 `Mana 0` | 시전 + 진영 층 (SkillHalo / SkillHorns) / '삥' (SkillReady) / '어-어' (Deny) | |
| 15 | 자동 전투 켬 / 끔 | 올라가는 '딸깍' / 내려가는 '딸깍' (AutoOn / AutoOff) | 강제로 꺼질 때 Deny가 같이 나면 C3 미해결 |
| 16 | 도시락 선택 Good / Evil, 내 진영 점수 내림, 새 칭호 | 바람 종 (Purify, 다음엔 Purify_b) / '앙! 꿀꺽 뽕' (Devour) / '또르르↓' (RankDown) / '또로롱↑' (RankUp) | 정화 두 버전 번갈아 |
| 17 | 크게 맞기 | 막힌 '쿵' (HurtBig) | 피·비명 느낌 없음 |
| 18 | ~~킹슬라임~~ Slime Prince(BigSlime, A23-84) 첫 처치(주문서 확정) / `Item Enh70` 뒤 강화 성공·실패 | '톡-톡-톡 티링~' (Loot) / '슈링 챙' (ScrollSuccess) / '푸스스 퐁' (ScrollFail) | 재료·물약 드롭은 소리 없음, 무기 드롭은 Loot 0.92배 |

## 2. 세계 사건 (명령으로 띄우기)
| # | 띄우기 | 들려야 할 소리 (키) | 확인 |
|---|---|---|---|
| 19 | `Goose` → 거위 때리기 → 끝 | 날갯짓 + '꽥꽥' (GooseArrive) → '꽉!' (GooseHonk) → 날아감 (GooseEnd) + 1.5 s 뒤 GoldPickup | 등장 때 전투 소리 낮아짐 |
| 20 | `PumpkinKing` / `GhostKing` → 쓰러뜨리기 | 왕 종 + '뻥 사르르' / 왕 종 + '후우?' (PumpkinKing / GhostKing) → '와르르 짜잔' (KingDefeat) | 1.6 s 동안 전투 소리 낮아짐, 무섭지 않음 |
| 21 | 전쟁 판 끝 · 30 s 전 · 공개 3 s 전 | 빛 '샤라라 치잉' / 뿔 '화르륵 쿵' (CrownHalo / CrownHorns), 자전거 벨 (WarFinal30), '똑 똑 똑' 계단 (CountTick) | 비김은 소리 없음 |
| 22 | 괴수 경보 → 쿵쿵 | '우르르릉 쿵! 쿵!' (KaijuSiren) → 거리 따라 '쿵' (KaijuStomp) | 사이렌 음 없음, 멀면 작아짐 |
| 23 | PvP 땅 들어가기 / 쓰러짐 / 다시 나타남 / 주머니 뺏김 | '두둥' (ZoneEnterPvP) / '콩! 삐요삐요' (KO) / '뿅!' (Respawn) / '짤그랑 또르르' (Plunder) | 스폰 3 s 안은 '두둥' 없음, 뺏은 사람은 GoldPickup |
| 24 | 황금 몬스터 보기 / 처치 | '반짝반짝' (GoldenSpot) / 같은 소리 + 동전 | 몬스터마다 한 번 |
| 25 | `Announce` "Jackpot:8" | '오오 반짝' (JackpotOther) | 30 s에 한 번 |

## 3. 끝나면
- PC·폰 흉내 둘 다 위 1번 표가 맞으면 소리 만들기에게 알려 준다 → ~~소리 만들기가 `asset_ids.json` "old" 30개와 `art/sfx/*.ogg`를 정리한다.~~ (→ 끝남: 10/08 Play 확인 `docs/art/verification_2026-10-08/sound_play/sound_play_table_2026-10-08.md`, 옛 ogg 30개 정리 55fe9a11. 남은 `SwingMage.ogg`·`SwingTamer.ogg`는 지금도 쓰니 지우지 않는다 — `asset_ids.json` "kept".)
- 이상한 소리는 키 이름과 장면만 적어 검수에게(소리 만들기가 다시 만듦). 설계 기준: `docs/design/sound_spec_2026-10-07.md`.
