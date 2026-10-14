# 디자인 검수 — 상태 (2026-10-14 낮, 대기 · 클리어 전 정리)

10/14 다시 켬(A23-172, Opus 5.5 high). 맡는 것 = **Blender 손보기 2**(Tripo 계정 2, 사용자 Chrome) 흰 모델 고르기 + PBR 첫 판정, 이미지 생성 2의 부품 2D. 위로 = 최종 검수. 세션 id는 list_sessions로(이름: 'Halo & Horns 최종 검수', 'Blender 손보기 2').

## 지금 (10/14 낮) — 대기
- **SPEC A23-174(사용자 10/14 낮): Tripo = HD 탭 한 번에 생성(65점, 멀티뷰 4면·텍스처 8K·조명 제거·PBR·폴리곤 20000/작은 부품 8000) → 흰 모델 고르기 단계 없음.** 내 몫 = ① 결과 PBR 판정(2D 옆 앞·옆·뒤·위 3/4 + 100% 크롭 + 자홍 비침 검사 = Baluster 때 방식 그대로; 구멍·비침·모양 다름 = 떨어짐 → 다시 생성 65, 2D 문제면 이미지 생성 2로) ② 이미지 생성 2의 2D 부품 판정. 두 번째 판정 = 최종 검수. 아래 판정 규칙의 '흰 모델 고르기' 줄은 이제 기록.
- **A23-175: 부품까지 3D 전부 Tripo HD(65점)** — 내 몫은 같음.
- **사용자 최종(10/14 낮): 사람도 부품(머리·몸·소품) 각각 HD → Blender 합침. 스마트 메시·흰 모델 고르기 다시 없음** — 내 몫 = HD 결과 PBR 판정 + 2D 부품 판정 그대로. 아래 통짜 사람 HD 판정(8명, HerbWife 19d2016d 포함)은 **기록용, 안 씀**. 앞으로 사람 = 이미지 생성 2의 **부품 2D(시범 Bright)부터 내가 먼저 판정** — 머리는 후광 없이 그림(게임 공용 후광 붙임) → 머리에 후광 있으면 다시.
- **사람 HD(10/14 낮):** BakerGranny e4e7b4f2·BellElder 7344655d 최종 통과; Bright 8ad5a30e·FlowerFarmer 9fc91c29·FlowerGirl bba1bc9f 첫 통과(최종 대기). **후광 규칙(최종 검수): Tripo 후광은 8각·납작해도 그대로, ⑤에서 메시 후광 숨기고 게임 공용 후광(CharacterVisuals)을 머리에 붙임 → 사람 판정에서 후광 각짐은 지적 안 함.** Rail·Base 비율 = 사용자 답 대기. 판정 수 9(난간 4 + 사람 5), 다음 요약은 10개째. 이미지 생성 2 부품 2D: ①(바위 3·통 1) = 최종 검수가 직접 통과, **②(분수 부품)부터 내가 먼저 판정**(모양·크기 비율이 승인 4면과 맞는지).
- **10/14 낮 사용자 '가' → 빛 마을 Tripo HD 시작.** Blender 손보기 2가 결과마다 판정 요청(난간 부품 4 → 사람 15 → 단순 14 → 부품들). 판정 = `pbr_gate.py` 시트 + `seethru.py` 비침 시트(초록 0) → 통과/다시(크롭 자리·이유) → 손보기 2 + 최종 검수. 사람 = 복장(아이용, 노출 없음)·얼굴 무늬 없음도. 이미지 생성 2 부품 2D 시트도 먼저 판정(모양·크기 비율이 승인 4면과 맞는지). **5개마다 최종 검수에 한 줄 요약.** 렌더만, 화면 안 씀.
- **다음 물건 = 빛 마을 목록이 사용자 '가'를 받으면 최종 검수가 순서대로 보냄 — 그때까지 대기.**
- **HaloVar4_Baluster = PBR 첫 판정 통과 → 최종 검수 최종 통과(10/14 낮).**
- **HD 묶음 1(난간 4, 10/14 낮, 시트 `art/review/design/pbr_gate_hd_1014/` + 비침 `pbr_gate_hd_1014_dr/`):** CornerPost 03d13086 최종 통과 · EndPost cd8d14b9 첫 통과(최종 대기) · RailSegment 0208d453 첫 통과, 깊이 +39% · BaseSegment 766224ad 첫 통과, 깊이 +36%·높이 +16%, 윗면 옅은 주름 2줄(그대로). 모두 비침 0·1조각. EndPost 최종 통과. **최종 검수 결정: 한 축만 늘이기/줄이기 = '모양 늘이기 금지'(A23-159 #5) → 안 씀. Rail = 다시 생성 1번(55점)**, 두 번째도 두꺼우면 최종 검수가 사용자에게 물음. Base(깊이 +36%·높이 +16%)는 결정 대기(같은 길로 갈 듯). 앞으로 비율 다름은 '다시 생성'으로 판정, 한 축 조정 추천 안 함. 비율 재기 = 2D 배경 차 bbox vs 렌더 bbox(깊이/길이, 높이/길이). 다음 = 사람 15명(폴리곤 20000, 텍스처 4K, 55점) → 복장·얼굴 무늬도.
  - 흰 모델 4개: d2cb7d72(위 파인 접시, 열린 모서리 573/10조각) · db407464(2/3) · **a7a73124(376/5, 실제로 쓴 것)** · 6a4879ed(40/2).
  - 나는 Tripo(Chrome 새 탭)에서 축 보기로 위·아래·앞·옆·뒤 보고 3을 골랐다가, 손보기 2의 FBX 열린 모서리 숫자(내가 Blender CLI로 다시 셈, 같음)를 보고 4로 바꿈 → **메시지 엇갈려 손보기 2가 3으로 텍스처를 누름** → 최종 검수 OK: 3을 PBR까지, 비침이면 4(25점). 결과 3 텍스처 29c5640c → PBR 8fc77956, 비침 0 → 4는 안 함.
  - 시트: `art/review/design/pbr_gate_1014_dr/HaloVar4_Baluster_p_SM_texMV4k_pbr_src.jpg` + 이음 비침 검사 `HaloVar4_Baluster_seams_magenta.jpg`(push 29f5965). 원본 FBX `art/models/tripo/web/HaloVar4_Baluster_p_SM_texMV4k_pbr_src.fbx` md5 343e4e31.
  - ⑤ 메모: 금이 2D보다 진하고 주황 → 밝게. 갓이 둥근 원판(2D는 모서리 깎은 네모 쪽, 흰 모델 4개 다 둥긂). 갓~위 금 띠 사이 대리석 목이 조금 김.
- 07:09 계정 2 잔액 55점 줄고 새 자산 093f98de 'marble hourglass prop'(일반 HD 생성 + 텍스처) = 우리 것 아님, 사용자가 직접 시험한 것으로 보임(손보기 2·최종 검수 앎).
- 다음 일 = 최종 검수가 줌(큰 것: 동상·분수·간판·NPC, 개수·점수 먼저 사용자에게).

## 방법 메모 (10/14 배움)
- **Chrome Tripo 돌리기:** 캔버스 left_click_drag는 안 돌아감(빠른 가짜 드래그). 오른쪽 위 **축 표시(Y·Z·X 공과 어두운 점)를 눌러 바로 보기**가 됨: 기본 보기에서 Y(≈972,88) = 위 → 그다음 아래쪽 Z = 앞 → 아래 어두운 점(-Y) = 아래 → 오른쪽 X = 옆 → 같은 자리 어두운 점(-Z) = 뒤. 누를 때마다 축 표시 자리가 바뀌니 zoom으로 축 표시를 먼저 보고 누름. 화면 크기 1280×575 기준. 카메라가 너무 가까우면 scroll down으로 멀리.
- **Tripo 그물이 깨끗해 보여도 조각 이음의 열린 모서리는 안 보임** → 고르기 전에 FBX 열린 모서리·조각 수를 같이 봄(Blender CLI bmesh `is_boundary`, scratchpad openedges.py 방식). 손보기 2가 FBX를 `art/models/tripo/wm2_1014/<이름>/<id8>.fbx`에 받음.
- **이음 비침 검사:** 배경을 자홍(1,0,1)으로 하고 이음 높이에서 아래·수평·위 4방향 확대 렌더(직교, ortho 0.30) → 자홍이 몸 안으로 비치면 떨어짐.
- 고른 것을 바꿀 때는 손보기 2가 이미 누르는 중일 수 있음 → '멈춤 + 이미 눌렀으면 그대로 PBR까지'를 한 메시지에.
- 자산 목록 API fetch는 Chrome 확장이 막음(쿠키) → 손보기 2에게 물음.

(아래 = 10/13 기록)
## (기록 10/13) 다시 시작하면 바로 할 일 (기다리는 것)
1. **이미지 생성 3 ⑤ 묶음 1 마지막 2개** → 오면 최종 검수에 묶음 1 보고:
   - 통과: Tulip 3곳, Lavender P083·P022, BenchA P056·065·068·105·P015(diag), BenchC P026(지형 다시 칠함)·P064·121, Sunflower P032·P077(180°, 색 맵 새 자산), 날개, **CastleRose v3**(fix_v2/castle_rose_close_v3.png, 판 6.65)
   - 남음: P049(위에서 앉는 판 안 보임 = 아직 묻힘 의심, f97ace01) · P048(P049 옆 8칸으로 옮김) → 낮·밤 가까이
   - 하늘색 표시 상자(P022 옆) = 건물 표시 파트, 게임 전 숨김
2. **NEW_ 6종 → Blender 손보기 1 큐 맨 뒤(최종 3aa188d7, 810점 내 OK)**: GatherBush·ArmoryBarrels(오른면 천 봄)·CandleCrate(초 뭉침)·Easel·NoticeBoard·WaterBuckets(뒤 갈퀴 이빨) → **흰 모델은 내가 고름.** 나머지 2D 4면(WallLamp·WateringCan·Beehive·SteppingStones·간판)과 Blender 손보기 2 것은 디자인 검수 2.
3. **PBR 관문 끝(10/13 오후)**: 묶음 2 = 35 통과(41358b5d, pbr_gate_1013b/), 묶음 3 = 39 통과(a0a3d315, pbr_gate_1013c/ + Daisy 다시 c2e4b5db + SignJuice 계정 2) — ⑤ 메모는 그 메시지에. **Blender 손보기 1 큐 비었음(잔액 1,705).** 앞으로 새 스마트 메시는 계정 2(Blender 손보기 2 → 디자인 검수 2 판정). 다음 PBR 결과도 같은 방법: `blender --background --factory-startup --python tools/design_review/pbr_gate.py -- <out> 700 2048 <glb…>`(3개로 나눠 동시에) → `pbr_gate_sheet.py <out>/r <sheet_dir> <이름>_TU=<2D 앞에서 _front_ns.png 뺀 것>`. 흰 모델: Blender 손보기가 FBX를 build/tripo_wm1/<이름>_wm_<id8>.fbx → clay_views.py → scratchpad wm_sheet.py(1줄 2D 4면 + 후보 줄마다 7면).
4. 흰 모델 고르기 끝: 25종(wm_1013b/), 11종 + 간판 3(wm_1013c/), Daisy c2e4b5db. + PotionCrate·GuardPost: 엇갈려 두 계정 모두 PBR까지 감 → 나란히 보고(pbr_gate_1013d/) **GuardPost = 계정 2 판, PotionCrate = 계정 1 판**(cee655c6). 같은 이름 파일 충돌 → 안 쓰는 판 `_acc1_spare`/`_acc2_spare`로 Blender 두 세션이 정리 중. 이미지 생성 3에 넘기기 전 TU가 맞는 판인지 확인. 교훈: 두 계정이 같은 물건을 가질 땐 고른 뒤 "누가 누른다"를 한 메시지로 둘 다에게 보내기.
4c. **묶음 d 최종 검수 '다시' 4(10/13 오후, docs/review/pbr_final_2026-10-13.md):** Beehive(상자 판 없음)·ArmoryBarrels(빈 X 격자)·Topiary_E(판 모서리 테 밖)·PotFlowers_D(꽃 민트) — 내가 바로 위·아래를 안 봐서 놓침. 다시 고름(9면, art/review/design/wm_1013d/, 8c61d691): Beehive **b27e41bd**, Topiary_E **ade62dd1** → 멀티뷰 4면·4K → PBR(70점). PotFlowers_D = 같은 흰 모델에 멀티뷰 다시. **ArmoryBarrels 4개 다 탈락 → 최종 검수 결정 (가): 이미지 생성 2가 2D 상자 판 PIL → 디자인 검수 2 → 계정 2 스마트 메시(내 일 아님).** PotionCrate 본 판(계정 2 vs 1) 최종 검수 확정 대기(5b6de888) — 지금 파일 = 계정 2 본 이름, 계정 1 = _acc1_spare. 이번엔 Tripo 화면 대신 받은 FBX 9면 점토로 봄 — 최종 검수에 알림, 답 따라 다음부터 Tripo 직접.
4d. **Tripo 직접 확인(10/13 오후, 앱 브라우저 내 탭 'seed', 끝나면 닫음):** Beehive b27e41bd·Topiary_E ade62dd1 = 멀티뷰 텍스처 붙은 판 확인 OK. PotFlowers_D 87f66ae2 멀티뷰 다시도 꽃 민트(pbr_gate_1013e/) → **19fef167로 바꿈**(Tripo 확인, 멀티뷰 → PBR 진행). 방법: 내 탭에서 자산 API로 id8 → 전체 id → /ko/workspace/generate/<id> → JS PointerEvent 드래그(hhRot)로 돌리고 zoom 캡처(창이 숨어도 그려짐). 화면 쓰기 전 최종 검수에 한 줄 → '전달함, 시작' → 끝나면 탭 닫고 "끝".
4e. **'다시' 3종 PBR 관문 통과(10/13 오후, pbr_gate_1013e/, 최종 검수에 fe61aa97·be8bb7e1):** Beehive b27e41bd·Topiary_E ade62dd1·PotFlowers_D 19fef167(멀티뷰). 멀티뷰 텍스처는 뒤·옆이 앞면 1장 때보다 2D에 확실히 가까움. Blender 손보기 1 큐 비었음(잔액 1,355).

5. **이미지 생성 3 벤치 P048·P049**: 모래·높이 6.0 다시 채우기 OK(최종 검수) → fix_v5 줄무늬 막대 + 낮·밤 앞·뒤 판정 → 통과면 ⑤ 묶음 1(화분 7·벤치 10·장식) 최종 검수에.
- 나눔: 간판 4·Beehive·WateringCan·SteppingStones = Blender 손보기 2(디자인 검수 2 판정).

- **계정 1 점수가 다 떨어지면(사용자 10/13 오후, 최종 검수 전달):** Blender 손보기 1도 Chrome 계정 2로 옮김 → 그 흰 모델도 내가 고름(누가 만든 물건인지로 나눔: Blender 손보기 1 것 = 나, 2 것 = 디자인 검수 2). 볼 때 사용자 Chrome(Claude 확장)에서 **새 탭 하나만**, 다른 세션 탭 안 건드림, 점수 버튼 안 누름, Chrome 창 보이는 채로(옮기기 금지), 끝나면 내 탭만 닫기. 먼저 FBX 받아 clay_views로 보는 길이 되면 그게 우선(화면 안 씀).

## 판정 규칙
- **⛔ 10/13 오후 사용자: Tripo 점수 쓰는 일 전부 멈춤 — 내 점수 승인(빛 마을 135/개 상시 OK)도 지금은 안 냄. 판정·보기만.** 다시 풀리면 최종 검수가 알려 줌.
- **사용자 10/13 오후(화남) — 흰 모델 고르기 순서 고정:** ① 4개를 Tripo 화면(앱 브라우저 내 탭 / 계정 1 끝나면 Chrome)에서 하나씩 열어 위·아래 포함 돌려 보고 고름(화면 쓰기 전 최종 검수에 신청) ② 고른 것·이유·멀티뷰 4면·4K·조명 제거·걱정되는 면을 **Blender 손보기와 메시지로 의논 → '합의, 진행' 오간 뒤에만 텍스처** ③ 점토 렌더는 보조 ④ Tripo에서 안 되면 사진으로 대신하지 말고 바로 최종 검수에.
- **사용자 10/13 오후 새 규칙(최종 검수 전달):** ① 흰 모델은 **Tripo에서 직접 돌려 보고 고름**(계정 1 = 앱 브라우저 내 탭, 계정 2 = Chrome 내 탭; 화면 쓰기 전 최종 검수에 한 줄 → '전달함, 시작' → 끝나면 내 탭 닫기), 점토 렌더는 보조. ② **위·아래·앞·뒤·양옆 + 3/4 모두** 보고 고른 이유에 '위·아래 확인함'. PBR 관문도 위·아래 포함(pbr_gate.py top/bot, clay_views up/down 추가, wm_sheet.py 9면). ③ A23-158 텍스처 = **가운데 '멀티뷰' 탭에 2D 4면**·4K·조명 제거 → PBR(새 텍스처부터) → 판정 때 뒤·옆이 전보다 나아졌는지 봄. ④ JuiceParasol 다시(줄무늬 없는 하늘색, 디자인 검수 2·계정 2) → 묶음 b JuiceParasol 빠짐. ⑤ GuardPost·PotionCrate = 둘 다 계정 2 판, 디자인 검수 2 일. GateLeaf R 거울판 안 씀(L 대칭 → L 그대로 두 짝).
- **3D = SPEC A23-154 다섯 단계뿐:** ① 그림자 없는 2D 4면 → 스마트 메시 ② **내가 흰 모델 4개 중 고름** ③ 텍스처(앞 1장·조명 없이·**4K** — 사용자 10/13 오후, 두 계정, Roblox가 1024로 줄임) ④ PBR(텍스처 끝나면 바로) ⑤ Roblox 재질(2D 옆 낮·밤) **내가 사진 판정**. 매직 브러시·붓 칠·Blender 색 고치기·다시 올리기 없음. 얼룩은 ⑤에서 좋게 하거나 그대로, 모양이 망가졌으면 ②에서 다른 흰 모델. Blender = 크기·피벗·방향(대칭 짝 뒤집기)만.
- **PBR 관문(사용자 10/13):** PBR 끝난 모델 = 내가 먼저(`tools/design_review/pbr_gate.py` 700 2048 → `pbr_gate_sheet.py`: 2D 4면 | 해+하늘 렌더 앞·옆·뒤·옆·위3/4 같은 배율 | 디테일 100% 크롭 3) → 통과만 최종 검수에 → 최종 검수 통과 뒤 이미지 생성 3. 묶음 1(13종) = 최종 통과(`art/review/design/pbr_gate_1013/`).
- **화면에 뜨는 일(앱 브라우저 창·다운로드·Blender 창·마우스·키보드) = 매번 최종 검수에 신청 → "전달함, 시작" 뒤에만.** 렌더는 Blender --background만. 사용자에게 할 말은 최종 검수에게만; 이미지 생성 2·3·Blender 손보기가 사용자에게 직접 말하면 최종 검수에 알림.
- 흰 모델은 내가 직접 봄(사용자 "시트 보지 말고 직접"). 창이 숨겨지면 Tripo가 안 그려짐 → 내 탭(창 신청 뒤)에서 Tripo 자산 목록 API로 model_url 모아 FBX 받고 점토 7면 렌더(`tools/design_review/README.md` 7번). 점수 버튼·좌표 클릭 금지, 다른 세션 탭 안 건드림, 내 localStorage 키 지우고 탭 닫기.
- 2D 4면: 한 장씩 + 옛 그림(`art/review/img3/chunk_refs/`) 옆, 물체 높이 재기(PIL bbox). 그림자·어두운 한쪽·어두운 틈 없음, 같은 카메라·같은 높이, 좌우 옆면 서로 맞음, 둥근 것은 4면 같은 폭, 옛과 개수·색 같음, 빛살 없음. 옆면 방향: `_left` = 앞이 화면 오른쪽, `_right` = 앞이 화면 왼쪽.
- 3D로 될 그림인지: 작은 알갱이 수백 개는 스마트 메시가 못 따라감 → 큰 덩어리.
- 고칠 때는 PIL(뒤집기·크기·색) 먼저.
- 점수: 빛 마을 목록(`docs/review/noshadow_redo_2026-10-12.md` 빛 마을 줄 + `art/prompts/house_chunks_queue_2026-10-13.json`) 안 = 내가 OK(135/개), 밖 = 최종 검수. 사람(NPC·주민·MailBoy)은 맨 마지막.
- 목록에서 뺀 것: NEW_Cauldron·NEW_Telescope(HaloChunk판만, 최종 검수 OK 10/13), NEW_WhiteRock a/b/c·BellFrame_Bell·WallLamp_Head(버림).

## 끝난 것 (10/13까지)
- **PBR 최종 통과 → 이미지 생성 3 놓음:** DoorSingle·DoorDouble·LampArm·CastleWingL/R·DomeRibbed·WindowBoxA·CastleRose·BenchA·BenchC·Lavender·Tulip·Sunflower(⑤에서 고칠 것 위 1번).
- **흰 모델 20종 고름(10/13, 시트 `art/review/design/wm_1013/`):**
  - Greenhouse d148d3bd, ShopSign e96efdb6
  - Lantern_A 3b8c167c, Lantern_B 4b6f9db9, Lantern_C 096e84f2, Lantern_D 1eed23ce, Lantern_E c102246e
  - IvyWall 18598e34, IvyBalcony 0352e909
  - **FlowerBushPot 5a5af84d**: 4개 다 뒤가 빔 → ⑤ 덤불 속 초록 공 파트 또는 뒤를 벽 쪽
  - DomePorchHalf e549329c, DomePavilion bc5097f2, DomeTowerSmall 6d925d8a, BreadDisplay e5467c5f
  - RoundTree_E 077f2fae, RoundTree_F cc3f527f, RoundTree_G a9395b47
  - Topiary_C 3e2847ad, Topiary_D 7c673fb4, Planter_E 1021df70
- 그 전에 고른 흰 모델:
  - 화분 5, DoorSingle, LampArm, WingL, DomeRibbed, DoorDouble, WindowBoxA, BenchA·C, CastleRose
  - GateLeaf 2bc07ecc, DomeOnion 414b871a, ConeTree 2bbbd641, DomeOctagon f9e91fe2, DomeBall 66894770, FlowerCart af2e2b5f, BenchB b8de1d3c
  - DomeOnionSlim 40dad418, BreadStand 00dac363, FruitStall 568b5b8e, DomeBrick 46f0bb09, JuiceParasol 6ec4d75d
- 집 덩어리 그림 1~43 끝(이미지 생성 2). 34~43 판정 끝, 흰 모델 큐에 들어감.
- 빛 성 C2 골격 v4 통과. 벽 재질 B(HH_HaloMarbleSmooth_Cream + 255,255,255) 적용 사진 통과. 밤 창 빛 = 장식/빛 단계. 마을 배치 때 정문이 낮에 해 받는지 확인.

## 넣을 때 메모 (이미지 생성 3에 보낸 것)
- 장식 파트:
  - CastleRose = 뒤 진한 파랑 원판(34,90,180)
  - LampArm·등불 = LampGlass/LampCore 파트
- 재질·면:
  - 화분 잎·창 화분 = DoubleSided
  - 돔 SurfaceAppearance.Color 255,222,180, 쌍문 255,236,214
  - Tripo 금은 2D보다 어둡고 레몬빛 → ⑤에서 맞춤
- 그대로 둘 것: DomeBrick 바닥 뚫림(지붕 위라 안 보임), DoorSingle 뒤 고리

## 교훈
- 같은 이름 파일을 두 세션이 디스크에서 덮어쓸 수 있음(10/13 PotionCrate) → 렌더 전 `md5sum <파일>`과 `git show origin/main:<파일> | md5sum` 비교, 판 비교 시트엔 어떤 파일(커밋/디스크)인지 적기.
- 옛 그림이 3/4면이면 '보이는 두 면'을 정면 하나로 합쳐 그리는 실수 → 면마다 개수 세기.
- 4면 흔한 고장:
  - 좌우 옆면이 서로 다름
  - 옆이 1.05~1.3배 크게 / 둥근 것 옆이 좁게
  - 한 면만 연한 빛 띠
  - 비스듬한 옛 시점
  - 아치 안 어두운 갈색
- 흰 모델 흔한 고장:
  - 바닥 뚫림, 속 조각, 떠 있는 조각
  - 뒷면에 앞 장식 찍힘, 잎이 한쪽 면이라 뒤가 빈 판
  - 가운데 큰 공 덩어리
  - 얇은 받침 두 겹 틈, 장식판 빠짐
- 시트 크롭이 맞닿으면 가짜 이음선처럼 보임 → 크롭 사이 틈(도구 고침).
- 메시지가 밀려 '못 받았다'고 하면 메시지 id로 다시 적어 줌.
