# 이미지 세션 인계 (검토 세션, 2026-10-06)

새 "이미지" 세션이 그림을 맡을 때 먼저 읽는 문서. 규칙의 원본은 `AGENTS.md`(Art workflow·Hard rules)와 `docs/design/visual_direction_2026-10-05.md`(스타일·묶음 0–21), 프롬프트는 `docs/design/firefly_prompt_pack_2026-10-05.md`.

## 역할 나누기
- **이미지 세션:** Firefly 생성 → 다운로드 → 누끼·검사 → 사용자에게 보여 주고 승인 → `art/approved.json` 기록 → 커밋(파일 경로를 하나씩) → 개발 세션에 파일·키 전달.
- **개발 세션(로블록스 선악 키우기 개발):** 업로드(≤10장씩), `Config.UIArt.Parts`·MaterialService ID 교체, Studio 적용, 직접 플레이 확인, 옛 그림 삭제.
- **검토 세션:** 문서·결정·검수·프롬프트 방향. Firefly 브라우저는 이미지 세션만 쓴다(같은 내장 브라우저 창을 두 세션이 동시에 쓰면 꼬인다).

## 사용자 규칙 (그림)
- 사용자에게는 **한국어로 짧게**. 설명 대신 그림을 보여 주고 "이걸 넣는다"고 말한다.
- 모델: Firefly 안의 **GPT Image 2.5 → Sunburst**. 품질 **중간(무제한)** 으로 탐색, **높음(장당 5크레딧)** 은 그대로 쓰는 중요한 최종본에만, 쓰기 전에 말한다. 쓴 크레딧은 보고한다.
- 시안이 승인되면 세부 부품은 **투명 배경 PNG로 한 장씩** 따로 그린다. 시안·목업을 잘라 쓰지 않는다.
- 그림에 글자를 넣지 않는다(게임 TextLabel로 한/영 전환).
- 사람 캐릭터는 어깨·몸통·배·다리를 옷으로 가린다(옛 계정 정지 이력). 브랜드 이름 대신 모양으로 묘사("blocky toy-avatar style, square head …").
- `art/out/v1/`와 노출 사본은 절대 쓰지 않는다. 옛 그림을 참조로 쓰지 않는다.
- 완성되고 승인된 그림은 **바로** 개발 세션에 넘겨 Studio에 넣고 플레이 확인하게 한다(모아 두지 않는다).
- 유료(Tripo 등)는 크레딧 총액을 먼저 말하고 사용자 OK 뒤에만.

## Firefly 작업 요령 (내장 브라우저 `mcp__Claude_Browser__*`)
- PC를 다시 켜면 로그인이 풀린다 → 사용자에게 내장 브라우저(Ctrl+Shift+B)에서 로그인해 달라고 한다.
- 모델 고르기: 모델 목록 → 파트너 탭 → GPT Image 2.5 Sunburst. **모델을 바꾸면 비율이 Auto로 돌아가니 1:1을 다시 고르고, 품질이 '중간'인지 확인**한다.
- 프롬프트 칸은 shadow DOM 안의 TEXTAREA다. JS로 focus·select 한 뒤 입력하고, `space BackSpace`를 한 번 쳐야 생성 버튼이 켜진다. 한 장 약 20초.
- 배경은 "plain flat medium gray background with a wide empty margin, soft even light, clean shadowless backdrop" 로 받는다(누끼가 쉽다).
- **다운로드는 브라우저 저장 창을 쓰지 않는다**(사용자가 헷갈려 함). Adobe MCP로 받는다:
  1. `adobe_mandatory_init`
  2. `asset_search` (entityScope GenAIAsset, sortBy createDate desc) → 방금 만든 것 찾기. 같은 계정에 다른 게임 생성물도 있으니 시간·프롬프트로 확인.
  3. `asset_get_presigned_urls` → `downloadUrl`을 `curl -sL`로 `art/out/<id>_src.png`에 저장(원본 약 1254px). `renditionURL`은 600px라 쓰지 않는다.

## 누끼·검사
- `py tools/cutout_flat.py art/out/<id>_src.png art/ui/<Key>.png --check art/review/<Key>_check.png`
  - 평평한 회색 배경 기준 테두리 flood-fill. 남색 외곽선을 지킨다(Adobe `image_remove_background`는 외곽선을 먹은 적이 있다).
  - 기본 512px, 피사체 86%. 체크 시트(밝은·남색·자홍 배경 + 48px)를 크게 보고 테두리 얼룩·구멍·떨어진 조각이 없는지 확인한 뒤 보여 준다.
- 지형 타일은 누끼하지 않는다: 이음새 없는 정사각 타일, 3×3으로 이어 붙여 확인.

## 현재 상태 (2026-10-06)
- 끝: 묶음 0(아기 슬라임·핼러윈 몬스터 시안 → Tripo 3D, Studio 반영), `IconPetBabySlime`, `IconCandy`, 몬스터 머리 아이콘 5장(`IconMonSlime`, `IconMonPumpkinSlime`, `IconMonLittleGhost`, `IconMonBatGoblin`, `IconMonPumpkinKing`, 커밋 8ed75e1, 개발 세션이 업로드·적용 중).
- 다음: `visual_direction` §3 묶음 1(스타일 보드)부터. 단, 화면 배치(HUD 재배치) 회색 상자 승인이 묶음 1보다 먼저다(RELEASE_PLAN 6단계). 기능 작업(BB·핼러윈)에 바로 필요한 아이콘·부품 요청이 오면 그것을 먼저 그린다.
- 작업 폴더에 출처를 모르는 미추적 프롬프트(`art/prompts/UI_FactionParts_*`, `NPC_EquipmentMerchant_*` 등)가 있다. 지우지 말고 쓰기 전에 사용자/검토 세션에 확인.
