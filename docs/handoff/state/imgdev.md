# 이미지 개발 — 상태 (2026-10-11 인계, 옛 세션 → 새 세션)

## 다음 큐 (순서대로)
1. **빛 마을 지붕 맵 올리기** — 이미지 생성 3이 지붕을 몸통에서 떼어 따로 굽는 중. 오면
   `py tools/upload_sa_maps.py art/models/tripo/halo_houses/<집> --tags CNMR --names <집>_Roof...` → 적용 목록 다시 만들기(아래 3).
2. **대리석 1판/2판 고르기 결과 반영** — 이미지 생성 3이 WorldKit 집 07 골격에서 `HH_HaloMarbleBlock`(9 studs) vs
   `HH_HaloMarbleBlock_Cream`(12 studs)을 나란히 보고 고름 → `art/models/worldkit/building_variants_halo.json`의 숫자만 고치고
   `py tools/building_variants.py` 다시. 메인은 메인 반영 1과(Luau 맨 위 ALLOW_MAIN).
3. **집·가게 SA 적용** — 가져오기(WorldKit, 사용자 클릭) 뒤 이미지 생성 1/3이 WorldKit에서 돌림. Luau 만들기:
   `py tools/apply_sa_by_name.py <집 01~12·가게 4 폴더> --glass <각 _Glass> --skip '_Body_t[0-9]+$' --mode survey|apply`
   (부품 64 + 유리 16; Mesh_0이면 부모 이름으로 찾음). 몸통(Body_t**) 맵은 A23-120으로 안 씀 — id만 장부에 있음.
4. **A23-105 사진 1번** — 새 마을(A23-121)이 메인에 들어간 뒤 메인 반영 1이 처마 밑 + 밤 등불 사진. 그것 말고 WeatherFx는 끝
   (메인 비 사진 rain_preview/sheet.jpg 확인함; DayPhasePreview는 WeatherFx만 속이고 하늘 밝기는 안 바꿈 = 원래 설계).
5. ~~스킬 Z·X 아이콘 SkillBar 사진~~ 끝(10/11 새 세션): art/review/imgdev/skillbar_lv25_2026-10-11.jpg (빛 Paladin Lv25, 간격 Q/Z 8 · Z/X 8.8 · X/공격 13.8 px). X Guardian 투구 옆 노란 호 3줄 → 빛살 규칙 판단 검수에 물음.

## 만든 MaterialVariant (building_variants_halo.json, main e2f466f·077dffd)
- `HH_HaloMarbleBlock` Marble 9 studs — color 133937959661245 normal 126193858276827 rough 82509703836879 metal 87489921567476
  (이미지 생성 1이 10/10에 올린 Halo_TowerMarbleBlock_*)
- `HH_HaloMarbleBlock_Cream` Marble 12 — color 80357186990466 normal 73394105072257 (rough/metal = 1판). 비교 시트
  art/review/imgdev/halo_marble_cream_compare_2026-10-11.jpg
- `HH_HaloGoldTrim` Metal 4 — color 94913368757526 normal 131597673772642 metal 91394364117916 rough 82910627301523, 파트 Color (240,186,56)

## 오늘 끝낸 것 (전부 main)
- A23-114 잠긴 장인 카드(가운데, 그림 FactionPickSoon 73776589039158) + 마스코트 둘 같은 규칙, 빛 C 118792983602547 / 뿔 D 106604703369405
- A23-113 ③ 접힘 고침(4424550b), 잠긴 칸 모양 UIKit.TileLock(병합, 개발 1이 씀)
- 스킬 아이콘 Q 6 + Z·X 12 (Skill_<Class>_<Slot>_<Faction>)
- 교차로 SA 21개(메인 적용됨, 검수: 임시 개선, 그 구역 차례에 부품별 새로)
- 집 12·가게 4 비몸통 맵 업로드(부품 64 × 4), 집 07·11 다시 구운 판으로 교체

## 도구 (tools/)
upload_sa_maps.py(빈 포트·200 확인, --replace, --stale-from), apply_sa_by_name.py(--skip, 부모 이름), apply_sa_maps.py(교차로식 MeshId 매칭),
building_variants.py, zone_split_batch.py(--gold-v-min, no_gold 마스크), deco_sa_maps.py, api_agent.py.

## Studio·worktree
- UiSandbox: 열려 있음(10/11 명령으로 다시 염), Edit, 마지막 sync = 공유 트리 main. 창이 뒤에 있으면 screen_capture가 하얗게 나옴(창 조작은 검수 허락).
- 포트 8765에 남의 http.server(PID 28400) — 끄지 말 것(검수).
- worktree C:/Users/glori/Documents/Roblox/Game-imgdev-q: 브랜치 imgdev-skillicons(병합됨). 수정된 건 시험 결과 json뿐(커밋 안 함).
  옛 브랜치 imgdev-tilereveal/-v2/-artisan-soon/-photos/-photos2는 버린 것.

## 막힌 것 / 기다리는 것
- 이미지 생성 3(새 세션, state/img3.md 큐 6): 4판에서 대리석 판 고르기 + 집 07·11 Roof 맵 굽기 → 판 이름·칸 수·Roof 폴더를 한 줄로 보내 줌. (10/11: WorldKit에 HH_HaloMarbleBlock 9칸·HH_HaloGoldTrim 적용됨, 집 07 골격 금 파트 = Metal + GoldTrim + (240,186,56), f686324) 사용자: WorldKit 가져오기 클릭(아침).
