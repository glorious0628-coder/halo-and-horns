# 게임성 개발 1 — 인계 상태 (2026-10-11 밤 늦게, ①②③ + 검수 후속 2묶음 끝·보고함, 스스로 비우기 전)

클라 코드만(창·HUD·Config·Fx). 메인 Studio는 건드리지 않음(sync·사진 = 메인 반영 1). 보고는 검수 `local_d522c0f1-07cf-4db1-b178-5f335a56db7c`(send_message, 묶음마다 한 번 → 턴 끝내기). 사용자에게 직접 묻지 않음.
- 지금 일하는 가벼운 worktree(sparse: src/tools/docs): `C:/Users/glori/Documents/Roblox/wt_lesstext`(브랜치 `fix/lesstext`), `C:/Users/glori/Documents/Roblox/wt_onehand`(브랜치 `fix/onehand`). 둘 다 base 201779da. build/luau_cli_0_741는 Game/build에서 복사해 둠.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 그 브랜치만 push(main push 금지, 병합은 검수). 공유 트리(Game)는 `py tools/push_paths.py`만.
- 큰 표·코드는 `py tools/api_agent.py`(읽기 모드 / `--write --branch api/<이름>`) 써도 됨.

## 10/11 밤 검수 급한 일 (사용자 플레이 중 지적)
1. **① A23-130 거위·보상 말풍선 — 끝, 보고함.** `fix/lesstext` 99dbd39f: EventHUD 거위 아래 줄 숨김(`Config.Nudges.GooseSub = false`), Lunch1·WB1 Choice Reply 4줄 삭제, StoryQuestService(서버 2줄 — 개발 2 파일, 검수에 알림) Reward 있는 선택은 lean/saved 줄 안 보냄. 시험: town_quests 1035·244/244, forest_call 51·26/26, story_text, english 81·21/21, a23_14 286(--no-mutations), hud_reveal, new_tag, death_screen 통과.
2. **② A23-128 전사 한손검만 — 끝, 보고함.** `fix/onehand` f51fce52: ClassGrips Warrior_Halo=Sword·Warrior_Horns=DarkSword 둘 다 OneHand(오른손 옆, 칼끝 앞·위 45°/35°, `OneHand.Pole` 팔꿈치 아래·가까이), 빛 OffHand·뿔 GreatSword/TwoHand 삭제, WeaponPose.OneHand Pole 읽기, CharacterVisuals SHAPES.GreatSword → SHAPES.DarkSword, grip_reference §1-8. 시험: one_hand_grips 75·29/29, two_hand_grip 14·14/14('두 손·대검 없음'), class_grips_server 18·6/6, weapon_pose 21·7/7. 스킬 동작(두 손 치켜들기)은 안 바꿈(검수 판단). 메인 사진 부탁함(앞·3/4·옆, 주먹-손잡이 100% 크롭, 걷기, GripProbe 줄).
3. **③ A23-130 남은 설명 글 전부 훑기 — 끝, 보고함.** `fix/lesstext` b92a1c36: 표 `docs/review/less_text_table_2026-10-11.md`(화면 38줄 판정·적용 + 서버 226곳 API 초안 '개발 2 몫'). 끔: `Config.Nudges.AttackHint`·`ShopFarewell` = false. 짧게: 선택 카드 점수 줄, 대화 대기 줄, 원한 자루 칩, 괴수 줄, 대장간 안내. 남김: "Press Q" 늦은 말풍선(키 표시 기본 꺼짐이라). 시험: first_steps 26/26, story_client 57·38/38, story_text, english, town_quests 1035·244/244, hud_reveal, new_tag, round3_client, quest_window 44/44 통과.

## 10/11 밤 검수 후속 (끝, 보고함)
4. **fix/lesstext 0325d628** (b92a1c36 위): 첫 PvP 카드 3장 → 1장 2줄(FirstSteps PVP.Text, PauseCard Tip 2줄 TipLines=2), "Saved!" 카드 = 장 끝(Why Chapter)만(PauseCard T.PauseWhy; 일일·전쟁 카드 클라에서 안 띄움, OptIn은 ComeBack.OptIn으로 넘김; 서버 ReturnService는 안 바꿈 — 개발 2가 Daily/War 안 보내면 더 깔끔). 시험: first_steps 51·28/28, pause_card 59·32/32, come_back 49·37/37, line_balance, english 81·21/21, audio passed.
5. **fix/onehand bf982c05** (f51fce52 위, 검수 반박 검증 5개): 전사 Hilt (1.65,-0.85,-0.6/-0.65)·Pole (0.6,-0.6,0.8)·뿔 Aim 45°, 팔꿈치 x 1.46, 팔뚝 0.46·손 0.52 몸통 밖, 손목 22.6°/23.7°, 칼-허벅지 ±40° 0.41/0.35. 시험 추가(test_one_hand_grips: 팔꿈치·팔뚝/손 상자·손목·허벅지·DarkSword=buildSword 모양; test_side_clips: Paladin·Berserker 클립 왼팔 균형·주석). PaladinRelease·BerserkerRelease/Z/X 왼팔 = 균형 팔. 시험 one_hand_grips 86·38/38, side_clips 156·13/13, two_hand_grip 14/14, weapon_pose 7/7, class_grips_server 6/6, skill_fx 18/18.

## 기다리는 것
- 검수: fix/lesstext(0325d628)·fix/onehand(bf982c05) 시험·병합 → 메인 반영 1 sync·Play 사진(전사: 앞·3/4·옆, 주먹-손잡이 100% 크롭, 걷기 때 칼-허벅지, Q·Z·X 한 번씩, GripProbe 줄). 사진 오면 쥐기 다시 봄.
- 서버 줄(끔 52·짧게 60)은 개발 2 몫(검수가 넘김). tools/_weapon_prompts.py 뿔 전사 문구는 이미지 생성 2 몫(검수가 넘김).
- 다음 일은 검수가 보냄: 황금 알 줍기 A23-131 화면 쪽 예정.

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
