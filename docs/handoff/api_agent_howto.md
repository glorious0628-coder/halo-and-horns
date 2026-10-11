# api_agent 사용법 (Anthropic API 크레딧으로 큰 일 돌리기) — 2026-10-11

키는 `.env`의 `ANTHROPIC_API_KEY`(스크립트만 읽음). 앱 사용량이 아니라 API 크레딧이 줄어든다. 도구: `tools/api_agent.py`.

## 명령 한 줄
- **읽기·검토(코드 안 바꿈):**
  `py tools/api_agent.py run --prompt-file P.md --out build/api_agent/<job> --model sonnet --max-usd 2`
- **코드 쓰기(브랜치로 받음):**
  `py tools/api_agent.py run --prompt-file P.md --out build/api_agent/<job> --model sonnet --max-usd 5 --max-turns 60 --make-worktree origin/main --write --branch api/<이름>`
- 이미지도 볼 수 있음(read_image, 한 번에 40장까지 `--max-images`). `--out`은 새 이름(`--overwrite`로 덮음).
- 상태: `py tools/api_agent.py status <job>` · 목록과 누적 비용: `py tools/api_agent.py list`.

## 프롬프트 요령 (P.md)
- 맨 앞에 "AGENTS.md를 먼저 읽어라". 그다음 **바꿀 파일·영역**, **읽어야 할 관련 문서**, **돌릴 시험 이름**(`tools/test_*.py`), **끝낼 조건**을 적는다.
- 한 번에 한 덩어리만(파일 몇 개, 시험 하나). 크면 쪼개서 브랜치를 여러 개.
- 모델이 한국어 짧은 커밋 제목을 쓰고 `git_commit`으로 직접 커밋한다. "하지 말 것"(건드리면 안 되는 파일)도 적는다.

## 결과와 브랜치 시험
- 결과: `build/api_agent/<job>/result.md`(보고+코드 변경 요약), `usage.json`(비용·커밋·바뀐 파일·푸시 여부).
- 러너가 끝에 `origin`의 `api/<이름>`만 푸시한다(main 거절, force 없음, 커밋 없으면 안 올림). 커밋 안 된 변경은 버려진다.
- 받아서 시험(검수·개발 세션):
  `git fetch origin api/<이름>` → `git worktree add <임시폴더> origin/api/<이름>` → 그 폴더에서 `py tools/test_<관련>.py`.
- 모델이 `.py`를 바꾸면 그 job 안의 `run_test`가 막힌다(쓴 코드가 곧 실행되지 않게). 시험은 위처럼 사람이 돌린다. `.py` 변경부터 읽기:
  `git diff origin/main...origin/api/<이름> -- '*.py'`. 믿는 일만 `--allow-run-modified-py`.
- 확인 뒤 병합은 검수가(개발 세션은 `api/` 브랜치를 직접 main에 안 올린다). 다 쓴 브랜치는 `git push origin --delete api/<이름>`.

## 비용 한도 권장 (Sonnet 기준 대략)
- 검토 1건 `--max-usd 2` · 작은 코드 수정 `--max-usd 2 --max-turns 30` · 큰 덩어리 `--max-usd 5 --max-turns 60`.
- 한도에 닿으면 모델이 "커밋하고 보고하라"는 알림을 받고 멈춘다. 이미지 많이 읽는 일은 `--max-images`를 줄이고 나눠서.
- Haiku(`--model haiku`)는 아주 작은 일·시험용, Opus는 설계가 어려울 때만(비쌈).
- 못 하는 것: Studio·네트워크·`.env`·`.github`·`build/`·AGENTS.md/CLAUDE.md·실행/스크립트 확장자 쓰기. Studio 시험이 필요한 일은 사람이 한다.
