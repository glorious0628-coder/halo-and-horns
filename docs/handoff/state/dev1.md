# 게임성 개발 1 — 인계 상태 (2026-10-11 밤, 스스로 비우기 전)

클라 코드만(창·HUD·Config·Fx). 메인 Studio는 건드리지 않음(sync·사진 = 메인 반영 1). 보고는 검수 `local_d522c0f1-07cf-4db1-b178-5f335a56db7c`(send_message, 묶음마다 한 번 → 턴 끝내기). 사용자에게 직접 묻지 않음.
- 지금 일하는 가벼운 worktree(sparse: src/tools/docs): `C:/Users/glori/Documents/Roblox/wt_lesstext`(브랜치 `fix/lesstext`), `C:/Users/glori/Documents/Roblox/wt_onehand`(브랜치 `fix/onehand`). 둘 다 base 201779da. build/luau_cli_0_741는 Game/build에서 복사해 둠.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 그 브랜치만 push(main push 금지, 병합은 검수). 공유 트리(Game)는 `py tools/push_paths.py`만.
- 큰 표·코드는 `py tools/api_agent.py`(읽기 모드 / `--write --branch api/<이름>`) 써도 됨.

## 10/11 밤 검수 급한 일 (사용자 플레이 중 지적)
1. **① A23-130 거위·보상 말풍선 — 끝, 보고함.** `fix/lesstext` 99dbd39f: EventHUD 거위 아래 줄 숨김(`Config.Nudges.GooseSub = false`), Lunch1·WB1 Choice Reply 4줄 삭제, StoryQuestService(서버 2줄 — 개발 2 파일, 검수에 알림) Reward 있는 선택은 lean/saved 줄 안 보냄. 시험: town_quests 1035·244/244, forest_call 51·26/26, story_text, english 81·21/21, a23_14 286(--no-mutations), hud_reveal, new_tag, death_screen 통과.
2. **② A23-128 전사 한손검만 — 끝, 보고함.** `fix/onehand` f51fce52: ClassGrips Warrior_Halo=Sword·Warrior_Horns=DarkSword 둘 다 OneHand(오른손 옆, 칼끝 앞·위 45°/35°, `OneHand.Pole` 팔꿈치 아래·가까이), 빛 OffHand·뿔 GreatSword/TwoHand 삭제, WeaponPose.OneHand Pole 읽기, CharacterVisuals SHAPES.GreatSword → SHAPES.DarkSword, grip_reference §1-8. 시험: one_hand_grips 75·29/29, two_hand_grip 14·14/14('두 손·대검 없음'), class_grips_server 18·6/6, weapon_pose 21·7/7. 스킬 동작(두 손 치켜들기)은 안 바꿈(검수 판단). 메인 사진 부탁함(앞·3/4·옆, 주먹-손잡이 100% 크롭, 걷기, GripProbe 줄).
3. **③ A23-130 남은 설명 글 전부 훑기 — 다음 일(아직 시작 안 함).**
   - 화면에 뜨는 토스트·띠·라벨·팁(Config.Text·Config.Nudges·각 창·HUD·EventHUD·Fx 등)을 표로 → `docs/review/less_text_table_2026-10-11.md`. 칸: 문구 / 어디서(파일·키) / 남김·끔·짧게 / 이유.
   - 기준 A23-99: 보상·위험/실패·한 번뿐인 안전 사실(PvP 안전 카드, New skill!·Stronger!, 첫 주문서 안내 한 번), 퀘스트 줄+마름모+거리만 남김. 한 화면에 설명 글 둘 이상 겹치지 않게. 서버가 보내는 줄은 '서버'로 표시(개발 2에 넘김).
   - 표가 크면 api_agent 읽기 모드로 맡겨도 됨. 클라이언트 끄기는 `fix/lesstext`에 이어서 커밋(가능하면 `Config.Nudges` 키로 끔) → 시험 → push → 표와 끈 목록을 검수에 보고.

## 기다리는 것
- 검수: fix/lesstext·fix/onehand 시험·병합 → 메인 반영 1 sync·Play 사진. 사진 오면 쥐기(주먹이 손잡이를 감싸는지) 다시 봄.

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
