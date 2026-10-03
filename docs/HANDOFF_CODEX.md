# HANDOFF_CODEX — 지금까지 한 것, 지금 상태, 다음에 할 것 (2026-10-03 기준)

> Codex(또는 다른 에이전트)가 이어서 작업하기 위한 문서. 먼저 루트의 `AGENTS.md`(규칙)를 읽고 이 문서를 읽는다.
> 사용자에게 말할 때는 항상 한국어, 짧게. 설명 대신 결과(스튜디오에서 플레이 가능한 상태)를 보여 준다.

## 1. 게임 한 줄 요약
"뇌 빼고 하는" 귀여운 로블록스 MMORPG **선악 키우기: 헤일로 & 혼즈**. 진영 3개(빛의 기사단 Halo / 뿔 군단 Horns / 장인 길드 Neutral, 청록 40,200,190) × 직업 3개(전사/마법사/궁수, 진영별 이름). 엘든 링 풍 대륙(교차로 → 말랑 초원 → 고블린 숲 → 해골 유적) + 진영 섬. 전체 맵은 지도(M)로만 본다.

### 바꾸면 안 되는 사용자 결정
- 변경 규칙: 무료 = 진행도 손실(직업 Lv1, 진영 점수 0), 로벅스 티켓 = 유지. 능력치/뽑기 판매 금지.
- 일일 퀘스트 유지 + 안 하면 휴가 보너스 70%.
- 독창성 7개: 덩치 저울, 원한 돈자루, 자동 장전/손 발사, 수배범 괴수화, 황금 거위 줄다리기(+단골 행운), 전향 환생, 휴가 보너스.
- 1:1 직접 거래 금지. 2단계 경제: 재료 드랍 → 전부 팔기 → 원버튼 제작 → 서버 간 거래소(판매 등록 + 예약 구매, 최소 10골드, 수수료).
- 모든 디자인은 GPT 그림으로 먼저(사용자가 고름) → 그대로 구현.
- 아바타: 진영·직업을 고르면 **3D 직업 코스튬**을 입힘(기본 켜짐, 설정에서 끄면 원래 로블록스 아바타).
- 메뉴 키 B (Esc는 로블록스 예약), 키 힌트는 키보드 기기에서만.

## 2. 지금 상태
### 코드 (`src/`, 약 2.6만 줄)
- 서버 서비스 19개 + 클라이언트 모듈 9개, 플레이 테스트에서 전부 정상 시작.
- 완료된 큰 작업 (자세한 계약은 SPEC_ADDENDUM):
  - A12 지도(WorldMap), A14 컴팩트 HUD, **GPT HUD 재디자인**(양피지+장난감, `Config.UIArt` + UIKit 아트 도우미)
  - **진영/직업 고르기 화면 재디자인**(GPT 카드, 남/여 전환, 능력치 5칸: 성기사 4/3/2, 마법사 2/4/3, 레인저 3/2/4)
  - **A15 타격감 + 아파하는 반응**(몬스터 예비 동작 `WindupAt`, 피격 `HurtSeq`, 플레이어 `Pain` Fx, 밀려나기, 베기 궤적, 히트스톱, 스티커)
  - 진영 고르기 전 팀 "진영 고르는 중"
- **코드 리뷰 R1 수정(HIGH 2 / MED 27 / LOW 51)**: 2026-10-03 GoodEvil에서 전체 33개 Luau 문법 정상 → 동기화 29개/동일 4개 → 15초 플레이 테스트를 완료했다. 서버 19/19와 ClientMain 클라이언트 8개 모듈이 정상 시작했으며 이번 검증에서 Luau 런타임 오류는 없었다.
  - 실제 UI로 빛의 기사단·성기사 선택, B 메뉴의 말랑 초원 이동, M 지도 열기/닫기·확대·내 위치, F 수동 전투, Q 발사, R 자동 공격, 안내 퀘스트 받기 중복 방지, 거위 공격, 괴수 Siren→Active를 확인했다. 거위 시작·괴수 별 5개·자동 공격용 레벨 5는 Studio 디버그로 설정했다.
  - 결과와 화면은 `docs/review/r1_studio_verify_2026-10-03.md`, 원본 체크리스트는 `docs/review/reviewer_code_r1.md`, 계약은 `docs/SPEC_ADDENDUM.md` A16을 본다.
  - DataStore API 미활성으로 메모리 모드였다. 저장·재접속/PairCD·다인 PvP·괴수 퇴장 정산·이동 오탐 조건 전체·새 계정 에셋은 미검증이다. 옛 Mesh/Texture 불러오기 실패 경고와 Developer Product ID 0도 남아 있다.
  - CR-H2(위치 검증)는 `Config.AntiCheat.Enforce = false`(로그만)를 유지한다. 메뉴 이동·리스폰·낙하 구조·덩치 변화·적 마을 튕김 등 오탐 조건 전체를 확인한 뒤 켠다.

### 아트 (`art/`)
- `art/prompts/<id>.txt` = 프롬프트, `art/out/<id>.png` = GPT 결과, `art/approved.json` = 사용자 승인 기록.
- UI 부품: `art/out/UIP_*` → 다듬은 것 `art/ui/UIP_*.png`, 크기/9-slice `art/ui/ui_meta.json`, (옛 계정) 업로드 id `art/ui/asset_ids.json`.
- 그림 글자(사용자가 고른 **C 스타일 = 금색 판타지 로고**): `art/out/TXT_*.png` 42개, 단어 목록 `art/ui/text_labels.json`. 아직 코드에 연결 안 함.
- 효과/스티커: `UIP_Fx*`(베기, 불꽃, 링, 마법, 먼지), `UIP_Emo*`(아야!, 눈물, 어지러움, 화남, 스트레스). 코드에는 `Id = ""`로 등록(대체 그림으로 동작 중).
- 무기 아이콘 27개 `Weapon_<Class>_<T1..T6|T7_Halo|T7_Horns|T7_Neutral>.png`, 텍스처 `Tex_*`, 지도 양피지 `UI_MapParchment.png`, 왕슬라임 `BigSlime.png`(연두색) — 아직 게임에 미연결.
- 직업 캐릭터 그림 18장 `UIP_Char<Faction><Class><M|F>.png` (뿔 6명·빛 여궁수는 노출 없게 다시 그림), 코스튬용 차렷 자세 `APose_*.png` 18장.
- 승인된 시안: `UI_HUD_Final.png`(HUD), `UI_Faction_B.png`(진영), `UI_Class_A.png`(직업), `UI_Lettering_C.png`(글자).
- **`art/out/v1/` 은 버린 그림. 절대 업로드 금지** (특히 `art/out/v1/revealing/`).

### 3D (`art/models/`)
- 몬스터 Tripo 모델: Slime, Goblin, GoblinBrute, Skeleton, SkeletonKnight, GoldenGoose(심술궂은 v2), SkeletonKing(보스, 게임에 아직 없음).
- 직업 코스튬 18명: `art/models/costume/fixed/Costume_<Faction><Class><M|F>.glb` (Tripo 2k → `tools/fix_face.py`: 머리 분리 + 머리 전용 1024 텍스처 + 샤픈). 원본 2k는 `raw/`(깃 제외), Tripo 작업 번호는 `tripo_tasks.json`.
- 몬스터는 스튜디오 place의 `ServerStorage.CustomModels.<Id>`에 넣으면 `MonsterService`가 자동으로 겉모습으로 씀(A1). 3D 가져오기: 스튜디오 3D Importer → 이름 정확히 → 크기 맞추고(슬라임 ~5, 고블린 5.5, 우두머리 8, 기사 7) 정면이 -Z인지 확인 → `ServerStorage.CustomModels`로 이동 → 저장(ctrl+s) → `build/GoodEvil.rbxlx`를 `place/`로 복사해 커밋.

### 계정 / 업로드 상황 (중요)
- 2026-10-03 옛 로블록스 계정 1일 정지(노출 그림). 사용자는 **새 계정을 계속 쓰기로 함**.
- 옛 계정이 올린 것은 새 계정 게임에서 안 보일 수 있다 → **같은 파일을 새 계정으로 다시 업로드/가져오기**(새로 만들 필요 없음). 2026-10-04부터.
  - UI 부품 68개(`art/ui/*.png`, id는 `Config.UIArt.Parts`와 `art/ui/asset_ids.json` 갱신), 효과·스티커 10개, 그림 글자 42개, 무기 아이콘 27개.
  - 몬스터 3D 7개 + 코스튬 18개는 3D Importer로 다시 가져오기. MaterialService `GE_Grass` 텍스처 다시.
  - 업로드 전 한 장씩 확인 → 사용자에게 보여 주기 → 10장 이하씩 나눠서.

## 3. 다음에 할 일 (우선순위)
1. **R1 기본 스튜디오 검증 완료**: 전체 문법·동기화·시작·진영/직업·전투·퀘스트·지도·거위·괴수 기본 동작 확인 완료(위 기록). 남은 다인 PvP/PairCD 저장·재접속/괴수 퇴장 정산/이동 오탐 전체 조건은 별도 검증한다. `AntiCheat.Enforce`는 아직 끄고 둔다.
2. **새 계정으로 재업로드**(10-04부터, 위 규칙대로) → `Config.UIArt.Parts`의 `Id = ""`들 채우기(코스튬 카드/캐릭터/아이콘/Fx/Emo).
3. **그림 글자 연결**: 고정 글자(공격, 발사, 메뉴, 지도, 받기, 교체, 오늘의 퀘스트, 진영·직업 이름, 화면 제목, "이 편으로!", "이 직업으로!", 레벨 업!, 지역 이름…)를 `TXT_*` 이미지(ImageLabel)로. 바뀌는 글자는 나눔고딕 ExtraBold(`Font.fromId(12187361718, Enum.FontWeight.ExtraBold)`, 게시한 place에서 403 확인)나 Montserrat Bold + 진갈색 UIStroke + 따뜻한 색. 이미지가 없으면 지금 글자로 대체(IMG-R4).
4. **직업 코스튬 시스템**(기본 켜짐, 설정에서 끄기):
   - 계획: Tripo 자동 리깅(biped, mixamo 뼈, 25크레딧) → 블렌더에서 뼈 가중치로 메시를 R15 15조각(Head, UpperTorso, LowerTorso, Left/RightUpperArm, LowerArm, Hand, Upper/LowerLeg, Foot)으로 나누고 관절 위치 JSON 출력 → 스튜디오에서 조각을 MeshPart로 가져와 커스텀 R15 리그(Motor6D를 관절 위치에)로 조립 → 스폰 때 `player.Character`로. 로블록스 기본 걷기/점프 애니메이션이 그대로 돈다. (로블록스 자동 아바타 설정은 치비 비율이라 실패함.)
   - 리깅은 `py tools/tripo_api.py`로(사용자가 API 충전 + `.env`에 키). 성기사(남) 하나로 먼저 시험.
5. **무기 아이콘/텍스처/지도 양피지/왕슬라임 연결**: 무기 업그레이드 카드·상점에 무기 아이콘, `Tex_*`는 MaterialVariant(`MaterialService`)로 지형, `UI_MapParchment`는 WorldMap 배경, 왕슬라임은 Tripo 3D → `CustomModels.BigSlime`.
6. **해골 왕 보스**: 아직 게임에 없음(기획 확인 후 추가).
7. 2단계 경제(재료/제작/거래소) — ADDENDUM에 설계 먼저.

## 4. 그림 → 게임 파이프라인
1. 프롬프트 `art/prompts/<id>.txt` 작성(캐릭터는 단정한 옷차림 문구 필수) → 생성 → `art/out/<id>.png`.
2. 사용자에게 보여 주고 고르게 함 → `art/approved.json` 기록.
3. UI 부품이면 `py tools/prep_ui.py <id>` → `art/ui/` → 업로드(로컬 http 서버 + `upload_image`) → `Config.UIArt.Parts`에 `{ Id, Size, Slice }`.
4. 3D면 Tripo(API: `tools/tripo_api.py`, 웹: studio.tripo3d.ai) → 텍스처 2k로 → `tools/fix_face.py`(캐릭터) → 스튜디오 3D Importer.

## 5. Tripo 3D
- 웹 스튜디오 크레딧 약 70 남음. API는 별도 선불(1크레딧=$0.01, 실패 환불): 충전 https://developers.tripo3d.ai/en/billing, 키 https://developers.tripo3d.ai/en/keys.
- 문서 전체 사본 `docs/vendor/tripo_api/*.md` + 한국어 정리 `docs/vendor/tripo_api/README_KO.md`(추천 레시피 9장).
- 추천 설정(캐릭터): H3.1 `v3.1-20260211`, `texture_quality: detailed`, `texture_version: v3.5-20260815`, `texture_alignment: original_image`, `pbr: false`, `face_limit: 18000`. 따로 리토폴로지 금지(다시 구우면서 흐려짐). 약 40크레딧(+리깅 25).
- 조사 결론: Tripo 유지가 최선(Meshy 7.1만 비교 후보).

## 6. 로블록스/스튜디오 함정
- `Terrain:FillBlock`은 요청보다 2스터드 높게 채움 → 모든 채우기를 2 낮춤(preview_map.lua 반영됨).
- Atmosphere 금지(WarService가 Fog를 트윈함). 조명: ClockTime 16.8, Brightness 1.8, Fog 120/650.
- 스크립트 만들기는 MCP `multi_edit`로만(execute_luau 샌드박스는 스크립트를 부모로 못 붙임). `sync_to_studio.py`가 처리.
- `luau_check.py`는 Edit 모드에서만. Play 중이면 `playtest.py --stop` 먼저.
- 스튜디오 화면 캡처는 창이 앞에 있어야 함(최소화면 흰 화면).
- 3D Importer 이름 칸에 Tab을 치면 이름에 탭이 들어감 → 클릭으로 확정.
- 로블록스 업로드 정지 중에는 자기 에셋(이미지/메시/텍스처)이 전부 403으로 안 불러와져 화면이 깨져 보임.

## 7. 문서 지도
- `AGENTS.md` 규칙 · `docs/GDD.md` 기획 · `docs/TECH_SPEC.md` 계약 · `docs/SPEC_ADDENDUM.md` 최신 결정(우선) · `docs/ART_DIRECTION.md` · `docs/review/` 리뷰 · `docs/vendor/tripo_api/` Tripo API.
