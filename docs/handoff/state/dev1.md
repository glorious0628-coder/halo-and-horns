# 게임성 개발 1 — 인계 상태 (2026-10-13, 지팡이·BB8·거위 광장 보고, 결과 기다림)

클라 코드만(창·HUD·Config·Fx). 메인 Studio는 건드리지 않음(sync·사진 = 메인 반영 1). 사용자에게 직접 묻지 않음. 보고는 send_message, 묶음마다 한 번 → 턴 끝내기.
- **보고처(10/13 게임성 검수 쉼): 가지 보고·시험 결과 = '최종 검수' `local_d522c0f1-07cf-4db1-b178-5f335a56db7c` (내 시험 + 변이 숫자 같이).** 옛 보고처(사용자 10/11 변경): 가지 push 보고 = **'게임성 검수'** `local_e148c3c7-2703-4fd7-8df3-aae3998d5de7`(시험·리뷰 → "병합 가능"이면 최종 검수가 병합). 화면 조작 승인·사용자 질문 = **'최종 검수'**(옛 '모든 것 검수') `local_d522c0f1-07cf-4db1-b178-5f335a56db7c`. 개발 2 = `local_8434905b-1b7a-44cb-b4c0-abce17954dac`. (id는 list_sessions로 다시 확인)
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

8. **(PC 재부팅 뒤) fix/onehand-2 6d449153** (33272a46 위, 게임성 검수 후속 6개, 게임성 검수에 보고): WarriorRelease 왼팔 = 받침·균형(grip_reference §1-9), CharacterVisuals `staffHandHeight`(아바타 몸으로 손 높이 → 발끝 땅 위 0.08, STAFF.Grip·FootMin 지움), 시험 빈 곳(위팔 ≥0.15 → 연금술사 Pole (1,-0.8,0); FK 두 손 간격 ≥1.2), 옛 대검 주석. 4번(진영 대기 자세): 최종 검수 OK → **a23c7e4a**(빛 Hold Waist +3·Neck +3, 뿔 Waist -10·Neck -6, 뿔 Aim (0.1,0.6,-0.7) ≈ 40°; ClassGrips Hold는 +rx = 뒤로 젖힘 — 질문 때 부호를 반대로 썼던 것 정정해 알림). **0dc6c46d**: 뿔 마법사 Waist +8→-8, 뿔 궁수 +12→-12(같은 부호 실수, main에도 있던 것), 시험 '뿔 줄 Waist ≤ 0·빛 줄 ≥ 0'. 6번 Legend 길이 = 의도(힘 T3~T4). fix/golden-egg-client **3d95925a**: EggFx 경고 10초에 한 번. **eebeebd3**: 미리 보기 없이 내가 주운 알에 '남이 주움' 팝·소리 안 냄(MineAt + Near, AND).

9. **fix/reward-chip a5de2b9f** (main에서, worktree wt_lesstext 재사용 — fix/lesstext는 병합됨): 첫 미션 '+150 gold'가 카드 연 채 '★ +150...'로 잘림(병합 사진 06_claim) → UIKit NOTIFY.CoinLine(골드뿐인 보상 줄 = IconCoin + '+N', 형식은 Config.Tutorial.Text.Claimed·StoryQuests.Text.ChoiceGold) + art 캡슐 TextFits 넓히기. 시험 test_reward_chip 12·7/7 등. 게임성 검수에 보고. 알게 된 것: test_audio는 다른 시험과 동시에 돌리면 시간 재는 2개가 흔들림 → 혼자 돌릴 것. test_english 'twins drift apart' 변이는 main에서도 0번 일치(원래 실패).

10. **fix/photo-1012 471d099c** (main 0696ccc4에서, wt_onehand 재사용 — onehand-2는 병합됨): ① 지팡이 끝이 사진에서 0.27/0.26 뜸 → WeaponPose.StaffStep/StaffLift(화면이 Shaft 끝→땅 재서 손 목표 보정, ±0.4) — 서버 HipHeight 식은 맞았음(PotionMerchant 부품 위치가 낡음: 몸 크기 1.06, 연결점 기준 윗몸통 3.441·키 5.46; 크기 1이면 ~5.15라 H 5.2 그대로; grip_reference §5-1 바로잡음). ② 가방 강화 칩 → Config.Loot.Text EnhanceOk/FailDown/FailKeep/MoveOk 결과만(인자 그대로), tools/test_enhance_lines.py. 게임성 검수·개발 2에 알림.

11. **main 96ec45ad에 병합됨:** golden-egg-client(eebeebd3까지)·onehand-2·photo-1012·reward-chip. **fix/egg-mine cef8f3f6** (wt_goldegg, main 8e6b7288에서): Eggs 켜기 전 낮은 것 — Near에 S.Trail 포함, MineAt은 미리 보기 없는 줍기만. test_egg_fx 55·29/29. 게임성 검수에 보고.

12. **fix/pvp-toast 2dec3bdf** (wt_lesstext, main 408e6a5f에서, push함, 게임성 검수에 보고): 첫 PvP 카드 + 'PvP zone!' 겹침 → UIKit.NotifyFilters + FirstSteps PVP.SkipToast(Config.Text.EnteredPvP / Key; 카드 기다림·열림·이번 진입에 열릴 때만 건너뜀). 시험 first_steps 57·32/32 등 통과. **test_audio(혼자 돌려야 함)는 못 끝냄 → 아침에 돌려 게임성 검수에 결과.**

## 10/12 밤 '아침에 할 것' → 10/13 아침 처리
1. test_audio를 fix/pvp-toast(wt_lesstext)에서 **혼자** 돌려 결과 보고(다른 시험과 동시면 시간 재는 2개가 흔들림).
2. 지팡이 끝 경사·계단: 사진 측정 평지 0.02~0.07 OK, 계단 −0.12(박힘)·경사 +0.51(뜸) → WeaponPose.StaffStep에서 Ground.Cast 법선(hit.Normal) 고려 (경사면에서 발끝 바로 아래 높이 vs 기울기; 계단 모서리는 발끝 둘레 몇 점 중 가장 높은 땅). 낮음. 새 가지(main에서) + test_one_hand_grips StaffLift 경사 사례.
3. HUD Hero 칸: 지금 'Coming soon!' 칩만(창 없음) → 베타 전 Hero 창(BB8 내 캐릭터·장비창) 계획 전까지 **다른 잠긴 칸과 같은 자물쇠 표시, 누르면 아무 글 없음**(덜 친절한 UI, A23-99/130). HUD 칸 잠금 모양은 이미 있는 잠긴 칸(Lv 5·Get pet·Story 1)과 같게.
4. 그다음 큐는 아래 '그다음 큐' + A23-137(거위 4시간마다: EventHUD 예고 칩 = 다음 거위 시각), A23-138(밈 묶음 fix/meme-en-client, Smokey → Rose) 지시 오면.

13. **10/13 아침:** test_audio(fix/pvp-toast, 혼자) 통과 362 — 보고함. **fix/staff-slope-hero 2179efa9** (wt_onehand, main c5168d76에서): StaffStep 끝 둘레 5점 중 가장 높은 땅(StaffRing) + GripProbe 'Staff tip-ground/lift' 줄(r1012b 'tip-foot'은 발바닥 기준이라 경사 판단 불가), HUD L.TileOpens: 열 창 없는 칸(Hero)은 잠금 유지('Lv 2' → 'Hero', 팝 없음, 흔들림만). 관련 시험 28개 통과. 게임성 검수에 보고, 사진 부탁(Hero 칸, 계단·경사 GripProbe).

14. **fix/stairs-ground 3099197e** (wt_onehand, main 7578bc15에서; staff-slope-hero·pvp-toast는 병합됨): 빛 계단 위 지팡이 2~3칸 뜸 = Config.GroundRoots가 Props 키트 조각 중 'Bridge'만 땅 → Config.Ground.KitWalk {Bridge, Stairs, Steps, Ramp}. 태그 없는 Floor는 장식 그대로. 새 빛 마을(메인 Studio) 다른 폴더 계단·바닥은 월드 쪽 확인(최종 검수에 전달 부탁). test_ground_rays 24·19/19 등 통과. 게임성 검수에 보고.

15. **fix/staff-hip 612274b1** (wt_onehand, main 170fce30에서; stairs-ground는 병합됨, 게임성 검수에 보고): 최종 검수 (a) '손 엉덩이 ≈2.1칸'은 불가 (곧은 지팡이 + 주먹 = 아래팔 내려간 만큼 손목 엄지 쪽 꺾임, 사람 15~25°; 2.1칸이면 팔 다 펴짐·손목 ≈70°; 내 첫 추천이 손목을 빼고 잰 실수 — 정정함). 손목 20° 안 가장 낮게: 빛 2.71칸(Hilt (1.4,-0.5,-0.8), 3°, Pole (0.2,-0.2,0.6))·연금술사 2.66(6°)·뿔 2.56(11°). 연금술사 = SHAPES.FlaskStaff(승인 2D), STAFF.FootMax 2.5, grip_reference §5-6, test_one_hand_grips 123·74/74 + 관련 14개 통과. 감은 곳: 디자인 검수가 메시 7개(LightMage T1·T3, DarkMage T1·T3, Alchemist T1~T3) 감은 곳 가운데를 바닥에서 빛 2.63·뿔 2.53·연금술사 2.59칸으로 올리게 이미지 생성 4에 보냄(내 손 높이 그대로). 쥐는 높이 표 = docs/design/weapon_grip_heights_2026-10-12.md. 사진(병합 뒤): 세 마법사 대기 앞·옆(디자인 검수에도 한 장), 주먹-막대 크롭, GripProbe 평지·계단, 걷기, 연금술사 지팡이 T1·T7, Q·Z → 참고 vs 우리 나란히 시트.

   - **a76e7564** (612274b1 위, 최종 검수 API 검토 MAJOR): 7단계 지팡이 1.008H → LEN.Staff 위 끝 4.45(0.9985H), 시험 REACH Staff (0.85, 1.0). 게임성 검수에 보고.
16. **BB8 내 캐릭터 창 = API 쓰기 job `dev1_character_ui`**(가지 api/dev1-character-ui, sonnet $6, 프롬프트 scratchpad api/bb8_character_ui.md — 세션 끝나면 사라짐; 결과 build/api_agent/dev1_character_ui/result.md). 게임성 검수 10/12: 큰 코드는 API 쓰기 모드 먼저(남은 약 $85, 한도 꼭). 개발 4와 약속: 창 안 빈 Frame 'EquipSlots' 전체를 개발 4에게 — C.GearSlots.Build(frame, { Refresh = fn }) 있으면 6칸(Weapon·Armor·Ring / Pet + Pet Armor·Pet Acc) 전부 개발 4가 그림, 없을 때만 내 임시 무기·펫 칸; 열 때마다 C.GearSlots.Refresh(). job 프롬프트는 무기·펫 칸을 내가 그리는 판이라 끝나면 그 위에 이 규칙으로 고쳐 해시를 개발 4·게임성 검수에. **결과:** job 1($6) = CharacterUI.luau 초안만(컴파일 OK, 미연결·시험 없음, ca33f568) → job 2 `dev1_character_ui_2`(가지 api/dev1-character-ui-2, $6, 프롬프트 scratchpad api/bb8_finish.md): GearSlots 있으면 6칸 전부 개발 4(내 칸 안 그림), ORDER 'BagUI' 다음, test_gather_view 변이, Panels Icons, tools/test_character_ui.py + fixture. 내 확인용 가지 fix/character-ui(wt_lesstext) = 초안 그대로.

17. **BB8 끝 = api/dev1-character-ui-2 47dce676** (job 2 $3.2: GearSlots 있으면 6칸 다 개발 4, ORDER 'BagUI' 다음, Panels Icons, test_character_ui 129·49/49 + 관련 12개 내가 다시 돌려 통과). 게임성 검수·개발 4에 보고. fix/staff-hip는 main ecde46c6에 병합됨.
18. **A23-141 거위 광장 화면 = API job `dev1_goose_square`**(가지 api/dev1-goose-square, $6, 프롬프트 scratchpad api/goose_square.md): Config.Goose.Square(내 것, 개발 2는 읽기), EggFx.Here/SquareButton/SquarePress/어두워짐, EventHUD Join·Leave, 알 화면·둥지/수레 표시는 InGooseSquare일 때만. 약속 docs/design/goose_square_contract_2026-10-12.md(main 8dc84f6) — 개발 2 답 기다림(원격 GooseSquare·속성 InGooseSquare·GooseJoinBlock은 Net/서버 = 개발 2).
19. **A23-142 급한 일 = fix/staff-short 68bef0e7** (wt_onehand, main 3570a8f3에서, 게임성 검수에 보고): 지팡이 3개 = 아바타 실제 키(avatarHeight)의 0.65~0.75, 손 43%(STAFF.Grip), 구슬 아래 ≥ 손+1.2(키 비례, staffOrb), 땅 안 짚음(발끝 0.89~1.26) → StaffCarry: WeaponPose는 박힐 때만 들어 올림. staffHandHeight·staffLow·FootMax 지움. grip_reference §5-7. 디자인 검수에 메시 숫자(43%) 보냄. 낮은 것 ①(실제 키)은 이걸로 끝, ②(자세 안 잡는 캐릭터 지팡이 누움)는 남음.
   - **d56d0f1e** (68bef0e7 위): 메인 사진 뿔 지팡이가 몸 가로지름(11°+숙임 8°) → 모든 지팡이 세상 기준 10° 안, 뿔 Aim (0,1,0)·손 2.71(빛과 같음). 시험 세상 기울기 줄.
20. **BB8 고침 = api/dev1-character-ui-2 b479014a** (= fix/character-ui, wt_lesstext): main merge(ORDER + BuffBar) + 닉네임 줄·[Change], HUD PowerOpen 잠금, Base hit, 축복 내 편만 +gold+XP, CombatPowerOf, [Equip] 죽음·직업 전·진영 무기 막기. test_character_ui 138·59/59 + 9개. 남은 낮은 것: 장착 간격 공유, 한국어 이름, 코드 모양 배경.
21. **거위 광장 화면 = fix/goose-square cb886aae** (wt_goldegg; 4e34b165 API job 한도에서 멈춤 → 내가 마무리): + GooseSpot 가운데. egg_fx 126·66/66, audio(혼자) 통과 + 10개. 게임성 검수에 보고. 서버(개발 2 앱 세션)와 같이 병합해야 동작.
22. **fix/staff-face cdab64c7** (wt_onehand, main a09de901에서; staff-short·d56d0f1e는 병합됨): 디자인 검수 staff_short_v2 판정 → 손 0.4칸 앞(z -1.2), 지팡이 바깥 5°, 구슬이 얼굴 앞·밖(test 'orb clears the face'), GripProbe 'tilt='. 게임성 검수·디자인 검수에 보고. 사진 = 세 마법사 옆 합본(디자인 검수).
23. **최종 검수 10/13:** staff-face cdab64c7 + character-ui-2 b479014a = 최종 검수 첫 검수 중 → 통과하면 같이 병합 → 메인 반영 1 사진. goose-square cb886aae = 개발 2 서버 가지와 같이. 서버 병합 뒤 한 가지로: 도움말 '10분·교차로' 글, Config.QuestGuide GuideZones.Goose, 큰 지도엔 거위 광장 안 그림(광장 안 미니맵만).
- 다음 큐 메모: A23-143 말풍선 스티커 고르기·잠금 화면(이미지 개발 imgdev-stickers 병합 + 지시 뒤, 키 Config.UIArt.Parts.Emo*, Free 5개). 이미지 생성 4 지팡이 메시 9개 = 0.65/0.70/0.75H·원점 43%(코드와 맞음, 올리기·연결은 최종 검수 승인 뒤 이미지 개발).
- **API: 남은 ≈$22 → 새 API 쓰기 job 금지(최종 검수 10/12), 큰 코드도 앱 세션에서.**

## 기다리는 것
- **BB8 job 결과(16번)** → 검토·EquipSlots 규칙 고침 → 개발 4·게임성 검수. 개발 2 황금 알 서버(api/dev2-golden-egg) 해시 오면 EggFx 깃털·장인 줍기·Bring 2 eggs 맞춤 화면 가지.
- 게임성 검수: fix/staff-hip 612274b1 결과 → 병합 뒤 사진(15번). stairs-ground는 병합됨 → Hero 칸·계단 GripProbe 사진 아직.
- 게임성 검수: fix/lesstext(0325d628)·fix/onehand(33272a46, "병합 가능")·fix/onehand-2(6d449153)·fix/golden-egg-client(eebeebd3) 시험 → 최종 검수 병합 → 메인 반영 1 sync·Play 사진(전사: 앞·3/4·옆, 주먹-손잡이 100% 크롭, 걷기 때 칼-허벅지, Q·Z·X 한 번씩, GripProbe 줄; **사용자 아바타 마법사 지팡이 발끝이 보이는 전신 옆 사진** — HUD에 발이 가려지지 않게; 대장장이 Q). 사진 오면 쥐기·길이 다시 봄. dev4-bag와 golden-egg는 ClientMain ORDER 한 줄 충돌(둘째 병합 쪽이 main 다시 받기).
- 사진(병합 뒤 메인 반영 1): 마법사 지팡이 tip-foot 다시(목표 0.05~0.15, 기본 R15도), 가방 강화 성공·실패 칩, 카드 연 채 첫 미션 받기(동전 +150), 빛|뿔 전사 나란히 앞·3/4·옆 + 이름표·후광/뿔 위치(숙임), 뿔 마법사·뿔 궁수 옆, 마법사 지팡이 발끝, 대장장이 Q.
- 새 SPEC: A23-137(거위 4시간마다·예고 칩 = 다음 거위 시각 → 황금 알 화면 EventHUD 칩 손볼 것, 지시 오면), A23-138(밈 묶음 = fix/meme-en-client, 급한 병합 뒤 지시 오면; Smokey → Rose 36곳).
- 개발 2: 황금 알 약속 답(장인 알 들고 다니나, 깃털 Kind, "Bring 2 eggs…" Notify) + 서버 GooseEggs → 그 뒤 진짜 서버로 Play 확인·폰 확인(메인 반영 1), 약속이 바뀌면 EggFx 맞춤.
- 서버 줄(끔 52·짧게 60)은 개발 2 몫. tools/_weapon_prompts.py 뿔 전사 문구는 이미지 생성 2 몫.
- 아직 안 한 황금 알 화면: 거위 조각 색(거위 3D 필요), "!"·"Zzz" 아이콘 그림(승인되면 글자 대신), 알 아이콘 IconGoldenEgg(이미지 개발 업로드 뒤 막대 양 끝).

## 그다음 큐 (검수가 새로 주지 않으면)
- **A23-146 (10/12): 한국어 모드 취소, 게임은 영어만** — 한국어 클라 덩어리(L10nText·TextKo·Lettering) 지움. 들어간 L10n 중심 코드는 꺼진 채 그대로(지우지 말 것). 글은 중앙 표 + 쉬운 짧은 영어.
- **A23-145: 폰 정리 라운드 10/21부터(개발 1 주로)** — 지금은 준비만: 폰에서 겹치는 버튼·작은 글자 목록을 짬 날 때 적기(docs/review/phone_round_prep_<날짜>.md).
- 지금 순서(최종 검수 10/13): 캐릭터 창 MAJOR 고침(537331d4 보냄) → 거위 광장 낮은 것 3개(서버 병합 뒤).
0. 낮음(최종 검수 API 검토 10/12): ① 지팡이 길이가 GetScale만 따라 작은 체형은 4단계부터 1.0H 넘음 → 실제 키(머리 꼭대기-발) 기준으로 ② 자세를 안 잡는 캐릭터(R6·멀리·12번째 이후)는 지팡이가 앞으로 누워 몸을 뚫음.
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

24. **api/dev1-character-ui-2 537331d4**: Settings 닉네임 줄 = Hero 잠김(Lv<2) 동안 남김(SettingsUI.NicknameRow). 최종 검수에 보고.
25. **fix/character-ui a5f6abd0** (= api/dev1-character-ui-2): 537331d4 + merge dev4-gear-slots 01a3fc3b + dev4-market-window 3bd187d9, ORDER 손으로 한 줄(GearSlots UIKit 다음, MarketWindow CraftWindow 다음). 11개 시험 통과, 최종 검수에 보고.
- 큐 뒤(개발 4 쉬는 중, 그 두 가지 켜기 전): 마켓 시간 글 1:05, 팔린 줄 수수료, T1 여분 — 최종 검수 10/13 지시, 자세한 건 최종 검수에 물어 확인.
26. character-ui 묶음 a5f6abd0 = main 3feb3232 병합됨. **fix/staff-face2 025b7fb6** (15bf290f 뿔 갈고리 앞으로·연금술사 z -1.3 + main merge): 최종 검수에 보고, 사진 = tools/play_mage_staff_photos.py.
- 거위 광장 낮은 것 3개 = 개발 2가 서버+화면 한 가지로 합치는 중 → 그쪽에 맞춤(먼저 손대지 않음).