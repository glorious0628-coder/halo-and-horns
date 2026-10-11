# 이미지 세션 인계 (검토 세션, 2026-10-06)

새 "이미지" 세션이 그림을 맡을 때 먼저 읽는 문서. 규칙의 원본은 `AGENTS.md`(Art workflow·Hard rules)와 `docs/design/visual_direction_2026-10-05.md`(스타일·묶음 0–21), 프롬프트는 `docs/design/firefly_prompt_pack_2026-10-05.md`.
> 10/11 갱신(Firefly 요령 절은 지금도 쓸 만, 나머지는 기록용): 3D는 Tripo HD H3.1 앞·뒤·좌·우 4면 → Blender 손보기(필수) → Roblox 재질(A23-122·125), 건물 큰 덩어리는 Studio 파트 골격(A23-120), 3D 생산은 이미지 생성 3. 이미지 생성 1은 세계·장소 배치(`build/WorldKit.rbxlx`). 구역 순서 빛 → 뿔 → 교차로 → 초원 → 새 구역(수정 동굴·산호 해안) → 숲 → (유적)(A23-119), 호박밭·유령 숲은 내년 10월까지 숨김. 고른 최종 그림은 High(5)·후보는 Medium(0)은 그대로.
> 2026-10-09 검수: '이미지 세션' = 지금 **이미지 생성 1**(세계·장소 디자인 리드, 큰 세계 그림, 3D 세계 키트·Tripo, WorldKit — AGENTS Roles). 자잘한 그림은 이미지 생성 2, '검토 세션' = 검수, 메인 Studio 반영은 메인 반영 1. 지금 할 일은 `docs/handoff/role_prompts/06_img1.md`, `docs/design/halo_town_plan_2026-10-09.md`.

## 역할 나누기
- **이미지 세션:** Firefly 생성 → 다운로드 → 누끼·검사 → ~~사용자에게 보여 주고 승인~~ 검수에게 보내 승인(사용자 승인은 검수를 거침, AGENTS Roles) → `art/approved.json` 기록 → 올리기(파일 경로를 하나씩, 공유 트리는 `py tools/push_paths.py`) → 이미지 개발 세션에 파일·키 전달(검수 참조).
- **이미지 개발 세션(2026-10-06 새로):** 업로드(≤10장씩), `Config.UIArt.Parts`·MaterialService ID 교체, Studio 적용, 직접 플레이 확인, 옛 그림 삭제. 규칙은 `docs/design/image_dev_session_handoff_2026-10-06.md`. 이미지 개발 세션이 생기기 전까지는 게임성 개발('개발') 세션에 보낸다.
- **게임성 개발 세션('개발'):** 기능·서버·테스트. 그림이 필요하면 이미지 세션에 직접 요청한다.
- **검토 세션(= 지금 '모든 것 검수'):** 문서·결정·검수·프롬프트 방향. Firefly 브라우저는 ~~이미지 세션만~~ 이미지 생성 1·2(그리고 소리 만들기)가 쓰고, 각자 자기 탭만 쓴다(같은 탭을 두 세션이 동시에 쓰면 꼬인다).
- 주의: 같은 이름('이미지 생성'·'이미지 개발'·'게임성 개발')의 **fashion 폴더(다른 게임) 세션**도 돈다. 받는 쪽은 `list_sessions`의 cwd(Game)나 받은 메시지의 from 주소로 고른다. 브라우저는 `preview_start(url)`로 연 내 탭의 tabId만 쓴다.

## 사용자 규칙 (그림)
- 사용자에게는 **한국어로 짧게**. 설명 대신 그림을 보여 주고 "이걸 넣는다"고 말한다.
- 모델: Firefly 안의 **GPT Image 2.5 → Sunburst**. 품질 **중간(무제한)** 으로 탐색, ~~높음(장당 5크레딧)은 그대로 쓰는 중요한 최종본에만, 쓰기 전에 말한다~~ → 고른 최종 그림은 종류와 관계없이 모두 **높음(장당 5)**(A23-47 보강 3). 쓴 크레딧·잔액은 기록과 검수 보고에 적는다(사용자에게는 잔액 약 500일 때만, A23-96).
- 시안이 승인되면 세부 부품은 **투명 배경 PNG로 한 장씩** 따로 그린다. 시안·목업을 잘라 쓰지 않는다.
- 그림에 글자를 넣지 않는다(게임 TextLabel로 ~~한/영 전환~~ — 게임은 영어만, A23-48).
- 사람 캐릭터는 어깨·몸통·배·다리를 옷으로 가린다(옛 계정 정지 이력). 브랜드 이름 대신 모양으로 묘사("blocky toy-avatar style, square head …").
- `art/out/v1/`와 노출 사본은 절대 쓰지 않는다. 옛 그림을 참조로 쓰지 않는다.
- 완성되고 승인된 그림은 **바로** ~~개발 세션에~~ 넘겨(UI 그림 → 이미지 개발, 3D·세계 소품 → 검수 통과 뒤 메인 반영 1) Studio에 넣고 플레이 확인하게 한다(모아 두지 않는다).
- ~~유료(Tripo 등)는 크레딧 총액을 먼저 말하고 사용자 OK 뒤에만.~~ → Tripo 3D는 사용자 상시 OK: 묶음마다 범위·합계를 검수에 보내고 검수가 승인한다(A23-47 보강 4). 지금은 Tripo 웹 25,000 계정 HD(1개 55포인트, A23-47 보강 8 — 10/07 비교 a0447d4 뒤로 웹은 모두 HD; A23-96), 재활용 금지(A23-96). 기록은 `art/models/tripo/records.json`.

## Firefly 작업 요령 (내장 브라우저 `mcp__Claude_Browser__*`)
- PC를 다시 켜면 로그인이 풀린다 → ~~사용자에게~~ 검수를 통해 사용자에게 내장 브라우저(Ctrl+Shift+B)에서 로그인해 달라고 한다.
- 모델 고르기: 모델 목록 → 파트너 탭 → GPT Image 2.5 Sunburst. **모델을 바꾸면 비율이 Auto로 돌아가니 1:1을 다시 고르고, 품질이 '중간'인지 확인**한다(고른 최종을 받을 때는 '높음', A23-47 보강 3).
- 프롬프트 칸은 shadow DOM 안의 TEXTAREA다. JS로 focus·select 한 뒤 입력하고, `space BackSpace`를 한 번 쳐야 생성 버튼이 켜진다. 한 장 약 20초.
- 배경은 "plain flat medium gray background with a wide empty margin, soft even light, clean shadowless backdrop" 로 받는다(누끼가 쉽다).
- **프롬프트는 1,024자까지.** 넘으면 생성 버튼을 눌러도 조용히 안 되고 빨간 알림만 잠깐 뜬다. 900자 안쪽으로 쓴다.
- 내장 브라우저 창이 좁으면 모바일 화면이라 모델 메뉴가 안 열린다 → `resize_window` 1280×900으로 넓히면 왼쪽 설정판이 나온다(턴이 끝나면 풀리니 다시 설정). 생성 버튼은 대략 (751,532) (800×562 좌표).
- 한 번에 한 장씩 생성된다. 프롬프트는 생성이 시작될 때 읽히므로, 생성 중에 칸을 바꾸면 다음 장이 새 문구로 나온다. 한 장 약 20~25초.
- 같은 계정에 다른 게임(fashion 폴더) 생성물이 섞여 있다. `asset_search`에 `query`로 프롬프트 첫머리(예: "Game ranking tab icon")를 넣으면 우리 것만 추린다. 최근 원본은 1024px.
- **다운로드는 브라우저 저장 창을 쓰지 않는다**(사용자가 헷갈려 함). Adobe MCP로 받는다:
  1. `adobe_mandatory_init`
  2. `asset_search` (entityScope GenAIAsset, sortBy createDate desc) → 방금 만든 것 찾기. 같은 계정에 다른 게임 생성물도 있으니 시간·프롬프트로 확인.
  3. `asset_get_presigned_urls` → `downloadUrl`을 `curl -sL`로 `art/out/<id>_src.png`에 저장(원본 약 1254px). `renditionURL`은 600px라 쓰지 않는다.

## 누끼·검사
- `py tools/cutout_flat.py art/out/<id>_src.png art/ui/<Key>.png --check art/review/<Key>_check.png`
  - 평평한 회색 배경 기준 테두리 flood-fill. 남색 외곽선을 지킨다(Adobe `image_remove_background`는 외곽선을 먹은 적이 있다).
  - 기본 512px, 피사체 86%. 체크 시트(밝은·남색·자홍 배경 + 48px)를 크게 보고 테두리 얼룩·구멍·떨어진 조각이 없는지 확인한 뒤 보여 준다.
- `--holes`: 트로피 손잡이·끈 고리처럼 **닫힌 회색 구멍**까지 지운다(지운 구멍을 출력하니 확인). 기본 기준 `--hole-tol 5`, 그늘진 구멍은 10까지. **흰 배경(BG_WHITE) 그림에는 쓰지 않는다** — 흰 반짝임까지 뚫린다(해골 기사 사례).
- 외곽선 밖에 빛 번짐이 생기면(뼈 첫 판) 다시 뽑는다: 문구에서 "glow and sparkles" 줄을 빼고 "outline with a crisp hard edge"를 넣는다.
- 색만 바뀌는 형제(주문서 70/30/10 등)는 **무채색 띠로 한 장** 그리고 `py tools/band_mask.py art/ui/<Key>.png art/ui/<Key>Band.png --preview ... --tints "r,g,b;..."` 로 띠 마스크를 뽑는다. 같은 512 캔버스라 겹치면 맞고, 개발은 Band.ImageColor3로 칠한다.
- 지형 타일은 누끼하지 않는다: 이음새 없는 정사각 타일, 3×3으로 이어 붙여 확인.

## 현재 상태 (2026-10-06)
> 2026-10-09 검수: 이 절은 낡음 — 지금은 한 구역씩 시안대로(A23-97, 지금 = 빛 마을), 장소마다 시안 묶음(A23-93), 재활용 금지(A23-96). 지금 할 일은 `docs/handoff/role_prompts/06_img1.md`.

- 끝: 묶음 0(아기 슬라임·핼러윈 몬스터 시안 → Tripo 3D, Studio 반영), `IconPetBabySlime`, `IconCandy`, 몬스터 머리 아이콘 5장(`IconMonSlime`, `IconMonPumpkinSlime`, `IconMonLittleGhost`, `IconMonBatGoblin`, `IconMonPumpkinKing`, 커밋 8ed75e1, 개발 세션이 업로드·적용 중).
- 다음: `visual_direction` §3 묶음 1(스타일 보드)부터. 단, 화면 배치(HUD 재배치) 회색 상자 승인이 묶음 1보다 먼저다(RELEASE_PLAN 6단계). 기능 작업(BB·핼러윈)에 바로 필요한 아이콘·부품 요청이 오면 그것을 먼저 그린다.
- 작업 폴더에 출처를 모르는 미추적 프롬프트(`art/prompts/UI_FactionParts_*`, `NPC_EquipmentMerchant_*` 등)가 있다. 지우지 말고 쓰기 전에 사용자/검토 세션에 확인.
