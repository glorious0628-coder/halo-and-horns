# Tripo API v3 공부 노트 (한국어)

- 출처: 이 폴더(`docs/vendor/tripo_api`)에 저장한 Tripo 공식 문서 43개 전부 (2026-10-03 저장본).
- 대상: 처음 보는 사람(초보) + 이 문서를 보고 파이썬 스크립트를 짜는 사람(구현 담당).
- 표시 규칙
  - **[문서]** 문서에 그대로 적힌 사실
  - **[추정]** 문서에 없고 우리가 짐작한 것 → 첫 테스트에서 확인해야 함
  - **[충돌]** 문서끼리 말이 다른 곳
- 바쁘면 **0장 → 1장 → 9장 → 10장**만 읽어도 된다.

---

## 0. 용어 풀이 (처음 보는 사람용)

| 말 | 뜻 |
|---|---|
| API | 사람이 웹사이트 버튼을 누르는 대신, 프로그램(파이썬)이 Tripo 서버에 직접 "이거 만들어줘" 하고 요청하는 통로 |
| API 키 | 우리 계정임을 증명하는 비밀번호 같은 문자열 (`tsk_...`로 시작). 남한테 보이면 안 됨 |
| 크레딧 | Tripo 안에서 쓰는 돈. 1크레딧 = 0.01달러(약 14원). 미리 충전해 두고 씀 |
| 작업(task) | "이 그림을 3D로 만들어줘" 같은 요청 하나. 만들면 `task_id`(작업 번호)를 받음 |
| 폴링(polling) | 작업이 끝났는지 몇 초마다 다시 물어보는 것 |
| GLB / FBX | 3D 모델 파일 형식. GLB는 그림(텍스처)까지 한 파일에 들어있음. 로블록스 3D 가져오기는 둘 다 됨 |
| face(면) / 삼각형 | 3D 모델을 이루는 작은 조각. 로블록스는 MeshPart 하나에 **삼각형 2만 개까지** |
| quad(사각면) | 사각형 조각. 사각면 1개 ≈ 삼각형 2개 |
| 텍스처 | 3D 모델 표면에 입히는 그림 (눈, 옷 무늬 등) |
| PBR | 색 그림 말고도 금속 느낌·거칠기·요철 그림을 같이 만드는 방식 |
| 리깅(rig) | 3D 모델 안에 뼈대를 넣어 움직일 수 있게 하는 것 |
| 리타깃(retarget) | 미리 만들어진 동작(걷기, 뛰기 등)을 우리 뼈대에 입히는 것 |
| 리토폴로지 | 면 개수를 줄이면서 모델 모양을 다시 짜는 것 (텍스처가 흐려질 수 있음) |

---

## 1. 한눈에 보기

### 1.1 기본 주소와 인증 [문서]
- 기본 주소(Base URL): `https://openapi.tripo3d.ai/v3`
  - 옛 v2 주소 `https://api.tripo3d.ai/v2/openapi/` 는 쓰지 말 것. (이전 안내 문서는 "v2와 v3는 **아직 같이 돌아간다**, 천천히 옮겨라"라고 함. `2015` 오류(버전 폐기)가 v2에서 나는지는 문서에 없음 → 그냥 v3만 쓴다.)
  - v2에서 만든 작업도 v3 `GET /v3/tasks/{id}` 로 조회 가능 (작업 id 형식 같음).
  - 중국용 사이트(developers.tripo3d.com)는 따로 있음. 우리는 국제판.
  - 프론트엔드(브라우저) 코드에 키를 넣지 말 것 → 서버/로컬 스크립트에서만 부른다 (인증 문서).
  - 새 계정은 무료 크레딧을 조금 받음 (Codex 플러그인 문서). 양은 문서에 없음.
- 모든 요청 헤더: `Authorization: Bearer <API 키>`
- 본문이 있는 POST는 `Content-Type: application/json` 도 붙인다. (단, 파일 업로드 `POST /v3/files` 는 multipart라서 이 헤더를 **직접 넣으면 안 됨**.)
- API 키 만들기: https://platform.tripo3d.ai → API Keys → Create Key. **키는 만든 직후 한 번만 보여줌** → 그때 복사.
- 키 보관 규칙
  - 환경변수 `TRIPO_API_KEY` 에 넣고 코드에서 `os.environ["TRIPO_API_KEY"]` 로 읽는다.
  - 코드·git·스크린샷·로그에 절대 넣지 않는다. `.env` 를 쓰면 `.gitignore` 에 넣는다.
  - 새면 콘솔에서 지우고 새로 만든다.
  - 윈도우에서 영구 설정 (사용자가 직접 PowerShell에 입력):
    `[System.Environment]::SetEnvironmentVariable("TRIPO_API_KEY","tsk_...","User")` → 터미널 다시 열기.
- v2 키와 v3 키는 같은 것 (새로 안 만들어도 됨).

### 1.2 응답 형식 [문서]
- 성공: `{"code": 0, "data": {...}}`
- 실패: `{"code": 2010, "message": "Insufficient credits", "suggestion": "Please top up your account", "request_id": "req_abc123"}`
- **`code == 0` 인지 먼저 확인하고 나서 `data` 를 읽는다.** 공식 빠른 시작 예제는 확인을 안 해서 오류 때 KeyError가 남.
- `request_id` 는 문의할 때 필요하니 로그에 남긴다. (소개 문서의 오류 예시에는 `request_id` 가 없음 → 없을 수도 있다고 보고 `.get()` 으로 읽기)
- `message`, `suggestion` 은 실패 때만, `data` 는 성공 때만 온다.
- **예외: OpenAI 호환 주소(`/v3/openai/...`)는 이 형식이 아니다.** 성공은 OpenAI 모양, 실패는 `{"error": {"message","type","param","code"}}` (3.7 참고).
- `task_id`, `file_token` 은 문서마다 `task_abc123` / `file_abc123` 처럼 접두사가 붙은 예와 `550e8400-...` 같은 UUID 예가 섞여 있음 → **접두사로 모양 검사하지 말 것.**

### 1.3 비동기 작업 흐름 [문서]
1. 만들기 요청(POST) → 곧바로 `{"code":0,"data":{"task_id":"task_..."}}` 를 돌려받음. (결과는 아직 없음)
2. `GET /v3/tasks/{task_id}` 로 1~2초마다 상태 확인 (여러 개면 `POST /v3/tasks/list`).
3. 상태가 `success` 가 되면 `output.model_url` 에서 GLB를 **바로** 내려받는다 (링크가 시간이 지나면 만료됨).
4. 다음 단계(리깅 등)는 `"input": "<앞 작업 task_id>"` 로 이어붙인다.

상태 값 7가지:

| status | 뜻 | 끝난 상태? |
|---|---|---|
| `queued` | 줄 서서 기다리는 중 (progress 0) | 아니오 |
| `running` | 만드는 중 (progress 0~100) | 아니오 |
| `success` | 완료, `output` 있음 | 예 |
| `failed` | 실패 (보통 서버 쪽 문제) | 예 |
| `banned` | 입력 그림/글이 콘텐츠 정책 위반 → 그림을 고쳐서 다시 | 예 |
| `expired` | 작업이 만료됨, 결과 파일 사라짐 | 예 |
| `cancelled` | 취소됨 | 예 |

- **공식 예제 폴링 코드는 `expired` 를 빼먹었다.** 우리 코드는 `failed / banned / expired / cancelled` 넷 다 끝으로 처리.
- 공식 예제의 제한 시간 5분은 짧다. 텍스처 포함 H3.1은 약 120초 + 대기열 → **10~15분**으로 잡는다.

### 1.4 돈(크레딧) [문서]
- 선불 충전식. **1크레딧 = 0.01달러** (100크레딧 = 1달러).
- 작업을 만들 때 필요한 크레딧이 "묶임(frozen)" → 성공하면 "사용됨", **실패·취소되면 그대로 돌려받음** (청구 없음).
- 잔액이 모자라면 작업이 아예 안 만들어지고 `2010` 오류 (HTTP 403). 이때도 청구 없음.
- 잔액 확인: `GET /v3/account/balance` → `{"balance": 10000.00, "frozen": 200.00}`
- 사용 내역: `GET /v3/account/usage` → `data` 가 **배열**: `[{"task_id","type","credits_consumed","created_at"}]` (기간 필터·페이지 넘김 파라미터는 문서에 없음)
- 크레딧 숫자는 소수점 2자리까지 나옴 (VIP 할인 때문). **int로 바꾸지 말고 float/Decimal로 읽는다.**
- 웹 스튜디오 구독 크레딧과 API 크레딧이 같은지는 문서에 없음 [추정: 따로일 가능성 → 콘솔에서 확인].
- 콘솔 Billing → Credit alert 에서 잔액 부족 알림을 켤 수 있음 (알림 자체가 작업을 실패시키지는 않음).
- 기업용 대량 구매 문의: business@tripo3d.ai (가격표).

---

## 2. 엔드포인트 전체 표

주소는 모두 `https://openapi.tripo3d.ai/v3` 뒤에 붙는다. 비용은 크레딧. 동시 실행 한도는 아래 7장 참고 (계정 단위, 분류별).

### 2.1 3D 만들기

| 경로 | 용도 | 비용 | 동시 실행 분류 |
|---|---|---|---|
| `POST /generation/text-to-model` | 글 → 3D | H: 텍스처 없음 10 / 표준 20 / HD 30 / 8K 40. P1: 30 / 40 / HD 50. P2: 100 / 110 / 120 / 130 | H 또는 P |
| `POST /generation/image-to-model` | 그림 1장 → 3D (**우리 주력**) | H: 20 / 30 / HD 40 / 8K 50. P1: 40 / 50 / HD 60. P2: 100 / 110 / 120 / 130 | H 또는 P |
| `POST /generation/multiview-to-model` | 여러 방향 그림 → 3D | 이미지→3D 와 같음 (H 20/30/40, P1 40/50/60, P2 100/110/120/130) | H 또는 P |
| `POST /generation/image-to-splat` | 그림 → 가우시안 스플랫 (Java SDK에만 있음, API 문서 페이지 없음) | 30 | 문서에 없음 |

H 시리즈 추가 요금(기본값 위에 더함): HD 텍스처 +10, 8K 텍스처 +20 (둘 다 "표준 텍스처" 값 위에), HD 지오메트리(`geometry_quality: detailed`) +20, quad +5, smart_low_poly +10, generate_parts +20.
P 시리즈 텍스처 추가 요금: 표준 +10 / HD(`detailed`) +20 / 8K(`extreme`) +30 (텍스처 없음 값 위에). P2는 변경 기록에 110/120/130 이 적혀 있음. **P1의 extreme 값은 문서에 없음** [추정: 같은 규칙이면 이미지→3D 70, 글→3D 60].
`texture_quality: "fast"` 는 standard 와 같은 값.

### 2.2 2D 그림 만들기

| 경로 | 용도 | 비용 | 분류 |
|---|---|---|---|
| `POST /generation/text-to-image` | 글 → 그림 (참고 그림 못 받음) | 모델별 5~50 (아래 3.7) | 이미지 생성 (동시 1개) |
| `POST /generation/image-to-image` | 그림 수정·스타일 변경·여러 그림 합치기·T포즈 변환 등 | 위와 같음 | 이미지 생성 |
| `POST /generation/image-to-multiview` | 그림 1장 → 앞/왼/뒤/오른쪽 4장 | 10 | 이미지 생성 |
| `POST /generation/edit-multiview` | 4방향 그림 중 일부 고치기 | 고친 그림당 5 | 이미지 생성 |
| `POST /openai/images/generations` | OpenAI 방식 글→그림 (기다렸다 바로 받음) | 네이티브와 같음 | 이미지 생성 |
| `POST /openai/images/edits` | OpenAI 방식 그림 수정 | 네이티브와 같음 | 이미지 생성 |

### 2.3 모델 후처리

| 경로 | 용도 | 비용 | 분류 |
|---|---|---|---|
| `POST /models/texture` | 텍스처 다시 입히기 | fast 10 / standard 10 / HD 20 / 8K 30 | 모델 처리 (5) |
| `POST /models/convert` | 형식 변환 (FBX 등), 텍스처 크기 지정 | 기본 5 / 고급 10 | 모델 처리 (5) |
| `POST /models/refine` | 초안 모델 다듬기 (v2 시절 기능, API 문서 페이지 없음) | 가격표에 없음 | 모델 처리 (5) |
| `POST /models/import` | 외부 3D 파일을 Tripo 작업으로 등록 | 가격표에 없음 | 표에 없음 |
| `POST /models/stylize` | 스타일 변환 (API 문서 페이지 없음. ComfyUI 노드 기준 `lego`, `voxel`, `voronoi`, `minecraft`, `block_size` 1~1000 기본 80) | 가격표에 없음 | 표에 없음 |
| `POST /mesh/segment` | 모델을 부위별로 자르기 | 40 (스마트: 모델 55 / 이미지 85. 어떤 요청이 "스마트"로 계산되는지 문서에 없음 [추정: v2.0 모델, `ref_image` 넣으면 85]) | 메시 작업 (10) |
| `POST /mesh/complete` | 잘린 부위 구멍 메우기 | AI 50 / quick_cap 30 | 메시 작업 (10) |
| `POST /mesh/decimate` | 리토폴로지 (면 줄이기) | v2.0 스마트 30 / v1.0 기본 10 | 메시 작업 (10) |

### 2.4 애니메이션

| 경로 | 용도 | 비용 | 분류 |
|---|---|---|---|
| `POST /animations/rig-check` | 뼈를 넣을 수 있는지 검사 | **무료 (0)** | 애니메이션 (10) |
| `POST /animations/rig` | 자동 리깅 | 25 (예제 결과에는 30.00 [충돌]) | 애니메이션 (10) |
| `POST /animations/retarget` | 동작 입히기 | 동작 1개당 10 (예제 결과에는 20.00 [충돌]) | 애니메이션 (10) |

### 2.5 작업·파일·계정 (가격표에 없음 = 요금 없는 것으로 보임)

| 경로 | 용도 |
|---|---|
| `GET /tasks/{task_id}` | 작업 1개 조회 |
| `POST /tasks/list` | 작업 여러 개(최대 100개) 한 번에 조회 |
| `POST /files` | 파일 업로드 (multipart) → `file_token` |
| `POST /files/presign` | 큰 파일 업로드용 서명 URL 받기 (변경 기록에는 `/files/upload-credentials` 라고 적힘 [충돌]. 실제 문서 페이지는 `/files/presign`) |
| `GET /account/balance` | 잔액 |
| `GET /account/usage` | 사용 내역 |

### 2.6 v2 → v3 바뀐 점 (옛 예제를 볼 때)
- v2는 `POST /v2/openapi/task` 하나에 `"type": "image_to_model"` 을 넣었음 → v3는 기능마다 주소가 따로. 요청 본문에 `type` 을 넣지 않는다.
- v2 `type` → v3 주소 전체 대응:

| v2 type | v3 주소 |
|---|---|
| `text_to_model` / `image_to_model` / `multiview_to_model` | `/generation/text-to-model` / `image-to-model` / `multiview-to-model` |
| `text_to_image` | `/generation/text-to-image` |
| `generate_image` | `/generation/image-to-image` |
| `generate_multiview_image` | `/generation/image-to-multiview` |
| `edit_multiview_image` | `/generation/edit-multiview` |
| `refine_model` / `convert_model` / `import_model` / `stylize_model` / `texture_model` | `/models/refine` / `convert` / `import` / `stylize` / `texture` |
| `animate_prerigcheck` / `animate_rig` / `animate_retarget` | `/animations/rig-check` / `rig` / `retarget` |
| `mesh_segmentation` / `mesh_completion` / `highpoly_to_lowpoly` | `/mesh/segment` / `complete` / `decimate` |
| `GET /v2/openapi/task/{id}` | `GET /tasks/{id}` |
| `POST /v2/openapi/upload` | `POST /files` |

- v2 이름 일부는 v3 응답에도 남아 있음: 작업 조회의 `type` (예: `generate_multiview_image`, `mesh_segmentation`).
- v3에서 새로 생긴 것: `POST /tasks/list`, `GET /account/usage`, 큰 파일 업로드.
- 이전 안내 문서는 옮기기용 AI 스킬 파일(`SKILL.md`)을 내려받게 해 줌. 우리는 v2 코드가 없어서 필요 없음.
- v2의 `file`, `file_token`, `url`, `object`, `draft_model_task_id`, `original_model_task_id` → v3는 전부 `input` 하나 (task_id / file_token / URL 을 서버가 알아서 구분).
- `create_time` → `created_at`, `consumed_credit` → `credits_consumed`.
- v2는 모델 이름 필드가 `model_version`, 결과 필드가 `output.model` → v3는 `model`, `output.model_url`.
- 응답의 `type` 값은 여전히 밑줄 표기 (`"image_to_model"`).
- v2 `highpoly_to_lowpoly` = v3 `/mesh/decimate`, v2 `animate_prerigcheck` = v3 `/animations/rig-check`.

---

## 3. 이미지 → 3D 자세히

### 3.1 모델 고르기: H3.1 vs P1 vs P2

같은 주소(`/generation/image-to-model`)에 `model` 값만 바꾸면 시리즈가 바뀐다.

| 항목 | H3.1 `v3.1-20260211` | P1 `P1-20260311` | P2 `P2-20260801` |
|---|---|---|---|
| 성격 | 최신 고품질, **기본값** | 로우폴리 전문, 토폴로지(면 배치) 가장 깔끔 | P1 업그레이드, **미리보기(Preview)** 단계 |
| 걸리는 시간 | 텍스처 없이 약 40초, 텍스처 포함 약 120초 | 약 10초 / 약 60초 | 문서에 없음 |
| face_limit 범위 | 상한 150만(Ultra 200만). 하한 문서에 없음. 안 넣으면 자동 (**2만 넘을 수 있음**) | 50~20,000 (models.md는 48~ [충돌]) | 삼각형 48~50,000, quad 48~25,000 |
| 이미지→3D 비용 (없음/표준/HD) | 20 / 30 / 40 (8K 50) | 40 / 50 / 60 | 100 / 110 / 120 (extreme 130) |
| geometry_quality | 있음 (+20) | 없음 | 없음 |
| smart_low_poly | 있음 (+10) | 없음 | 없음 |
| quad | 있음 (+5, **FBX 강제**) | **없음 (보내면 HTTP 400)** | 있음 |
| generate_parts | 있음 (+20) | 없음 | 없음 |
| compress | 있음 | 없음 | 없음 |
| 동시 실행 | H 분류 | P 분류 | P 분류 |

- 옛 모델: `v3.0-20250812` (안정판), `v2.5-20250123` (옛날). v2.5에는 `texture_quality, geometry_quality, auto_size, quad, smart_low_poly, generate_parts, compress` 를 보내면 안 됨 (v3.0 이상 전용).
- **모델 이름 표기 [충돌]**: 빠른 시작·모델 안내 페이지는 `tripo-v3.1`, `tripo-p1`, `tripo-v3.0`, `tripo-v2.5` 같은 별칭을 쓰고, 각 기능 페이지는 날짜가 붙은 `v3.1-20260211`, `P1-20260311` 을 쓴다. **날짜 붙은 이름을 쓴다** (문서도 실제 서비스에서는 버전을 고정하라고 권함).
- **`model` 필수인가 [충돌]**: 기능 페이지는 "Required", 모델 안내·이전 안내 문서 예제는 `model` 없이 보냄(기본값 v3.1). → **항상 넣는다.**
- 걸리는 시간 (models.md): 리깅 약 30초, 리타깃 약 5초.
- 의외의 사실: **H3.1이 P1보다 싸다** (표준 텍스처 30 vs 50). P1의 장점은 가격이 아니라 깔끔한 면 배치.
- Tripo CLI는 "로우폴리" 또는 "면 2만 이하"라고 하면 알아서 P1을 고른다. 우리 스크립트는 직접 고른다.

### 3.2 요청 파라미터 전체 표 (image-to-model)

"지원" 칸: H = H시리즈(v3.0 이상), P1, P2.

| 이름 | 타입 | 기본값 | 허용값 / 범위 | 지원 | 설명 |
|---|---|---|---|---|---|
| `input` | string | (필수) | file_token / 공개 URL / 이미지 생성 작업(`text_to_image`·`image_to_image`)의 task_id 중 **딱 하나** | 전부 | PNG·JPEG·WebP, 20MB 이하, 256×256 이상 권장, 배경 깨끗하게, 가림 적게 |
| `model` | string | (필수) | `v3.1-20260211`, `v3.0-20250812`, `v2.5-20250123`, `P1-20260311`, `P2-20260801` | 전부 | 시리즈 결정 |
| `model_seed` | int | 무작위 | 정수 | 전부 | 같은 시드 + 같은 입력 → 같은 모양 |
| `texture_seed` | int | 무작위 | 정수 | 전부 | 같은 시드 → 같은 텍스처. **모양은 두고 텍스처만 다시 뽑기** = model_seed 고정, texture_seed 변경 |
| `face_limit` | int | 자동 | 3.4 참고 | 전부 | 최대 면 수 |
| `texture` | bool | `true` | | 전부 | false = 텍스처 없는 맨 모양 |
| `pbr` | bool | `true` | | 전부 | base_color + metallic + roughness + normal 맵. **pbr=true 이면 texture 도 강제로 true** |
| `texture_quality` | string | `standard` | `fast`, `standard`, `detailed`(=HD), `extreme`(=8K) | 전부 | fast는 v3.5 텍스처 전용 |
| `texture_version` | string | 모양 모델에 따라 자동 | `v3.5-20260815`, `v3.0-20250812`, `v2.5-20250123` | 전부 | 텍스처 모델을 따로 고정. **생략하면 v3.0** (v2.5 모양만 v2.5) |
| `delight` | bool | `true` | | 전부 (v3.5 텍스처에서만 작동) | 그림에 그려진 조명·그림자를 지우고 텍스처화. false = 원래 명암 유지 |
| `texture_alignment` | string | `original_image` | `original_image`, `geometry` | 전부 (글→3D 에는 없음) | 원본 그림 색에 맞출지, 만들어진 모양에 맞출지 |
| `orientation` | string | `default` | `default`, `align_image` | 전부 (글→3D 에는 없음) | align_image = 입력 그림 시점에 모델 방향 맞춤. 텍스처 켜져 있어야 효과 |
| `enable_image_autofix` | bool | `false` | | 전부 (이미지→3D만) | 입력 그림을 AI가 손봐서 개선. 그린 얼굴이 바뀔 위험 |
| `geometry_quality` | string | `standard` | `standard`, `detailed`(=Ultra) | H만 | 더 세밀한 모양 (+20) |
| `auto_size` | bool | `false` | | 전부 | 실제 크기(미터)로 맞춤 |
| `quad` | bool | `false` | | H, P2 | 사각면 출력. H에서는 **FBX로 강제**, face_limit 없으면 1만 면. P2에서도 FBX로 강제되는지는 문서에 없음 |
| `smart_low_poly` | bool | `false` | | H만 | 손으로 다듬은 듯한 깔끔한 로우폴리. 면 수 삼각형 500~20,000 고정. 복잡한 모델은 가끔 실패 |
| `generate_parts` | bool | `false` | | H만 | 부위별로 나뉜 모델. **texture=false 와 pbr=false 둘 다 보내야 함** (아니면 1004). quad는 조용히 무시, smart_low_poly 와 같이 보내면 부위가 안 나뉨 |
| `compress` | string | 없음 | `geometry` | H만 | meshopt 압축. 로블록스·블렌더 호환 불확실 → 쓰지 말 것 [추정] |
| `export_orientation` | string | `+x` | `+x`, `-x`, `+y`, `-y` | 전부 | 앞방향 축. **나중에 리깅·변환할 거면 넣지 말 것** (방향이 틀려도 success로 나옴) |
| `export_uv` | bool | `true` | | 전부 | 생성 때 UV 펼치기. false = 더 빠르고 파일 작음, UV는 텍스처 단계에서 펼친다고 함. 우리는 true 유지 |

텍스트→3D 에만 있는 것: `prompt` (필수, 1024자. 모양·재질·스타일·크기를 적으라고 권함. 예: "A box." 는 나쁜 예), `negative_prompt` (255자), `image_seed` (글→그림 내부 단계 시드).
텍스트→3D 에 **없는** 것: `input`, `enable_image_autofix`, `texture_alignment`, `orientation`.
멀티뷰→3D 는 `input` 대신 `inputs` (3.5 참고), `enable_image_autofix` 없음.

### 3.3 얼굴·눈이 뭉개질 때 쓸 수 있는 손잡이

| 손잡이 | 효과 | 우리 판단 |
|---|---|---|
| `texture_quality: "detailed"` | 텍스처 더 세밀 (+10) | **기본으로 켠다** |
| `texture_quality: "extreme"` | 8K 텍스처 (+20) | 우리는 결국 1024로 줄이니 아까움. fix_face.py 머리 굽기 원본으로 쓸 때만 시험해볼 가치 |
| `texture_quality: "fast"` | 빠르지만 덜 세밀, **값은 standard와 같음** | 쓰지 않음 |
| `texture_version: "v3.5-20260815"` | 최신 텍스처 모델 | **명시해서 넣는다** (안 넣으면 자동으로 v3.0) |
| `delight` | 그림 속 명암 제거 여부 (v3.5에서만) | 만화풍이라 `false`(그린 명암·눈 하이라이트 유지)부터 시험, `true` 와 비교 [추정] |
| `texture_alignment: "original_image"` | 원본 그림 색 우선 | 기본값 그대로 |
| `orientation: "align_image"` | 모델 방향을 그림 시점에 맞춤 | 얼굴 정면 투영이 더 맞을 수 있음 → 비교 시험 [추정] |
| `geometry_quality: "detailed"` | 모양 세밀 (+20, H만) | 얼굴 굴곡이 뭉개질 때만 |
| `model_seed` + `texture_seed` | 좋은 모양을 잡으면 텍스처만 다시 뽑기 | **매번 직접 시드를 정해서 보내고 기록** (응답에 시드가 안 나옴) |
| 멀티뷰 입력 | 옆·뒤 정보가 있어 뒤통수·옆 얼굴 덜 뭉개짐 | 보스·중요 캐릭터에 |
| `/models/texture` 재텍스처 | 모양은 두고 텍스처만 새로 (HD 20) | 얼굴만 망했을 때 |
| `/mesh/segment` + `/models/texture` 의 `part_names` | 머리 부위만 다시 텍스처 | 실험적. fix_face.py로 충분하면 불필요 |
| `enable_image_autofix` | 입력 그림 AI 보정 | 쓰지 않음 (GPT 그림은 이미 고해상도, 디자인이 바뀔 위험) |

웹 스튜디오에서 "따로 리토폴로지하면 흐려지는" 이유 [추정]: `/mesh/decimate` v2.0은 `bake: true`(기본)로 원래 텍스처를 새 저폴리 메시에 **다시 구워** 옮긴다. 이 굽기에서 흐려진다. → **만들 때부터 `face_limit` 을 주면** 텍스처가 최종 메시에 바로 만들어져 다시 굽기가 없다.

### 3.4 face_limit 정리 (로블록스 2만 삼각형)

| 상황 | 범위 |
|---|---|
| H, 일반 삼각형 | 상한: v3.1 150만 (Ultra 200만), v3.0 100만 (Ultra 200만), v2.5 50만. 하한 문서에 없음. 생략 = 자동(2만 넘을 수 있음) |
| H, quad | 상한 15만. 생략 시 1만 |
| H, smart_low_poly | 삼각형 500~20,000, quad 500~10,000 (버전 무관 고정) |
| P1 | 50~20,000 (models.md는 48~) |
| P2 | 삼각형 48~50,000, quad 48~25,000 |
| P 시리즈 품질 팁 | 단순한 물건 150 이상, 복잡한 것 250 이상부터 |
| 문서 권장 | 게임용 5만~10만, 웹·모바일 1만~5만 (로블록스 MeshPart는 2만이 한계라 우리는 더 낮게) |

- **우리 규칙: 항상 `face_limit` 을 넣는다. 18,000 정도로 여유를 둔다.** 삼각형 모드에서 face = 삼각형.
- quad는 쓰지 않는다 (FBX 강제 + 사각면 1개 ≈ 삼각형 2개).
- fix_face.py가 머리/몸을 두 메시로 나누므로 전체가 2만 이하면 각각도 2만 이하.

### 3.5 멀티뷰 → 3D (`/generation/multiview-to-model`)
- `inputs` 필드 (배열). 세 가지 형식 중 **하나만**, 섞지 말 것.
  1. 방향 키 형식 (**추천**): `[{"front": "<token 또는 URL>"}, {"back": "..."}, {"left": "..."}]`. 객체 하나에 키 하나(`front`/`left`/`back`/`right`). 값은 URL, file_token, 또는 `{"url":..}` / `{"file_token":..}` / `{"object":{"bucket","key"}}`. 순서 상관없음 (서버가 `[앞, 왼, 뒤, 오른]` 으로 다시 정렬).
  2. 옛 위치 형식: 정확히 4개 문자열 `[앞, 왼, 뒤, 오른]`, 없는 방향은 `""`.
  3. 작업 형식: `[{"task_id": "<image-to-multiview 또는 edit-multiview 작업 id>"}]` (원소 1개만). 그 작업은 `success` 상태이고 type이 `generate_multiview_image` 또는 `edit_multiview_image` 여야 함.
- **앞(front)은 꼭 있어야 함**, 그림은 최소 2장, 같은 물체·같은 조명. PNG/JPEG/WebP, 256px 이상. 파일 크기 한도는 이 페이지에 없음 (이미지→3D 는 20MB).
- "left" 가 모델 기준 왼쪽인지 보는 사람 기준인지는 문서에 없음 → 시험 필요.
- 비용은 이미지→3D와 같다 (H 표준 30).

### 3.6 응답(결과) 모양
```json
{"code":0,"data":{"task_id":"task_abc123","type":"image_to_model","status":"success","progress":100,
 "output":{"model_url":"https://cdn.tripo3d.ai/output/model_pbr.glb","rendered_image_url":"https://cdn.tripo3d.ai/output/preview.png"},
 "credits_consumed":40.00,"created_at":"2026-04-28T12:00:00Z","completed_at":"2026-04-28T12:01:30Z"}}
```
- `model_url` = GLB (기본, H에서 quad=true면 FBX). `rendered_image_url` = 미리보기 그림 (분할 작업은 .webp).
- 위 예시의 `credits_consumed` 는 우리가 고친 값. 문서 원문은 모든 예제가 `100.00`.
- 문서 예제들은 `type` 을 다 `"text_to_model"` 로 복붙해 놨음 → `type` 으로 분기하지 말 것.
- **생성 결과 텍스처가 몇 픽셀인지 (standard/detailed) 문서에 없다.** extreme만 8K라고 적힘. 첫 결과를 내려받아 직접 확인.

### 3.7 2D 그림 생성 기능 (참고용, 우리 주력은 GPT)
- `text-to-image` 기본 모델 `seedream_v4`, `image-to-image` 기본 모델 `seedream_v5` (서로 다름).
- 모델 목록: `seedream_v5`, `seedream_v4`, `banana`, `banana2`, `banana_pro` (구글 계열로 보임), `chat_image_1` (**2026-10-23 종료**), `chat_image_1.5` (**2026-12-01 종료**), `chat_image_2`, `chat_image_2.5_flare` (빠름), `chat_image_2.5_sunburst` (수정할 때 원본 보존 최고). text-to-image 에는 seedream_v4 도 있고, image-to-image 목록에는 seedream_v4 가 없음.
  - [충돌] 모델 안내 페이지는 구글 모델을 `gemini-2.5-flash`, `gemini-3-pro`, `gemini-3.1-flash` 로 적음 (banana 이름 없음). 기능·가격 페이지 이름(`banana*`)을 쓴다.
- 비용 (1K 이하 / 2K / 4K):

| 모델 | 1K 이하 | 2K | 4K |
|---|---|---|---|
| seedream_v5 / seedream_v4 | 5 | 5 | 5 |
| banana | 5 | — | — |
| banana2 | 10 | 10 | 15 |
| banana_pro | 15 | 15 | 20 |
| chat_image_1 (종료 예정) | 5 | — | — |
| chat_image_1.5 (종료 예정) | 10 | — | — |
| chat_image_2 / 2.5_flare / 2.5_sunburst (`low`·`medium`·생략) | 10 | 10 | 15 |
| chat_image_2 / 2.5 `high` | 20 | 25 | 40 |
| chat_image_2.5 `xhigh` (2.5만) | 25 | 30 | 45 |
| chat_image_2.5 `max` (2.5만) | 30 | 50 | 50 |

  - "—" = 그 크기 없음. `size` 를 auto로 두면 2K 요금 (가격표).
- `prompt` (text-to-image 필수): 중국어·영어. 중국어 300자 / 영어 600단어 이하 권장, 중요한 것을 앞에. 빼고 싶은 것은 프롬프트 끝에 `--no ...`.
- `quality`: chat_image_2 = `low|medium|high`, chat_image_2.5_* = `low|medium|high|xhigh|max`. 다른 모델에 보내면 **오류**. 생략 = `low` (OpenAI 기본 `auto` 와 다름, `auto` 불가). high 이상은 더 비싸고 오래 걸림.
- `background` (`auto|opaque|transparent`): 2.5 모델만. 다른 모델은 **조용히 무시**. 생략 = 모델이 정함. transparent는 `output_format: png` 필수 (jpeg와 같이 보내면 오류).
- `size`: `"2K"`, `"4K"` 또는 `"2048x2048"`. 기본 2048x2048. 모델마다 허용값이 다름 (문서의 모델별 탭은 저장본에 없음). GPT(chat_image_2·2.5) 직접 크기: 각 변 3840 이하·16의 배수, 긴 변 ≤ 짧은 변 3배, 총 픽셀 655,360~8,294,400.
- `aspect_ratio` (기본 `1:1`): **banana 계열만**. banana·banana_pro: `1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9`. banana2는 `1:8, 1:4, 4:1, 8:1` 도. seedream·chat_image는 `size` 로만.
- `output_format`: `png` (기본, 투명 가능) / `jpeg`.
- `watermark` (기본 `false`): seedream 계열에서만 작동. banana 계열은 지울 수 없는 보이지 않는 워터마크가 항상 들어감. chat_image는 워터마크 조절 없음.
- `template`
  - text-to-image: `asset_extraction` (장면에서 물체만 뽑기), `character_completion`, `t_pose`, `variants`, `figure` (전신).
  - image-to-image: `t_pose` (T포즈로 변환), `character_completion`, `3d_enhance` (3D 변환용으로 그림 개선), `variants`, `figure`. (`3d_enhance` 는 image-to-image에만, `asset_extraction` 은 text-to-image에만)
- image-to-image
  - `prompt` 는 `template` 이 없을 때만 필수.
  - `input` (필수): 공개 URL / file_token / task_id 중 하나. jpeg/png 권장 (webp는 일부 경로에서 거부), 20MB, 최대 6000×6000=36MP, 각 변 최소 14px, 가로세로비 1/3~3.
  - `inputs` 로 여러 장 (seedream 4, banana 10, chat_image 16장까지), 프롬프트에서 `image[1]`, `image[2]` 로 부름.
- 결과: 작업 조회 `output.generated_image_url` (type `text_to_image` / `image_to_image`).
- `image-to-multiview`: `{"input": "<file_token 또는 URL>"}` 만 (task_id 안 됨). PNG/JPEG/WebP, 배경 깨끗하게. 결과 `output.front_view_url, left_view_url, back_view_url, right_view_url`. 10크레딧.
- `edit-multiview`: `{"input": "<task_id 또는 4방향 그림 file_token/URL>", "prompts": [{"prompt": "...", "view": "front"}]}`. `view` = `front|left|back|right`. 그림당 5. 결과 모양은 문서에 없음.
- **OpenAI 호환 API** (`base_url="https://openapi.tripo3d.ai/v3/openai"`)
  - 주소: `POST /v3/openai/images/generations` (글→그림), `POST /v3/openai/images/edits` (그림 수정, multipart 또는 JSON).
  - 모델 `gpt-image-2`, `gpt-image-2.5-flare`, `gpt-image-2.5-sunburst` 만. 날짜 붙은 이름·`chat_image_*` 이름은 404 `model_not_found`.
  - 결과는 서명 URL로만 (`data[0].url`). `response_format: "b64_json"` → 400. `n` 은 1만 (다른 값 400). `stream` 안 됨. `output_format` 은 png/jpeg (webp 400).
  - `size` 기본 `1024x1024`, `auto` 도 1024x1024 로 처리. 각 변 16의 배수.
  - `quality` 생략·`auto` = 기본 등급(low). (네이티브 주소와 달리 `auto` 를 받아줌)
  - `background`: 2.5만, transparent는 png 필수.
  - edits 입력: multipart는 `image` 또는 `image[]` 파트로 한 장씩. JSON은 `"images": [{"image_url": "https://... 또는 data: URL(10MiB 이하)"} 또는 {"file_id": "<file_token>"}]`. 입력 그림 10MiB 이하.
  - `mask` (선택): 알파 채널 있는 PNG, 입력 그림과 같은 크기, 20MiB 이하, 완전 투명 부분이 다시 그릴 곳. 첫 번째 입력 그림에 적용.
  - 응답: `{"created", "data":[{"url"}], "size", "quality", "output_format", "background", "tripo":{"task_id"}}`. `usage` 블록 없음 (크레딧은 계정/작업 조회로).
  - 실패 모양: `{"error": {"message","type","param","code"}}` (Tripo 기본 `code` 형식 아님).
  - 요금·콘텐츠 검사·동시 실행(이미지 생성 1개)은 네이티브와 같음. 요청이 20~80초 기다렸다 답함. 240초 넘으면 HTTP 400 `generation_in_progress` (실패 아님, 이미 1번 청구됨 → **다시 보내지 말고** `GET /v3/tasks/{id}` 로 조회, id는 `X-Tripo-Task-Id` 헤더(오류 때도 옴)와 `tripo.task_id`).

---

## 4. 파일 업로드, 작업 조회, 결과 다운로드

### 4.1 작은 파일 업로드: `POST /v3/files` [문서]
- multipart/form-data, 필드 이름 `file`.
- 그림: **JPEG, PNG 만** (WebP 안 됨), 20MB 이하. 3D: GLB, GLTF, FBX, OBJ, STL, 150MB 이하.
- 응답: `{"code":0,"data":{"file_token":"file_abc123"}}` → 다음 요청의 `"input"` 에 넣는다.
- curl: `curl -s -H "Authorization: Bearer KEY" -F "file=@photo.png" https://openapi.tripo3d.ai/v3/files`
- file_token 유효기간은 문서에 없음 → 업로드 후 바로 쓴다.
- 60MB 넘으면 presign 방식 권장.

### 4.2 큰 파일 업로드: `POST /v3/files/presign` [문서]
1. `POST /v3/files/presign` 본문 `{"format": "glb"}` (점 없는 확장자). 그림: jpeg, jpg, png, webp, bmp, tiff. 3D: glb, gltf, fbx, obj, stl, 3mf, usdz.
2. 응답 `presigned_url`, `file_token`, `expires_in: 1800` (30분).
3. `presigned_url` 에 HTTP **PUT**, 헤더 `Content-Type: application/octet-stream`, **API 키 헤더 넣지 않음**. 200이 와야 성공.
4. 업로드가 끝난 뒤에 `file_token` 을 `input` 에 쓴다 (예: 가져오기, 리토폴로지, 변환).
- WebP·BMP·TIFF 그림, 3MF·USDZ 3D 파일을 올리려면 이 방식밖에 없음 (또는 PNG로 바꿔서 4.1). 다만 각 기능이 그 형식을 받는지는 기능 페이지 목록을 따른다 (예: 가져오기는 GLB/GLTF/FBX/OBJ/STL만).
- 60MB 이하 작은 파일도 이 방식 사용 가능 (더 빠르다고 함).

### 4.3 작업 조회
- `GET /v3/tasks/{task_id}` → `data` 안에: `task_id`, `type`, `status`, `progress`(정수 0~100), `error_code`(실패 시, **정수**), `error_message`(실패 시, 있을 때만), `output`(성공 시만), `credits_consumed`(선택, 소수), `created_at`, `completed_at`(선택).
  - 필수로 오는 것: `task_id`, `type`, `status`, `progress`, `created_at`. 나머지는 없을 수 있으니 `.get()`.
  - `output` 안의 키는 작업 종류마다 다름: 3D = `model_url`(+`rendered_image_url`), 그림 = `generated_image_url`, 멀티뷰 그림 = `front_view_url` 등 4개, rig-check = `riggable`, `rig_type`.
  - 리깅·리타깃·rig-check 예제 결과에는 `type`, `progress`, `created_at` 이 빠져 있음 → 없어도 죽지 않게.
- `POST /v3/tasks/list` 본문 `{"task_ids": [...]}` (최대 100개) → `{"tasks": {id: {...}}, "missed": [...]}`.
  - `missed` = 없는 id, 다른 API 키로 만든 작업, **만료된 작업**.
  - 예제에는 성공 작업에도 `output` 이 안 보임 → 실제로 없으면 `GET /tasks/{id}` 로 다시 조회.
- 1~2초 간격보다 자주 조회하지 말 것. 작업이 많으면 일괄 조회.

### 4.4 결과 다운로드 [문서]
- `output.model_url`, `rendered_image_url` 은 **서명된 임시 URL**. 만료 시간은 문서에 없음 → **성공하자마자 받는다**. 임시 URL을 영구 주소로 저장하지 말 것 (SDK 문서).
- 내려받을 때 `Authorization` 헤더를 **넣지 않는다** (SDK들도 안 넣음).
- URL이 만료됐으면 작업을 다시 조회하면 새 URL을 준다 (SDK 문서). 작업 자체가 만료(`expired`)되면 끝.
- 작업 보존 기간도 문서에 없음 → task_id와 파일을 우리 쪽에 저장.

---

## 5. 후처리: 텍스처, 변환, 리토폴로지, 분할

공통 `input`: task_id / file_token / URL 중 하나. 형식 GLB, GLTF, FBX, OBJ, STL, 150MB 이하. (convert·decimate·rig 페이지 머리말은 "task_id 또는 file_token" 이라고 하지만 목록에는 URL도 있음 → task_id나 file_token을 쓰자.)
- **task_id 는 문서상 "3D 생성 작업(`text_to_model`, `image_to_model`, `multiview_to_model`)의 id"** 라고만 적혀 있음 (texture, convert, segment, decimate, rig-check, rig 모두). 텍스처 다시 입힌 작업·가져오기 작업·리깅 작업의 id를 다음 단계 input으로 넣어도 되는지는 문서에 없음 [추정: 가져오기는 "후처리용"이라 될 것]. 안 되면 결과 GLB를 내려받아 `/files` 로 올린 file_token을 쓴다.

### 5.1 텍스처 다시 입히기 `POST /v3/models/texture`

| 이름 | 기본값 | 값 / 설명 |
|---|---|---|
| `input` | (필수) | |
| `model` | `v3.0-20250812` | `v3.5-20260815`(최신, fast·delight 필요), `v3.0-20250812`(v3.0·v3.1 모양에 권장), `v2.5-20250123` |
| `texture_prompt` | 없음 | 객체. Tripo에서 만든 모델이면 생략 가능. `text` / `image` / `images` 중 **하나만**. `style_image` 는 `text` 와만 같이 |
| └ `text` | | `{"text": "worn leather with scratches"}` |
| └ `style_image` | | 화풍 참고 그림 (file_token 또는 url, 256px 이상 권장). `{"text": "...", "style_image": {"url": "https://..."}}` |
| └ `image` | | 참고 그림 1장 (file_token 또는 URL). 정확한 JSON 모양은 문서에 없음 [추정: `{"image": {"file_token": "file_..."}}`] |
| └ `images` | | 정확히 4장 `[앞, 왼, 뒤, 오른]` |
| `pbr` | `true` | |
| `texture_seed` | 무작위 | |
| `texture_alignment` | `original_image` | `geometry` |
| `texture_quality` | `standard` | `fast`(v3.5만), `standard`, `detailed`, `extreme`(8K) |
| `part_names` | 전체 | 분할 작업에서 나온 부위 이름 목록. 일부만 다시 텍스처 |
| `compress` | 없음 | `geometry` (model v3.0 이상에서만) |
| `bake` | `true` | 고급 재질 효과를 기본 텍스처에 구워 넣음 (호환성용) |
| `delight` | `true` | v3.5만 읽음 |

- `model_seed`, `face_limit` 등 모양 관련 파라미터는 없음 (모양은 그대로).

- 기존 task_id로 다시 텍스처할 때 **원본 그림을 `texture_prompt` 로 다시 넣으라고 강력히 권장**.
- 텍스처 크기 지정 파라미터 없음 → 크기는 `/models/convert` 의 `texture_size` 로.
- 예: `{"input":"task_abc123","model":"v3.5-20260815","texture_quality":"detailed","delight":false,"pbr":false}`

### 5.2 형식 변환 `POST /v3/models/convert`

| 이름 | 기본값 | 값 / 설명 |
|---|---|---|
| `input` | (필수) | |
| `format` | (필수) | `GLTF`(웹), `FBX`(Unity·Unreal·Blender), `USDZ`(애플 AR), `OBJ`(애니메이션 없음), `STL`·`3MF`(3D 프린트, 모양만). **GLB 값은 없음** (GLTF가 .glb로 나오는지 문서에 없음) |
| `quad` | `false` | true면 FBX 강제, face_limit 없으면 1만 |
| `force_symmetry` | `false` | quad=true 일 때만 |
| `face_limit` | 원래 면 수 유지 | 범위 문서에 없음 (ComfyUI는 -1~500,000) |
| `flatten_bottom` | `false` | 바닥 평평하게 |
| `flatten_bottom_threshold` | `0.01` | 평평하게 자를 깊이 (ComfyUI 기준 0.0~1.0) |
| `texture_size` | `4096` | 색(diffuse) 텍스처 한 변 픽셀 (ComfyUI 기준 128~4096) |
| `texture_format` | `JPEG` | `PNG`, `WEBP`, `BMP`, `DPX`, `HDR`, `OPEN_EXR`, `TARGA`, `TIFF` |
| `bake` | `true` | |
| `pack_uv` | `false` | UV 한 장으로 모으기 |
| `export_vertex_colors` | `false` | OBJ, GLTF만 |
| `pivot_to_center_bottom` | `false` | 기준점을 바닥 가운데로 (로블록스 배치에 편함) |
| `scale_factor` | `1` | 크기 배율 (ComfyUI 기준 0 이상) |
| `with_animation` | `true` | 뼈·애니메이션 포함 |
| `animate_in_place` | `false` | 제자리 애니메이션 (뿌리 이동 없음) |
| `part_names` | 전체 | 분할 작업의 부위 이름 중 내보낼 것 |
| `export_orientation` | `+x` | `+x`, `-x`, `+y`, `-y` (z 없음). 생성 때 말고 **마지막 변환 때** 방향을 바꾸라고 문서가 권함 |
| `fbx_preset` | `blender` | `blender`, `3dsmax`, `mixamo`, `bake_scale` (크기 변환을 노드 대신 메시에 구워 넣음) |

- **요금: 아래 중 하나라도 기본값과 다르면 "고급" 10크레딧, 아니면 "기본" 5크레딧**: `quad`, `face_limit`, `flatten_bottom`, `flatten_bottom_threshold`, `texture_size`, `texture_format`, `pivot_to_center_bottom`, `scale_factor`.
  - 즉 `texture_size: 1024` 또는 `texture_format: "PNG"` 만 넣어도 10.
  - `format`, `bake`, `pack_uv`, `export_orientation`, `fbx_preset`, `with_animation`, `part_names` 만 바꾸면 5.
- JPEG 기본값은 작은 눈 디테일을 블록 노이즈로 망칠 수 있음 → 텍스처를 받을 거면 `PNG`.
- 예 (FBX): `{"input":"task_abc123","format":"FBX","texture_size":2048,"texture_format":"PNG","pivot_to_center_bottom":true,"fbx_preset":"blender"}`

### 5.3 리토폴로지 `POST /v3/mesh/decimate`

| 이름 | 기본값 | 설명 |
|---|---|---|
| `input` | (필수) | |
| `model` | `v2.0` | `v2.0` (스마트, 깔끔한 면 배치, 30) / `v1.0` (기본 줄이기, 10). 날짜 없는 이름 |
| `face_limit` | (조건부 필수, 조건 미기재) | **항상 넣는다** |
| `quad` | `false` | 둘 다 지원 |
| `bake` | `true` | 원래 텍스처를 새 메시에 구움. v1.0은 미지원 |
| `part_names` | 전체 | v1.0은 미지원 |

- 텍스처 크기·형식 옵션 없음 → 필요하면 뒤에 convert.
- **v2.0의 다시 굽기(bake) 때문에 흐려질 가능성** → 우리는 생성 때 face_limit을 주는 쪽을 먼저 쓴다.

### 5.4 분할 `POST /v3/mesh/segment`
- `model`: `v1.0-20250506` (기본, 모양 기준) / `v2.0-20260430` (베타, 의미 기준 라벨).
- v2 전용: `segmentation_granularity` (`simple|balanced|detailed`, 기본 balanced), `split_by_connectivity` (기본 true, 떨어진 덩어리끼리 나누기), `ref_image` (분할 마스크 그림, file_token 또는 공개 URL, 넣으면 앞의 두 옵션 무시). v1에 보내면 무시됨 (ComfyUI 기준).
- 결과: 작업 type `mesh_segmentation`, `output.model_url` (mesh_seg.glb), `rendered_image_url` (.webp). **부위 이름 목록을 따로 주지 않음** → GLB 안의 노드 이름을 읽어야 할 것 [추정].
- 비용 40 (스마트 55/85). 예제는 약 2.6분 걸림.

### 5.5 부위 채우기 `POST /v3/mesh/complete`
- `input` 은 **분할 작업의 task_id만** (file_token·URL 불가).
- `model`: `v1.0-20250506` (기본이자 유일한 버전).
- `completion_mode`: `ai_completion` (기본, AI가 빠진 모양을 만들어 채움, 50) / `quick_cap` (AI 없이 구멍만 막기, 30). `part_names` 선택 (생략 = 전체 부위).

### 5.6 가져오기 `POST /v3/models/import`
- `{"input": "file_..."}` 또는 URL → 외부 3D 파일을 Tripo 작업(task_id)으로 만든다 (뒤 단계 처리용).
- 형식 GLB, GLTF, FBX, OBJ, STL, 150MB 이하. (presign은 3mf·usdz 도 올릴 수 있지만 가져오기 목록엔 없음. ComfyUI 노드는 .ply, .3mf, .zip 도 받는다고 적음 [충돌])
- presign 예제는 `"model": "default"` 도 같이 보냄 (본 페이지엔 없는 필드).
- 비용·동시 실행 분류 문서에 없음.

### 5.7 refine / stylize (API 문서 페이지 없음)
- `/models/refine`: 초안(draft) 모델을 다듬기. ComfyUI 기준 "다듬을 수 있는 초안"이어야 함 (옛 v1.4·v2.0 모델 결과로 보임). 우리는 안 씀.
- `/models/stylize`: ComfyUI 기준 `style` = `lego|voxel|voronoi|minecraft`, `block_size` 1~1000 (기본 80). API 필드 이름이 같은지는 문서에 없음 [추정].
- 둘 다 SDK 중 Java에만 있음.

---

## 6. 리깅과 애니메이션

순서: **rig-check (무료) → rig (25) → retarget (동작당 10, 선택)**

### 6.1 `POST /v3/animations/rig-check`
- 본문 `{"input": "<생성 task_id 또는 file_token 또는 URL>"}`. 형식은 **GLB만**.
- 이것도 비동기. 결과는 작업 조회의 `output`: `{"riggable": true, "rig_type": "biped"}`.
- `rig_type` 7종: `biped`(두 다리 사람형), `quadruped`(네 발), `hexapod`(여섯 다리), `octopod`(여덟 다리), `avian`(새), `serpentine`(뱀), `aquatic`(물고기).
- 머리 큰 치비 체형이 통과하는지는 문서에 없음 → **무료니까 먼저 돌려본다.**

### 6.2 `POST /v3/animations/rig`

| 이름 | 기본값 | 값 |
|---|---|---|
| `input` | (필수) | task_id / file_token / URL. GLB, GLTF, FBX, OBJ, STL, 150MB |
| `model` | `v1.0-20240301` | `v1.0-20240301` = **사람형(biped) 전용, 사람형에 권장, 동작 프리셋 101개** (문서는 "90+"라고 적지만 리타깃 목록을 세면 101개). `v2.5-20260210` = 사람형 아닌 생물용 (quadruped, hexapod, octopod, serpentine, aquatic, avian. 동작 프리셋 16개) |
| `rig_type` | `biped` | 위 7종 |
| `spec` | `tripo` | `tripo` (Tripo 뼈 이름) / `mixamo` (Mixamo 호환 뼈 이름) |
| `out_format` | `glb` | `glb` / `fbx` |

- 결과: `output.model_url` (rigged.glb).
- [충돌] 공식 예제는 `v2.5-20260210` 에 `biped` 를 같이 보냄. 리타깃 문서도 v2.5에 사람형 동작 11개를 둠 → v2.5도 biped를 받는 듯. 하지만 **사람형은 v1.0 권장**.
- [충돌] ComfyUI 노드는 기본 리깅 모델을 `v2.0-20250506` 으로 적음 (API 문서에는 없는 이름). models.md 제목도 "rig-v2.0". API 문서의 두 이름(`v1.0-20240301`, `v2.5-20260210`)을 따른다.
- ComfyUI 리깅 노드는 리깅 전에 rig-check를 자동으로 돌림 (API는 따로 불러야 함).
- `model` 을 빼면 v1.0(사람형 전용)이 되므로, 네 발 몬스터 등은 반드시 `"model": "v2.5-20260210"` 을 넣는다.
- 리깅이 메시·텍스처·면 수를 바꾸는지 문서에 없음 → 리깅 뒤 삼각형 수·텍스처 크기 다시 확인.
- 뼈 이름은 둘 다 **로블록스 R15 이름이 아님**. 로블록스 자동 아바타 설정 대신 "커스텀 스킨드 메시 + AnimationController/Animator" 로 쓴다 [추정]. mixamo 이름이 블렌더 도구로 다루기 쉬움 [추정].

### 6.3 `POST /v3/animations/retarget`

| 이름 | 기본값 | 설명 |
|---|---|---|
| `input` | (필수) | **리깅 작업의 task_id만** (원래 생성 작업 id 아님, 파일 불가) |
| `animation` | (둘 중 하나 필수) | 프리셋 1개. `animations` 와 같이 쓰면 안 됨 |
| `animations` | (둘 중 하나 필수) | 프리셋 여러 개 배열 (models.md: 최대 5개. 기능 페이지엔 개수 한도 없음) |
| `out_format` | `glb` | `glb` / `fbx` |
| `bake_animation` | `true` | glb일 때만 효과 |
| `export_with_geometry` | `true` | 메시 포함 여부 (ComfyUI 노드는 기본 false [충돌] → API는 명시적으로 true 보내자) |
| `animate_in_place` | `false` | 제자리 걷기·뛰기 (게임 이동용은 true) |

- 결과는 `model_url` 하나. 여러 동작을 보내도 파일 하나 (동작 여러 개가 한 파일에 들어가는 듯 [추정]).
- 여러 동작 한 번에 보낼 때 요금이 동작 수만큼인지 문서에 없음 (가격표는 "동작당 10").
- **프리셋 이름은 리깅 버전에 맞춰야 한다.**

v2.5-20260210 리깅용 (16개, `biped:` 없음):
- 사람형 11개: `preset:idle`, `preset:walk`, `preset:run`, `preset:dive`, `preset:climb`, `preset:jump`, `preset:slash`, `preset:shoot`, `preset:hurt`, `preset:fall`, `preset:turn`
- 기타: `preset:quadruped:walk`, `preset:hexapod:walk`, `preset:octopod:walk`, `preset:serpentine:march`, `preset:aquatic:march` (새(avian)용 없음)

v1.0-20240301 리깅용 (101개, 모두 `preset:biped:<이름>`):
afraid, agree, angry_01, angry_02, angry_03, basketball_shot, bow, box_01, box_02, box_03, cast_a_spell, cheer, chop, clap, climb, complain_01, complain_02, cross_body_crunch, crossover_dribble, cry, dance_01~06, defeat_02, defeat_03 (01 없음), depressed, dig, dive, dribble, fall, fire, flee_01, flee_02, flip, fold_arms, football_catch, football_save, football_pass, freaky, frightened, front_kick_01, front_kick_02, frustrated_01, frustrated_02, golf, greet_01~04, heart_pose, hit_to_body_01, hit_to_body_02, hit_to_head, hit_to_side, hit_to_stomach, hug, hurt, idle, jump_down, jump, jump_rope_01, jump_rope_02, laugh_01, laugh_02, lift_heavy, look_around, make_a_call_01, make_a_call_02, pitch_baseball, play_mobile_game, play_video_game, press-up (**하이픈**), run_upstairs, run, scared_01, scared_02, scratch, shoot, shovel, sing_01~04, sit, slash, sob, standing_relax, surf, swagger, swim, turn, victory_celebration, volleyball, wait, walk, warm_up, wave_goodbye_01, wave_goodbye_02

우리 게임에 쓸 만한 것: `idle`, `walk`, `run`, `jump`, `slash`, `shoot`, `cast_a_spell`, `hurt`, `hit_to_head`, `hit_to_body_01`, `fall`, `victory_celebration`, `greet_01`, `cheer`, `standing_relax`.

---

## 7. 오류, 속도 제한, 웹훅

### 7.1 HTTP 상태
| HTTP | 뜻 | 다시 시도? |
|---|---|---|
| 200 | 성공 | |
| 400 | 파라미터 잘못 | 아니오 (고쳐야 함) |
| 401 | 키 없음/틀림 | 아니오 |
| 403 | 권한 없음 또는 **크레딧 부족** | 아니오 |
| 404 | 작업/자원 없음 (OpenAI 호환 주소에서는 없는 모델 이름 `model_not_found` 도) | 아니오 |
| 429 | 요청 너무 많음 또는 동시 실행 꽉 참 | **예** (기다렸다가) |
| 500 | 서버 오류 | **예** (나중에) |

### 7.2 오류 코드 전체
| code | 뜻 | 대처 |
|---|---|---|
| 1000 | API 키 틀림/삭제됨 | 키 확인 |
| 1001 | Authorization 헤더 없음 | 헤더 넣기 |
| 1004 | 파라미터 조합 거부 (`fast` 를 v3.5 아닌 텍스처에, `generate_parts` 를 텍스처 켠 채로) | 조합 수정 |
| 1007 | 요청 빈도 초과 (HTTP 429) | `X-RateLimit-Reset` 까지 기다림 |
| 2000 | 동시 실행 꽉 참 (HTTP 429, `Retry-After` 헤더 있음) | `Retry-After` 초만큼 기다림. (오류 문서는 "Rate limit exceeded" 라고 적음 [충돌]) |
| 2002 | 지원 안 하는 파라미터 | 필드 이름·값 확인 |
| 2003 | 빈 파일 | 파일 확인 |
| 2004 | 지원 안 하는 파일 형식 | 형식 바꾸기 |
| 2008 | **콘텐츠 정책 위반** | 같은 그림 재시도 금지. 그림 고치기 (옷차림 단정하게) |
| 2010 | **크레딧 부족** (HTTP 403) | 충전 |
| 2015 | 버전 폐기 | v3 사용 |
| 2018 | 모델이 너무 복잡 | 면 수 줄여서 다시 (리깅·변환 전) |
| (HTTP 400) | P1에 `quad: true` | quad 빼기 |
| (번호 미기재) | GPT 그림에 `transparent` + `jpeg` / 다른 모델에 `quality` | 조합 수정 |
| `model_not_found` (HTTP 404) | OpenAI 호환: 지원 안 하는 모델 이름 | `gpt-image-2` 등 3개만 |
| `generation_in_progress` (HTTP 400) | OpenAI 호환: 240초 넘게 아직 만드는 중 (이미 청구) | 재전송 금지, 작업 조회 |
| (HTTP 400, 코드 미기재) | OpenAI 호환: `b64_json`, `n`≠1, `stream`, webp, 잘못된 mask | 조합 수정 |

- 1004·1007 은 오류 코드 표에는 없고 각 기능/속도 제한 페이지에만 나옴.
- 작업 실패는 HTTP 오류가 아니라 작업 조회 결과의 `status: failed` + `error_code`(정수) + `error_message` 로 온다. 웹훅에서는 `data.error.code` 가 문자열 (`"task_failed"`).
- OpenAI 호환 주소의 오류는 숫자 `code` 가 아니라 `{"error": {"code": "model_not_found", ...}}` 모양.

### 7.3 속도 제한과 동시 실행 [문서]
- **요청 빈도**: API 키 단위. 생성 주소는 낮고 조회 주소는 높음 (숫자 비공개). 모든 응답에 `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` (유닉스 초) 헤더.
- **동시 실행**: **계정** 단위 (키 여러 개 만들어도 소용없음), 분류별 따로. 같은 분류 안에서는 한 통을 같이 씀 (예: H 글→3D 10개가 돌면 H 이미지→3D 도 못 띄움). 다른 분류는 영향 없음.

| 분류 | 포함 작업 | 기본 동시 실행 (rate-limits 문서) |
|---|---|---|
| 3D 생성 H | H 시리즈 글/그림/멀티뷰→3D | 10 |
| 3D 생성 P | P 시리즈 글/그림/멀티뷰→3D | 5 |
| 이미지 생성 | text-to-image, image-to-image, image-to-multiview, edit-multiview | **1** |
| 애니메이션 | rig, rig-check, retarget | 10 |
| 모델 처리 | texture, convert, refine | 5 |
| 메시 작업 | segment, complete, decimate | 10 |

- [충돌] models.md는 H·P·애니메이션 모두 "3개 동시" 라고 적음. → **우리 스크립트는 분류별 최대 3개만 동시에 돌린다** (안전한 쪽).
- 다시 시도 규칙: 429·500만. 1, 2, 4, 8… 초 (최대 32초), 최대 5번. `Retry-After` → `X-RateLimit-Reset` → 지수 대기 순서로 따른다. 400/401/403은 재시도 금지.
- 공식 오류 처리 예제는 500을 재시도 안 하고 `Retry-After` 도 무시함 → rate-limits 문서의 `request_with_backoff` 방식을 쓴다.
- 더 많은 동시 실행은 지원팀에 문의.

### 7.4 웹훅 (우리는 안 씀)
- 작업 완료/실패·잔액 부족 때 Tripo가 **우리 HTTPS 서버**로 POST 해줌. 설정은 웹 콘솔에서만 (Settings → Webhooks → Add Endpoint → 주소·이벤트 고르고 Save). 요청마다 콜백 주소를 주는 필드는 문서에 없음.
- 이벤트: `task.completed`, `task.failed` (실패 또는 취소), `balance.low` (Billing → Credit alert 의 기준값 아래로 떨어질 때).
- 본문: `{"id": "<task_id>:<이벤트>", "type": "<이벤트>", "created_at": "...", "data": {...}}`. 작업 이벤트 `data` = `task_id, type, status, output(성공 시)`, 실패면 `error: {code, message}`. balance.low `data` = `{balance, threshold}`.
- 헤더: `Tripo-Webhook-Id`(엔드포인트 id), `Tripo-Webhook-Delivery`(배달 id, 중복 제거용), `Tripo-Webhook-Event`(= type), `Tripo-Webhook-Signature`, `Content-Type: application/json`.
- 서명 `Tripo-Webhook-Signature: t=<유닉스초>,v1=<hex>` = HMAC-SHA256(비밀키 `whsec_...`, `"{t}.{원본 본문}"`) 소문자 hex, 상수 시간 비교. 5분 넘은 건 거부(선택). 비밀키는 만들 때 한 번만 보여줌. 5초 안쯤 2xx로 답해야 함.
- 2xx가 아니거나 시간 초과면 Tripo가 자동 재시도. 실패 기록은 Settings → Webhooks → Recent deliveries.
- **우리처럼 내 컴퓨터에서 도는 스크립트는 공개 HTTPS 주소가 없으니 폴링이 간단하다.** (단, 콘솔의 balance.low 알림은 켜두면 좋음)

---

## 8. SDK / CLI / Codex 플러그인 / ComfyUI 요약

| 도구 | 내용 | 우리에게 |
|---|---|---|
| 공식 Python SDK `tripo3d==0.4.2` | **대부분 v2용** (`model_version`, `output.model`, v2 주소 `/v2/openapi/task`, `/user/balance`, `/upload`, `/upload/sts/token`). v3는 분할(`mesh_segmentation(..., model_version="v2.0-20260430")`)만 | **안 씀.** v3 REST를 `requests` 로 직접 부른다 |
| JS / Go / Rust / Java SDK | v3 지원. 특정 커밋에 고정해서 설치 (JS `e351348`, Go `2c8c8d4`, Rust `f992f6a`, Java `7b6a68d` 소스 빌드) | 우리는 파이썬이라 참고만. Java에만 presign·import·refine·stylize·usage·splat 있음. Java에는 text-to-image·image-to-image·edit-multiview 없음. OpenAI 호환 주소는 어느 SDK에도 없음 |
| Tripo CLI (`npm install -g tripo-cli`, Node 20+) | `tripo login`(브라우저 승인, 키 안 붙임) → `tripo doctor`(로그인·네트워크·잔액 점검) → `tripo make "글" / 그림.png / 앞.png 뒤.png / 모델.glb`, `--then texture,rig,convert:fbx`, `--for <프리셋>`, `tripo view @last`, `tripo redo`, `tripo files upload`, `tripo task get/list/watch`, `tripo balance/usage/topup`, `tripo batch run 목록.yaml --concurrency 2`, `tripo mcp`(MCP 서버), `--json` 출력 | 빠른 수동 시험용으로 좋음. 면 2만 이하면 자동으로 P1(더 비쌈)을 고름. 결과는 `tripo-out/` 에 모델 + `task.json` + `preview.png`. 설정은 `%USERPROFILE%\.tripo`. 윈도우 PowerShell은 실행 정책 설정 필요(`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`), `'@last'`, `'texture,rig'` 처럼 따옴표로 감쌀 것 |
| CLI 프리셋 (`--for`) | `game-mobile`, `game-pc`, `film`, `print`, `ar-web`, `anim`, `toy` | `game-mobile` = 로우폴리 생성 → 텍스처 → FBX |
| CLI 환경변수 | `TRIPO_API_KEY`(최우선), `TRIPO_PROFILE`, `TRIPO_REGION`(`ov`/`cn`), `TRIPO_API_BASE_URL`, `TRIPO_PLATFORM_BASE_URL`, `TRIPO_HOME`, `TRIPO_LLM_*`(`tripo ai` 용) | 키는 환경변수 하나로 CLI·우리 스크립트 같이 씀 |
| CLI 종료 코드 | 0 성공, 1 내부, 2 사용법, 3 인증, 4 크레딧 부족, 5 콘텐츠 정책, 6 작업 실패(환불), 7 네트워크, 8 없음, 9 속도 제한 | subprocess로 부를 때 분기용 |
| Codex 플러그인 "Tripo 3D" | ChatGPT 데스크톱 앱의 Codex 또는 Codex CLI 에서만 (일반 ChatGPT 채팅 X). Node 20+ 필요. Plugins → Plugins Directory → "Tripo 3D" 설치. 말로 "3D 만들어서 ./assets에 저장해" 가능. 브라우저 일회용 코드 로그인, 키를 채팅에 붙이지 않음. 여러 개 만들 땐 크레딧 쓰기 전에 확인을 물음 | GPT 그림을 Codex에서 만들고 있으니 한 자리에서 이어갈 수 있음. 다만 세부 파라미터 통제는 우리 스크립트가 나음 |
| ComfyUI-Tripo 노드 (1.3.0, 소스 태그 v1.3.1.1) | 노드 11개 (생성, 가져오기, 텍스처, 다듬기, 분할, 채우기, 스마트 로우폴리, 스타일, 리깅, 리타깃, 변환). 키는 노드 입력 → `TRIPO_API_KEY` → `config.json` 순 | 안 씀. 다만 `TripoSmartLowPoly` (모델 `P-v2.0-20251225`, face_limit 기본 1만, -1~20000, quad, part_names, bake) 라는 후처리가 있다는 단서 — API 문서 주소는 없음. 리타깃 노드는 v2.5 프리셋 16개만 |
| 에디터 플러그인 | Unity 1.0.1 (2022+), Unreal 1.0 (5.6.0), Blender 0.7.3 (3.0+, `Edit > Preferences > Add-ons > Install from Disk`, 사이드바 `Tripo 3D` 에서 그림→3D, face limit·texture·PBR·quad 설정, GLB/FBX 가져오기), Godot 0.02 (4.4+), Cocos Creator 1.0.0 (3.8.6+), ComfyUI 1.1.21 | 블렌더 플러그인은 수동 시험용 |

---

## 9. 우리 파이프라인 추천 레시피

흐름: **GPT(Codex) 정면 A포즈 그림 → Tripo 이미지→3D → (Tripo 리깅) → 블렌더 `tools/fix_face.py` (머리 분리 + 머리 전용 1024 텍스처 굽기 + 선명하게) → 로블록스 스튜디오 3D 가져오기**

### 9.0 모든 레시피 공통 규칙
1. 그림은 **PNG**, 배경 깨끗하게, 20MB 이하, 256px 이상, 옷차림 단정하게 (2008/banned 방지).
2. `POST /v3/files` 로 올려서 `file_token` 받기.
3. 모델 이름은 날짜 붙은 이름으로 고정 (`v3.1-20260211`, `P1-20260311`).
4. **`face_limit` 항상 넣기** (자동이면 2만 넘을 수 있음).
5. **`texture_version: "v3.5-20260815"` 항상 넣기** (안 넣으면 옛 v3.0 텍스처).
6. `pbr: false` 권장. 이유:
   - 만화풍엔 색 그림만 있으면 됨.
   - **fix_face.py는 재질에서 "첫 번째 이미지 노드"를 원본 텍스처로 잡는다.** PBR 맵(노멀·거칠기 등)이 여러 장이면 엉뚱한 맵을 잡을 수 있음. (PBR을 쓰려면 스크립트를 Base Color에 연결된 노드를 찾도록 고쳐야 함)
7. `model_seed`, `texture_seed` 를 직접 정해서 보내고 기록 (좋은 모양 → 텍스처만 다시 뽑기용).
8. `export_orientation`, `compress`, `quad`, `enable_image_autofix`, `auto_size` 는 넣지 않는다.
9. 결과 GLB는 성공 즉시 내려받고, task_id·시드·크레딧을 JSON으로 저장.
10. 동시 실행은 분류별 3개까지, 폴링 3초 간격, 제한 시간 15분.
11. **텍스처 크기**: Tripo에서 1024로 받지 않는다. fix_face.py가 큰 원본(2k 이상)에서 머리 전용 1024를 굽기 때문에 원본이 클수록 얼굴이 선명해짐. 첫 결과의 텍스처 크기를 확인하고, 2k보다 작을 때만 `/models/convert` (`format: "GLTF"`, `texture_size: 4096`, `texture_format: "PNG"`, 10크레딧)를 시험.

### 9.1 파이썬 뼈대 코드 (구현 담당용)

```python
import os, time, requests

BASE = "https://openapi.tripo3d.ai/v3"
KEY = os.environ["TRIPO_API_KEY"]          # 키는 환경변수에서만
AUTH = {"Authorization": f"Bearer {KEY}"}
BAD = {"failed", "banned", "expired", "cancelled"}


class TripoError(Exception):
    pass


def call(method, path, *, json_body=None, files=None, retries=5):
    """429/5xx는 기다렸다 다시, 나머지 오류는 바로 예외. 성공하면 data만 돌려줌."""
    for attempt in range(retries + 1):
        r = requests.request(method, BASE + path, headers=AUTH, json=json_body, files=files, timeout=120)
        if r.status_code == 429 or r.status_code >= 500:
            if attempt == retries:
                break
            ra, reset = r.headers.get("Retry-After"), r.headers.get("X-RateLimit-Reset")
            if ra:
                wait = float(ra)
            elif reset:
                wait = max(int(reset) - time.time(), 1)
            else:
                wait = min(2 ** attempt, 32)
            time.sleep(wait)
            continue
        try:
            body = r.json()
        except ValueError:
            raise TripoError(f"HTTP {r.status_code}: {r.text[:200]}")
        if body.get("code") != 0:
            raise TripoError(f"[{body.get('code')}] {body.get('message')} | {body.get('suggestion')} | {body.get('request_id')}")
        return body["data"]
    raise TripoError(f"{path}: 재시도 다 씀")


MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".glb": "model/gltf-binary"}


def upload(path):
    with open(path, "rb") as f:
        data = f.read()          # 바이트로 읽어둬야 재시도 때도 다시 보낼 수 있음
    ext = os.path.splitext(path)[1].lower()
    files = {"file": (os.path.basename(path), data, MIME.get(ext, "application/octet-stream"))}
    return call("POST", "/files", files=files)["file_token"]


def create(path, body):
    return call("POST", path, json_body=body)["task_id"]


def wait(task_id, timeout=900, interval=3):
    t0 = time.time()
    while time.time() - t0 < timeout:
        d = call("GET", f"/tasks/{task_id}")
        if d["status"] == "success":
            return d
        if d["status"] in BAD:
            raise TripoError(f"{task_id} {d['status']} {d.get('error_code')} {d.get('error_message')}")
        time.sleep(interval)
    raise TimeoutError(f"{task_id} 시간 초과 (나중에 다시 조회 가능)")


def download(url, out_path):
    r = requests.get(url, timeout=600)     # 서명 URL: Authorization 헤더 넣지 않음
    r.raise_for_status()
    with open(out_path, "wb") as f:
        f.write(r.content)


# 사용 예: 캐릭터 1명
# tok = upload("art/out/APose_HaloWarriorM.png")
# gen = create("/generation/image-to-model", {...9.2의 JSON..., "input": tok})
# d = wait(gen); download(d["output"]["model_url"], "build/tripo/HaloWarriorM_raw.glb")
# chk = wait(create("/animations/rig-check", {"input": gen}))["output"]   # {"riggable":..,"rig_type":..}
# rig = create("/animations/rig", {"input": gen, "model": "v1.0-20240301", "rig_type": "biped", "spec": "mixamo", "out_format": "glb"})
# download(wait(rig)["output"]["model_url"], "build/tripo/HaloWarriorM_rig.glb")
# 잔액: call("GET", "/account/balance")  -> {"balance": float, "frozen": float}
```

### 9.2 캐릭터 (치비, 얼굴 선명이 최우선)

**C1. 기본 (먼저 이걸로 시험)** — H3.1 + HD 텍스처

```json
{
  "input": "<file_token>",
  "model": "v3.1-20260211",
  "face_limit": 18000,
  "texture": true,
  "pbr": false,
  "texture_quality": "detailed",
  "texture_version": "v3.5-20260815",
  "delight": false,
  "texture_alignment": "original_image",
  "model_seed": 12345,
  "texture_seed": 777
}
```
- 비용: 이미지→3D 표준 30 + HD +10 = **40크레딧 ($0.40)**.
- 첫 시험에서 같은 `model_seed` 로 아래만 바꿔 비교 (각 40):
  - `delight: true` vs `false`
  - `orientation: "align_image"` 추가 여부
- 얼굴만 망하면: `texture_seed` 만 바꿔 다시, 또는 `/models/texture` (아래 C4).

**C2. 면 배치가 지저분할 때** — C1에 `"smart_low_poly": true` 추가
- 면 수 500~20,000 고정이라 로블록스 한계와 딱 맞음. 복잡한 모델은 가끔 실패 (실패하면 환불).
- 비용 **50**.

**C3. P1 비교용** — 깔끔한 로우폴리 전문
```json
{
  "input": "<file_token>",
  "model": "P1-20260311",
  "face_limit": 18000,
  "texture": true,
  "pbr": false,
  "texture_quality": "detailed",
  "texture_version": "v3.5-20260815",
  "delight": false,
  "model_seed": 12345,
  "texture_seed": 777
}
```
- 비용 **60** (H3.1보다 비쌈). `geometry_quality`, `smart_low_poly`, `quad` 넣으면 안 됨.

**C4. 얼굴 텍스처만 다시** (모양은 마음에 들 때)
```json
{
  "input": "<생성 task_id>",
  "model": "v3.5-20260815",
  "texture_prompt": {"image": {"file_token": "<원본 그림 file_token>"}},
  "texture_quality": "detailed",
  "texture_alignment": "original_image",
  "delight": false,
  "pbr": false,
  "texture_seed": 778
}
```
- 비용 **20**. `texture_prompt.image` 모양은 문서에 정확히 없음 [추정] → 거부되면 `"image": "<file_token>"` 로 시험.

**리깅 (치비라서 로블록스 자동 설정이 실패하니 Tripo 리깅 사용)**
1. `POST /animations/rig-check` `{"input": "<생성 task_id>"}` — 무료. `riggable: true`, `rig_type: "biped"` 인지 확인.
2. `POST /animations/rig`:
```json
{"input": "<생성 task_id>", "model": "v1.0-20240301", "rig_type": "biped", "spec": "mixamo", "out_format": "glb"}
```
- 비용 **25**.
3. (선택) 동작: `POST /animations/retarget`
```json
{"input": "<rig task_id>", "animations": ["preset:biped:idle", "preset:biped:walk", "preset:biped:run", "preset:biped:slash", "preset:biped:hurt"], "out_format": "glb", "export_with_geometry": true, "animate_in_place": true}
```
- 동작당 **10** (5개면 50 추정).

**fix_face.py 와 리깅 순서 (중요)**
- 지금 fix_face.py는 **메시만 다루고 뼈(armature)를 고려하지 않는다** (메시 합치기 + `transform_apply`). 리깅된 GLB를 그대로 넣으면 뼈 연결이 깨질 수 있다.
- 방법 A (추천): 생성 → Tripo 리깅 → 리깅된 GLB를 fix_face.py → 로블록스. fix_face.py를 뼈 대상(armature 부모·Armature 모디파이어·버텍스 그룹)을 유지하도록 고쳐야 함. `mesh.separate` 는 버텍스 그룹을 유지하므로 머리/몸 분리 자체는 가능 [추정].
- 방법 B: 생성 → fix_face.py → 고친 GLB 업로드 → rig-check(file_token, GLB만) → rig(file_token). 머리/몸 두 메시짜리 파일을 Tripo 리깅이 어떻게 처리하는지 문서에 없음 → 시험 필요. 리타깃이 필요하면 rig 작업의 task_id로 하면 됨.
- 리깅 없이 정적 모델만 필요하면: 생성 → fix_face.py → 로블록스 (지금 방식 그대로).

**캐릭터 1명 예상 비용**: C1 40 + 리깅 25 = **65크레딧 ($0.65)**. 동작 5개 더하면 +50.
18명이면 약 1,170크레딧 (약 $11.70), 시험 비용 별도.

### 9.3 몬스터 (일반 몹)

**M1. 기본**
```json
{
  "input": "<file_token>",
  "model": "v3.1-20260211",
  "face_limit": 12000,
  "texture": true,
  "pbr": false,
  "texture_quality": "standard",
  "texture_version": "v3.5-20260815",
  "delight": false,
  "model_seed": 23456,
  "texture_seed": 888
}
```
- 비용 **30** (얼굴이 중요한 몹이면 `"texture_quality": "detailed"` → 40).
- 작은 몹은 `face_limit` 6,000~10,000 으로 더 낮춰도 됨 (로블록스 성능에 유리).
- 몬스터는 A포즈 규칙이 없음. 몸 전체가 잘 보이는 정면 그림 1장, 배경 깨끗하게.

**리깅**
1. rig-check (무료) → `rig_type` 확인.
2. `biped` 면 캐릭터처럼 `v1.0-20240301`.
3. 그 외(`quadruped` 등)면:
```json
{"input": "<생성 task_id>", "model": "v2.5-20260210", "rig_type": "quadruped", "spec": "tripo", "out_format": "glb"}
```
- 비용 25. 이 버전에서 쓸 수 있는 동작은 `preset:quadruped:walk`, `preset:hexapod:walk`, `preset:octopod:walk`, `preset:serpentine:march`, `preset:aquatic:march` 뿐 (새 종류는 없음) → 공격·피격 동작은 로블록스 애니메이션 에디터에서 직접.
- `riggable: false` 면 리깅 없이 정적 메시 + 스크립트로 통통 튀기기 등으로 처리.

**몬스터 1마리 예상 비용**: 30~40 + 리깅 25 + 걷기 10 = **65~75**. 리깅 없으면 30~40.

### 9.4 보스

**B1. 멀티뷰로 뒤·옆까지 정확하게**
1. 그림 준비 (둘 중 하나)
   - GPT에게 같은 보스의 정면 + 뒷면 (+ 옆면) 을 같은 조명으로 그리게 한다 (무료, 디자인 통제 쉬움).
   - 또는 Tripo `POST /generation/image-to-multiview` `{"input": "<정면 file_token>"}` (10크레딧, 이미지 생성 동시 1개) → 결과 4장 확인 후 이상한 면만 `edit-multiview` (장당 5).
2. 생성:
```json
{
  "inputs": [
    {"front": "<정면 file_token>"},
    {"back": "<뒷면 file_token>"},
    {"left": "<옆면 file_token>"}
  ],
  "model": "v3.1-20260211",
  "face_limit": 20000,
  "geometry_quality": "detailed",
  "texture": true,
  "pbr": false,
  "texture_quality": "detailed",
  "texture_version": "v3.5-20260815",
  "delight": false,
  "texture_alignment": "original_image",
  "model_seed": 34567,
  "texture_seed": 999
}
```
   - Tripo 멀티뷰 결과를 쓸 때는 `"inputs": [{"task_id": "<image-to-multiview task_id>"}]`.
- 비용: 멀티뷰→3D 표준 30 + HD 텍스처 10 + HD 지오메트리 20 = **60** (+ Tripo 멀티뷰 그림 10).
- 2만 삼각형이 모자라면 [추정]: face_limit을 4만 등으로 올려 만든 뒤 블렌더에서 2만 이하 조각 여러 개로 나눠 MeshPart 여러 개로 가져오기. 조각마다 1024 텍스처를 따로 줄 수 있어 큰 보스도 선명. (단, 다시 굽기 없이 자르기만 해야 흐려지지 않음)
- 리깅은 몬스터와 같은 규칙 (rig-check → biped면 v1.0, 아니면 v2.5). 사람형 보스면 `cast_a_spell`, `slash`, `hit_to_body_01`, `victory_celebration`, `angry_01` 등 v1.0 동작이 쓸모 있음.

**보스 1마리 예상 비용**: 60~70 + 리깅 25 + 동작 5개 50 = **약 135~145**.

### 9.5 비용 한눈에 (1크레딧 = $0.01)

| 항목 | 크레딧 |
|---|---|
| 이미지→3D H3.1 표준 텍스처 | 30 |
| + HD 텍스처 | +10 |
| + HD 지오메트리 | +20 |
| + smart_low_poly | +10 |
| 이미지→3D P1 표준 / HD | 50 / 60 |
| 이미지→3D P2 표준 / HD / extreme | 110 / 120 / 130 |
| 텍스처 다시 (HD) | 20 |
| 변환 기본 / 고급 | 5 / 10 |
| 리깅 검사 / 리깅 | 0 / 25 |
| 동작 1개 | 10 |
| Tripo 멀티뷰 그림 | 10 |
| 실패·취소 | 0 (환불) |

---

## 10. 함정과 주의사항

1. `code == 0` 확인 전에 `data` 를 읽지 말 것.
2. 끝 상태는 `success / failed / banned / expired / cancelled` 다섯. 공식 예제는 `expired` 를 빼먹음.
3. 공식 예제 제한 시간 5분은 짧음 → 15분.
4. 결과 URL은 임시. 바로 받고, 받을 때 `Authorization` 헤더 넣지 않기. 만료되면 작업 재조회로 새 URL.
5. 크레딧 숫자는 소수 → float/Decimal.
6. 모델 이름: 별칭(`tripo-v3.1`, `tripo-p1`) 말고 날짜 이름(`v3.1-20260211`, `P1-20260311`)으로 고정.
7. `face_limit` 을 안 넣으면 자동 → 2만 넘을 수 있음. 항상 넣기.
8. P1에 `quad` → HTTP 400. H에서 `quad` → FBX 강제. 우리는 quad 안 씀.
9. `texture_version` 을 안 넣으면 최신이 아니라 v3.0. v3.5는 직접 넣어야 함.
10. `texture_quality: "fast"` 는 v3.5 텍스처에서만 (아니면 1004). 값은 standard와 같으니 쓸 이유 없음.
11. `delight` 는 v3.5 텍스처에서만 작동, 기본값 true. 다른 버전에선 조용히 무시.
12. `pbr` 기본값 true 이고 pbr=true 면 texture도 강제 true → 맨 모양을 원하면 `texture:false` 와 `pbr:false` 둘 다.
13. `generate_parts` 는 texture·pbr 둘 다 false여야 함 (아니면 1004). `smart_low_poly` 와 같이 쓰면 부위 분할이 조용히 사라짐. `quad` 는 조용히 무시.
14. `export_orientation` 을 넣고 나중에 리깅·변환하면 방향이 틀려도 success로 나옴 → 넣지 말기.
15. `orientation: align_image` 는 텍스처가 꺼져 있으면 효과 없음.
16. `/v3/files` 는 그림을 JPEG·PNG만 받음 (WebP는 presign으로).
17. presign PUT은 `Content-Type: application/octet-stream`, 키 헤더 없이, 30분 안에. 업로드 끝난 뒤에 token 사용.
18. rig-check는 GLB만. rig는 GLB/GLTF/FBX/OBJ/STL.
19. retarget의 `input` 은 **리깅 작업 id만**. 원래 생성 id나 파일은 안 됨.
20. 리타깃 프리셋 이름은 리깅 버전에 맞게: v1.0은 `preset:biped:walk`, v2.5는 `preset:walk`. `press-up` 만 하이픈.
21. `model` 을 빼고 리깅하면 v1.0(사람형 전용) → 네 발 몬스터는 `v2.5-20260210` 명시.
22. 뼈 이름(tripo/mixamo)은 로블록스 R15가 아님.
23. convert에 `GLB` 값이 없음 (`GLTF` 만). `texture_size`·`texture_format`·`pivot_to_center_bottom` 등 하나만 바꿔도 10크레딧. 기본 텍스처 형식이 JPEG라 작은 눈이 뭉개질 수 있음 → PNG.
24. `/mesh/decimate` v2.0은 텍스처를 다시 구움 → 흐려짐의 원인일 수 있음. 생성 때 face_limit으로 해결.
25. `compress: "geometry"` (meshopt) 는 로블록스·블렌더 가져오기에서 문제될 수 있으니 쓰지 않기.
26. 동시 실행은 **계정** 단위. 이미지 생성 분류는 1개뿐. 문서끼리 숫자가 달라서(3 vs 5~10) 분류별 3개로 제한.
27. 429는 `Retry-After` 를 따르고 재시도. 400/401/403은 재시도 금지. 2008(콘텐츠 정책)은 같은 그림 재시도 금지.
28. OpenAI 호환 이미지 API에서 `generation_in_progress` 가 나오면 이미 청구됨 → 다시 보내지 말고 작업 조회.
29. `chat_image_1` 은 2026-10-23, `chat_image_1.5` 는 2026-12-01 종료. GPT 그림 `quality` 기본은 `low`.
30. 문서 예제의 `type`, `credits_consumed` 값은 복붙이라 실제와 다름. 실제 값은 작업 조회로.
31. 생성 결과 텍스처 크기(standard/detailed)는 문서에 없음 → 첫 결과로 확인.
32. 시드는 응답에 안 나옴 → 우리가 정해서 보내고 기록.
33. 콘텐츠 정책: 입력 그림이 걸리면 `banned` 상태 또는 `2008`. 노출 있는 옷차림 금지 (로블록스 계정 제재 경험과 같은 규칙).
34. API 키는 사용자가 직접 콘솔에서 만들고 환경변수에 넣는다. 코드·채팅·git에 넣지 않는다.
35. `task_id`·`file_token` 이 `task_`/`file_` 로 시작한다고 가정하지 말 것 (UUID 예제도 있음).
36. 후처리(texture·convert·rig 등)의 task_id 입력은 문서상 "3D 생성 작업 id" 만 보장. 텍스처 다시 입힌 작업 id로 리깅이 되는지는 시험 필요 → 안 되면 GLB를 내려받아 다시 업로드.
37. 텍스트→3D 에는 `texture_alignment`, `orientation`, `enable_image_autofix` 가 없음.
38. OpenAI 호환 주소는 오류 모양이 다름 (`{"error":{...}}`). 우리 `call()` 은 그 주소에 쓰지 말 것.
39. image-to-multiview 는 task_id 입력을 안 받음 (file_token·URL만). edit-multiview 는 task_id·file_token·URL 다 받음.
40. 작업 조회 결과에 `type`, `progress`, `credits_consumed`, `completed_at` 이 빠질 수 있음 (리깅 예제 등) → `.get()`.

### 10.1 문서끼리 안 맞는 곳 모음

| 주제 | A 문서 | B 문서 | 우리 선택 |
|---|---|---|---|
| 모델 이름 | `tripo-v3.1`, `tripo-p1` (빠른 시작) | `v3.1-20260211`, `P1-20260311` (기능 페이지) | 날짜 이름 |
| P1 face_limit 하한 | 48 (models.md) | 50 (기능 페이지) | 50 이상 |
| 동시 실행 | 3개 (models.md) | H 10, P 5, 이미지 1 등 (rate-limits) | 분류별 3개 |
| 리깅 비용 | 25 (가격표) | 30.00 (예제 결과) | 25로 계산, 실제는 `credits_consumed` |
| 리타깃 비용 | 동작당 10 (가격표) | 20.00 (예제 결과) | 10으로 계산 |
| 리깅 v2.5 | 사람형 아닌 생물용 | 예제는 v2.5 + biped | 사람형은 v1.0 |
| 리깅 기본 모델 | v1.0-20240301 (API) | v2.0-20250506 (ComfyUI) | API 문서 |
| export_with_geometry 기본 | true (API) | false (ComfyUI) | true를 명시해서 보냄 |
| 큰 파일 업로드 주소 | `/files/upload-credentials` (변경 기록) | `/files/presign` (기능 페이지) | `/files/presign` |
| 오류 2000 | "Rate limit exceeded" (오류 문서) | 동시 실행 초과 (rate-limits) | 둘 다 429로 보고 기다림 |
| seedream 표기 | `seedream-v5` (예제) | `seedream_v5` (표) | 밑줄 |
| 이미지 크기 auto 요금 | 2K 요금 (가격표) | 1024x1024로 처리 (OpenAI 호환) | auto 안 씀 |
| 최고 품질 모델 | P1이 "flagship" (models-and-versions) | H3.1이 flagship (models.md) | 얼굴 품질은 H3.1 |
| 3D `model` 필수 여부 | 필수 (기능 페이지) | 생략 가능, 기본 v3.1 (models-and-versions, 이전 안내 예제) | 항상 넣음 |
| 구글 그림 모델 이름 | `banana`, `banana2`, `banana_pro` (기능·가격) | `gemini-2.5-flash`, `gemini-3-pro`, `gemini-3.1-flash` (models-and-versions) | 기능 페이지 이름 |
| task_id 모양 | `task_` 로 시작 (작업 조회 문서) | UUID (멀티뷰·OpenAI 호환 예제) | 모양 검사 안 함 |
| 상태 종류 | 5개 (소개·작업 조회 문서) | 7개, `banned`·`expired` 포함 (작업 수명 문서) | 7개 다 처리 |
| v1.0 리깅 동작 수 | "90+" (리깅 문서) | 101개 (리타깃 목록) | 목록 기준 |
| 리타깃 묶음 한도 | 최대 5개 (models.md) | 한도 언급 없음 (기능 페이지) | 5개 이하 |
| v2 주소 | 아직 병행 운영 (이전 안내) | 2015 = 폐기 버전 (오류 표) | v3만 씀 |
| 가져오기 형식 | GLB/GLTF/FBX/OBJ/STL (API) | +ply, 3mf, zip (ComfyUI) | API 목록 |
| ComfyUI 패키지 버전 | 1.3.0 (ComfyUI 문서) | 1.1.21 (플러그인 문서) | 상관없음 (안 씀) |
