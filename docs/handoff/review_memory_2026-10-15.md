# 최종 검수 기억 이식 (2026-10-15 17:40, 옛 최종 검수 → 새 최종 검수)

옛 최종 검수(앱 세션 `local_5994bea0…`, 10/14 09:24~10/15 16:58)의 대화 기록이 112MB라 앱에서 통째로 못 불러와서 새 세션으로 바꾼다. 이 파일이 옛 세션의 기억 전부다(규칙 파일이 아니라 기억 노트 — 충돌하면 AGENTS.md "Which rule wins" 순서). 만든 방법: 기록을 13조각으로 나눠 API(Sonnet)로 뽑고 옛 세션이 직접 합침.
- 원문이 필요하면: `C:\Users\glori\.claude\projects\C--Users-glori-Documents-Roblox-Game\de5eecf9-d637-4ae8-9c1e-cfe8d35ccc52.jsonl`(grep만, 통째로 읽지 말 것). 읽기 쉬운 판: `build/api_agent/mem_src_1015/chunk00~12.txt`(시간순, UTC), 조각별 요약 `build/api_agent/mem1015_c00~c12/result.md`(+ `c10b`), 압축 요약 2개 `build/api_agent/mem_src_1015/summaries.txt`.
- 옛 scratchpad 도구 사본: `build/review_kit_1015/` (git 무시, 이 PC에만). chain70.sh(병합 체인 본보기), ko_up.py(한국어 업로드), council.html(회의실 페이지 원본), sweep.sh, run_tests.sh, merge_ko5.py 등.

## 1. 새 최종 검수가 맨 먼저 할 일 (순서대로)
1. `get_session self`로 내 id 확인 → list_sessions로 **게임성 개발 1·2, 메인 반영 1**에 "새 최종 검수 시작, 내 id = …, 보고·병합 요청·화면 신청은 이제 나한테. 옛 최종 검수에 보내고 답 못 받은 건 다시 보내" 한 번씩.
2. 회의실 지켜보기: `ArtifactComments` watch https://claude.ai/artifact/4hhwZZKHM4j2VkmoKw47S1 (아래 §6).
3. **개발 2 병합 요청 처리:** `dev2-quest-p1` (10/15 17:30 tip 2cab4ba8, main보다 11커밋 앞). 내용 = 퀘스트 P1 묶음 2 서버(⑧ 추격/호위 빼고) + 데이터 규격 `docs/design/quest_data_contract_2026-10-15.md`(이 가지에 있음) + 예시 `tools/fixtures/quest_pack_example.luau` + 검사 `py tools/test_quest_data.py` + 귀속 아이템(A23-206)·매일 부탁 하루 5개(A23-205). 개발 2가 "전체 223개 전후 비교 끝나면 결과 + 병합 요청"이라 했음 → 결과 받고 merge_chain으로 시험·병합. **저장 형식이 바뀌는지(v7 귀속) 확인** → 바뀌면 다음 게시 때 '모든 서버 종료'.
4. **개발 2 질문에 답:** M1_4가 '등불'로 바뀌며 옛 '안내자 보고' 대사(영웅 동상·용암 틈 설명, "다음 조각은?")가 빠짐 → 어디로 옮길지(또는 버릴지) 정해 줘야 함. 아직 미답.
5. **개발 1 보고 확인:** `dev1-a191` 3cb5ef23(설명 줄 삭제 A23-191 + 옛 영어 하드코딩, main보다 1커밋 앞) — 보고가 오면 시험·병합. 그 밖에 오늘 보고된 dev1·dev2 가지는 전부 main에 들어감(확인함).
6. **파티 API 작업 실패 처리:** `party1`(Opus, write 모드, 가지 api/party1)이 턴 한도 40에 걸려 **커밋 0개로 멈춤**($2.64). 계획 노트만 남음: `build/api_agent/party1/notes/party_plan.md`, 프롬프트 `build/api_agent/party1/prompt.md`. 다시: `--max-turns 120 --max-usd 12` 정도로 재시작(노트를 프롬프트에 붙이기) 또는 개발 2 큐 뒤로. 설계 = `docs/design/party_guild_2026-10-15.md` + SPEC A23-201·202·204. 개발 2는 "파티 가지 오면 공동 인정이 퀘스트 엔진과 맞는지 검토"하기로 함.
7. **퀘스트 데이터 = Codex:** 규격이 main에 들어가면 최종 검수가 Codex(gpt-6-astra high)에게 장별 퀘스트 데이터(대사·단계·보상)를 시킴 — 장마다 별도 가지(dev2-quest-p1/main 위), 파일 `src/ReplicatedStorage/Shared/Quests/<진영>_Ch<N>.luau`, `Config.AddQuests`가 합침(같은 id 두 번 = 불러오기 실패), 검사 `py tools/test_quest_data.py`. 순서: 첫 30분 → 마을 연결 → 숲 → 폐허 첫 결말. 개발 2가 시험·통합. 매일 부탁 12종 보상 표 초안은 개발 2가 만들고 최종 검수가 확정.
8. **다섯 언어 현지화:** `build/l10n/loc/run_loc.sh`가 옛 세션에서 띄운 채 계속 돌고 있음(부모 PID 1, 세션과 무관). 10/15 17:30 = 65개 중 37개(ja·zh-hans 13/13 끝, es 6, fr 5, zh-hant 0). 끝 확인 = `ls build/l10n/loc/out_*.csv | wc -l` → 65. 멈췄으면 `bash build/l10n/loc/run_loc.sh` 다시(끝난 조각은 건너뜀; 한 번에 두 언어 = 429 방지). 끝나면: `build/l10n/loc/entries.json`의 Id로 identifier 찾아 locale별 PATCH(`build/review_kit_1015/ko_up.py` 방식, locale만 바꿈) — **올리기 전 언어마다 샘플 확인**.
9. **영어 덤프 사진(아직 안 시킴):** 메인 반영 1에게 `HH_MAIN_STUDIO=1 py tools/play_phone_round_photos.py first10 out=docs/art/verification_2026-10-15/en_first10` 와 `… out=docs/art/verification_2026-10-15/en_windows` → 결과 `english_words.json` → 개발 1 화면 몫. (화면 사용 = 🟠 알림 먼저.)
10. 사용자에게 한국어 5줄: 지금 상태·기다리는 결정·다음 할 일.

## 2. 지금 상태 (10/15 17:40)
- main = 7e932e01 (코드 마지막 병합 20c5b51f 부근: 퀘스트 핀 2개·부탁 창 서버 보상). 오늘(10/14~15) 병합 약 90개.
- 게시판(라이브): 10/15 04:30 사용자가 저장한 판(main 856a8540, place push 6113c1de). **10/15 아침 Alt+P를 실제로 했는지 확인 못 함**(08:58 안내 뒤 '게시함' 답 없음). 다음 게시판 = 10/16 오후(개발 1·2 SHA → 메인 반영 1 sync·사진 → 사용자 Save As → place push → 사용자 Alt+P → 저장 형식 바뀌었으면 Creator Hub '모든 서버 종료').
- 세션: 최종 검수(새로) + 게임성 개발 1(Opus 5.5 high) + 게임성 개발 2(Opus 5.5 high) + 메인 반영 1(Sonnet 5.5 medium). 디자인 세션 전부 없음(디자인은 계획 순서 4번/9번 — 게임성 다음).
- 개발 1 큐(최종 검수 10/15): 설명 줄 삭제(dev1-a191) → 묶음 2 화면(개발 2 P1 ⑤~⑨ 화면 몫 7줄 = 규격 문서 끝) → #2 폰 동시 조작 + 공격 '통역사'(누르면 가까운 몬스터 쪽으로 살짝 돌기, 폰 터치 넓게, 줍기 스쳐도 성공) + '이게 왜 안 돼?' 점검(닫힌 문 판자·투명 벽 → 보이는 울타리, PvP 경계 붉게) → #1 실패 원인 그 자리 → #7 도감 획득처 → #11 왕관 막대 내 기여 → #8 친구 위치. 근거 `docs/design/game_feel_talk_2026-10-15.md`, `docs/design/ref/video_textbook_2026-10-15.md`. 상태 `docs/handoff/state/dev1.md`.
- 개발 2 큐: dev2-quest-p1 병합 → ⑧ 추격/호위 → 하루 5개 반복 엔진 마무리 → 파티 가지 검토 → 모험단(파티 뒤). 상태 `docs/handoff/state/dev2.md`.
- 계획 문서: `docs/design/gameplay_plan_2026-10-14.md` 맨 위 순서표(✅/▶/⬜, 날짜 없음). 10단계 합격선: Lv5까지 5분, Lv10까지 15분, 첫 무기 4분(무료 T1 기준), 대장간 30초, 저장 잃음 0.
- 퀘스트 범위(사용자 16:00 "첫 30분 한정 말고 게임 전반 퀘스트, 아주 잘 짜인"): `docs/design/quest_bible_2026-10-15.md` v3 전체 = 진영별 본편 30×3 + 마을 12×3 + 공통 20 + 연결 끝 6 = 일회성 152 + 매일 12종, Lv1~35(초원→숲→폐허 첫 결말). Lv50~100은 베타 뒤.
- 사용량: 주간 64%(10/15 오후, 리셋 **10/20(월) 16:00 KST**) → 세션 안 늘림(사용자가 16:41 "세션 하나 더?" 물음 → "안 늘리는 게 낫다" 답, **10/20 리셋 뒤 다시 보고하기로 약속**). API: 10/13 저녁 충전($200) 뒤 38개 job ≈ $39 → 남은 ≈ $161(추정). Codex·ChatGPT 요금제는 Claude 사용량과 무관.

## 3. 사용자 — 일하는 법과 화나는 것 (옛 세션이 혼난 일에서 배운 것)
1. **모든 말은 한국어**, 짧게. 짧은 진행 알림도(10/15 13:17 "나한테 말할 때는 한국어 써줭").
2. **"됐어요/완성" 전에 100% 나란히 비교.** 화분 코드 모델링을 '됐다' 했다가 "저걸 완성이라고 한 거야?"; 난간 합친 판을 작은 시트로 통과시켰다가 "너 검수 잘하고 있어?". 합친 물건은 2D와 같은 각도·크기로 겹쳐 본다. 재질 뺀 판은 "회색이 정상"이라고 미리 말한다.
3. **증상을 글로 덮지 말고 원인을 없앤다.** 스킬 거절 알림을 넣었다가 "서버가 거절을 안 하게 해야지 멍청아"(A23-180).
4. **한 번 싫다고 한 UI는 '그 종류 전부'를 코드째 지운다** + 정적 검사로 못 박는다. 파란 설명 띠: 문구만 하나씩 껐다가 "몇 번을 말하냐", "다 삭제하라고"(A23-191). 왕관 막대 아래 글·막대 안 숫자(A23-184, "저 9:25 뭐냐고!"). 스위치로 숨기지 말 것.
5. **계획은 날짜가 아니라 순서**(✅/▶/⬜). "날짜로 하지 말라고 ㅋㅋ", "하나 끝나면 다음".
6. **디자인은 원래 계획 순서대로, 디자인 세션에 미리 맡기지 않는다.** 10/14 옛 세션이 계획(six_week_plan·A23-163)을 안 읽고 인계문 한 줄만 보고 디자인 세션 4개를 켜서 Tripo 1,815점을 씀 → "계획 읽었어 안 읽었어?". 세션을 켜거나 일을 주기 전에 계획 문서부터 읽는다. 사용자가 가져온 디자인 자료는 `docs/design/idea_backlog.md`로, 게임성 지적은 바로 처리.
7. **중립(장인 길드)·거래소를 빼먹지 않는다**("중립 애들 작업도 해야 할 거 아니야").
8. **이미 한 일을 다시 부탁하지 않는다.** 10/15 아침 패스 9개를 또 만들라 해서 "어제 했잖아!". 부탁 전 `docs/design/pass_ids_2026-10-14.md`·체크리스트·review.md 확인.
9. **세션 만들어 달라 하기 전에 list_sessions**("최종 검수 메시지 대기 세션 있잖아 멍청아").
10. **사용자 말을 넓혀 읽지 않는다.** "영어만"을 "자동 번역 끔"으로 읽어 번역 0% 사고(A23-179).
11. **저장·PC 끄기를 내가 하겠다고 약속하지 않는다.** computer-use 허락이 다른 설치 경로 Studio에만 걸려 실패 → 사용자가 새벽 4시에 직접 저장하고 끔. 저장은 마지막 반영 직후 사용자에게 부탁(메모리 main-save-user-does-save-as).
12. **외부 아이디어(영상·Gemini·GPT)는 우리 게임 규칙과 먼저 대조.** 영상의 '첫 10분 몰래 쉬움'을 붙였다가 지적받음. Gemini 의견은 코드로 맞다/틀리다만 짧게.
13. **번역은 직역 싫어함:** 한국 정서 현지화("아야! 때리지 마!"), 각 나라 정서(5개 언어도). 게이머 영어(스킬·레벨·보스·퀘스트·스토리…)는 외래어 그대로. "무기는 절대 안 부서져요" 같은 안심 문구는 영어로도 넣지 않음.
14. **새 이름보다 원래 이름**(몬스터 새 이름 두 번 거절 → 그대로).
15. **새 돈·보상 아이디어는 A23-75(스탯 판매 금지)·도감 규칙과 먼저 대조.** 로벅스 기부 → "A23-75와 정면으로 부딪히면 하지 말자"; 도감 진척 보상 → "안 되지 ㅋㅋ".
16. **"퀘스트 지옥"·강요 싫어함:** 연속 보상·압박 없음, 하나만 해도 보상(A23-203·205).
17. 화면이 답답·못생김에 민감: 가운데 정렬, 칩 끼임, 글자 잘림("글자 씹힌다"). 사진 볼 때 "읽히나"까지 본다.
18. 질문은 **번호 한 줄 + 추천 + "답 없으면: 기본값"**. 사용자는 "ㅇㅇ", "추천대로", "가보자공"처럼 짧게 답한다 — 그 짧은 말도 결정이니 SPEC에 적는다.
19. 사용량에 민감(주간 50% 넘으면 줄임). 무거운 일은 Codex(무료)·API 크레딧으로.
20. 사진·스크린샷으로 자주 말한다(대화 첨부 이미지는 파일로 안 남음 → 개발 세션엔 글로 설명). 잘못은 숨기지 말고 바로 말하고, 틀린 숫자는 정정한다(Tripo 715 → 1,815점 정정 사건).

## 4. SPEC 밖에 흩어진 결정·규칙 (메모리 MEMORY.md와 겹치는 건 이름만)
- 세션은 **일 끝나면 스스로 clear**(자동 클리어 기대 X) — 상태 파일 push 뒤 `clear_session("self")`. 최종 검수도 "중간중간 일 정리한 다음 클리어".
- **모델·노력은 최종 검수가 일마다 다시 맞춘다**(set_session_model/effort). 지금: 개발 1·2 Opus 5.5 high, 메인 반영 1 Sonnet 5.5 medium.
- Codex = 상담 파트너(메모리 codex-discuss-user-complaints): 사용자가 "이상해" 한 것·게임성 결정마다 `codex exec -m gpt-6-astra -c model_reasoning_effort=high`. 결과 문서는 `build/codex/`, 확정본은 `docs/design/`.
- 번역 업로드 전 GPT Astra 검토(메모리 translation-review-with-gpt-astra). Gemini는 안 씀(메모리 gemini-cli-dropped).
- 회의실(메모리 council-page): 사용자 글마다 Claude와 GPT(Astra high)가 각자 답, 프롬프트는 Claude·그림은 GPT(`tools/codex_image.py`). 모델 표기 "Claude · Fable 5.1 high / GPT · Astra high".
- Blender 일은 Codex에게(10/14, 디자인 재개 때).
- 몬스터 이름은 원래 그대로. NPC 이름만 한국어(A23-185 목록).
- 개인 서버 월 100 R$ 켬. 강화 연속 실패 보정 없음(A23-203).
- 제작자 계정의 새 저장 골드 300 = 2배 골드 패스 자동 소유(버그 아님, 일반 150).
- 가방 칸: `Config.BagSlots` 12→16→20, 종류 수로 셈(재료+주문서+토닉+여분 무기), 보상은 가득 차도 받음.
- 꽃 오브제(A23-189): 게임에 풀·꽃·덤불 없음, 오브제가 대신. 빛 = HaloFlowerGarden_4v2, 뿔 = HornsFlowerGarden_1v2 확정, 장인 = ArtisanFlowerGarden_1v2 후보(사용자 판정 대기, 디자인 때). 도감 카드 그림은 맛보기였고 디자인 때 새로(A23-195).
- 디자인 재개 때 쓸 것: 부품 2D 판정 4기준(비율·대칭/개수·잘라낸 자국·둥글지 않은데 4면 같음 = 떨어짐), 2D 다시 그릴 목록 `docs/handoff/state/img2.md`, Tripo 계정 2 HD 설정(메모리 tripo-hd-one-shot-parts-method), 꽃 슬라임 3D·도감 카드 15+12종·거위 진짜 걷기(Tripo 리깅).

## 5. 사용자 몫·미답 질문
- 10/15 아침 게시(Alt+P) 했는지 — 확인 안 됨. 10/16 게시판 때 같이.
- 대장장이가 무기 2개 준 상황(두 번 받았나, 가방에 나뭇가지가 남았나) — 미답. 개발 2 추정: 가진 T1 + 다른 무기일 가능성.
- 새 돈 종류 '서버 부스트', '일일 진열 리롤 99 R$' — 미답(가방 칸 패스는 상점 라운드 때).
- 직업별 기본 공격 몸짓 9종 + 소리 3종을 베타에 넣을지 — 미답(10/14).
- Fast Travel 구독 ID 코드 표기 'EXP-' 접두가 맞는지 — 게시판에서 확인.
- 패스 아이콘 5장(art/ui/PassIcon*.png) game-passes API로 올리기 — 아직(올리기 전 5장 직접 보고 하나로 먼저 시험). 6장은 디자인 때.
- 사용자 할 일은 지금 없음(다음 = 10/16 Save As·Alt+P).

## 6. 도구·방법 (자주 쓰는 것)
- **병합:** `py tools/merge_chain.py build <scratch>/mcN <sha>="제목" …` → 트리에 `build/luau_cli_0_741/*`, `build/*.luau`, `place/GoodEvil.rbxlx`(place_english용), `art/models/tripo/weapons/weapons_fit_manifest.json`(weapon_mesh용) 복사 → src 전부 luau-compile → 관련 `tools/test_*.py`(느린 a23_14·first_ko_king·ranking은 `--no-mutations`) → `py tools/merge_chain.py push <트리 sha> <같은 목록>` → `git merge-base --is-ancestor <sha> origin/main` → `git reset -q --keep origin/main`. 본보기 `build/review_kit_1015/chain70.sh`(SP 경로를 새 scratchpad로). push가 timeout이면 같은 명령 다시. 한 번에 시험 셋 이하(PC 렉).
- **가짜 실패:** 임시 트리는 git이 아님 → new_zones·skill_signals 실패 무시. test_audio는 전체 스윕에서 멈춤. main 원래 실패 = costume_physics·halloween·metrics_board(인자)·place_english(성긴 트리)·rank_marks·skeleton_ground·skin_binding_studio·walk_forge_client·weapon_shop_meme(정적) + a23_14 놓침 2·패턴 5. 변이 패턴 matched 0 = 글이 Config.ClientText로 옮겨진 것(코드 아님).
- **반박 검토:** `py tools/api_agent.py run --prompt-file P.md --out build/api_agent/<job> --model sonnet --max-usd 2~4`(큰 서버는 opus). 지적은 그대로 믿지 말고 luau.exe 등으로 재현해 거짓/진짜 가른다(Neutral nil 거짓 사례). 자주 나온 진짜 버그: 약한 키 표(`__mode "k"`) GC로 상태 사라짐, 복제 경로(BindToClose·settle 겹침·pity 루프).
- **공유 트리:** git commit 금지, `py tools/push_paths.py -m "제목" <파일들>`(디렉터리 인자 X). `.git/index.lock` 낡으면 git 프로세스 0개 확인 뒤 rm. Bash heredoc은 `\n`·`\t`를 바꿔 버림 → 이스케이프 든 스크립트는 Write로 파일 만든 뒤 실행.
- **SPEC 쓰기:** `docs/SPEC_ADDENDUM.md` 맨 위(A23 표 바로 아래)에 새 번호, 사용자 원문 인용 + 결정, push 후 `git show origin/main:docs/SPEC_ADDENDUM.md | grep`으로 확인. 지금 마지막 = **A23-207**.
- **번역(한국어):** 클라우드 표 `18c4f901-c48c-4ec3-92e2-b01a8423f4f2`(소스 en), universe 10769445522. 영어 항목 `py tools/l10n_upload.py --csv … --chunk 20`, 한국어 `py tools/l10n_upload_ko.py --csv <Key,Source,Ko> [--by-key]` 또는 `build/review_kit_1015/ko_up.py <csv>`. 숫자 자리는 `{1}`(`%s` 안 됨), 같은 Source엔 한국어 하나. 표는 게시 없이 바로 라이브. 누락 검사 `tools/l10n_coverage.py`(임시 트리에 .env 복사 → 실행 → .env 지움) → missing_ko.csv·suspect_ko.csv. 글이 바뀐 병합마다 한국어 다시 올림. 영어 원문 다듬기 결과 `build/l10n/en_review/en_changes_reviewed.csv`(191줄 반영됨).
- **Codex CLI:** `"/c/Program Files/WindowsApps/OpenAI.Codex_26.1007.9446.0_x64__2p2nqsd0c76g0/app/resources/codex.exe" exec --cd <repo> -m gpt-6-astra -c model_reasoning_effort=high -s workspace-write --skip-git-repo-check -` (프롬프트는 stdin). 이미지는 `-i "a.png,b.png"`(쉼표 하나로). 429 → 하나씩, 10~20분 뒤. `taskkill //F //IM codex.exe`는 Codex 앱까지 끌 수 있음. 코드 읽기 일은 20분 넘게 걸림.
- **Open Cloud 키**(`.env` ROBLOX_OPENCLOUD_KEY, 출력 금지): game-passes 읽기·쓰기 + universe manage(로컬라이제이션) + Assets 읽기·쓰기(10/15 추가). 무기 30개 업로드 끝(`build/weapon_model_ids.json` → MeshId `build/weapon_mesh_ids.json`, main에 메시 연결됨).
- **화면 사용 순서:** 세션 신청 → 사용자에게 "🟠 제어: <세션> — 무엇 — 몇 초" **먼저** → 세션에 "전달함, 시작" → "끝". (10/14 순서를 뒤집은 적 있음.) 한 번에 한 세션. 메인 Studio 창이 최소화되면 3D가 하얗게 찍힘 → 메인 반영 1이 창 복원.
- **게시:** 파일로 연 Studio에서 Alt+P 하면 올릴 곳을 물음 → 새로 만들지 말고 기존 'Halo & Horns'(place 81671223175574) 덮어쓰기. Publish는 사용자만.
- **사진:** 폰 첫 10분 `HH_MAIN_STUDIO=1 py tools/play_phone_round_photos.py first10 out=<dir>`(메인 반영 1만). 개발 1은 메인이 아닌 `build/HoldTest_1014.rbxlx` 복사본에서 찍음(메인과 관절 값이 다르니 최종은 메인 사진). 시험 중 숫자판: `HH_MAIN_STUDIO=1 py tools/test_metrics_board.py --studio --save build/test_metrics_PT1_<날짜>.json --out build/test_metrics_PT1_<날짜>.md` 매일(10/17~20).

## 7. 숫자·ID
- place 81671223175574 · universe 10769445522 · 소유자 userId 11753301316 · 구독 Fast Travel 118606392447792 · 패스 9개 `docs/design/pass_ids_2026-10-14.md`(2x XP 199, 2x Gold 149, VIP 249, 나머지 99).
- 회의실: 페이지 https://claude.ai/artifact/4hhwZZKHM4j2VkmoKw47S1 , 댓글 대상 https://claude.ai/code/artifact/1dfa65bb-632e-4375-ad43-1d153728fe1a (스레드 d9d0f777-c686-4da5-a2dd-d9549cdddfbd). 답 = ArtifactData collection `chat` {who,text,img,alt,ts}, 그림은 asset 올리고 `/_blob/<id>`.
- Tripo 계정 2 잔액 ≈ 18,045(10/14 저녁, 지금 지출 멈춤). Firefly·ChatGPT 생성 = 디자인 때.
- 옛 세션 id(쓰지 말 것): 최종 검수 local_5994bea0-37e5-4d41-a7dc-219c5113b532(제목 '최종 검수 (옛)'로 바꿈). 현재 개발 1 local_13e2d0a2-43ad-4bd2-8b31-0e6f9ab61058, 개발 2 local_3ab5bfc5-f398-42fe-8492-06cc4b09b984, 메인 반영 1 local_cfaf1a19-af50-44e6-9fc1-041d147eea44(바뀔 수 있으니 list_sessions로 확인).

## 8. 정리해도 되는 것
- 옛 scratchpad `C:\Users\glori\AppData\Local\Temp\claude\C--Users-glori-Documents-Roblox-Game\de5eecf9-d637-4ae8-9c1e-cfe8d35ccc52\scratchpad\mc1~mc70`(병합 임시 트리 70개, 디스크 큼) — 필요한 도구는 `build/review_kit_1015/`에 복사해 둠. 지우려면 사용자에게 한 줄 묻고.
- 옛 worktree 다수(`git worktree list`: wt_* 30개 이상, 대부분 이미 병합된 가지) — 개발 세션 것이니 지우기 전 그 세션에 확인.
