> **검수 메모(2026-10-07, 이 설계서보다 먼저):** A23-67 이후 소리는 **소리 만들기** 세션이 Firefly 효과음을 먼저 써서 만들고, **검수가 1개씩 골라 바로 게임에 넣는다**(사용자 듣기판 없음). 사용자 정정 "그대로 두는 것도 다시 다!" — 펫 B·말랑 B·동전 두 개도 **복사하지 않고 다시 만든다**(좋아했던 방향 참고로만). 아래 본문의 '개발 2'는 '소리 만들기', '사용자 듣기판'은 '검수 고르기'로 읽는다. 숫자·피할 것·버그 목록은 그대로 기준이다.
> **2026-10-09 검수:** §4-1 묶음 1~4 소리는 4차로 새로 만들어 올렸고(`art/sfx/picks_r4.json`·`art/sfx/asset_ids.json`; SwingTamer·장인 SwingMage는 아직 3차 그대로 — "kept") `Config.Audio`에 연결됨(ab708339, 남은 이벤트 10개 f78959ce), 메인 Play 확인 10/08(`docs/art/verification_2026-10-08/sound_play/`), 옛 ogg 정리 55fe9a11. 아래 '지금 게임 32개' 판정은 10/07 기록이고 지금 값은 `Config.Audio`. §4-2 클라 항목은 `Audio.luau`·`Config.Audio`와 대조해서 본다(전부 들어갔다고 확인한 것은 아님). 남은 업로드는 `asset_ids.json` "pending".

# 소리 설계서 — 만들기 전에 정하기 (2026-10-07)

> 이 설계서와 `docs/design/lines_pack_2026-10-06.md` §6 소리 표가 다르면 이 설계서를 따릅니다. 기준 숫자는 `tools/sfx_spec.json`에 들어 있고, 검사는 `tools/sfx_check.py`로 합니다.

## 0. 한눈에

1. **사용자 말 반영:** 활 소리는 화살이 날아가는 '슉' 두 번입니다. 줄 '팅'·'트왕'은 넣지 않습니다. 마법·퍽·치명타는 처음부터 다시 만듭니다. 동전은 '짤-랑' 두 개입니다. 사용자가 좋아한 펫 휘파람 B와 말랑 B는 그 파일을 바이트 그대로 씁니다.
2. **지금 게임 32개 중 8개가 사용자가 싫다고 했거나 좋아한 B가 아닌 파일입니다:** SwingArcher=SwingBow_a, SwingMage=SwingMagic_c, HitHeavy1·2=HitThud_c·a, ComboCoin=Coin_a, HitSoft1·2=HitSquish_a·HitSoft_b, SwingTamer=SwingWhistle_a. 이것부터 바꿉니다. 새 궁수 소리가 올라오기 전까지는 궁수 id를 ""로 둡니다. 줄 '팅'보다 소리가 없는 편이 낫습니다.
3. **공통 규칙:** 자주 나는 소리일수록 짧고 조용하게 합니다. 폰에서 3 dB 넘게 작아지면 탈락이므로 150 Hz 아래에 기대지 않습니다. 샘플 하나에는 뜻 하나만 줍니다. 진영 짝(빛·뿔)은 크기를 같게 맞춥니다. 계단식 아르페지오는 성장 소리 셋(LevelUp·QuestDone·ComboMilestone)에만 씁니다.
4. **자동 검사기:** 사용자가 거절한 13개를 모두 FAIL로 잡았습니다. 그래서 사람이 듣기 전에 걸러낼 수 있습니다. 지금 게임 소리 32개는 PASS 2 · WARN 11 · FAIL 19입니다.
5. **순서:**
   - 개발 2: 후보 3개 → 검사 → 시트·장면 렌더 → 검수가 2개로 줄임 → 사용자 듣기판 → 업로드.
   - 개발 1: 처치 '뽕'·동전이 타격보다 먼저 나는 버그, 마법사 진영별 파일, 치명타 층을 먼저 고칩니다.

## 1. 소리마다 설계 표

**모든 소리에 적용**
- **파일 크기:** K가중(BS.1770) 기준으로 가장 큰 100 ms를 −17, 최고점을 −3 dBFS로 맞춘 뒤 Volume을 곱합니다.
  - 지금은 RMS로 맞춰서 밝은 소리가 2.5~3.5 dB 크게 들립니다.
  - `art/sfx/sources.json`의 "−14 dBFS, peak −1" 메모는 틀렸으니 고칩니다.
- **크기 등급(Volume):** 조용 0.24~0.30 · 보통 0.32~0.40 · UI 0.40~0.50 · 큰 순간 0.55~0.70 · 최대 0.85(LevelUp만).
- **소리 조건:**
  - HP 150 Hz(UI는 300 Hz). 8 kHz 위 에너지 5% 이하.
  - 폰에서 줄어드는 정도 3 dB 이하(진영 짝은 2 dB 이하). 잔향 0.3 s 이하.
  - 목소리·비명·피·무서운 저음은 넣지 않습니다. 유명 게임 소리는 흉내 내지 않습니다. ~~재료는 Kenney CC0나 우리 합성만 씁니다.~~ → 재료는 Firefly 효과음 먼저, 그다음 Kenney CC0, 그다음 우리 합성(A23-67).
- **자동 전투와 다른 플레이어:**
  - 자동 전투: 전투 소리 0.5배, 보상(KillPop·ComboCoin·ComboMilestone) 0.75배.
  - 다른 플레이어 소리: 0.35배, 40 studs 안에서만. 내 소리를 막지 않도록 풀을 따로 씁니다.
- **표기:** `KL(…)`은 Kenney 파일을 불러오는 것이고, `whoosh/bell/svf/sparkle/finish`는 `tools/sfx_game.py` 함수입니다.

### 1-1. 전투

| 키 · 결정 | 언제 | 아이가 기대하는 소리 | 층 | 길이 ms | 높낮이/쓸림 | 크기 등급 | 1분에 | 진영 차이 | 피할 것 | Kenney 후보 | 합성 방법 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **SwingWarrior** 유지(SwingWarrior_a) · 지금 WARN | 전사 기본 공격을 누를 때(t=0, 타격 0.23 s). 대장장이 0.85배, 맨손 1.15배(지금 1.3배)×0.6, 전사 Q 시전. 충격파의 땅 '쿵'은 베타 뒤 | 휙! 부웅 (장난감 칼) | 띠 잡음 하나(공기만), 금속·음정 없음 | 150~200 (175), 220 넘으면 안 됨 | 500→3k→900 Hz로 올랐다 내려감. 1.5~4 kHz 60% 이상, 중심 ≈4 kHz, 300 Hz 아래 없음 | 조용 0.30 | ≤60 | 없음 | 칼 '쉥' 금속, 300 Hz 아래 '우웅', 8 kHz 위 '칙', 두 번 쉭(궁수와 헷갈림) | 없음(진짜 휙이 없음). close_002·open_002·scratch_005 탈락 | `whoosh(0.18, 500, 3000, 900, q1.1, peak .45, seed3)` → `finish(hp150)`. 맨손판은 6 kHz LP |
| **SwingMageHalo** 새 키 · 지금 FAIL | 빛 마법사 기본 공격, Q 메테오 시전(0.85배). 가장 큰 지점이 구슬 발사(0.24 s)에 오게(At ≈ 0.24 − 최고점 시각 ≈ 0.20 s) | 슝~ 샤랑 (반짝 빛 화살) | ① 틱 사인 900→1300 Hz 25 ms ② 공기 잡음 2.4→4.2 kHz(Q1.5) 150 ms ③ 유리 '칭' 하나 ≈3.2 kHz(배음 1:2.76, 감쇠 60 ms, −8 dB) ④ 반짝 6~8알 3~6 kHz. 음정 성분 30% 이하 | 160~220 | 올라감. 1.5~6 kHz, 중심 2.8~4.5 kHz, 8 kHz 위 5% 이하 | 조용 0.28. 뿔과 K가중 1 LU 안 | ≤55 | 빛(오르는 공기 + 유리 반짝) | 사인 하나로 미끄러지는 음(거절된 SwingMagic a/c, 휘파람과 같음), G6-B6-D7 화음 '딩'(보상처럼 들림), 레이저 '퓨', 교회 종·합창·하프 | 없음(합성). maximize_003 탈락(끝에 커짐) | `svf(noise,2400→4200,Q1.5)` + tick + `bell(3200, partials (1,1),(2.76,.3))`×0.4 + `sparkle(.12,7,3k–6k,.3)` → LP 7.5k → `finish(150)` |
| **SwingMageHorns** 새 키 · 지금 FAIL | 어둠 마법사 기본 공격·Q 시전. 타이밍은 빛과 같음 | 푸슉-파직! (장난꾸러기 불꽃) | ① 불 잡음 500→1400→700 Hz(Q2, tanh) ② '뽁' 330→220 Hz + 2·3배음, 70 ms 이하 ③ 불티 5~8알 2~5 kHz로 끝남 | 170~220 | 내려감. 몸통 220~1000 Hz, 불티 2~5 kHz, 중심 ≈1.85 kHz | 조용 0.28. 빛과 K가중 1 LU·폰 2 LU 안, 폰 손실 1.5 dB 이하 | ≤55 | 뿔(불 + 불티로 끝) | 으르렁·악마 목소리·웃음, 150 Hz 아래, 80~200 Hz 긴 출렁임(방귀), 길게 '보잉', 불티가 몸통보다 큼 | scratch_001(불티층, 먼저 들어 봄). maximize_006(폰 −9.3 dB)·toggle_003(8 kHz 위 34%)·drop_003(처치 전용) 탈락 | 명세 레시피(fw×0.8 + bw 70 ms×0.6 + crackle×1.0) → `finish(150)` |
| **SwingArcher → SwingArrow** 교체(사용자: '슉'만) · 지금 FAIL | 궁수 화살 발사(0.22 s), 타격 0.37 s, Q 화살비(0.85배). **화살 한 발 파일**을 올리고, 대상이 2 이상이면 Audio가 +0.068 s에 한 번 더 냄(1.10배, 볼륨 0.85). Gap 0.05·Max 3 | 슉슉! (화살 두 개가 날아감) | 화살 한 발 = 좁은 잡음 휙, 멀어지며 내려감. 줄·활·음정 없음 | 한 발 65~90, 두 발 합쳐 110~150, 사이 완전히 조용 | 발마다 내려감 2.8→3.3→1.1 kHz. 중심 3.2~4.5 kHz(시제품 3.83), 8 kHz 위 2% 이하 | 가장 조용한 전투 소리. HitHeavy보다 2 LU 이상 작게(≈0.22~0.24) | ≤120번(휙 240번), 가장 자주 | 없음 | 줄 '팅'·튕김·활 삐걱 전부(거절된 SwingBow a/b/c), 음정 '싯', 레이저, 휘파람, 160 ms 초과, 쉿 | 없음(합성). close_002 탈락(중심 6.75 kHz, 8 kHz 위 31%), toggle_003 탈락 | `LP8k(whoosh(.065,2800,3300,1100,q1.8,peak .1))` → `finish(150)`. 두 발 파일이 필요하면 +0.068 s에 1.10배 −1.5 dB(검사 PASS). Speed 0.95~1.05 |
| **SwingTamer** B 그대로 복사 · 지금 FAIL(A가 들어감) | 펫 조련사 기본 공격(베타 뒤). Q 펫 돌진(`Swing.PetDash` 추가). 펫 박치기 소리는 대상 재질을 따름(HitSoft/HitHeavy) | 휘-휙! (강아지 부르기) | B 그대로: 음 1500→1700 Hz 80 ms + 2000→2500 Hz 90 ms, 숨소리 12% | 190 | 올라감. 1.5~2.5 kHz, 중심 2.2 kHz | 조용 0.24~0.26 | ≤60(Gap 0.9 s) | 없음 | B의 음높이·리듬을 바꾸는 것, 호루라기 떨림, 4 kHz 위, 목소리 | 필요 없음 | `build/sfx_game/cand/SwingWhistle_b.ogg`를 복사하고 sha256 기록. Speed 0.97~1.03 |
| **HitSoft** B 그대로 복사 · 지금 WARN(B가 아님) | 슬라임·킹 슬라임·호박 슬라임·유령에 맞은 휘두름 1번에 1회(0.23/0.30/0.37/0.44 s). "3마리 이상이면 HitHeavy" 규칙은 삭제하고, 대신 같은 재질을 1.25배 볼륨·0.95배 속도로. 유령은 1.15배 속도 | 말랑! 뽀용 (젤리 찌르기) | B 그대로: impactSoft_medium_001(HP120, k4) + 젤리 덩어리(공명 1600→380 Hz, 사인 240→150 Hz, 22 Hz 흔들림) | 180 | 내려감. 중심 ≈300 Hz, 150 Hz 아래 51% | 보통 0.32 | 60~120 | 없음 | 젖은 철퍽·피, 120 ms 넘는 낮은 출렁임(방귀), 딱딱한 '톡', 거절된 HitSquish_a·HitSoft_b | impactSoft_medium_001(B 몸통), impactSoft_medium_003(B2) | `build/sfx_game/cand/HitSquish_b.ogg` 복사. 폰에서 −5.5 dB라 실제 폰으로 들어 봄. 사라지면 'B+'(B + 550 Hz '뽀' 사인 −10 dB)를 따로 후보로. B2는 새 시드로 B와 A/B 통과 시에만 |
| **HitHeavy** 교체(A/B/C 셋) · 지금 FAIL | 고블린·박쥐·브루트·플레이어(PvP)에 맞은 휘두름 1회. 해골·해골 기사는 나무 변형만(종류별 표) | 퍽! (단단한 만화 한 방) | ① 찰싹 잡음 2.2 kHz 14 ms ② '허' 1.4→0.7 kHz 35 ms ③ 톡 ④ 몸통 300→160 Hz 80~100 ms. A=명세, B=톡 0.5·허 1.1·몸통 0.45, C=Kenney 톡 없음. 돌아가며 쓰는 2개는 같은 레시피 다른 시드 | 100~150(나무 190) | 0.7~3 kHz 순간음 + 160~300 Hz 몸통. 최고점 0~3 ms, 중심 350~500 Hz | 보통+ 0.36 | 60~120 | 없음 | 지금 파일(뭉툭, 최고점 27~35 ms 늦음, 폰 −6.5~−8.2 dB), 강한 찌그러짐, 뼈 '우두둑', '오프' 목소리, 쿵 꼬리 | impactGeneric_light_004(톡, 타격 전용), impactPunch_medium_003(앞 12 ms 자르고 HP180), impactWood_medium_002(나무). impactPlate_light_003 탈락 | slap×1.3 + puh×0.9 + `KL(impactGeneric_light_004)`×0.9 + body(drive2)×0.3 → `finish(150)`. 시제품 0.111 s, 폰 2.1~2.5 dB |
| **HitCrit** 새 키(A/B 둘) | 치명타(PvE 휘두름만, 스킬·PvP 제외). 재질 타격 **위에 얹는 층**(말랑 + 별). 첫 대상이 치명일 때만 + Gap 1.5 s·Max 1(궁수 ≈12번/분) | 빡! 캉★ ('특별한 한 방!') | A: 금속 '캉'(impactMetal_medium_000 + heavy_003 ×0.6) + 반짝 6알 4.2~7 kHz. B(금속 없음): 10 ms '팡' 1.5~4 kHz + 별 알갱이 7→3 kHz로 내려감 + '징' 1.2→2.4 kHz −10 dB. 몸통은 재질 타격이 맡음. 사용자가 거절한 치명타는 둘 다 금속이 있었으므로 B를 꼭 함께 | 180~250 | 넓음(0.9~7 kHz), 중심 ≈3.5 kHz, 폰 손실 3 dB 이하 | 0.38(장면 렌더에서 확정) | ≤12 | 없음 | 거절된 HitCrit a/b/c(쿵 + 금속, 늦은 최고점), 유리 깨짐, 사인 '딩'(헤드샷), 동전 '팅' 2.3~3 kHz, 오르는 2~7 kHz 번쩍(ScrollSuccess 몫), 목소리 | A: impactMetal_medium_000, impactMetal_heavy_003. B: 없음 | A = KL 둘 + `sparkle(.10,6,4.2k–7k,.5)`@30 ms. B = 잡음 10 ms 2.5k + 내려가는 sparkle + 사인 1.2→2.4k 60 ms. 둘 다 `finish(150)` |
| **KillPop** 유지(drop_002) · 지금 PASS | 내 처치. **버그:** 지금은 누를 때(타격보다 0.23~0.44 s 먼저) 남 → 내 다음 Swing/Release 패킷의 ContactDelay + 0.04 s에. 여러 마리를 한 번에 잡아도 1번 | 뽕! (비눗방울) | 사인 같은 '뽕' 800→940 Hz (+선택: 1.5~4 kHz '푸' −12 dB) | 60~120(103) | 살짝 올라감. 700~1000 Hz는 이 소리 몫 | 보통+ 0.38~0.40 | 15~30 | 없음 | 폭발, 비명, 철퍽, 풍선 '빵', 바람 빠짐, '오프', 동전처럼 오르는 쓸림, 타격보다 먼저 남 | drop_002. drop_004(동전 오름과 겹침)·select_006(1.94 s) 탈락 | 필요 없음 |
| **SkillHalo** 교체 · 지금 FAIL | 스킬 시전 Q/Z/X **모두**(지금은 X만이라 베타에서 안 들림). SkillCast 위에 얹고 LaunchDelay에 맞춤 | 샤라랑~ (금빛이 감돌며 올라감) | ① 오르는 바람 1.2→5 kHz 200 ms ② 계단 없는 유리 차임 덩어리 1.2~2.0 kHz(무작위 4~5번) 또는 1.0~1.6 kHz '빛' 패드(공격 40 ms) ③ 반짝 10알 3.5~7 kHz. glass_005는 첫 틱으로만 | 300~400(<450) | 올라감. 중심 ≈3.4 kHz, 800 Hz 아래 없음 | 보통 0.36. 뿔과 K가중 1 LU·폰 2 LU 안 | 8~12 | 빛 | C7-E7-G7 계단 종(동전 음과 겹침), 교회 종·오르간·합창·하프, 지금 65 ms 핑 하나, 7 kHz 위 큰 소리 | glass_005(틱만). maximize_001 탈락 | `svf(noise,1200→5000,Q1.4)`×sin^1.5 + 차임 덩어리(배음 1:2.76) 또는 패드 + `sparkle(.18,10,3.5k–7k,.25)` → `finish(150)` |
| **SkillHorns** 교체 · 지금 FAIL | 같은 때(뿔) | 화르륵-토독! (모닥불이 찡긋) | ① 불 휙 400→1200→600 Hz(Q1.6, tanh) 220 ms ② 불티 10알 2~5 kHz ③ '뽐' 440→260 Hz 120 ms 이하 ④ 끝 '토-독'. drop_003 '뽕'은 삭제 | 250~350 | 올랐다 내려감. 260~1500 Hz + 2~5 kHz, 중심 ≈1.3 kHz, 기본음 220 Hz 이상 | 보통 0.36. 빛과 맞춤, 폰 손실 2 dB 이하(지금 8.3) | 8~12 | 뿔 | 홀로 쓰는 230~350 Hz '봉'(지금 파일), 으르렁·웃음·드론·천둥, 길고 낮은 출렁임, '뽕'(처치와 헷갈림), 400 ms 초과 | impactWood_light_000(토독, 뿔 서명), scratch_001. bong_001(폰 −19.6 dB)·maximize_006 탈락 | fw + crackles + bwomp + `KL(impactWood_light_000,1.6)`@0.20 + `(…,1.35)`@0.26 → `finish(150)` |

### 1-2. 보상·진행

| 키 · 결정 | 언제 | 아이가 기대하는 소리 | 층 | 길이 ms | 높낮이/쓸림 | 크기 등급 | 1분에 | 진영 차이 | 피할 것 | Kenney 후보 | 합성 방법 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **ComboCoin** 교체(사용자: 동전 두 개) · 지금 FAIL | 처치마다 KillPop 50 ms 뒤(타이밍 고침도 같이). 콤보마다 장음계 한 칸(0.80→1.60배). 여러 마리를 한 번에 잡으면 동전을 70 ms 간격으로 최대 4개, 한 칸씩 오르는 물결로. Max 4·Gap 0.05 | 짤-랑! (동전 두 개가 주머니로) | 같은 샘플 둘: 동전1 = impactMetal_light_000 0.891배(D7) 70 ms ×0.8, 동전2 = 1.0배 +45 ms, 울림 150~200 ms | 200~260(242) | 두 음 2반음 위로. 1.0배에서 2.3~2.7 kHz(1.6배면 3.8~4.3), 1.5 kHz 아래 없음 | 조용-보통 0.28~0.30 | 15~30 | 없음 | 4도·5도 사각파 두 음(배관공 게임), 고슴도치 링, 계산대 '카칭', 슬롯, 3반음 넘는 둘째 음, 250 ms 넘는 울림, 지금 Coin_a('팅' 한 번 0.5 s), tick_004(거꾸로 틱) | impactMetal_light_000(돈 전용) | `fade(KL(light_000,.891),70ms)`×.8 + `fade(KL(light_000),200ms)`×1@45 ms → `finish(150)`. 0.242 s, 2.68 kHz, 폰 0.1 dB |
| **ComboMilestone** 유지·고침(confirmation_003) · 지금 WARN | 콤보 x10·25·50·100에 도달한 처치. 동전 150 ms 뒤 | 띠리링! ('잘 나가!') | confirmation_003의 네 음 오름을 0.85~0.89배로 낮춤. 단계별로 높이는 것은 1.0배까지만(또는 6 kHz LP) | 300~400 | 올라감. 끝음 5.0~5.3 kHz(지금 5.9, x100이면 7.0) | UI 0.45 | 드묾(x10이 30~60 s에 1번) | 없음 | 1-up 징글, 잭팟 종, 함성, 0.6 s 넘는 팡파르, QuestDone·ScrollSuccess와 같은 파일 | confirmation_003. confirmation_002(KingDefeat 전용)·maximize_001 탈락 | 필요 없음 |
| **GoldPickup** 교체 · 지금 FAIL | 처치 말고 금이 들어올 때: 마을에서 맡김(Bank), 빛 택배(Courier, 0.6배), 거위 Rare(동전 + glass_002 반짝). **Upgrade(무기 장착·구매)는 빼서 Equip으로** | 짤랑-찰캉! (동전이 쏟아짐) | 맡김 = 동전 3~4개 계단 D7·E7·G7. 택배 = 동전 2개 D7→E7(+55 ms). 동전마다 2~3 ms '착' −12 dB. 종 꼬리·잔향 없음 | 250~350 | 동전마다 위로. 본음 2.3~3.2 kHz, HP 400 | UI 0.45(택배 0.27) | 0.5~1 | 없음 | 지금 tick_004 한 번(54 ms), 배관공 동전, 링 소리, '카칭', 0.4 s 넘는 종 꼬리 | impactMetal_light_001(D7), light_000(E7), light_004 | `coin(f)=bell(f,.24,14,비정수 배음)` + 3 ms 클릭. 2349@0, 2637@0.055, 3136@0.11 → HP400. 순서를 바꾼 판 2개, Speed 0.96~1.06 |
| **QuestNew** 교체 · 지금 FAIL | 새 퀘스트 받음(접속 직후 첫 목록은 조용). QuestDone이 0.6 s 안에 났으면 0.6 s 뒤로 | 팔락-띠링? ('새 일이다!') | ① 종이 펄럭 2.5~5 kHz 두 번 −6~−8 dB(꼭 넣음, 이 소리의 얼굴) ② 마림바 C6→G6(1047→1568 Hz, 열린 5도) | 330~450 | 올라감. 으뜸음이 아닌 열린 끝, 500 Hz 아래 없음 | UI 0.50(QuestDone보다 1.5 LU 이상 작게) | 처음 10분 0.3~0.6 | 없음 | 폰 알림음(카톡·삼성·아이폰), WindowOpen 오름, 지금 select_003(4.8 kHz로 가늘고 음이 어긋남), G6→E7(휘파람 모양·동전 음), 끝맺는 화음 | 없음. select_005는 참고만 | `marimba(f)=sine f + .25·sine 3.9f`, 빠른 감쇠. 1047@0 + 1568@0.07(0.3 s 울림) + 잡음 펄럭 둘 → `finish(150)` |
| **QuestDone** 교체 · 지금 FAIL | 퀘스트·이야기·일일·게시판 완료**만**(Notify `Sound='QuestDone'`). LevelUp이 ±0.4 s 안에 나면 생략 | 따라링~ 짠! ('다 했다!') | 종 E6-G6-C7(1319/1568/2093 Hz) 65 ms 간격, 마지막 음이 울림 + C6 삼각 몸통 ×0.35 + 반짝 2~3알 −12 dB | 450~600 | 올라가서 C로 닫힘. 1.0~2.1 kHz, LevelUp보다 한 옥타브 위 | 큰 순간 0.65 | 0.3~0.6 | 없음 | 지금 confirmation_001(첫 음 391 Hz, 폰 −5 dB), confirmation_004 0.794배(LevelUp과 같은 음), 짧-짧-짧-길 팡파르 리듬, 0.6 s 초과 | 없음(합성) | `bell(E6/G6,.22,10)`@0/0.065 + `bell(2093,.45,5)`@0.13 + tri C6×.35 + `sparkle(.15,3,3k–5k,.12)` → `finish(150)` |
| **LevelUp** 유지 + 폰 몸통 추가 · 지금 WARN | 내 레벨업. 전투 소리를 0.5배로 1.2 s. 처음 10분에 ≈9번 | 빠-바-밤~ 반짝! ('세졌다!') | 지금 LevelUp_a(C5 E5 G5 C6, 마지막 0.75 s 비브라토, 공기, 반짝) + 폰용 몸통 523 + 785 Hz −10 dB | 1000~1150(지금 973) | 올라감. 음 520~1050 Hz, 300 Hz 아래 없음 | 최대 0.85, 자동 전투에서도 줄이지 않음 | 처음 0.8, 뒤에 ≤0.2 | 베타 뒤 선택: 빛 유리 반짝 / 뿔 불티 층(+0.3 s) | 합창·오르간·교회 종, 유명 레벨업 징글, 칩튠(거절된 LevelUp_b), 낮은 쿵, 1.3 s 초과, 무작위 음높이 | 필요 없음 | `fanfare()` + `(osc523×.25 + osc785×.15)·env(1.0)` → `finish(150)` |
| **ScrollSuccess** 교체(뒤 순서) · 지금 WARN | 강화 성공. 전투 소리 낮춤. 같은 때 QuestDone은 끔 | 슈링~ 챙! 반짝 (무기가 빛남) | ① 번쩍 쓸림 2→7 kHz 80 ms(이 소리만 씀) ② G7 3.1 kHz 링 + 1.05 kHz 몸통 배음 −6 dB(또는 링 대신 '빛 번짐' 패드) ③ glass_004 반짝 +0.15 s. G5-C6-E6 차임 계단은 삭제 | 600~800 | 올라감. 500 Hz 아래 없음 | 큰 순간 0.70(실패보다 4.8 dB 이상 크게) | 0~3 | 없음 | 슬롯·잭팟·동전 소나기(뽑기 느낌), 진짜 칼 뽑는 '쉬잉', 동전 같은 가는 '팅', confirmation_002·004 | glass_004(이 소리 전용), select_008(먼저 들어 봄). impactMetal_light_003 탈락(돈 샘플) | glint `svf(2k→7k,Q2)` + `bell(3136,.45,6, 0.335배 배음 .5 포함)` + `KL(glass_004)`@0.15 → `finish(150)` |
| **ScrollFail** 교체 · 지금 FAIL | 강화 실패. 유지든 한 단계 하락이든 **같은 파일 1.0배**. 0.5 s 동안 Deny 끔 | 푸슈… 퐁 ('에이, 다시!') | ① '푸' 잡음 3.5→0.9 kHz 0.22 s(12 ms 부드러운 시작) ② '퐁' E5→C5 + 2배음 @0.10 s ③ 꺼지는 반짝 2알 −18 dB | 250~350 | 내려가서 둥근 C로 끝. 400 Hz~6 kHz | 0.40 | 0~6 | 없음 | 부저·Deny·error_*, 유리 깨짐(장비는 안 부서짐), 슬픈 트롬본, 사인 미끄럼(WindowClose 모양), 지금 back_002(196 Hz), 0.89배 '하락판', drop_003 | scratch_002 0.6배('푸' 층) | `svf(noise,3500→900,Q1.2)` + plop(659→523)@0.10 + `bell(2400/2800,.03)`×.12 → `finish(150)`. Speed 0.97~1.03 |
| **RankDown** 교체 · 지금 FAIL | 반대편을 골라 내 진영 점수(명예/악명)가 내려감. 선택 소리가 끝나고 0.1 s 뒤(Purify ≈1.05 s, Devour ≈0.8 s) | 또로롱↓ ('조금 내려갔네') | 나무 마림바 E5-D5-C5(659/587/523 Hz) 55 ms 간격, 한 음마다 1.5 dB 작게 | 250~350 | 계단으로 내려가 C에서 편히 끝. LP 4k, 400 Hz 아래 없음 | 조용 0.30~0.35 | ≤0.1 | 없음 | Deny와 같은 삼각파·같은 떨어짐(명세 합성은 Deny와 너무 비슷), 단조·'와와', 느린 G-E-C 종(방송 차임), 선택 소리와 겹침 | 없음. question_002·back_004 탈락 | `marimba(659/587/523)`, env(5 ms, 18/s) → LP4k → `finish(150)` |
| **Potion** 교체 · 지금 FAIL | HP/MP 물약 개수가 줄 때(마심, 10 s 쿨). HP 1.0배, MP 1.12배(같은 파일) | 뽁! 보글보글↑ ('나아졌다') | ① 코르크 1400→500 Hz 25 ms + 3 ms 클릭 ② 거품 6~8개, 700→1800 Hz로 차례로 오름 ±8%. '회복 딩'은 삭제 | 350~450(지금 102) | 올라감. 0.5~2.9 kHz, 450 Hz 아래 없음 | 0.40 | 0~3 | 없음 | 꿀꺽(Devour 몫)·후루룩·트림, 유리잔 '짠'(지금 glass_003), 병원 삐, drop_002(처치) | drop_001 0.5배(거품, 참고). glass_002·impactGlass_light_003 탈락 | cork + bubbles×7 → `finish(150)` |
| **Purify** 교체 · 지금 WARN | 천사 쪽 선택(Good·돌려주기·나누기)을 고른 순간. 진영과 상관없이 고른 선택지를 따름. 명예 상승·PvP 명성으로는 울리지 않음 | 샤라라랑~ 반짝 (빛이 올라가 피어남) | ① 바람 차임: 유리 6~8번을 무작위 순서로 0.25 s(C장조 음) ② 오르는 공기 1.5→6 kHz ③ C-E-G 패드(±3 cent) @0.22 s ④ 반짝 4~8 kHz. 순서가 다른 판 2개를 돌려 씀 | 850~1000(지금 1.13 s) | 위로. 1.05~2.6 kHz + 공기 | 0.55. Devour와 K가중 1 LU·폰 2 LU 안(지금 2.9/8.1 LU 차이) | ≤0.3 | 선택의 천사 반쪽 | 8음 계단 글리산도(하프 '천국'), 합창·오르간·교회 종, 4음 팡파르, E장조(C장조 보상과 부딪힘) | impactGlass_light_002 0.944배(여러 높이로), glass_001 1.0595배(맨 위 울림) | 무작위 순서 `bell(1047…2093,.5,6)` + 공기 + 패드 + `sparkle(.6,16,4k–8k,.18)` → `finish(150)` |
| **Devour** 교체 · 지금 FAIL | 악마 쪽 선택(Evil·갖기·다 갖기)을 고른 순간. 고른 선택지를 따름. 악명·PvP·원한 자루로는 울리지 않음 | 앙! 꿀-꺽 뿅! 타닥 (냠, 장난스럽게 기분 좋음) | ① '앙' 아작 알갱이 4개 1.5~5 kHz + 900 Hz 톡 ② '꿀-꺽' 두 번: 720→480 Hz와 600→400 Hz, 각 60 ms, 70 ms 간격 ③ '뿅' 900→1800 Hz 90 ms ④ 불티 4~5알로 끝(뿔 서명) | 550~700 | 내려갔다가 끝에 위로. 300 Hz 아래 없음 | 0.55, Purify와 같게 | ≤0.3 | 선택의 악마 반쪽. 매번 똑같이(Speed 1.0, 한 판) | 트림·방귀·후루룩·이빨 씹기, 악마 웃음, 0.3 s 한 번 미끄럼 + 11 Hz 흔들림, 내려가며 끝남, 지금 bong_001(폰 −20 dB), 무작위 음높이 | impactWood_light_000(끝 '토독' 대안). minimize_006·bong_001·impactGeneric 탈락 | crunch + glk①@0.08 + glk②@0.15 + pop@0.26 + crackle 5알 0.38~0.6 s → `finish(150)` |

### 1-3. UI

| 키 · 결정 | 언제 | 아이가 기대하는 소리 | 층 | 길이 ms | 높낮이/쓸림 | 크기 등급 | 1분에 | 진영 차이 | 피할 것 | Kenney 후보 | 합성 방법 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Tap** 유지(select_002) + 클릭층 · 지금 WARN | 모든 UIKit 버튼. Fx 'Click'를 `Audio.Play('Tap')`로 바꿔 풀·속도가 듣게 함. 스킬 준비 알림은 SkillReady로 분리 | 톡 (말랑한 버튼) | select_002 몸통(609→468 Hz) + click_003 −10 dB | 30~45 | 살짝 내려감. 중심 1.2~1.8 kHz, HP 300 | UI 0.42~0.50(짧아서 측정이 4~5 dB 작게 나옴, 귀로 맞춤) | 메뉴 5~40 | 없음 | 키보드 딸깍만, 2 kHz 위 삐, 오르는 음(열림 뜻), 60 ms 넘는 꼬리, TalkBlip과 같은 소리 | select_002, click_003. tick_002·toggle_004 탈락 | 명세 합성은 TalkBlip과 너무 비슷해서 안 씀. Speed 0.97~1.03 |
| **WindowOpen** 유지(maximize_009) · 지금 PASS | 가방·캐릭터·상점·퀘스트·지도·목록 창이 열림(Tap 16 ms 뒤) | 뾰롱↑ (카드가 올라옴) | 둥근 음이 1078→1734 Hz로 오름 | 180~230(222) | 위로. 300 Hz~3 kHz | UI 0.45 | 2~10 | 베타 뒤: 빛 4~6 kHz 반짝 / 뿔 불티 −22 dB(모양은 그대로) | open_001~004(쉿), 끝에 커지는 maximize_001/002/004/005, 낮은 maximize_006/008 | maximize_009 | 필요 없음 |
| **WindowClose** 교체 · 지금 FAIL | 창이 닫힘(X·Esc·바깥 누름) | 쏙↓ (카드가 주머니로) | minimize_009(1734→1078 Hz)의 포락선을 펴서 4 ms 시작 + 감쇠 ≈16/s, 170 ms로 자름 = WindowOpen의 거울 | 140~180 | 아래로. 처음이 가장 큼 | UI 0.42 | 2~10 | WindowOpen과 같음 | 지금 파일(거꾸로 부풀어 176 ms에 최고 → 창이 사라진 뒤에 들림), minimize_006/007, close_* 쉿, question_002 | minimize_009(다시 다듬은 것, 검사 PASS). minimize_001 0.55배(대안) | 거울 합성 1550→1000 Hz, 공격 4 ms |
| **Deny** 교체 · 지금 FAIL | **내가 누른 것이 거절될 때만**(MP 부족, NeedFaction 같은 'bad' 거절). 당하는 일·강화 하락·자동 꺼짐에는 울리지 않음. 4 s 안에 3번 넘으면 0.6배 | 응-응 (장난감이 고개를 저음 '아직!') | 코맹맹이 고무 음 두 개: 펄스 30%를 1 kHz 대역 필터 40%와 섞고 LP 2.5k. 622 Hz 75 ms → 쉼 30 ms → 523 Hz 120 ms, 끝이 살짝 처짐 | 200~250 | 단3도 두 계단 아래로. 500~650 Hz + 1~2.5 kHz, HP 300 | UI 0.45 | 0~6 | 없음 | 부저·퀴즈 오답·사이렌, 슬픈 트롬본, error_002/004/005/006/007/008, 맑은 음(question_004 1.4배는 RankDown과 비슷), ScrollFail·AutoOff와 같이 울림 | 없음(합성) | `note(f,d)=(pulse30%(f·1→0.97)→bp1k 40%)·env(4ms,12/s)→LP2.5k`. 622@0 + 523@0.105 → HP300 |
| **AutoOn** 교체 · 지금 WARN | 자동 전투 켬(버튼·키, 서버 확인 뒤) | 딸깍-위잉↑-삐! (도우미 켜짐) | ① 걸쇠(switch_002, AutoOff와 같음) ② 모터 오름: 대역 잡음 또는 LP 톱니파 520→1400 Hz 90 ms −6 dB ③ 삐: 사인/삼각 1568 Hz 70 ms | 220~270 | 위로, 밝게 끝. 중심 1.8~2.8 kHz | UI 0.50 | 0~4 | 없음 | 펄스파·칩튠(사용자가 칩 LevelUp_b를 거절함), 종·C-E-G(보상), 유리, 지금 파일(Off와 같은 음색), 300 ms 초과 | switch_002, toggle_002(대안 핵심) | latch + `saw→LP3k glide 520→1400` + `tri(1568)` → HP300 |
| **AutoOff** 교체 · 지금 WARN | 자동 전투 끔(버튼·키·서버 강제). 서버가 끌 때는 Deny 안 울림 | 딸깍-위웅↓-똑 (차분, 실패 아님) | ① 같은 걸쇠 ② 모터 내림 1300→420 Hz, LP 3000→900 Hz로 닫힘 ③ 나무 '똑' 523 Hz 40 ms | 170~210 | 아래로, 어둡게 끝. 중심 0.9~1.2 kHz(On과 0.5옥타브 이상 차이) | UI 0.45 | 0~4 | 없음 | 슬픈 하강, 부저, WindowClose 모양, 울리는 꼬리(지금 89 ms), 400 Hz 아래 | switch_002, toggle_001(거꾸로), back_004(끝 '똑', 이 소리 전용) | latch + motor down + `(osc523 + .2·osc1569)·env(2ms,55/s)` → HP300 |
| **TalkBlip** 교체(짧게) · 지금 WARN | 대사 타자기. 2글자마다 → **3글자마다**로 권장. 말하는 사람마다 속도(뿔 0.78 ~ 조각 1.45). BarkPop도 이 파일을 씀 | 삐비비빅 / 뽀뽀뽀 | 삼각파 한 번 620→595 Hz, 2 ms 시작 | 30~35(지금 47이라 0.78배에서 60 ms로 뭉개짐) | 평평. 470~870 Hz, LP 3k, HP 300 | 조용 0.25(Tap보다 3 LU 이상 작게) | 줄을 칠 때 700~1200 | 사람마다 음높이. 선택: TalkBlipHorns(부드러운 펄스, LP 2.2k) | Tap과 같은 소리, 타자기 '탁', 모음 말소리·TTS, 유명 게임 동물 말, 1반음 넘는 무작위, 잔향 | pluck_001 0.5배(35 ms로 잘라, 대안) | `tri(620→595)·env(2ms,95/s)` → LP3k → HP300. 음높이는 {0,+2,+4}반음 중 하나 |

### 1-4. 세계(할로윈·거위·전쟁·괴수)

| 키 · 결정 | 언제 | 아이가 기대하는 소리 | 층 | 길이 ms | 높낮이/쓸림 | 크기 등급 | 1분에 | 진영 차이 | 피할 것 | Kenney 후보 | 합성 방법 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **PumpkinKing** 새 파일 KingPumpkin · P0 · 지금 FAIL(KingBell) | 호박 왕 등장(PumpkinKingActive), 20분마다, 서버 전원. 큰 순간 줄에 넣음(한 번에 하나, 다음 것은 2 s까지 기다림) | 딸랑딸랑~ 뻥! 사르르르 (웃긴 손님 왔다!) | ① 왕 종 두 번 @0·150 ms(두 왕이 같음) ② @330 ms 속 빈 '뻥' = 나무 몸통 + 합성 445 Hz '톡' ③ 사탕 딸깍 30~40알(6→3 kHz) + @620 ms 사탕 반짝 | 1200~1400 | 쓸림 없음. 종 600~700 Hz, 사탕 2.5~6 kHz, 폰 손실 3 dB 이하 | 큰 순간 0.70, 전투 낮춤 1.6 s, Speed 1.0 고정 | 0.05 | 없음 | 교회·장례 종 하나(지금 KingBell), 중간 빈 구멍(지금 156 ms), 두 왕이 같은 파일, 시계탑 차임, 오르간 토카타, 악당 웃음, 단조, 천둥·늑대, 0.85배 밑 | impactBell_heavy_003 2.0배(왕 종), impactWood_medium_002 1.3배 k2.5 HP150, impactGlass_light_003 2.4배 25 ms(사탕). glass_002·impactGeneric 탈락 | 명세 mix에서 톡은 합성으로, 반짝은 impactGlass_light_003으로 → `finish(150)` |
| **GhostKing** 새 파일 KingGhost · P0 · 지금 FAIL | 유령 왕 등장(호박 왕 10분 뒤, 20분마다). 유령 왕을 때리면 HitSoft 1.15배 | 딸랑딸랑~ 후우? 찰랑 (장난치는 유령 '부?') | ① 같은 왕 종 두 번 ② @300 ms '후우': 숨 50% + 음 50%, 'oo' 필터(BP ≈700 Hz, LP 2 kHz), 620→740 Hz(3반음 이내로 오름, 질문 모양), ±15 cent ③ @650 ms 유리 1 kHz + 반짝 | 1300~1500 | 위로만. 400 Hz 아래 없음 | 큰 순간 0.70, 1.6 s 낮춤, Speed 1.0 | 0.05 | 없음 | 사인 70% 슬라이드 휘파람(거절된 마법 소리와 같은 문제), 내려가는 신음, 40 cent 넘는 떨림·테레민, 0.3 s 넘는 잔향, 속삭임·쇠사슬 | impactBell_heavy_003 2.0배, impactGlass_medium_001 | whoo = `.5·(sine+tri) + .5·svf(noise,700,bp)` → LP2k, 공격 60 ms. 종 + whoo@0.30 + 유리@0.65 + sparkle@0.70 |
| **GooseArrive** 새 키 · P0 | 황금 거위 착지(GooseActive, 10분마다). Duck.By에 추가 | 꽥꽥! 푸드덕 반짝 ('잡아 봐!') | 날갯짓 3번(1.8→0.9 kHz 잡음) + 꽥 두 번(GooseHonk와 같은 목소리, 둘째는 3반음 위) + 금 반짝 3~7 kHz | 900~1100 | 꽥이 위로. 400 Hz 아래 없음 | 큰 순간 0.65, 1.2 s 낮춤 | 0.1 | 없음 | 진짜 거위 녹음·유명 거위 게임, error_004 부저, 내려가는 두 음(Deny 모양), 총소리 같은 날갯짓 | footstep_grass_001 1.6배 HP400(날갯짓), glass_002(금 반짝) | flap×3 + `honk_toy(560)`@0.25 + `honk_toy(665)`@0.47 + sparkle → `finish(150)` |
| **GooseHonk** 교체 · P0 · 지금 FAIL | 내 공격(또는 40 studs 안 다른 사람 공격)이 거위에 맞음. 60 s 동안만, Gap 3 s | 꽉! (고무 거위 한 번) | 꽥 **하나**: 15~25 ms 고무 '삑'이 올라감 + 코맹맹이 몸통 110~140 ms(포먼트 1.0/1.8/2.8 kHz) + 숨 10% | 140~180(지금 356, 두 번) | 올랐다가 살짝 내려감. 540~680 Hz, 450 Hz 아래 없음 | 0.40(지금 0.55), 자동 0.5·남 0.35배 | ≤20(60 s 동안만) | 없음 | 두 번 꽥·내려가는 끝(Deny와 비슷), 포먼트 없는 톱니 부저, 450 Hz 아래(방귀 농담), 잔향 | 없음(합성) | `honk_toy(600,.16)` → `finish(150)` |
| **CrownHalo** 새 키 · P1 | 전쟁 한 판 끝(600 s마다)에 빛이 왕관을 가져감, 금빛 새벽. 모두 같은 파일, 비김·Idle이면 없음. 전쟁 상자 보상은 1.5 s 미룸 | 샤라라라~ 치잉! ('빛이 왕관을!') | ① 0~700 ms 차오름: 반짝 10→60/s + 공기 1.5→5 kHz ② @700 ms A장조 블록 화음 A5-C#6-E6 유리 타격 ③ 반짝 꼬리 0.8 s(합성) | 1500~1700 | 차올라 한 번 침. 800 Hz~7 kHz | 큰 순간 0.70, 1.6 s 낮춤. CrownHorns와 K가중·폰 2 dB 안 | ≤0.1 | 빛 반쪽 | 합창·오르간·교회 종·하프, LevelUp C-E-G-C·Purify와 비슷함, 승리 팡파르, 진 쪽 놀리기 | impactGlass_medium_000 **0.989배**(화음에 맞춤), impactGlass_light_000. glass_004·glass_001 탈락 | swell + `bell(880/1108.7/1318.5)` + KL@0.70 + `sparkle(.8)` → `finish(150)` |
| **CrownHorns** 새 키 · P1 | 뿔이 왕관을 가져감, 붉은 일식 | 화르륵~ 둥! 타닥 토독 ('뿔이 가져갔다! 히히') | ① 0~600 ms 불이 확 300→2500 Hz + 불티 15→70/s ② @600 ms 450~1000 Hz 나무 북(impactWood_medium_002 1.6~2배, 포화) + 불티 터짐 ③ 꼬리 불티 + '토-독' | 1400~1600 | 불이 위로, 치는 소리 450~1000 Hz, 250 Hz 아래 없음 | 큰 순간 0.70. CrownHalo와 맞춤, 폰 손실 2 dB 이하 | ≤0.1 | 뿔 반쪽 | bong_001(폰 −19.6 dB), 300 Hz 아래 나무 몸통, 악당 웃음·천둥·폭발·메탈 기타, 단조 '둠', 길고 낮은 '봉' + 잡음 | impactWood_medium_002, impactWood_light_000(토독), footstep_snow_000(HP 200일 때만) | flare + snow(HP200) + 나무 북 + crackle + `KL(impactWood_light_000,1.6/1.35)` → `finish(150)` |
| **KingDefeat** 유지 · P1 | 왕을 쓰러뜨림. 기여자는 KillPop·동전 0.25 s 뒤. 그냥 떠나면 소리 없음 | 와르르르~ 짜잔! (피냐타에서 사탕 비) | ① '딱' 깨짐(합성 톡 + 40 ms 종이 찢김) ② 사탕 40~60개가 2~3번씩 튐 2~6 kHz ③ @350 ms confirmation_002 | 1000~1200 | 쓸림 없음 | 기여자 0.65(1.2 s 낮춤), 나머지 0.45 | ≤0.1 | 없음 | 폭발, 유리 깨짐, 함성·목소리, 슬롯, 동전 소나기(사탕 ≠ 금), 1.2 s 넘는 반짝 | confirmation_002(이 소리 전용), impactGlass_light_003 2.0~2.6배(사탕), click_002. impactGeneric_light_004 탈락 | crack(합성) + rain + `KL(confirmation_002)`@0.35 → `finish(150)` |
| **WarFinal30** 새 키 · P1 | 전쟁 한 판 끝 30 s 전, 판마다 1번(진영 있음, 들어온 지 30 s 넘음) | 따르릉! (자전거 벨 '서둘러!') | 합성 자전거 벨: ≈3.2 kHz 금속 + 1 kHz 몸통. 정체성은 공이 떨림(150 ms 동안 초당 ≈18번 다시 침). @0·250 ms 두 번 | 400~550 | 쓸림 없음. 800 Hz 아래 없음 | UI 0.50 | 0.1 | 없음 | 동전 샘플(돈으로 들림), 알람시계·사이렌·째깍·폭탄 타이머, 가는 '팅' 하나, '탁탁' 대안(CountTick과 겹침) | 없음(합성) | `ring = bell(3200)+bell(3215)+.4·bell(1040)`을 55 ms 간격으로 3번. ring@0 ×.8, ring@0.25 ×1 → `finish(150)` |
| **CountTick** 새 키 · P2 | 공개 3 s 전 3-2-1(전쟁 끝, 거위 끝은 때린 사람만, 괴수 경보). 1.0→1.12→1.26배 | 똑, 똑, 똑! (나무 목탁) | 합성 목탁 ≈1.6 kHz + 2.76배 배음, 2~3 ms 클릭 | 70~100 | 한 번은 평평, 세 번이 계단으로 위로. 600 Hz 아래 없음 | 0.40, 커지지 않음 | 평균 0.3~0.6(3번 묶음) | 없음 | impactGeneric_light_*(싸울 때 타격처럼 들림), 전자 삐, 째깍째깍, 10·30초 세기, tick_004, select_002 | 없음(합성) | `bell(1600,.09,30,((1,1),(2.76,.3)))` + 클릭 3 kHz → `finish(150)` |
| **GooseEnd** 새 키 · P2 | 거위 60 s 끝(Fx GooseEnd), 카메라 가까이일 때만. 보상은 QuestDone이 아니라 **GoldPickup**(Rare면 동전 + 반짝). 큰 순간 줄 | 푸드득~ 꽥! 팔랑팔랑 | 날갯짓 4~5번 멀어짐 + 꽥 한 번(+2반음, 기쁨) + 깃털 휙 3~4번 1.5~4 kHz | 900~1100 | 400 Hz 아래 없음 | 0.50, 낮춤 없음 | 0.1 | 기본은 한 파일. 선택: 빛 '풀어줌'(꽥이 오름 + glass_006) / 뿔 '자루 속'(베개 '푹' + 토독) | 진 쪽 슬픈 '와와', 아파하는 꽥·버둥, 진짜 새 녹음 | footstep_grass_001(날갯짓), footstep_carpet_001(뿔 '푹') | flap×5(1.0→0.4) + `honk_toy(600,+2st)`@0.15 + drift×4 → `finish(150)` |
| **KaijuSiren** 새 키 · P2 | KaijuPhase 'Siren' 10 s 경보(뿔 5별 플레이어가 괴수로). 뒤이어 CountTick, 'Active'에 첫 KaijuStomp | 우르르릉~ 쿵! 쿵! ('뭔가 큰 게 온다!' 신나게) | ① 0~900 ms 굴러오는 우르릉 300~700 Hz + 14 Hz 떨림, −24→−6 dB ② @950·1300 ms 발 쿵 두 번(KaijuStomp + 고무 '뿌웅') ③ 불티 6~10알 | 1700~1900 | 크기만 커지고 음높이는 그대로. 150 Hz 아래 없음 | 큰 순간 0.70, 1.6 s 낮춤 | 드묾 | 같음 | 공습·경찰 사이렌, 파티 게임 '비상 회의' 알람, 포효·비명·심장·천둥·폭발, 100 Hz 아래 지진 저음, '둥둥둥' 밈 | impactWood_medium_002(k3 HP150), footstep_snow_000(HP200), impactPunch_medium_002 1.4배 k3 HP200 | rumble + stomp×2 + crackle → `finish(150)` |
| **KaijuStomp** 새 키 · P2 | 괴수 120 s 동안 4 s마다(Fx Stomp). 60 studs 안에서만(15 studs 안 1.0 → 60에서 0) | 쿵! 뿌웅 (커다란 고무 장화) | 나무 몸통 250~600 Hz(포화) + 먼지 퍽 400~2000 Hz 150 ms + **고무 '뿌웅' 사인 900→600 Hz 40 ms −12 dB**(폰용, impactGeneric 대신) | 300~400 | 몸통이 5% 내려감. 150 Hz 아래 없음 | 0.45. Max 1·Gap 1.0, Speed 0.92~1.05 | 15(가까이서만) | 없음 | 폭발, 저음만 있는 쿵(impactSoft_*: 폰에서 안 들림), 금속 쾅, 0.5 s 넘는 꼬리 | impactWood_medium_002, footstep_snow_000(HP200), footstep_concrete_003 | wood + snow + squonk + dust → `finish(150)` |
| **ZoneEnterPvP** 새 키 · P2 | ZonePvP false→true(다른 팀이 공격하고 주머니를 뺏을 수 있는 곳). 스폰·순간이동 후 3 s는 제외, Gap 10 s, 나갈 때는 없음 | 두둥! ('조심, 여기선 다른 팀도 놀아!') | 합성 음정 톰 두 번: 400 Hz → 530 Hz(+130 ms) + 북 가죽 잡음 클릭 | 350~450 | 두 계단 위로. 250 Hz 아래 없음, 폰 손실 3 dB 이하 | UI 0.45 | 0.1~0.5 | 없음 | impactWood_light_000(폰 −7.7 dB, 뿔 '토독' 뜻), 전쟁 북·행진 스네어, 사이렌, 칼 '쉥', 무서운 저음 | 없음(합성) | `tom(f)=sine(f·1.05→1)+.4·sine(1.5f)`, env(3ms,18/s) + 클릭(BP 2.5k). tom(400)@0 + tom(530)@0.13 → `finish(150)` |
| **GoldenSpot** 새 키 · P2 | 황금 몬스터(4%)가 처음 50 studs 안·화면 안에 들어옴. 몬스터마다 1번, 10 s에 1번 | 반짝반짝~ ('황금이다!') | 계단 없는 반짝 알갱이 2.5~5 kHz 300 ms + @280 ms glass_002 '핑' | 400~500 | 살짝 위로(계단 없이). 1.5 kHz 아래 없음 | 0.40 | 0.1~0.5 | 없음(금 = 보물) | 6.6 kHz까지 오르는 계단 알갱이, '카칭', 배관공 동전, ComboCoin·GoldPickup 재사용, 0.5 s 초과 | glass_002 | `sparkle(.3,8,2.5k–5k)` + `KL(glass_002)`@0.28 → `finish(150)` |
| **BarkPop** 재사용(업로드 0) | 몬스터 말풍선(BarkAt), 35 studs 안·화면 안. 거위는 제외 | 블룹? (꼭두각시 두 음절) | TalkBlip 두 번, 70 ms 간격. 종류별 속도(슬라임 1.35→1.5, 고블린 0.95→0.9, 해골 1.15×2, 유령 0.85→0.95, 호박 0.9→1.0, 왕 ×0.9), 0.8 밑으로는 안 내림 | ≈120 | 종류마다 다름 | 0.15(가장 조용) | 2~10 | 없음 | TTS·목소리, 으르렁, 글자마다 삐, 타격보다 큼 | TalkBlip 재사용 | 없음 |
| **ShardLean** 재사용(업로드 0) | 점수 0인 이야기 선택 'shard leaned to the light/dark' | 찰랑 / 꿀꺽 (작은 메아리) | Purify 또는 Devour를 1.12배·0.40으로 | 새 파일 기준 Purify ≈850 / Devour ≈550 | 원본과 같음 | 0.40 | 드묾 | 고른 쪽을 따름 | 에러·Deny 톤(틀린 쪽은 없음) | 재사용 | 없음(새 Devour가 폰 3 dB 이하면 지금 WARN도 사라짐) |
| **JackpotOther** 선택 · P3 | 다른 사람의 Jackpot·FirstMax 알림(RareWeapon은 제외), 30 s에 1번 | 오오~ 반짝! | 30 ms 색종이 팡(대역 잡음 2 kHz) + 오르는 유리 '삥' 2.2~2.9 kHz + 반짝 300 ms | 500~650 | 위로. 1~7 kHz | 0.40 | <0.2 | 없음 | 슬롯·카지노, 동전 소나기, '잭팟' 목소리, 내 LevelUp만큼 큼 | maximize_007. drop_001·glass_001 탈락 | 명세 mix → `finish(150)` |

## 2. 쌍 구별 규칙

### 2-1. 켬/끔, 열림/닫힘

| 짝 | 같게 둘 것 | 다르게 들릴 것 | 검사 기준 |
|---|---|---|---|
| AutoOn / AutoOff | 같은 걸쇠 딸깍, 같은 모터 음색 | On은 위로 가서 밝은 '삐'(중심 1.8~2.8 kHz), Off는 아래로 가서 어두운 '똑'(0.9~1.2 kHz). Off가 더 짧음 | 밝기 차이 ≥0.5옥타브, 모양 차이 ≥0.3(지금 0.10 → 실패) |
| WindowOpen / WindowClose | 같은 음색(maximize_009와 그 거울) | 열림은 위로 부풀어 25~40 ms에 최고, 닫힘은 아래로 가며 처음이 가장 큼 | 모양 차이 ≥0.25옥타브. 닫힘 공격 ≤8 ms |
| AutoOff / Deny | — | 끄는 것은 '거절'이 아님. Off는 걸쇠 + 미끄럼 + 똑, Deny는 고무 음 두 개 | 점수 ≥1.0 |

### 2-2. 성공/실패, 예/아니오

| 짝 | 다르게 들릴 것 | 검사 기준 |
|---|---|---|
| ScrollSuccess / ScrollFail | 성공은 번쩍 + 링 + 반짝으로 위로, 600~800 ms. 실패는 '푸' + '퐁'으로 아래, 250~350 ms, 둥근 C로 끝나서 슬프지 않음. 같은 순간에 Deny·QuestDone 없음 | 성공이 4.8 LU 이상 큼(지금 +7.1 통과) |
| Deny / RankDown | Deny는 코맹맹이 고무 음 두 개(단3도 아래). RankDown은 나무 마림바 세 계단(E-D-C)이고 더 조용함 | 음높이 차이 ≥0.3옥타브 또는 음색 차이 ≥10 dB(명세 합성은 실패 → 이번에 바꿈) |
| Deny / GooseHonk | 꽥은 한 음이 위로 꺾임. Deny는 두 음이 아래로 | 점수 ≥1.0 |
| QuestNew / QuestDone | New는 종이 펄럭 + 열린 5도(끝나지 않은 느낌). Done은 세 음이 C로 닫힘 | Done이 New보다 1.5 LU 이상 큼(지금 −1.3 → 실패) |

### 2-3. 얻음/잃음

| 짝 | 규칙 |
|---|---|
| GoldPickup / Spend / Plunder | 셋 다 같은 돈 샘플(impactMetal_light_*)이고, 방향이 뜻입니다. 얻으면 동전이 위로 올라가고(D7→E7→G7), 쓰면 두 개가 아래로(E7→D7, 조용히), 뺏기면 동전이 흩어지며 멀어집니다(아래로, 점점 작게). |
| RankUp / RankDown | 같은 마림바로 거울처럼: C5-D5-E5 / E5-D5-C5. 둘 다 조용하게. |
| Purify / Devour | 둘 다 '좋은' 소리여야 하고 둘 다 끝은 위로 갑니다. 크기는 같게(게임 안 ≤1 LU, 폰 ≤2 LU; 지금 2.9/8.1). Purify는 판 2개를 돌려 쓰고 Devour는 늘 같습니다. |
| KillPop / Potion | 처치는 짧은 음정 '뽕' 하나(0.7~1.0 kHz). 물약은 코르크 + 오르는 거품. |
| HitHeavy / HurtBig | '내가 때림'은 퍽 순간음, '내가 맞음'은 뭉근한 범프 + 내려가는 짹. 같은 파일을 쓰지 않습니다(지금은 HurtBig=HitHeavy2라 실패). |

### 2-4. 진영 짝과 서명

- **짝:** SwingMageHalo/Horns, SkillHalo/Horns, CrownHalo/Horns, Purify/Devour. 크기는 K가중으로 같게, 폰 차이는 2 LU 이하.
- **빛 서명:** 올라가는 공기 + 유리 반짝(계단 없음).
- **뿔 서명:** 불 잡음 + 불티 + 나무 '토-독'. 뿔 소리는 모두 토독이나 불티로 끝납니다.

### 2-5. 헷갈리기 쉬운 짝

| 짝 | 구별법 |
|---|---|
| SwingWarrior / SwingArrow | 넓고 부푸는 휙 한 번 vs 좁고 빠른 휙(두 발이면 사이가 조용함) |
| SwingMageHalo / SwingTamer | 마법에는 음정 미끄럼을 넣지 않음. 휘파람만 사인 두 음 |
| QuestNew / SwingTamer | 마림바 C6→G6 + 종이 vs 휘파람 1.5~2.5 kHz 미끄럼 |
| QuestDone / LevelUp | QuestDone이 한 옥타브 위(검사기 ≥0.8옥타브, 지금 0.62) |
| Tap / TalkBlip | Tap이 타악기 쪽이고 3 LU 이상 큼. 같은 파일 금지 |
| PumpkinKing / GhostKing | 종 두 번은 같고 가운데가 다름(뻥 + 사탕 vs 후우 + 유리). 폰 볼륨으로 0.5 s 안에 구별돼야 함 |
| CountTick / HitHeavy | 목탁 1.6 kHz 합성. 타격 톡 샘플 금지 |
| WarFinal30 / 동전 | 떨림 벨 합성. 돈 샘플 금지 |
| SkillHalo / ComboCoin | 2.3~2.7 kHz 종은 동전만 씀 |
| HitCrit / ScrollSuccess | 오르는 2~7 kHz 번쩍은 강화 성공만 씀 |
| SkillHorns·Devour / KillPop | 0.7~1.0 kHz 음정 '뽕'은 처치만 씀 |

### 2-6. 소리 자리(높이)와 샘플의 뜻

| 자리 | 주인 |
|---|---|
| 150~500 Hz 몸통 | 타격(HitSoft·HitHeavy) |
| 0.7~1.0 kHz 음정 '뽕' | KillPop |
| 2.3~2.7 kHz 금속 울림(1.0배) | 동전(ComboCoin·GoldPickup·Spend·Plunder) |
| 계단 아르페지오 | LevelUp 0.5~1 kHz · QuestDone 1.3~2.1 kHz · ComboMilestone 2~5 kHz만 |

| 샘플 | 뜻(쓰는 곳) | 이제 쓰지 않는 곳 |
|---|---|---|
| impactGeneric_light_* | 타격(HitHeavy) | CountTick, KingDefeat, Devour, PumpkinKing, KaijuStomp, ZoneEnterPvP |
| impactMetal_light_000/001/003/004 | 돈 | WarFinal30, ScrollSuccess |
| confirmation_002 | KingDefeat | LevelUp, ScrollSuccess, ComboMilestone |
| question_002 | 아무도 안 씀 | RankDown, WindowClose, Deny |
| drop_002 / drop_003 | 처치 '뽕'(drop_003은 예비) | SkillHorns, ScrollFail, HitSoft B+, SwingMageHorns, TalkBlip |
| glass_002 | 금 반짝(GooseArrive, GoldenSpot, 거위 Rare) | PumpkinKing 사탕, Potion |
| glass_004 | ScrollSuccess | CrownHalo, GoldenSpot, ComboMilestone, LevelUp |
| glass_005 | SkillHalo 틱 | Purify |
| impactGlass_light_003 | 사탕(PumpkinKing, KingDefeat) | Potion |
| impactBell_heavy_003 | 왕 종(두 왕) | LevelUp |
| impactWood_light_000 | 뿔 '토-독'(SkillHorns, CrownHorns, Devour, GooseEnd 뿔판) | ZoneEnterPvP |
| footstep_grass_001 | 거위 날갯짓 | — |
| switch_002 | 자동 전투 걸쇠 | — |

## 3. 자동 검사

**도구**
- `tools/sfx_check.py`와 `tools/sfx_spec.json`(51키 = 명세 47개 + SwingArrow, HurtBig, RankUp, SkillReady; 짝 규칙 55개).
- 이 설계서와 JSON이 다르면 JSON을 이 설계서에 맞춥니다(개발 2). 예: HitCrit을 층으로 바꾼 것, Devour 길이, RankDown 마림바.
- 실행:
  - 지금 게임 소리: `py tools/sfx_check.py art/sfx --out build/sfx_check/current`
  - 후보: `py tools/sfx_check.py build/sfx_game/cand --out build/sfx_check/cand`
- 파일 이름은 `키[_변형].wav/ogg`로 읽습니다. 별칭도 알아봅니다(KingBell → 두 왕, SwingMage → 두 마법사).
- 필요한 것: numpy·scipy·PIL, ogg는 ffmpeg. 32개를 검사하는 데 약 17초.
- 출력: 키마다 PNG(파형·dB 포락선·스펙트로그램·스펙트럼·통과 표시), `pairs.png`, `summary.json`/`summary.txt`.

**판정**
- **FAIL:** 꼭 지킬 한계를 넘음. 듣지 않고 버립니다.
- **WARN:** 이 점을 알고 듣습니다.
- **PASS:** 먼저 들어 볼 후보입니다.
- 크기는 FAIL로 치지 않습니다. 대신 `gainToTargetDb`에 몇 dB를 고치면 되는지 적습니다.

**재는 것**
- 길이·앞 무음·차오름·최고점 시각, 잘림.
- K가중 크기 + Volume, 폰 손실, 150 Hz 아래·8 kHz 위 비율.
- 밝기 흐름, 음높이 흐름·가장 낮은 음, 잡음/음정 비율, 같은 음으로 오래 울리는 길이('팅'), 2~5 kHz 날카로운 봉우리.
- 터지는 횟수·간격·사이의 조용함, 중간 빈 구멍.
- 게임 속도로 다시 재기(동전 1.6배, 대화 0.78배, 맨손 1.3배), 좋아한 B와 바이트까지 같은지(sha256).

**기준이 맞는지 확인한 결과**
- 사용자가 거절한 13개(SwingBow a·b·c, SwingMagic a·c, HitThud a·b·c, HitCrit a·b·c, Coin_a)는 **모두 FAIL**입니다.
- 사용자가 좋아한 B:
  - 휘파람 B는 PASS.
  - 말랑 B는 WARN. 150 Hz 아래가 51%이고 폰에서 −5.5 dB라서 실제 폰으로 들어 봐야 합니다.
- 고친 레시피로 만든 시제품:
  - 궁수 PASS(3.83 kHz, 두 화살 사이가 완전히 조용함).
  - 동전·Deny·RankDown·GoldPickup·WindowClose도 PASS.
  - 원래 궁수 명세는 WARN(4.70 kHz, 간격 47 ms, 사이 17 dB만 조용함).
  - 빛 마법사 고친 레시피는 8 kHz 위가 5.8%라 WARN → 7.5 kHz LP를 넣습니다.

**지금 게임 32개: PASS 2 · WARN 11 · FAIL 19**

| 판정 | 소리 |
|---|---|
| PASS | KillPop, WindowOpen |
| WARN | HitSoft1·2(B 아님, 폰 −3.6~3.9 dB) · SwingWarrior(맨손 1.3배에서 5.1 kHz, 8 kHz 위 15%) · TalkBlip(0.78배에서 60 ms로 뭉개짐) · Tap(짧아서 4~5 dB 작게 잼) · ComboMilestone(끝음 5.9 kHz, x100에서 7.0) · AutoOn · AutoOff(울림 89 ms) · LevelUp(0.97 s) · Purify(1.13 s, 오르는 느낌 약함) · ScrollSuccess(조금 어두움) |
| FAIL | SwingArcher(줄 울림 259 ms, 음정 0.65, 화살 1번, 294 ms) · SwingMage(빛 기준 1.78 kHz 사인 하나·휘파람과 같은 미끄럼, 뿔 기준 260 ms) · HitHeavy1·2(최고점 27~35 ms 늦음, 폰 −6.5~−8.2 dB) · ComboCoin(동전 1번, 495 ms) · SwingTamer(A라서 한 음) · GoldPickup(54 ms 틱) · Devour(223 ms, 206 Hz, 폰 −5.5) · QuestDone(391 Hz, 폰 −5.0) · QuestNew(205 ms) · RankDown(81 ms, 폰 −4.4) · ScrollFail(78 ms, 폰 −4.9) · SkillHalo(65 ms 핑) · SkillHorns(350 Hz, 폰 −8.3) · Potion(102 ms) · WindowClose(거꾸로 부풂, 176 ms에 최고) · Deny(폰 −3.75, 낮은 4도) · GooseHonk(두 번, 356 ms) · KingBell(156 ms 빈 구멍, 두 왕이 같은 파일) |

**짝 규칙: 42개 중 30개 통과.** 걸린 것:
- 빛·뿔 마법사가 같은 파일.
- HitHeavy2와 HurtBig이 같은 파일.
- 두 왕이 같은 파일.
- AutoOn과 AutoOff의 밝기 차이 0.10옥타브.
- Purify와 Devour 크기 차이 2.9/8.1 LU.
- SkillHalo와 SkillHorns의 폰 크기 차이 9.4 LU.
- QuestDone이 QuestNew보다 작음.
- QuestDone이 LevelUp보다 0.62옥타브만 높음.
- HitHeavy가 궁수보다 2 LU 이상 크지 않음.

**판정에 대한 메모**
- 이 판정은 기준표의 계획 Volume으로 계산했습니다(예: 궁수 0.25, 지금 게임은 0.28).
- 검사를 통과해도 승인은 아닙니다. 귀, 장면 렌더, 실제 폰까지 거쳐야 합니다.

## 4. 만드는 순서

### 4-1. 개발 2 — 소리 파일(만들기·고르기·업로드)

**키마다 거치는 단계**
1. 이 표의 행대로 후보 3개를 만듭니다: `build/sfx_game/cand/<키>_a|b|c.wav`. 레시피 변형이나 Kenney 조합.
2. `sfx_check.py`를 돌립니다. FAIL은 듣지 않고 다시 만듭니다.
3. 시트를 만듭니다: 키마다 PNG + 듣기판.
   - 전투 소리는 **장면 렌더**를 꼭 붙입니다(`sfx_game.py scene` 새로 만듦). 실제 Plan 타이밍(휘두름→타격→뽕→동전)과 Config Volume/Speed/Gap을 씁니다.
   - 장면: 궁수 120발/분, 전사가 슬라임 3마리를 쓸기, 마법사 빛·뿔, 폰판(400 Hz 4차 HP), 각 20~30 s.
4. 검수가 들어 보고 2개로 줄입니다. 다시 만들라고 몇 번이든 돌려보낼 수 있습니다.
5. 사용자 듣기판은 **검수를 통해서만** 보냅니다. 고른 파일은 바이트 그대로 두고 sha256을 기록합니다.
6. 업로드: wav로 Creator Hub에 한 번에 10개 이하. 라이선스 상자는 사용자 OK가 필요합니다(검수를 거쳐, AGENTS). `art/sfx/asset_ids.json`과 `sources.json`을 갱신합니다(크기 메모 −17 K가중/−3).

**묶음 순서**
- **0 (바로, 새로 만들 것 없음):** HitSquish_b → HitSoft1, SwingWhistle_b → SwingTamer. 파일을 복사하고 해시를 적은 뒤 업로드.
- **1 (사용자가 지적한 전투 소리):** SwingArrow, SwingMageHalo, SwingMageHorns, HitHeavy A/B/C, HitCrit A/B, ComboCoin. 장면 렌더로 판단합니다.
- **2 (깨졌거나 거꾸로인 것):** GoldPickup, QuestNew, QuestDone, WindowClose, Deny, RankDown, ScrollFail, SkillHalo, SkillHorns, Purify, Devour, Potion, AutoOn, AutoOff, TalkBlip. 빠진 소리 중 Equip, SkillReady, HurtBig도 여기서.
- **3 (할로윈 베타 주간, P0):** KingPumpkin, KingGhost, GooseArrive, GooseHonk.
- **4:**
  - P1: CrownHalo/Horns, KingDefeat, WarFinal30.
  - P2: CountTick, GooseEnd, KaijuSiren, KaijuStomp, ZoneEnterPvP, GoldenSpot.
  - 그 뒤: ScrollSuccess, Spend, RankUp, KO, Plunder.
  - P3: JackpotOther.

**개발 2의 서버 일**
- 선택지를 고를 때 Fx `Choice {Option='Good'/'Evil'}`를 보냄(StoryQuestService pickScore 등).
- Notify에 `Sound` 필드(아래 경로표).
- (선택) Reward 패킷에 ContactDelay를 넣음.
- (선택) HalloweenService FirstDelay +20 s.

### 4-2. 개발 1 — Audio.luau·Config.Audio(클라이언트)

~~Studio 동기화·Play는 검수의 '전달함, 시작'을 받은 뒤에 합니다.~~ → 메인 Studio 동기화·Play는 메인 반영 1이 합니다(개발 1은 코드만, 10/09 역할).

1. **지금 바로:** `Files.SwingArcher = ""`. 업로드되는 대로 HitSoft는 B 하나만(`Files={"HitSoft1"}`), SwingTamer는 B id로.
2. **처치 타이밍:** Reward 소리를 0.15 s까지 붙잡아 두었다가 내 다음 Swing/Release의 ContactDelay + 0.04 s에 냅니다. 한 번에 여러 마리면 KillPop 1번 + 동전 70 ms 물결(최대 4개). ComboCoin은 Max 4·Gap 0.05.
3. **마법사 진영 파일:** `Swing.Mage`를 시전자 진영에 따라 SwingMageHalo/Horns로 고릅니다. SkillCast도 같게. 가장 큰 지점이 발사 순간에 오게(At ≈ 0.20 s).
4. **SkillCast:** t=0이 아니라 LaunchDelay에 냅니다. 진영 층(SkillHalo/Horns)은 Q/Z/X 모두에.
5. **궁수:** SwingArrow 한 발, 대상이 2 이상이면 +0.068 s에 1.10배·0.85볼륨으로 한 번 더. Gap 0.05·Max 3. `Swing.PetDash='SwingTamer'`.
6. **hitEvent:**
   - HitCrit 키를 새로 만들어 재질 타격 위 층으로 냅니다(첫 대상 치명 + Gap 1.5 s·Max 1).
   - `HitHeavyAt=3` 삭제 → 같은 재질 ×1.25 볼륨·×0.95 속도.
   - 종류별 표: 유령 HitSoft 1.15배, Skeleton·SkeletonKnight는 나무 변형.
7. **다른 플레이어 풀 분리**(`event.."_O"`): 남의 소리가 내 소리를 막지 않게 합니다.
8. **MaxPlaying 우선순위:** 전투가 아닌 소리는 상한을 넘어도 내거나, 가장 오래된 전투 소리를 끊습니다.
9. **자동 전투 보상:** KillPop·ComboCoin·ComboMilestone에 Auto 표시를 주고 0.75배.
10. **큰 순간 줄:** 큰 소리는 한 번에 하나, 다음 것은 2 s까지 기다림.
    - Duck.By에 GooseArrive, CrownHalo/Horns, KaijuSiren 추가.
    - 왕 소리는 Duck.Seconds 1.6.
    - 두 왕 파일 분리(KingPumpkin/KingGhost), Speed {1,1}.
11. **겹침 규칙:**
    - QuestDone은 LevelUp ±0.4 s 안이면 생략.
    - QuestNew는 QuestDone 뒤 0.6 s 이상 띄움.
    - 강화 뒤 0.5 s는 Deny 끔. 자동 전투가 강제로 꺼질 때도 Deny 끔.
    - RankDown은 선택 소리가 끝나고 0.1 s 뒤.
    - 거위 끝·왕관 뒤의 보상 소리는 1.5 s 미룸.
12. **UI:**
    - Fx 'Click'을 `Audio.Play('Tap')`로(Speed 0.97~1.03).
    - SkillBar 쿨다운 끝 → SkillReady.
    - Deny가 4 s 안에 3번을 넘으면 0.6배.
    - TalkBlip은 BlipEvery 3, 음높이는 {0,+2,+4}반음.
    - PunchSpeed 1.15.
13. **Purify/Devour 계기:** 명예·악명이 바뀔 때가 아니라 Fx `Choice`를 받을 때. PvP 명성·원한 자루로는 울리지 않음.
14. **GoldPickup:** 'Upgrade'를 빼고 Equip으로. 택배는 0.6배. GooseHonk는 거위를 때렸을 때만, GooseArrive는 GooseActive가 될 때.

**Notify·Fx 소리 경로표**

| 일 | 소리 |
|---|---|
| 퀘스트·이야기·일일·게시판 완료 | QuestDone |
| 거위 보상(`GooseService:580`)·전쟁 상자·괴수 몫·PvP 현상금 | GoldPickup |
| NewTitle(`StoryQuestService:296`) | RankUp |
| 무기 구매·장착(Upgrade) | Equip |
| 물약 구매 | Spend |
| 강화 | ScrollSuccess / ScrollFail만(QuestDone·Deny 없음) |
| 거절된 내 입력('bad' 거절) | Deny |
| 약탈당함·자루 잃음·PvP 진입 등 당하는 일 | 각자 소리(5번) 또는 없음, Deny 아님 |

## 5. 빠진 소리 제안(우선순위)

| 순위 | 키 | 언제 | 소리 | 업로드 |
|---|---|---|---|---|
| P0 | **Equip** | 무기를 사거나 장착(첫 퀘스트 150 gold 직후 나무 무기) | 톱니 '착' + 작은 반짝(합성), 250~300 ms, 0.45 | 1 |
| P0 | **Loot**(내 드롭) | 처음 10분 안에 첫 주문서가 떨어짐 | 따로 있는 전리품 목록에서 정함. 베타 전에 꼭 확인 | 목록 |
| P0 | **SkillReady** | 스킬 쿨다운이 끝남(지금은 Tap이 남) | 부드러운 '핍' 사인 1.4→1.6 kHz 50 ms, 0.25 | 1 |
| P0 | **HurtBig** | 크게 맞음(지금 HitHeavy2와 같은 파일) | 뭉근한 300~700 Hz 범프 + 1.1→0.6 kHz 짹, 150 ms, 0.36 | 1 |
| P0 | 진영 고르기 확인 | 진영 선택 확정(지금은 Tap만 남) | SkillHalo / SkillHorns 재사용 | 0 |
| P1 | **Spend** | 물약 구매 | 동전 두 개가 아래로(E7→D7), 0.35 | 1 |
| P1 | **KO** + 다시 나타남 | 내가 쓰러짐(Fx KO는 나에게만 옴) / 부활 | 만화식 어질어질: 부드러운 범프 + 빙글 도는 '짹' 별 3개, ≈0.8 s. 죽음 징글은 없음. 부활은 짧은 '뿅' | 2 |
| P1 | **Plunder** | 내 주머니를 뺏김(지금 'Coin'은 takeOver 때문에 소리가 꺼져 있음) | 당한 사람: 동전이 흩어지며 멀어짐. 뺏은 사람: GoldPickup | 1 |
| P1 | **RankUp** | 내 진영 점수가 오름·새 칭호 | 마림바 C5-D5-E5(RankDown의 거울), 0.35 | 1 |
| P2 | GoldenKill | 황금 몬스터 처치(Reward Golden=true) | GoldenSpot 파일 재사용, 동전 0.1 s 뒤 | 0 |
| 베타 뒤 | Rebirth | 환생(지금 'Release'는 소리가 꺼져 있음) | 나중에 설계 | — |
| 베타 뒤 | 전사 충격파 '쿵' · LevelUp/창 진영 층 · TalkBlipHorns | — | 위 표의 "베타 뒤" 항목 | — |