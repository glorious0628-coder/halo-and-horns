# 게임성 개발 1 — 인계 상태 (2026-10-11 밤 늦게, ①②③ + 후속 3묶음 + 황금 알 화면(7) 끝·보고함)

클라 코드만(창·HUD·Config·Fx). 메인 Studio는 건드리지 않음(sync·사진 = 메인 반영 1). 사용자에게 직접 묻지 않음. 보고는 send_message, 묶음마다 한 번 → 턴 끝내기.
- **보고처(사용자 10/11 변경):** 가지 push 보고 = **'게임성 검수'** `local_e148c3c7-2703-4fd7-8df3-aae3998d5de7`(시험·리뷰 → "병합 가능"이면 최종 검수가 병합). 화면 조작 승인·사용자 질문 = **'최종 검수'**(옛 '모든 것 검수') `local_d522c0f1-07cf-4db1-b178-5f335a56db7c`. 개발 2 = `local_8434905b-1b7a-44cb-b4c0-abce17954dac`. (id는 list_sessions로 다시 확인)
- 지금 일하는 가벼운 worktree(sparse: src/tools/docs): `C:/Users/glori/Documents/Roblox/wt_lesstext`(브랜치 `fix/lesstext`), `C:/Users/glori/Documents/Roblox/wt_onehand`(브랜치 `fix/onehand`), 둘 다 base 201779da; `C:/Users/glori/Documents/Roblox/wt_goldegg`(브랜치 `fix/golden-egg-client`, base 368f490e). build/luau_cli_0_741는 Game/build에서 복사해 둠. place 파일이 없어서 test_place_english는 place를 잠깐 복사해 돌리고 지움.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 그 브랜치만 push(main push 금지, 병합은 검수). 공유 트리(Game)는 `py tools/push_paths.py`만.
- 큰 표·코드는 `py tools/api_agent.py`(읽기 모드 / `--write --branch api/<이름>`) 써도 됨.

## 10/11 밤 검수 급한 일 (사용자 플레이 중 지적)
1. **① A23-130 거위·보상 말풍선 — 끝, 보고함.** `fix/lesstext` 99dbd39f: EventHUD 거위 아래 줄 숨김(`Config.Nudges.GooseSub = false`), Lunch1·WB1 Choice Reply 4줄 삭제, StoryQuestService(서버 2줄 — 개발 2 파일, 검수에 알림) Reward 있는 선택은 lean/saved 줄 안 보냄. 시험: town_quests 1035·244/244, forest_call 51·26/26, story_text, english 81·21/21, a23_14 286(--no-mutations), hud_reveal, new_tag, death_screen 통과.
2. **② A23-128 전사 한손검만 — 끝, 보고함.** `fix/onehand` f51fce52: ClassGrips Warrior_Halo=Sword·Warrior_Horns=DarkSword 둘 다 OneHand(오른손 옆, 칼끝 앞·위 45°/35°, `OneHand.Pole` 팔꿈치 아래·가까이), 빛 OffHand·뿔 GreatSword/TwoHand 삭제, WeaponPose.OneHand Pole 읽기, CharacterVisuals SHAPES.GreatSword → SHAPES.DarkSword, grip_reference §1-8. 시험: one_hand_grips 75·29/29, two_hand_grip 14·14/14('두 손·대검 없음'), class_grips_server 18·6/6, weapon_pose 21·7/7. 스킬 동작(두 손 치켜들기)은 안 바꿈(검수 판단). 메인 사진 부탁함(앞·3/4·옆, 주먹-손잡이 100% 크롭, 걷기, GripProbe 줄).
3. **③ A23-130 남은 설명 글 전부 훑기 — 끝, 보고함.** `fix/lesstext` b92a1c36: 표 `docs/review/less_text_table_2026-10-11.md`(화면 38줄 판정·적용 + 서버 226곳 API 초안 '개발 2 몫'). 끔: `Config.Nudges.AttackHint`·`ShopFarewell` = false. 짧게: 선택 카드 점수 줄, 대화 대기 줄, 원한 자루 칩, 괴수 줄, 대장간 안내. 남김: "Press Q" 늦은 말풍선(키 표시 기본 꺼짐이라). 시험: first_steps 26/26, story_client 57·38/38, story_text, english, town_quests 1035·244/244, hud_reveal, new_tag, round3_client, quest_window 44/44 통과.

## 10/11 밤 검수 후속 (끝, 보고함)
4. **fix/lesstext 0325d628** (b92a1c36 위): 첫 PvP 카드 3장 → 1장 2줄(FirstSteps PVP.Text, PauseCard Tip 2줄 TipLines=2), "Saved!" 카드 = 장 끝(Why Chapter)만(PauseCard T.PauseWhy; 일일·전쟁 카드 클라에서 안 띄움, OptIn은 ComeBack.OptIn으로 넘김; 서버 ReturnService는 안 바꿈 — 개발 2가 Daily/War 안 보내면 더 깔끔). 시험: first_steps 51·28/28, pause_card 59·32/32, come_back 49·37/37, line_balance, english 81·21/21, audio passed.
5. **fix/onehand bf982c05** (f51fce52 위, 검수 반박 검증 5개): 전사 Hilt (1.65,-0.85,-0.6/-0.65)·Pole (0.6,-0.6,0.8)·뿔 Aim 45°, 팔꿈치 x 1.46, 팔뚝 0.46·손 0.52 몸통 밖, 손목 22.6°/23.7°, 칼-허벅지 ±40° 0.41/0.35. 시험 추가(test_one_hand_grips: 팔꿈치·팔뚝/손 상자·손목·허벅지·DarkSword=buildSword 모양; test_side_clips: Paladin·Berserker 클립 왼팔 균형·주석). PaladinRelease·BerserkerRelease/Z/X 왼팔 = 균형 팔. 시험 one_hand_grips 86·38/38, side_clips 156·13/13, two_hand_grip 14/14, weapon_pose 7/7, class_grips_server 6/6, skill_fx 18/18.

6. **fix/onehand 33272a46** (bf982c05 위, A23-133 무기 길이): 참고 = Roblox 공식 gear 1,942개 실측(GitHub Roblox/Catalog; 칼 249개 중간값 5칸·손 12%, Linked Sword 4칸·12.5%, 지팡이 5.4·활 5.25·망치 4.75) + 실제 칼·지팡이·활 치수 → `docs/design/grip_reference_2026-10-11.md` §5. place 기본 R15(PotionMerchant) 실측 키 5.18칸·몸통 가운데 3.21칸(옛 시험 어림 3.9 틀림 → 긴 지팡이 발끝이 땅에 박혔을 수 있음). CharacterVisuals `LEN`/`tierLen`: 검 0.74~0.88H(뿔 폼멜 포함 0.80~0.93H), 지팡이 구슬 포함 0.85~1.0H(`STAFF.FootMax` 3.4→2.8, 발끝 땅 위 0.06), 활 0.6~0.95H(짧은 활 0.75배). 망치·막대는 그대로(0.42H·0.45H). 시험 one_hand_grips 95·48/48(길이 범위·손 위치 + 돌연변이 11), weapon_motion 253, class_grips_server 18·6/6, two_hand_grip 21·18/18, weapon_pose 21·7/7, side_clips 149·8/8, unarmed_start 221 통과. 숫자 한 줄은 그림 High 때문에 먼저 검수에 보냄.

7. **fix/golden-egg-client 30fa96da** (A23-131·134 황금 알 줍기 화면, 게임성 검수에 보고): 서버-화면 약속 `docs/design/golden_egg_contract_2026-10-11.md`(Effects.GooseEggs 부품 + Id·Kind·Points·From·LandAt, 플레이어 EggCarry·GooseCount·EggDelivered·EggCan·EggShield, GameState GooseOvertimeUntil·정수 GooseRescue/Poach, 거위 Act·ActUntil, Fx EggDeliver·EggReturn·EggTag, Config.Goose.Egg 모양 + Center, EggStack Motor6D EggJoint). 새 `EggFx.luau`(ClientMain "FountainFx" 다음), EventHUD 알 막대(EggFx.Bar), Audio(EggDeliver/EggTag, 알 주운 사람만 3-2-1), QuestMarker(알 들면 집), QuestTarget·WorldMap(둥지·수레), Config.GooseEggFx + 소리 7줄. Mode ≠ "Eggs"면 전부 꺼짐(병합해도 게임 그대로). 시험 test_egg_fx 51·25/25 + 관련 41개 통과. 개발 2에게 약속 보냄, 9절 질문 3개 답 기다림.

## 기다리는 것
- 게임성 검수: fix/lesstext(0325d628)·fix/onehand(33272a46)·fix/golden-egg-client(30fa96da) 시험 → 최종 검수 병합 → 메인 반영 1 sync·Play 사진(전사: 앞·3/4·옆, 주먹-손잡이 100% 크롭, 걷기 때 칼-허벅지, Q·Z·X 한 번씩, GripProbe 줄; **마법사 지팡이 발끝이 보이는 전신 옆 사진** — HUD에 발이 가려지지 않게). 사진 오면 쥐기·길이 다시 봄.
- 개발 2: 황금 알 약속 답(장인 알 들고 다니나, 깃털 Kind, "Bring 2 eggs…" Notify) + 서버 GooseEggs → 그 뒤 진짜 서버로 Play 확인·폰 확인(메인 반영 1), 약속이 바뀌면 EggFx 맞춤.
- 서버 줄(끔 52·짧게 60)은 개발 2 몫. tools/_weapon_prompts.py 뿔 전사 문구는 이미지 생성 2 몫.
- 아직 안 한 황금 알 화면: 거위 조각 색(거위 3D 필요), "!"·"Zzz" 아이콘 그림(승인되면 글자 대신), 알 아이콘 IconGoldenEgg(이미지 개발 업로드 뒤 막대 양 끝).

## 그다음 큐 (검수가 새로 주지 않으면)
1. 한국어 클라 다음 덩어리(API 쓰기, `docs/design/l10n_contract_2026-10-11.md` §10-1 나머지; L10n 중심은 main 398733a4에 병합됨): L10nText 처리기(간판 TextKey·현상수배판 BoardRows·글자 그림 Lettering 먼저), 프롬프트 훅(ActionKey/ObjectKey), Announce 조합기 → L10n.T, 이름표·몬스터 바 클라 조합, l10n_export --lettering·클라 표 export/apply. 그다음 첫 10분 화면 UIKit.Tx 키로.
2. 스트리밍 고침(검수가 켜기 정하면, `docs/review/streaming_risk_2026-10-11.md`).
3. 스킬 소리 41개 연결(id 오면), 개발 2 Z·X 패킷 필드 SkillFx 연결.
4. 나중: 장인 기능 클라, 슬롯별 화면 흔들림 세기.

## 브랜치 / worktree
- 작업 중: wt_lesstext(fix/lesstext), wt_onehand(fix/onehand) — 병합 뒤 지워도 됨.
- ../Game-dev1-opening(dev1-opening-v2, 6단계 때 병합 예정 — **지우지 말 것**). 옛 Game-wtc(invite)·Game-dev1-* 병합된 것들은 지워도 됨.

## 알아둘 것
- 시험은 동시에 3개까지. 오래 걸리는 test_a23_14 등은 `--no-mutations`로 먼저. 시험이 docs/art/verification_* 보고서를 다시 쓰니 커밋에 넣지 말 것(pathspec).
- Bash 도구는 문자열 속 \n을 줄바꿈으로 바꿈 → 시험 파일 수정은 Write/Edit로. Windows에서 Python `write_text`는 CRLF로 씀(git이 LF로 바꿈, 커밋 diff는 정상).
- 직업 id는 Warrior/Mage/Archer뿐(연금술사 = Mage+Neutral).
- HUD.luau·Fx.luau·UIKit.luau는 지역 변수 200개 한도 근처 → 새 값은 표(L / MOTION / UIKit 필드)에.
- 쥐기·자세는 참고 먼저(`docs/design/grip_reference_2026-10-11.md`), 숫자 시험(test_one_hand_grips) + 메인 사진.
