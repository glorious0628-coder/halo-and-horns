# 검수 인계 — 2026-10-11 오후 (2번째 검수 → 3번째 검수)

> 이유: 2번째 검수의 대화 창이 75%가 넘어 턴마다 사용량을 많이 먹는다(주간 91%, 리셋 약 5시간 뒤). 사용자: "더 큰 작업도 API로 해도 돼!".
> 먼저 읽을 것: AGENTS.md, MEMORY.md, `docs/handoff/role_prompts/README.md`(모델·노력은 일마다 다시 맞춘다), 이 파일. 이 앞날의 인계 `review_handoff_2026-10-11.md`(낮)는 10/11 정리 때 지웠다(이 파일이 이어받음). 세션 id는 문서에 쓰지 않는다(list_sessions로 찾는다, 10/11 정리에서 이 표의 id 칸을 뺐다).

## 1. 오늘 사용자 결정 (SPEC 새 번호, 새것이 위)
- **A23-126 스킬 공정 2개 "추천대로":** 빛 자기 회복 3%/3초(친구 몫 30% 그대로), 원거리 Q 치유 중심 = 나 기준 12칸 → 개발 2 브랜치 dev2-healfair(아직).
- **A23-125 모든 3D = Tripo(HD 모델 H3.1 + "멀티 뷰 이미지 3D 변환", 4면) → Blender 손보기(반드시) → Roblox 재질 손보기.** P2.0·스마트 메시·한 장 변환은 안 씀(P2.0은 사용자가 이미 써 보고 재질 때문에 뺐다). 동그란 금속 장식은 Blender에서 정확한 모양으로 바꿔 끼운다. 검사표 13번에 넣었다.
- **A23-124 빛 마을 1.5배:** 하늘에 뜬 섬, 595×532, 집 19, 빛 성 100×70. 6단계 때 Zones.HaloTown·Map.Bounds·미니맵·큰 지도를 맞춘다.
- **A23-123 새 구역 몬스터:** 슬라임은 없다. 수정 동굴 몬스터는 도마뱀·버섯·박쥐 B·골렘 B이고, 고슴도치는 이야기 펫이다. 산호 해안은 A(게·해파리·소라게). 4면 2D는 통과했고 Tripo 차례를 기다린다.
- **A23-122 3D 전부 다시 검수:** 결과 `docs/review/3d_recheck_2026-10-11_result.md` — 179개 중 178개 다시, 통과 0. 순서·담당이 그 문서에 있다.
- 빛 성: **C2 확정**(F3c). 확정 세트는 `art/review/s2/halo_castle_c2_final_set.jpg`, 장식 4면(날개 back2·장미창·첨탑 끝 High)은 통과했다.
- 빛 마을 ② 조감 **A3 확정**: 2차(성 C2·돔 0)를 이미지 생성 2가 그리는 중이다.
- **빛 마을 ③ 회색 상자 OK → ④ 건물 골격 진행 중**(`docs/design/halo_restart_2026-10-11.md` 맨 아래 '진행'·'6단계에 같이 넣을 것').
- 쥐기·자세는 참고부터 찾는다(메모 grip-pose-research-references-first). 유튜브는 열자마자 음소거하고 다 보면 닫는다.

## 2. 세션 (전부 2번째 검수가 연 링크 세션 → 3번째 검수로 보고처를 바꿈; id는 list_sessions)
| 세션 | 모델·노력(지금) | 하는 일 → 다음 |
|---|---|---|
| 메인 반영 1 | Sonnet medium | main 2406d35d sync + 사진(지팡이·플라스크 쥐기 twohand_v3, 빛 마을 조명 C2c 낮·밤) |
| 게임성 개발 1 | Opus high | dev1-grips9(fa8c7cfd 대검 자루 1.15+폼멜) + ② 9조합 빈 손 IK 같은 브랜치 → 병합 요청 예정. 사용자 "마법봉 너무 크지 않니?" → 지팡이 크기 줄이기 같이. 한국어 계약 v3 = 메모 붙여 승인(코드 직전 v4에 6개 반영). |
| 게임성 개발 2 | Opus high | dev2-bosshp 고칠 것 6(`docs/review/bosshp_verify_2026-10-11.md`) → dev2-landcircle 시험 패턴(test_halloween 272줄) → dev2-healfair(A23-126). dev2-landcircle + dev1-leapfx(3a95f712)는 같이 병합. (할로윈 시험은 병합 조건이 아니다, 사용자 10/11) |
| 이미지 개발 | Sonnet high | api_agent **쓰기 모드**(worktree 안 쓰기·api/* 브랜치 push) 만드는 중 → 지붕 맵은 재검수 뒤로 미룸. 금 확정 (255,175,25)+R2, 빛 마을 조명 C2c 확정(main 2406d35d). |
| 이미지 생성 1 | Sonnet high | ④ 성문·탑·무기고·전망 탑 골격 끝 → WorldKit 사진 28장 대기(이미지 생성 3 사진이 끝난 뒤 "전달함, 시작"). 5단계 재료 목록 완료. |
| 이미지 생성 2 | Sonnet high | 조감 A3 2차 → 새 집 7채·무기고 2D → 4면 큐(등불 A~E → 화분·토피어리·나무 → 벤치 → 이유 소품 14 → 몬스터 → 무기). |
| 이미지 생성 3 | Opus high | 집 07 fixed.glb 가져옴(사용자 클릭 끝) → 재질 3단계 + 낮·밤 사진(WorldKit 카메라 지금 3 차례) → ④ skeleton_house.py 일반화(집 01~12·가게 4·새 집 7·대성당·빛 성 C2). records.json에 blender_touchup 칸. |

- WorldKit 카메라·창 사진은 한 번에 한 세션만 쓴다. 검수가 "전달함, 시작"으로 순서를 정한다.
- 세션 메시지는 사용자가 한 번 말할 때마다 10개로 막힌다. 막히면 사용자에게 한마디 해 달라고 한다.

## 3. API(api_agent) 쓰는 법 — 앱 사용량 아끼기
- 자세한 것은 `docs/handoff/api_agent_howto.md`. 한 줄: `py tools/api_agent.py run --prompt-file <md> --out build/api_agent/<job> --model sonnet|opus --max-usd N [--max-images N] [--make-worktree <ref> --allow-tests]`. read_image가 있다(2257314).
- 오늘 쓴 것: 3D 판정 179장(Sonnet 4묶음 약 $6) + 반박(Opus 약 $2.3), 한국어 계약 v2·v3 확인(Opus 각 약 $0.8), AGENTS.md 줄이기(초안 → **적용 끝**, 10/11 줄인 판 + `docs/handoff/agents_detail.md`).
- 병합 전 시험은 `$TEMP/run_tests.sh <worktree> name[:flags]...`(2번째 검수가 만든 안전한 실행기, 3개씩)으로 돌린다. `cd X && (a) & (b) &`는 쓰지 않는다 — 첫 줄만 X에서 돌아 공유 트리 기록이 덮였다(되돌렸다).

## 4. 병합 기록 (오늘)
skillq 515a1207, friendpvp f3c2ef5c, twohand ce92d19a·7864b9c6·d7455d46·a2f9d61f, walkground e1213b53, staffgrip 72912234. 걷는 바닥은 클라·서버 모두 끝났다(파트 바닥 + WalkGround 태그).

## 5. 사용자 대기·할 일
- 없음(④ 진행 중, 사진이 오면 ★).
- 나중: 스킬 소리 42개 올리기(크롬 연결 + 소리 세션 새로, 45분), 메인 Studio 저장(메인 반영 1이 부탁하면).
