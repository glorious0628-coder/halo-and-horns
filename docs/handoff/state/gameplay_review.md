# 게임성 검수 상태 (2026-10-11 밤)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2` (src·tools·docs + build/luau_cli_0_741). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`.

## 끝난 판단
- **fix/onehand 33272a46 = 병합 가능**(최종 검수에 보냄). 시험 병합 8e4c20a6: one_hand_grips 95·48/48, weapon_motion 253, weapon_pose, two_hand_grip, side_clips, class_grips_server, land_shadow, quick_slots, beta_basics, commission, grudge, loot, story_client, tamer, unarmed_start, weapon_first, ranking(--no-mutations). rank_marks = art 없는 가짜 실패. 낮은 후속 6개는 개발 1에 보냄(WarriorRelease 두 팔, 지팡이 발끝 = 사용자 아바타 사진, STAFF.Grip·FootMin 안 쓰임, 위팔·PaladinZ 시험 빈 곳, 대기 자세, Legend 길이 질문).

## 기다리는 것
- **묶음 ①** = fix/lesstext 0325d628 + fix/lesstext-server(개발 2 MinGap 고침 커밋 대기) + fix/onehand. lesstext 쌍 시험 병합(d6b6a5e5) 충돌 0, GooseService·QuestService 정적 분석 main과 같음, 지운 글 이름 쓰는 곳 없음. 고친 커밋 오면: a23_14·onboarding·weapon_first·unarmed_start·gamepass·notify_sound(변이 포함) + ReturnService 관련 시험.
- fix/spawnclear: 최종 검수 '고쳐서 다시'(docs/review/spawnclear_review_2026-10-11.md) → 고친 커밋 오면 시험 + 실제 지도 측정(숲 면적 손실·첫 KO 킹 실패율).

## 진행 중
- dev3-v4-tables e5c8bb08 (시험 병합 33ffb735): 코드 리뷰 끝(낮은 것: EggHonorAt 미래 값 → 0이라 서버 시계 차이 몇 초에도 1시간 제한이 풀림). 시험 남음: save_v4_tables(변이), save_lock, item_seq, pet_speed, pet_window, tamer, stats, potions 등.
- fix/golden-egg-client 30fa96da (시험 병합 28db855d): 꺼짐 길(Mode ≠ "Eggs") 코드로 확인 끝. 시험 남음: egg_fx(변이) + audio·quest_target·map_v2 등. 낮은 것: EggFx.Step 오류 시 RenderStepped마다 warn(줄이기).
- dev4-bag ada1a4ef (시험 병합 c83a8059): API 반박 리뷰(gprev_bag_review_1)가 PC 꺼짐으로 끊김 → 다시. 시험 남음: bag_ui·keys_settings·quick_slots·skill_book.
- **충돌 주의:** dev4-bag × golden-egg-client = ClientMain ORDER 한 줄 충돌 → 둘째 병합 가지는 main 다시 받기.
- 새로 옴: dev4-gather bcc7b951.
