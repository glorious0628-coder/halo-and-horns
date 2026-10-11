# 인수 검수 — 문서 브랜치 4개 (2026-10-11)

판정: **4개 모두 병합 보류.** Git 충돌 없음은 내용 통과가 아니다. 이번 범위는 정적 1차 검수이며, 전체 문서의 모든 문장·게임 동작·그림 품질을 승인한 결과가 아니다. 아래 확인은 검수 담당이 직접 수행했으며 독립 검사관의 재검증이라고 표시하지 않는다.

## 고정한 입력과 방법

- fetch 후 기준: `origin/main 398733a4`.
- 각 브랜치와 main의 공통 조상부터 tip까지 `git diff --name-status`·실제 diff를 읽었다. 주요 규칙·작업 프롬프트를 AGENTS와 A23-111·119·120~127에 대조했다.
- `git merge-tree --write-tree 398733a4 <tip>`으로 각각의 가상 합침 결과를 확인했다. 공유 checkout·index·main은 변경하지 않았다.
- 삭제 파일의 basename을 합쳐진 tree의 추적 중인 md·py·luau·json·yaml·yml에서 `git grep -n -F`로 검색했다. **문자열 언급 수이며 모두 실행 중인 의존성이라는 뜻은 아니다.** 기록·삭제 안내문·증거 인용도 포함한다. 재검수 때 각 참조의 용도를 분류해야 한다.
- 네 브랜치 모두 `git diff --check` 통과. AGENTS·src·tools·place 변경 없음. core의 SPEC 결정 본문(`## A23.` 이후)은 그 브랜치 공통 조상과 동일함을 비교했다. 삭제된 과거 문서의 안전 규칙이 전부 다른 곳에 보존됐다는 판정까지 한 것은 아니다.
- 재현용 로컬 결과: `build/review_takeover_2026-10-11/audit_md.py`, `md_branch_audit.json`(git 밖). 영구 근거는 아래 tip·경로·줄 번호다.

| 브랜치 | 검사 tip | 변경 파일 | 삭제 | 기준 main과 합침 | 판정 |
|---|---|---:|---:|---|---|
| `api/md-audit-core` | `926e48b0` | 28 | 1 | 충돌 없음 | 아래 규칙·프롬프트 고침 필요 |
| `api/md-audit-design1` | `1df101c9` | 36 | 0 | 충돌 없음 | A23-127 및 기록 우선순위 반영 필요 |
| `api/md-audit-design2` | `7142c9a8` | 37 | 2 | 충돌 없음 | 삭제 참조·근거 없는 일정 변경 고침 필요 |
| `api/md-audit-history` | `f1fd729d` | 78 | 57 | 충돌 없음 | 삭제 19개에 남은 언급의 처리·증거 보존 확인 필요 |

위 합침은 브랜치별 단독 결과다. 다른 브랜치를 먼저 합치면 참조 수가 달라진다. 이번 인계·프롬프트 수정 이후에는 현재 main으로 다시 검사해야 한다.

## 고칠 곳

### core

1. **기록을 현재 규칙으로 올림.** tip의 `docs/handoff/README.md:7`이 `after_reset_2026-10-11.md` 등을 '새 기준 문서'로 올린다. AGENTS의 우선순위 6은 이런 날짜별 기록의 옛 큐·허락을 오늘의 권한으로 쓰지 못하게 한다. 읽는 순서와 참고 자료를 나누고 현재 브랜치·사용자 결정으로 재확인하도록 고친다.
2. **복사할 프롬프트 안의 3D 방법이 그대로 낡음.** `docs/handoff/role_prompts/10_img3.md:9-10`은 집 몸통을 Tripo로 만들고 소품을 앞면 한 장으로 돌리라고 한다. 바깥의 경고만으로는 복사된 시작 프롬프트를 고칠 수 없다. 코드 블록 안을 Studio 골격·4면 Tripo·Blender 필수 보정으로 교체해야 한다.
3. **최신 인계와 작업 순서가 뒤처짐.** README:6은 11b를 최신이라고 쓰며 `state/img2.md:3`은 무기를 큐 끝에 둔다. 인수 직전 최신 11c에는 무기 우선이 기록돼 있다. 현재 확인과 새 11d 인계를 먼저 반영하고, 그림 통과 표시는 승인 근거를 다시 확인해야 한다.

이번 검수에서 공유 폴더의 인계 README·검수/메인/3D 시작 안내를 별도 수정했다. 이 브랜치 전체가 고쳐지거나 병합됐다는 뜻은 아니다.

### design1

1. **기록의 숫자를 다시 설계 기준으로 선언함.** `docs/design/gathering_2026-10-06.md:5`의 '채집 규칙·숫자 자체는 이 문서가 설계 기준'은 AGENTS의 기록 분류와 충돌한다. 숫자는 최신 SPEC·GDD·코드에서 확인된 것만 구분하고, 옛 초안의 수치를 자동 승인하지 않는다.
2. **새 제작 결정 반영 부족.** `docs/design/commission_server_2026-10-09.md:6`은 오토의 T4~T6 의뢰를 장인 미니게임으로 이어갈 현재 계획처럼 고친다. A23-127 §2는 오토 무기 판매·의뢰가 새 장인 전용 제작과 충돌하므로 재설계하도록 한다. 기존 구현 기록과 미래 재설계를 분리하고 확정되지 않은 계승 방식을 만들지 않는다.

### design2

1. **지우는 두 문서의 언급이 남음.** `sound_cleanup_preview_2026-10-07.md`는 1곳, `sound_wiring_onepass_2026-10-07.md`는 5곳이다. 후자 5곳 중 하나는 새로 단 삭제 안내문이다. 남은 옛 인계와 `sound_play_check_2026-10-07.md:5`의 경로는 기록 보존 또는 Git 근거 경로로 정리한 뒤 삭제 판단을 한다. 단순히 '안 쓰는 파일'로 확정하지 않는다.
2. **중간 일정이 자동으로 미뤄졌다고 단정함.** `skills18_2026-10-10.md:584`의 '10/21~23 … 이 기간 날짜도 늦춰짐'은 A23-119에서 확인되지 않는다. 확인된 기능 마감만 고치고 중간 일정은 옛 계획/재확인 필요로 남긴다.
3. **같은 안내문 안에 모순이 남음.** `quest_chain_2026-10-06.md:2`는 앞에서 장인 베타 포함, 뒤에서 '장인 진영 베타 제외(A23-57)'라고 한다. 이전 결정을 명확히 과거로 표시한다.

### history

57개 삭제 중 19개에 문자 참조가 남았다. 전부 살아 있는 작업 지시라는 뜻은 아니지만, '참조 없음'으로 보고할 수 없다. 특히 JSON의 `source`·`file`이 가리키는 증거 문서는 재현 가능한 Git 버전 또는 보존 파일이 필요하다.

| 삭제 후보 | 남은 언급 수 | 예시 |
|---|---:|---|
| `docs/art/codex_brief_tripo_fidelity.md` | 4 | `docs/design/visual_direction_2026-10-05.json:2631` |
| `docs/art/costume_rig_plan_2026-10-03.md` | 2 | `docs/HANDOFF_CODEX.md:376` |
| `docs/art/playthrough_progress_2026-10-04.md` | 4 | `docs/review/reference_lessons_2026-10-05.json:86` |
| `docs/handoff/account_switch_2026-10-08_2100.md` | 6 | `docs/HANDOFF_CODEX.md:9`, `docs/design/film_session_handoff_2026-10-06.md:6` |
| `docs/handoff/dev1_2026-10-08_audit.md` | 1 | `docs/review/style_drift_2026-10-08.md:202` |
| `docs/handoff/dev1_handoff_2026-10-07.md` | 2 | `docs/handoff/review_handoff_2026-10-07.md:11` |
| `docs/handoff/dev2_handoff_2026-10-07.md` | 2 | `docs/handoff/dev2_2026-10-07_evening.md:8` |
| `docs/handoff/game_dev1_status_2026-10-06.md` | 1 | `docs/design/zone_check_halo_2026-10-10.md:116` |
| `docs/handoff/image_gen2_status_2026-10-06.md` | 1 | `docs/design/image_gen2_session_handoff_2026-10-06.md:43` |
| `docs/handoff/imagegen1_handoff_2026-10-07.md` | 1 | `docs/handoff/review_handoff_2026-10-07.md:14` |
| `docs/handoff/imagegen2_handoff_2026-10-07.md` | 1 | `docs/handoff/review_handoff_2026-10-07.md:15` |
| `docs/handoff/imgdev_handoff_2026-10-07.md` | 1 | `docs/handoff/review_handoff_2026-10-07.md:13` |
| `docs/handoff/review_handoff_2026-10-11.md` | 1 | `docs/handoff/review_handoff_2026-10-11b.md:4`의 삭제 안내 |
| `docs/handoff/sound_handoff_2026-10-07.md` | 1 | `docs/handoff/review_handoff_2026-10-07.md:16` |
| `docs/review/external_findings.md` | 1 | `docs/review/reference_lessons_2026-10-05.json:107` |
| `docs/review/round2_inputs.md` | 2 | `docs/HANDOFF.md:41` |
| `docs/review/worker_addendum_2026-10-05.md` | 1 | `docs/review/checkpoint_2026-10-05_1400_snapshot.json:1087` |
| `docs/review/worker_fix_2026-10-05_1400.md` | 1 | `docs/HANDOFF_CODEX.md:127` |
| `docs/review/worker_prompt_2026-10-06.md` | 11 | `docs/HANDOFF_CODEX.md:141`, 검증 JSON 여러 곳 |

삭제 안내문과 역사적 인용을 구분해 보존/참조 변경/삭제 이유를 파일별로 남긴다. AGENTS의 복장·금지 업로드·Publish·비밀 키 규칙이 현재 규칙 문서에서 빠지지 않았는지도 최종 합침 전체에서 확인한다. 이번에는 삭제를 실행하지 않았다.

## 재검수 조건

- 현재 main에서 위 내용을 고치고 변경된 tip을 고정한다. 수정 없는 옛 승인·시험 보고로 통과 처리하지 않는다.
- 현재 규칙과 참고 기록의 경계를 유지하고, 날짜 변경으로 새 기능·일정·그림 승인을 만들지 않는다.
- 삭제 참조를 최종 합침 tree에서 다시 검색하고 의도적인 역사 인용에는 되찾을 근거를 남긴다.
- 작은 문서 안내 수정은 `git diff --check`·경로 확인·실제 diff 읽기로 검증한다. 게임 코드·place를 건드리지 않은 문서 변경을 위해 Studio Play를 수행하지 않는다.

## 이번 인수 문서의 별도 검토

수정한 문서 8개(인계 README, 역할 README, 검수·메인 반영·3D 프롬프트, 검수 state, 11d 인계, 이 보고서)를 별도 검사관과 반박 검사관이 읽기 전용으로 확인했다. 상태·경로·역할 경계에 지적 없음. 반박 검사관은 고정 tip의 변경·삭제·참조 수와 예시 줄도 대조해 일치를 확인했다. 이 결과는 인수 문서 검토이며, 네 API 브랜치 전체에 대한 병합 승인이나 Studio 검증으로 확대하지 않는다.
