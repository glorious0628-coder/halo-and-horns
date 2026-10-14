# 이미지 생성 2 — 인계 (10/14 오전 10시, 최종 검수 새 지시 ①~④)
## 10/14 10:00 (맨 위 = 이것부터)
- **최종 검수 지시 순서**: ① 디스크에만 있던 부품 2D push → ② ④ 화분·꽃 마무리·시트 → ③ 사람 14명 부품(머리·몸·소품, 3~4명 묶음 시트) → ④ ⑤ 103장(+VegGarden 4부품 = 하기로 함, `jobs_b5_all.txt` 108).
- **① 끝**: 부품 PNG 84·프롬프트 143·시트 2(1ac6e7f~f841674, 6묶음).
- **② 끝·push(939e5b3)**: 공유 꽃 9종(WhiteDaisy·Blue5·Lilac·RedDaisy·PinkRose 4면, RedBud·RoseBud·TulipWhite·TulipBlue 1면 복사), 시트 `art/review/s2/parts_b4_pots_flowers_2026-10-14.jpg`, 물건마다 꽃 목록 `art/review/s2/parts_b4_flower_map_2026-10-14.md`. 꽃 옆면 방향: 왼 면 = 꽃이 화면 오른쪽을 봄(Blue5·RedDaisy raw는 뒤집어 맞춤, 원본 `pil_orig/*_left_raw_mirrored.png`). 판정 대기.
- **③ 진행**: 프롬프트 생성기 `build/img2_next/parts_prompts_npc.py <1-4>`(머리 = 후광 없음, 몸 = 머리·소품 없음, 소품 = 캐릭터 기준 방향; 등에 메는 소품은 back 먼저 그리고 나머지는 그 raw를 ref1). 작업 목록 `jobs_npc_g1~4.txt`(1 SirGleam·BakerGranny·JuiceMan·FlowerGirl / 2 PotionMerchant·BellElder·StarScholar·OldSailor / 3 PondAngler·MailBoy·FlowerFarmer / 4 Folk4·HerbHusband·HerbWife). 소품: SirGleam Sword, FlowerGirl Bag, PotionMerchant PotionRack(등), BellElder Bell, StarScholar ScrollCase, OldSailor Rope·Spyglass, PondAngler FishingRod(등), MailBoy Satchel, HerbHusband Herbs, HerbWife Basket(등). 가방 끈은 몸 부품에 그림. 맞춤 `parts_fit.py <Name> --dir npc`.
- **ChatGPT 사용량 끝(09:55) → 11:40 다시 열림.** 끝난 raw: SirGleam·PotionMerchant Head front·left. 11:41 자동 재개 대기(`build/img2_next/resume_1141.sh`, 두 줄: A = g1+g3, B = g2+g4, 그 뒤 ⑤). Firefly High는 쓰지 않음(최종 검수 지시).

# 이미지 생성 2 — 인계 (10/14 오후, 부품 2D 큰 묶음)
## 10/14 오후 (맨 위 = 이것부터)
- **최종 검수 지시(사용자 "가")**: 빛 마을 2D 부품 ①~⑤ 전부 Codex(0원). 규칙 = 난간 부품과 같음. 파일 `art/out/s2/noshadow/parts/<이름>_{front,left,right,back}_ns.png`, 프롬프트 `art/prompts/<이름>_<면>_ns.txt`. 묶음마다 시트 push + 최종 검수 보고, clear 말고 계속.
- **도구(build/, git 무시)**: 구동 `py build/img2_next/parts_batch.py Name:view:ref1[,ref2] ...`(ref 'NEW' = 그 이름의 새 앞 raw; raw = `build/img2_next/parts_raw/`; 있으면 건너뜀; 끝 코드 3 = 사용량 끝). **Codex 두 줄 동시 OK**(10/14 확인). 맞춤 `py build/img2_next/parts_fit.py <Name> [--sym]`(80% 여백, 옆면은 앞 높이에 맞춤, 마스크 구멍 채움). 시트 `parts_sheet.py`. 프롬프트 생성 `parts_prompts_b4.py`·`parts_prompts_b5.py`(작업 목록 `jobs_b4.txt`·`jobs_b5*.txt`).
- **끝·push**: ① 흰 바위 a·b·c 4면 + NEW_ArmoryBarrel(751dfeb) · ② 분수 Basin·MidTier·Top · ③ TreePlanter(공유)·TreeFruit(E)·RoundTree_E·F·G Trunk/Canopy(acd2174). 판정 대기 = 최종 검수.
- **진행**: ④ 34장(그릇 7·잎 8·공유 꽃 HaloPart_Flower_*), ⑤ 103장(계획은 최종 검수에 보냄; VegGarden 4부품은 답 대기, 목록 `jobs_b5_all.txt`). 꽃 공유 = 최종 검수 OK, 시트에 '물건마다 어느 꽃 몇 개' 메모 필수.

# 이미지 생성 2 — 인계 (10/14 아침, Opus 5.5 세션)
## 10/14 아침 (맨 위 = 이것부터)
- **새 방식(사용자 10/14, 최종 검수 전달): 3D 물건은 부품마다 2D 따로 → 부품마다 Meshy → Blender로 합침.** 소품 4면은 앞으로 '부품 단위'로 그림: 부품 하나만 화면 가운데 크게(여백 10%), 다른 부품·바닥 없음, 그림자 없음, 밝은 회색 민무늬. 돌려도 같은 부품(둥근 기둥) = 앞 1장 → 3면 복사. 앞뒤 같은 네모 부품 = back 좌우 뒤집기, left/right 앞 복사. 가로대·바닥 받침 같은 단순 덩어리는 Studio 파트라 안 그림(A23-120).
- **첫 시험 끝(push 1803900) → 최종 검수 통과(10/14, 3종 다; 사용자 OK 오면 최종 검수가 Meshy로 보냄, 받침 아래 단은 Blender에서 안 자르고 Studio 바닥 파트를 깖)**: HaloVar4_Balustrade_C 부품 3종 `art/out/s2/noshadow/parts/HaloVar4_{Baluster,CornerPost,EndPost}_{front,left,right,back}_ns.png`, 프롬프트 `art/prompts/HaloVar4_<부품>_front_ns.txt`(ref1 = 승인 2D, EndPost는 ref2 = CornerPost 앞), 시트 `art/review/s2/balustrade_parts_2026-10-14.jpg`. EndPost 첫 판은 공이 커서 다시(백업 `build/img2_next/pil_orig/HaloVar4_EndPost_front_ns_v1.png`). 여백 맞춤 = 물체 bbox를 80%로 줄여 배경색 캔버스에 마스크 붙임(원본 `pil_orig/*_raw.png`; 스크립트는 스크래치라 없음, 짧게 다시).
- 사용자가 '다시'를 주면 그 부품만 Codex로. 다음 부품 그리기 일은 최종 검수가 줌(지금 할 일 없음 → clear).
- **10/14 낮: 가로대·받침도 부품으로(사용자 "가로도 했어야겄다")** — `HaloVar4_{RailSegment,BaseSegment}_{front,back,left,right}_ns.png` 끝·push(812992c), 시트 `art/review/s2/balustrade_parts2_2026-10-14.jpg`, 최종 검수 판정 대기. 앞 1장 + 끝 단면 1장 Codex(ref1 승인 2D, 단면 ref2 = 새 앞), back = 앞 뒤집기, right = left 뒤집기. 비율은 PIL로 한 축만 줄여 맞춤(가로대 앞 7.9:1·단면 1.2:1, 받침 앞 9.4:1·단면 2.3:1), 단면은 앞면과 같은 px 높이. 원본·줄인 판 `build/img2_next/pil_orig/HaloVar4_*Segment_*_{raw,squash}.png`. 맞춤 스크립트 = bbox → 긴 변 80%(또는 h=앞 높이) → 1254² 배경색 캔버스, 마스크 붙임(스크래치, 짧게 다시).

# 이미지 생성 2 — 인계 (10/13 밤 끝 정리, Opus 5.5 세션)
## 10/13 밤 끝 (맨 위 = 이것부터)
- **지금 일 순서(최종 검수, 사용자 "뿔 먼저 말고 빛부터")**: 빛 마을 먼저. 도구는 `py tools/codex_image.py`(ChatGPT 요금제, 추가 0; 끝 코드 3 = 사용량 끝 → 멈추고 최종 검수). **Firefly High·Tripo·Meshy·브라우저·화면 사용 금지(A23-160)**. 보고는 전부 최종 검수(local_30f96900…)에게 시트로. 할 일이 끝나 기다리기만 남으면 이 파일 적고 push → `clear_session("self")`(A23-168).
- **빛 마을 사람 2D 그림자 없이(A23-150) — 14명 전부 그림**: 도구 `py tools/_noshadow_npc.py <NPC_Name>`(사람용; 옛 4면을 방향 ref로, 결과 `art/out/s2/noshadow/npc/<이름>_{front,back,left,right}_ns.png`, 규칙: 단정한 옷·얼굴 무늬(주근깨) 없음·작은 금고리 후광). MailBoy는 10/12에 통과.
  - 1묶음 Bright·SirGleam·BakerGranny·JuiceMan·FlowerGirl = **최종 검수 통과**, approved.json 기록(c0405d5).
  - 2묶음 PotionMerchant(후광 넣음, 최종 검수 OK)·BellElder·StarScholar·OldSailor·PondAngler, 3묶음 주민 FlowerFarmer·Folk4·HerbHusband·HerbWife = **판정 대기**. 시트 `art/review/s2/npc_halo_noshadow_set{2,3}_2026-10-13.jpg`.
  - **4면 방향 규칙(사람)**: 왼 면 = 화면 오른쪽을 봄, 오른 면 = 화면 왼쪽. 한쪽 엉덩이·어깨 물건(칼집·가방·종·통·밧줄·망원경·주머니·약초·어깨 꽃)은 그쪽 면에만, 반대 면에선 몸에 가려 안 그림, 뒤에서는 좌우가 바뀜. 옛 승인 4면도 이게 틀린 것이 많음 → 생성 후 반드시 확인하고 `<이름>_<면>_ns_fix.txt` 프롬프트로 그 면만 다시(ref1 = 틀린 그 면, ref2 = 새 앞). 고친 면 목록: SirGleam R, Bright L·B, FlowerGirl R(+B 뒤집기), BellElder R, StarScholar R, OldSailor L·R, FlowerFarmer R, Folk4 L(배경 짙음)·R, HerbHusband R. 고치기 전 판은 `build/img2_next/pil_orig/*_ns_v1.png`.
- **앞뒤 같은 물건 = 뒤는 앞 좌우 뒤집기(최종 검수 새 규칙, 사용자 FlowerBuckets 지적)**: 빛 마을 30종 바꿈(f036b71), 목록·안 바꾼 8종 이유 `art/review/s2/backflip_list_2026-10-13.md`. 10/20부터 뿔 마을 물건에도: 앞뒤가 거의 같은 것(덤불·화분·양동이·대칭 소품)은 뒤를 그리지 않고 뒤집기, 옆은 앞 끝 기준으로 폭 맞춘 생성. 앞뒤 다른 것(사람·간판·문)만 따로.
- **A23-168(3D = 골격 먼저 + Meshy 리텍스처)**: 4면을 그릴 때 골격을 단순 덩어리로 세우기 쉬운 모양(큰 잎 뭉치 10~15개, 가는 줄 없음, 큰 꽃)으로.
- **빛 마을 땅 목표 시트**(끝, 419b046): `art/review/world/halo_new/ground_target_2026-10-13.jpg` — 시안 100% 크롭 5칸 + 재질별 중앙값 RGB(크림 포장 ≈249,231,214 · 그늘 돌 ≈180,167,160 · 금 선 ≈196~218,158~190,89~108 · 초록 잎 ≈100,111,65 · 물 38,135,191 · 거품 249,251,252). 시안엔 넓은 잔디 없음.
- **뿔 마을(멈춤, 나중에)**: 성채 시안 A~D 끝(시트 `art/review/s2/horns_castle_ABCD_2026-10-13.jpg`, push). 조감 a는 그림만 있음 `art/out/s2/horns_zone/HornsZone_a.png`(push 안 함, 깃발에 작은 별 무늬), 조감 b는 안 그림(프롬프트 `art/prompts/HornsZone_Concept_b.txt` 그대로). 참고표 `docs/design/ref_horns_town_2026-10-13.md`(A23-165: 새 시안은 실제 장소 먼저 검색).
- 시트 만드는 법: PIL로 1줄에 옛 4면|새 4면, 라벨에 공백 없이(셸이 자름). 이 세션 스크립트는 스크래치라 없음 — 필요하면 다시 짧게.

# 이미지 생성 2 — 인계 (10/13 낮 정리)
## 10/13 낮 (맨 위 = 이것부터)
- **10/13 낮 3**: 최종 검수 요청(사용자 결정)으로 HaloChunk_JuiceParasol 4면 다시 — 줄무늬 없는 하늘색 차양 + 흰 물결 테(92efd66), 디자인 검수 2 판정 대기, 통과하면 Blender 손보기 2(계정 2). 옛 줄무늬 4면 백업 `build/img2_next/pil_orig/juice_parasol_v1/`, 구동 스크립트 `build/img2_next/juice_parasol_v2.py`. 옛 Tripo 모델은 새로 만들어야 함.
- **10/13 밤 2**: GuardPost 통과. PotionCrate 3번째 다시(디자인 검수 2 지적: 끝면에 천 + 깊이 다름) → left Codex로 천 없이 다시, right = left 뒤집기 + 옛 right 기둥·받침 오려 얹음(a49a750), 판정 대기. 백업 `build/img2_next/pil_orig/HaloReasonHQ_PotionCrate_*_{before,v2}.png`. 할 일 없음(사람 보류, PhotoDisc 안 그림). Codex 사용량 다시 열림(10/13 밤).
- **10/13 밤**: 디자인 검수 2 판정(11종 중 9 통과)의 다시 2건 끝·푸시(036677af): GuardPost right(left 뒤집기+안내판 얹음), PotionCrate left(Firefly 새로 그림, 간판 얇은 선). **PhotoDisc = 최종 검수 결정으로 Studio 파트(이미지 생성 3)라 다시 그리지 않음**. 결과 판정 대기 = 디자인 검수 2. Firefly 탭 닫음.
- **10/13 저녁 갱신**: 빛 마을 11종(HaloFlagpole_1·2·3, HaloReasonHQ_GuardPost·PhotoDisc·Clothesline·PotionCrate·RackShieldSword·Scarecrow·VegGarden·Woodpile) 4면 + NEW_BellFrame 옆면 다시 그려 푸시(3b9c207d), **디자인 검수 2 판정 대기**(오면 '다시' 먼저). 큰 지도 V3(a·b)는 디자인 검수 2 통과·최종 검수가 고르는 중. **사람(상인·주민) 2D는 사용자 답이 오기 전엔 손대지 말 것.** Firefly 탭 닫음(Codex 아직 사용량 끝).
- **끝·푸시됨(10/13)**: 집 덩어리 43종 · 빛 마을 소품 NEW_ 11종(GatherBush·Hedge·WallLamp·WateringCan·ArmoryBarrels·Beehive·CandleCrate·Easel·NoticeBoard·SteppingStone(돌 하나)·WaterBuckets; Telescope·Cauldron은 뺌) · 가게 간판 4종(HaloSign_Sign<Bakery|Flower|Juice|Potion>) — 전부 디자인 검수(2)가 통과, Blender 손보기로 넘어감. 마지막 푸시 6327220.
- **판정 대기**: 큰 지도 V3 시안 2종 `art/out/s2/worldmap/UIP_WorldMapV3_HaloNew_{a,b}.png`(추천 b; 1041×760, 옛 지도 (17,77), 새 빛 섬 실제 크기, 합성 `tools/worldmap_compose.py`, 섬 원본 `WorldMapV3_HaloIsland_{a,b}_src.png`). 판정·수정 요청은 **디자인 검수 2**(local_b0cabbea…), 통과하면 그쪽이 최종 검수에게. 수정 시: 섬을 다시 그릴 때 Firefly 두 ref(안내 그림 crop + 지금 합성본 crop, 업로드 후 `__multiUrls`), 합성은 같은 스크립트.
- **Firefly 길(승인됨)**: Codex(ChatGPT) 사용량이 끝나 있으면 Firefly 고급(GPT Image 2.5 high, 5크레딧/장). 방법 `docs/handoff/firefly_autodownload_2026-10-13.md`: 앱 브라우저 Firefly 탭(로그인돼 있음, 보이는 창이 아니어도 몇십 초 뒤 그려짐)에 `tools/firefly_autodl_helpers.js`를 **생성 전에** 붙임 → `__tasks([{k,view,ref,prompt}])`(앞 = ref URL, 나머지 = 새 앞면 blob) → `__urlMap()`으로 사전서명 S3 주소를 읽어 `tools/ff_lines_to_map.py` + `tools/ff_fetch.py`로 curl. **브라우저 다운로드·Downloads·127.0.0.1·데스크톱 창 금지, 사용자에게 할 부탁은 최종 검수에 먼저**. 한 번에 한 세션만 Firefly 탭 사용(이미지 생성 3과 번갈아). 잔액 약 2,500/10,000(10/13 낮).
- 4면 맞춤 도구: `tools/ns_fix.py <id> --faces ...`(높이·발선·배경을 앞에 맞춤, 이미지 생성 3 도구), `tools/_chunk_sidefix.py`(--fill). 한쪽을 보는 물건은 4면 방향 규칙(왼 면 = 앞이 화면 오른쪽).
- 이 줄 아래는 10/13 새벽 정리(이전).

# 이미지 생성 2 — 인계 (10/13 새벽 정리: 컴퓨터 끄기 전)
## 10/13 새벽 (맨 위 = 이것부터; 10/13 04시 갱신)
- **집 덩어리 큐** `art/prompts/house_chunks_queue_2026-10-13.json` (43종, 순서대로). 구동기 `py tools/_chunk_redo.py <HaloChunk_Id>`(앞면 → 뒤·왼·오른, 결과 `art/out/s2/noshadow/chunks/<Id>_<view>_ns.png`, 한 번에 하나·run_in_background; 끝 코드 3 = ChatGPT 사용량 끝 → Firefly 고급), 옆면 PIL 고침 `py tools/_chunk_sidefix.py <Id> [--fill]`(right=left 뒤집기+높이 맞춤; 흰·크림 물체는 --fill; 캔버스 밖이면 STOP), 색 보정 `tools/_tint_obj.py`. 규칙: 둥근 것은 4면 폭 같게, 한쪽을 보는 것(꽃·덩굴·가판대)은 4면 방향 맞게(왼 면 = 앞이 화면 오른쪽, 오른 면 = 화면 왼쪽; 어긋나면 한쪽을 뒤집어 맞춤), 잎·덩굴·울타리는 큼직·굵게(도구가 자동 문구), 원본 백업 `build/img2_next/pil_orig/`. 보고처 = **디자인 검수**(통과 판정·흰 모델 큐는 거기서), 막힌 것만 최종 검수.
- **1~43 그림 전부 끝, 푸시됨(마지막 7ebb4494)**. 34~43은 Firefly high(1024², Codex 사용량 끝). 판정은 디자인 검수 대화 기준(보고 메시지). 판정 대기: 36 ChimneyLantern 아치 안 밝게·37 RoundTree 옆 폭(10/13 반영해 재보고함), 38~43 6종(방금 보고), 42 WindowBoxB 뒤가 앞과 같음(잎 쪽으로 바꿀지 물어봄). 새 묶음이 오면 Codex(`_chunk_redo.py`)가 풀렸으면 그걸로, 아니면 Firefly 길.
- **Firefly 결과 받는 법(최종 검수 승인)**: `docs/handoff/firefly_autodownload_2026-10-13.md` — 페이지 도구 `tools/firefly_autodl_helpers.js`(생성 전에 붙임) + 사전서명 S3 주소를 `tools/ff_fetch.py`로 curl. **브라우저 다운로드·Downloads 폴더·127.0.0.1·데스크톱 창은 금지**(사용자 화남). 사용자에게 할 부탁·화면에 뭔가 뜨는 일은 항상 최종 검수에 먼저. Firefly 계정 잔액 약 2850/10000(10/13 낮).
- 이 줄 아래는 10/12 저녁 정리 내용(이전).

## 10/12 저녁 정리 (맨 위 = 이것부터)
- **하는 일 = 그림자 없이 다시 그리기(SPEC A23-150·151)**. 도구 `py tools/codex_image.py --prompt-file <txt> --ref <옛 2D> [--ref <새 앞면>] --out <png>`(사용자 ChatGPT 요금제, Codex 앱; 끝 코드 3 = 사용량 끝 → 그 장만 Firefly 고급). 4면 구동기 `py tools/_noshadow_redo.py <이름> [<이름>...]`(이름 = `docs/review/noshadow_redo_2026-10-12.md` 표의 이름; 앞면 먼저 → 뒤·왼·오른은 옛 그 면 + 새 앞면 ref, 옛 면이 없으면 새 앞면만; 결과 `art/out/s2/noshadow/<이름>_{front,back,left,right}_ns.png`, 프롬프트 .txt 같은 폴더, 로그 `build/img2_next/noshadow_log.txt`; 이미 있는 파일은 건너뜀; **한 번에 하나씩**, 한 장 약 3~4분, 방향은 말 말고 'ref1과 같은 시점·방향'). 반드시 `run_in_background`로 돌리고 한 묶음(5개)마다 옛|새 시트 → 최종 검수.
- **그린 것(시트 `art/review/s2/noshadow_set1_statue_fountain_old_new.jpg`, 판정 대기)**: Halo_Statue 4면 · Town_Halo_Fountain3 4면(옛은 앞면만, 둥글어 4면 거의 같음). 앞서 통과: MailBoy 4면(`art/out/s2/noshadow/npc/`, approved.json 기록, 옛은 최종 검수가 지움).
- **남은 71개(그릴 것 67 + 가게 간판 4)**: `docs/review/halo_redo_split_2026-10-12.md`의 '그릴 것' 목록 − Halo_Statue·Fountain3(끝) − HaloStairs_3·HaloVar4_Balustrade_B·D(안 놓임, 뺌) + NEW_WhiteRock a/b/c + HaloSign_Bakery/Flower/Juice/Potion. 순서: 눈에 띄는 것 먼저 — 꽃화분 5(HaloFlowerPotHQ_*) · 벤치(HaloReasonHQ_BenchA~C) · 가판대(BreadStand·FruitStall·FlowerCart) · 등불(HaloVar4_Lantern_A~D·HaloVar3_Lantern_E) · 나무·토피어리·화분(Var3/4) · 난간 · NEW_ 소품 · 나머지. 다음 묶음은 HaloFlowerPotHQ_Daisy부터. v2에 놓인 이름 대조 = `docs/design/halo_v2_placed_names_2026-10-12.txt`. 집 22채·성·가게·부품 46개는 통째로 안 그리고 덩어리 장식 목록(`docs/design/house_chunk_decor_2026-10-12.md`) 단위. **사람(NPC·주민)은 맨 마지막**(주민 36장·MailBoy 외 새로 그려야 함).
- **버린 앞면**: Halo_Cathedral·DomeHouseA/B·Balustrade·CloudBush(옛 메인 빛 마을, 버림) — 내가 만든 새 파일은 지움. 옛 2D 지우기는 최종 검수가 함.
- **새 그림 규칙**: 3D 렌더로 그림자만 없이(볼륨·둥근 모서리·부드러운 형태 음영·재질 광택은 유지; 사방 고른 빛; 바닥·드리운·닿는 곳·AO·어두운 면·강한 반사광 없음; 밝은 회색 배경; 빛살 금지; 사람은 단정한 옷). 기준: `art/review/codex/mailboy_front_original_flat_3d_1012.jpg`, `art/prompts/_noshadow_3d_example.txt`.
- 이전(점심) Firefly 인계 내용은 아래에 그대로.

## 지금 상태
- **Firefly 큐 비어 있음(생성 중인 것 없음).** 이어받는 세션 = 이미지 개발. 시트 보고는 **최종 검수**(디자인 검수 쉼, 대기 목록 `docs/handoff/state/design_review.md`).
- 오늘 끝·푸시·보고(전부 origin/main): 가방/제작 아이콘 16종(통과) · 게임 아이콘 C(통과) · 새 집 7채 4면(통과) · 무기 4면 84(통과) · 물약 상인 4면(통과) · 성문 등 머리 4면·받침·무기고 뒤(통과) · 밈 5장 High(통과)+GG `EmoGG`(통과) · 밈 후광·뿔 4면 16(통과, PixelHalo 옆면 최종 = `Meme_PixelHalo_{left,right}_final_HQ.png`, right는 left 좌우 뒤집음) · 스티커 17종 High+컷아웃(통과, 올리기 승인됨) · 채팅 말풍선 8 Medium v2(통과, 사용자 고르기 대기) · 빛 성 C2 정면·right·금문 한 짝(통과) · 큰 지도 빛 섬 합성본 ★(통과, 최종 검수에 올림) · **주민 9명 High 정면+뒤·왼·오른 36장(`art/out/s2/npc2_hq/`, 시트 `art/review/s2/npc_residents_4v_a/b.jpg`, 정면 시트는 통과·4면 판정 대기)**.
- approved.json에 밈 5장·4면 기록 푸시함.
## 남은 일(요청 오면)
1. 채팅 말풍선: 사용자가 고른 것 High(5크레딧) — 규칙: 512×256 투명, 장식은 왼쪽 위·오른쪽 위 모서리 64×64 안에만, 위·아래 변 가운데 장식 없음, 꼬리 없음, 글자 없음, 가운데 평평. Medium 파일 `art/out/s2/bubbles/Bubble_<Light·Horns·Pixel·Donut(m2)·Night·Cloud·Flower·Crown(m2)>`, 투명 512×256 `bubbles_cut/`, 시트 `chat_bubbles_8_medium_v2.jpg`. 글 읽힘 칸: 밝은 면 짙은 남색 글, 어두운 면 흰 글.
2. 주민 4면 판정 반려 시 해당 칸 다시. 그 뒤 Tripo는 이미지 생성 3/4.
3. 큰 지도 합성본이 사용자에게 보인 뒤 수정 요청 오면: `art/out/s2/worldmap/WorldMapV2_HaloNew_r2m1_HQ.png`(High 전체) + 옛 지도 `art/ui/UIP_WorldMapV2.png`, 합성은 바다 쪽으로 부드럽게(스크립트는 이 세션 기록: 땅 마스크=파란 바다 아닌 곳 팽창+블러10, `build/img2_next/` 임시).
4. 올리기는 이미지 개발(승인은 최종 검수). 나는 올리지 않음.
## 크레딧
- 오늘 High 합계 약 145장(≈725크레딧) 사용. 어젯밤 약 1,400. 표시 잔액은 Firefly 화면에서 확인(어제 아침 추정 3,400 → 지금 약 2,200~2,700 추정), **500 근처면 최종 검수에 알림**.
## Firefly / 도구 요령 (이어받는 세션용)
- 탭 `seed`(https://firefly.adobe.com/generate/image), `resize_window` 1440x900. **앱 브라우저 창이 보이는 상태여야 렌더·속도 정상**(숨김이면 멈춤/느림 → 최종 검수에 Ctrl+Shift+B 부탁, 로그인은 사용자가). 로그인 풀리면 최종 검수에 알림, 비밀번호 입력 금지.
- helper: `tools/_firefly_helpers.js` 내용을 javascript_exec에 붙여 심기(`__runList` ref 있음 / `__runNoRef`, 품질 value+change 고침 포함, `__qLog`, `__stopList`). 프롬프트 <1000자(넘으면 조용히 실패). 폴링은 한 번에 ≤37초.
- 참조 이미지: `asset_get_presigned_urls`(assets=[{id,sourceType:"acp"}]) downloadUrl(몇 시간 유효), 로컬 파일은 `asset_initialize_file_upload`(path,file_size,media_type) → `curl -L -X PUT` → `asset_finalize_file_upload`(transfer_document) → presignedAssetUrl.
- 결과 받기: `asset_search`(query `*` 또는 프롬프트 글, sortBy createDate, sortOrder desc, limit N; start 없음) → 오래된 것부터 로그 순서와 대조 → presign → curl. 로그엔 '성공'인데 에셋이 없는 칸이 가끔 있음(주민 Folk4_left처럼) → 개수 세어 다시.
- 컷아웃: `py tools/cutout_flat.py <src> <out> --size 512 --fill 0.86 --holes --check <시트>`(장당 ~20초, 한 장씩 백그라운드), 확인 시트는 항상 **자홍 칸 포함**. 푸시는 `py tools/push_paths.py -m "제목" <파일 경로들>`(디렉터리 인자 안 펼쳐짐, 백그라운드).
- 프롬프트·큐 원문: `art/prompts/`(`Meme_*.txt`, `Icon*.txt`, `img2_*queue*.json`), 주민·스티커·말풍선 프롬프트는 이 세션 javascript에서 만든 것이라 파일엔 없음 → 규칙만 기억: 주민 = "Use the attached image as the exact design reference… same face/clothes… add a small thin floating gold halo ring above the head… full-body front view, relaxed A-pose, plain flat medium gray background"; 4면 = "only turn the camera… straight-on at mid-height… BACK / exact LEFT-SIDE (faces right edge) / RIGHT-SIDE".
- **새 규칙(사용자 10/12 16:30, Blender 손보기 경유): 2D 그림(특히 Tripo에 넣는 앞면·4면)에 그림자 금지** — 바닥 그림자·드리운 그림자·진한 음영 없이 고르고 평평한 빛(그림이 그대로 색 맵이 돼 그림자가 굽힘). 프롬프트에 'no shadows, no cast shadow, flat even lighting, no ground shadow' 넣고, 이미 만든 4면 그림(주민·밈·성·소품)에 그림자가 보이면 다시 그리기 대상.
- 규칙: Medium 0크레딧 → 고르기 → High 5크레딧 → 컷아웃 → 시트(밝은·남색·자홍·48px). 빛살 무늬 금지, 사람은 단정한 옷(얼굴·손만), 밈·스티커 글자는 철자 하나하나 확인.
