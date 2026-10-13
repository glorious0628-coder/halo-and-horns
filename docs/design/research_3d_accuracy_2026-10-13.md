# 2D 시안대로 더 정확한 3D 뽑기 — 조사 (2026-10-13 밤, 조사 전용)

목적: Meshy(멀티뷰·리텍스처·리메시)와 Tripo(스마트 메시·멀티뷰)에서 **모양이 2D와 더 같게** 나오게 하는, 공식 문서·사용자 글에 근거가 있는 방법 모음. 우리 규칙(그림자 없는 4면, 붓질·다시 올리기 없음, Blender는 크기·피벗·방향만, Roblox 메시 ≤ 20,000 삼각형·텍스처 1024)은 그대로 두고, **2D 그리는 법과 생성 설정**에서 바꿀 수 있는 것만 적었다. 돈 드는 생성은 사용자 "가" 뒤(A23-160).

읽은 것: `3d_pipeline_2026-10-13.md`, `meshy_pipeline_2026-10-13.md`, `pbr_final_2026-10-13.md`, `noshadow_redo_2026-10-12.md`. 웹: Meshy 공식 문서·튜토리얼·도움말, Tripo 도움말·블로그(curl로 받아 읽음), Roblox Creator Hub, 독립 비교글(HackerNoon, strayspark, digitalproduction). YouTube는 제목 검색만 가능했고 쓸 만한 영상 1개(아래 출처 14)뿐이라 영상 근거는 약하다.

## 1. 기법 표

| # | 기법 | 어떤 문제를 줄이나 | 도구 | 우리 2D 4면 규칙에 바꿀 것 | 출처 |
|---|---|---|---|---|---|
| 1 | **물체가 화면의 70~85%**, 사방 여백 같게, 가장자리에 닿지 않게 | 흐릿·디테일 없음, 잘린 모델 | 둘 다 | `ns_fix.py`에 "4면 모두 긴 쪽 70~85% + 여백 검사" 추가. 지금은 면마다 크기가 다를 수 있음 | T1, T2 |
| 2 | **4면 같은 카메라 거리·같은 축척**(옆면이 작아도 억지로 키우지 않음) | 비율 틀어짐, 한쪽으로 기움 | 둘 다 | 가장 큰 면 기준으로 축척 고정, 작은 면은 여백으로 채움. 1번과 충돌하면 **축척 통일이 우선** | M2, M4 |
| 3 | **PNG·1024 이상(2048 권장)**, JPEG 압축 금지 | 표면 울퉁불퉁(압축 노이즈가 요철로 읽힘), 작은 디테일 사라짐 | 둘 다 | 이미 PNG. Codex 출력이 1024 미만이면 2048로 다시 뽑기 | T2, M2, T6 |
| 4 | **바탕은 흰색·밝은 회색 단색**, 물체 색과 비슷한 바탕 금지 | 바탕이 모양에 섞임, 테두리 번짐 | 둘 다 | 지금 회색 OK. 연두 잎·회색 돌처럼 바탕과 가까운 색은 흰 바탕으로 | T1, M2 |
| 5 | **대칭 물체는 정면을 정확히 가운데**, 3/4 시점 금지, 좌우 옆면은 거울 | 대칭 물체가 비뚤게 나옴(대칭은 스위치가 아니라 입력에서 읽음; Meshy `symmetry_mode`는 폐기됨) | 둘 다 | `ns_fix.py --mirror left=right` 기본값으로. Meshy에 대칭 옵션을 기대하지 말 것 | T2, M1 |
| 6 | **앞면 = 첫 칸(주 시점)**. Tripo는 칸 순서 고정(앞·왼·오른·뒤), Meshy는 첫 장만 앞, 나머지 순서 무관 | 뒤·옆이 지어내진 모양, 뒤에 앞 장식 찍힘 | 둘 다 | Meshy 호출 시 앞면이 첫 장인지만 확인. 뒤·옆은 "참고"가 아니라 **관측**이므로 빼지 말 것 | M1, M3, H1 |
| 7 | **작은 부품은 최소 한 면에 또렷이 보이게**, 가려진 부품은 다른 면에서 보이게 | 작은 부품이 공중에 뜨거나 사라짐 | 둘 다 | 4면 판정 항목에 "모든 부품이 어느 한 면엔 다 보이나" 추가 | M4 |
| 8 | **가는 선(줄·끈·철사·실)은 2D에서 빼고 Studio 파트로** | 가는 부분이 뭉치거나 끊김, 폴리곤 낭비 | 둘 다 | 빨랫줄 줄·깃대 끈·거미줄은 그리지 않고 얇은 Part. 그림엔 걸린 물건만 | T2, T3 |
| 9 | **복잡한 물건은 덩어리로 쪼개 따로 생성**(각자 폴리곤 예산), 빈틈 없이 닿게 그림 | 부품 누락, 작은 장식 뭉개짐 | 둘 다(Meshy 리메시도 "부품별로") | 이미 덩어리 규칙 있음. 추가: 한 그림에 **떨어진 물체 2개 금지**(합쳐짐), 수레+꽃더미처럼 따로 만든 것은 계속 따로 | T2, M6, M5 |
| 10 | **유리·크롬·투명은 2D에서 불투명 단색으로** | 유리가 꽉 찬 덩어리·구멍으로 나옴 | 둘 다 | 등불 유리는 연한 하늘색 불투명으로 그리고 ⑤에서 Glass 파트(이미 하는 방식) | T2 |
| 11 | **사람은 A-pose**(Meshy `pose_mode a-pose`), 몸과 옷·소품 분리 | 손·팔 뭉개짐, 리깅 불가 | 둘 다 | NPC 4면은 A-pose로 그림. Meshy에서 `--pose a-pose` | M1, M4, T1 |
| 12 | **폴리곤 예산을 생성 전에 정함**(Tripo 스마트 메시 슬라이더; Meshy는 `should_remesh=true`+`target_polycount`) | 너무 낮음 → 가는 부분 끊김·구멍, 너무 높음 → 숨은 면에 낭비, Roblox 한도 초과 | 둘 다 | 소품 10~15k 삼각형, 큰 장식 ≤ 20k. Meshy는 **같은 작업 안에서 리메시 뒤 텍스처**가 입혀지므로 UV가 맞음(생성 뒤 따로 Blender 감면은 우리 규칙상 금지) | T2, T5, M7, R1, R3 |
| 13 | **Meshy `geometry_resolution 2k`(+5크레딧)** = 요철·얇은 테·글자 돋을새김에 효과 | 얇은 난간·테두리가 평평해짐 | Meshy | 난간·격자·글자 있는 간판에만 켬 | M1, M2 |
| 14 | **Meshy `image_enhancement=false`, `remove_lighting=true`(기본)** | 우리 그림을 AI가 "보정"해 색·모양이 바뀜 / 그림자 구움 | Meshy | `meshy_api.py` 기본값으로 둘 다 고정 | M1, M8 |
| 15 | **Meshy 텍스처는 `texture_image_urls` 4면**(첫 장 앞) — Tripo 멀티뷰 텍스처 탭과 같은 역할 | 옆·뒤 텍스처 번짐, 무늬 끊김 | Meshy | retexture에 4면 넣기(이미 계획). 단일 참고 그림 금지 | M1, M3 |
| 16 | **Tripo 4개 동시 생성 = 폴리곤 범위 펼치기**("spread"), 실루엣이 사는 것을 고른 뒤 그 근처로 한 번 더 | 한 설정에만 걸고 4개 다 실패 | Tripo | 디자인 검수가 4개 중 고를 때, 가능하면 4개를 다른 폴리곤 값으로(UI에서 되는지 Blender 손보기가 확인) | T2 |
| 17 | **모양용 입력과 색용 입력을 분리**: 모양 단계엔 색·무늬를 뺀 "점토" 그림이 더 정확(Tripo 도움말: 흰 프로토 재질 스크린샷을 입력하면 "모양 정확도가 크게 오름") | 꽃 수백 개·무늬가 표면 요철로 읽힘 | 둘 다(Tripo 스마트 메시 4면 ≠ 텍스처 4면이라 가능; Meshy는 mesh만→retexture) | **시험 3**으로 확인 뒤 규칙화. 0원: PIL로 채도 0·대비 ↑ 판 만들기 | T1 |

Meshy 웹에서 멀티뷰와 Smart Topology(저폴리 직접 생성)는 **같이 못 켬** → 멀티뷰로 만든 뒤 리메시(API는 `should_remesh`가 그 일). Meshy 리메시 문서: "작은 부속이 사라지면 부품별로 리메시", "리메시 뒤 텍스처를 다시 입히는 쪽이 낫다".

## 2. 다음 시험 3개 (Meshy, 사용자 "가" 뒤; 비교 상대 = 이미 있는 Tripo PBR 결과)

공통: `py tools/meshy_api.py mesh <이름> --front/--left/--right/--back art/out/s2/noshadow/<이름>_<면>_ns.png --wait`, ai_model `meshy-7.1`, `remove_lighting true`, `image_enhancement false`, `multi_view_thumbnails true`, 텍스처 = `texture_image_urls` 4면·4K·PBR. 판정 시트 = `tools/final_review/final_gate.py`로 Tripo 판과 **같은 각도·같은 크기**로 나란히(2D | Tripo | Meshy).

| 시험 | 물건(4면 있음) | 설정 | 크레딧 | 무엇을 비교 |
|---|---|---|---|---|
| 1 기본 비교 | `NEW_Hedge` | `should_remesh false`, geometry standard, 메시 20 → retexture 10 | 30 | 울타리 **양 끝면**(Tripo·Meshy 둘 다 번졌던 곳), 꽃 개수·크기, 옆면 텍스처 선명도, 삼각형 수(Roblox 20k 넘으면 시험 2 설정으로 다시) |
| 2 모양 정밀 + 예산 | `HaloVar4_Balustrade_C`(Tripo에서 '다시' 판정: 없는 세 번째 변·각도 80°) | `geometry_resolution 2k`(+5), `should_remesh true`, `topology triangle`, `target_polycount 15000`, `save_pre_remeshed_model true` | 35 | ㄱ자가 열려 있나(세 번째 변 없음), 모서리 90°, 난간 기둥 6개 다 있고 끊김 없나, 리메시 전/후 비교(가는 기둥이 15k에서 사나) |
| 3 점토 입력 | `NEW_FlowerBush`(Tripo: 꽃 적고 가운데 큰 파란 꽃 없음) | 메시 단계 입력 = 4면을 PIL로 **채도 0·대비 ↑·배경 흰색**으로 만든 판(`build/meshy_clay/`), 텍스처 단계 = 원래 색 4면 | 30 | 꽃 덩어리 개수·위치가 2D와 같나, 가운데 큰 꽃이 생기나, 색 텍스처가 점토 모양에 맞게 붙나. 좋으면 Tripo 스마트 메시 4면에도 점토판을 쓰는 규칙 후보 |

성공 기준: 세 시험 모두 "모양 다름" 항목이 Tripo 판보다 적고 삼각형 ≤ 20k. 하나라도 Tripo보다 나쁘면 그 설정은 버리고 기록만(`art/models/meshy/records.json`).

## 3. 잎·꽃·울타리(hedge)

- **왜 끝이 번지나:** 긴 울타리의 옆면은 작은 네모 하나라 정보가 없고, 꽃 수백 개는 표면 노이즈로 읽힌다(T2 "가는 것은 재구성할 게 없다", T6 "애매하면 평균으로 뭉갠다"). 두 도구가 같은 곳에서 실패한 것은 입력 문제다.
- **권장(돈 0):** 울타리 몸통 = **Studio 파트 골격 + 잎 타일 MaterialVariant**(벽·바닥처럼), 꽃은 **큰 꽃 덩어리 1종**(10~15개 덩이, A23-150 5번 "같은 2D = 한 모델")을 Tripo/Meshy로 한 번 만들어 위에 여러 개 놓기. 업계 방식도 같다: "지오메트리는 형태, 디테일은 텍스처", 카드·덩어리(cluster) 5~7개를 흩뿌려 덤불 하나(T4, T7).
- **꼭 통째로 만들어야 하면:** 길게 그리지 말고 **짧은 모듈(가로:세로:깊이 ≈ 2:1:1)**로 그려 4면 모두 정보가 있게 하고, 끝면은 둥근 캡으로 또렷하게. 잎은 알갱이 대신 **큰 덩이 10~15개**(이미 규칙), 꽃은 덩이당 1~3송이 크게. 작은 꽃 점 수백 개는 금지.
- **잎·꽃 양면:** ⑤에서 DoubleSided(이미 함). 카드형 잎은 Roblox에서 알파 테두리가 흐려 보이므로 지금처럼 덩어리형이 맞다.
- **폴리곤:** 잎 덩이는 15k 이상이어야 덜 깨진다는 우리 기록(메모리 "foliage high, then decimate")과 Tripo "너무 낮으면 가는 부분 끊김"이 일치. 단 Blender 감면은 금지이므로 **Tripo 슬라이더 15k 삼각형 / Meshy target_polycount 15000**으로 생성 시점에 맞춤.

## 4. Roblox 한도 확인
- 메시 하나 **20,000 삼각형**(Creator Hub en-us 일반 사양; 다른 언어 판엔 10,000이 남아 있음), 물샐틈없이·두께 0 금지(R1). 텍스처 **1024×1024 최대**, 5×5스터드 256·10×10 512·20×20 1024 권장(R2). 소품 권장 2~10k(M7).
- 감면이 필요하면: Blender Decimate(Collapse)는 UV·텍스처가 살고, Voxel 리메시는 가는 부분이 녹고 UV가 죽는다(S1). 우리 규칙상 둘 다 안 쓰고 생성 설정(12번)으로 맞춘다.

## 5. 출처
- M1 Meshy API Multi-Image to 3D(파라미터·순서·`symmetry_mode` 폐기·`image_enhancement`) https://docs.meshy.ai/api/multi-image-to-3d
- M2 Meshy 튜토리얼 "How to Use Multi-View Image to 3D in Meshy (2026 Guide)"(1040px·배경·같은 거리·문제 해결 표) https://www.meshy.ai/tutorials/multi-view-image-to-3d
- M3 Meshy 블로그 "Multiview Upgrade"(멀티뷰 텍스처, 지어낸 면 vs 관측한 면) https://www.meshy.ai/blog/multiview-upgrade
- M4 Meshy 도움말 "Multi-View Best Practices: Angles and Images" https://help.meshy.ai/en/articles/16102789-meshy-multi-view-best-practices-angles-and-images
- M5 Meshy 웹앱 문서 Image to 3D(근접 정사영·그림자→검은 얼룩·여러 물체 합쳐짐) https://docs.meshy.ai/en/webapp/image-to-3d
- M6 Meshy 리메시 가이드(부품별 리메시·리메시 뒤 리텍스처) https://docs.meshy.ai/en/webapp/guides/3d-model/remesh
- M7 Meshy "3D model for Roblox workflow"(20k·소품 2~10k·골격은 쪼개기) https://www.meshy.ai/tutorials/3d-model-for-roblox-workflow
- M8 Meshy AI Texturing(Remove Lighting) https://docs.meshy.ai/en/webapp/guides/3d-model/ai-texturing
- T1 Tripo 도움말 "How to Get Better Image-to-3D Results"(70~85%·흰 프로토 재질 입력·두께 틀림=옆면 없음) https://www.tripo3d.ai/help/features/how-to-get-better-image-to-3d-results
- T2 Tripo 도움말 "How to Handle Common Issues - Smart Mesh"(대칭은 입력에서·부품 쪼개기·가는 선·폴리곤 예산·4개 spread·P2.0 500~50k) https://www.tripo3d.ai/help/features/how-to-handle-common-issues---smart-mesh
- T3 Tripo 블로그 "AI 3D Model Generator: Mastering Thin Structures" https://www.tripo3d.ai/blog/explore/ai-3d-model-generator-and-thin-structures-survival-strategies
- T4 Tripo 블로그 "Smart Mesh Topology for Foliage & Vegetation" https://www.tripo3d.ai/blog/explore/smart-mesh-topology-for-foliage-and-vegetation
- T5 Tripo 블로그 "How to Use Tripo Smart Mesh P1.0"(슬라이더·멀티뷰 4면·Smart Mesh vs HD) https://www.tripo3d.ai/blog/smart-mesh-tutorial
- T6 Tripo 블로그 "How to Avoid Blurry Textures in AI 3D Generation" https://www.tripo3d.ai/blog/explore/how-to-avoid-blurry-textures-in-ai-3d-generation
- T7 Tripo 블로그 "AI-Generated Plants & Foliage" https://www.tripo3d.ai/blog/explore/how-to-generate-plants-and-foliage-with-ai
- H1 HackerNoon "I ran the same anime character through Meshy multiview and single-image 3D"(멀티뷰가 요철·비대칭을 지킴, 단일은 평균으로 뭉갬) https://hackernoon.com/i-ran-the-same-anime-character-through-meshy-multiview-and-single-image-3d
- S1 strayspark "Reduce polycount of AI 3D models: Blender decimate vs remesh" https://www.strayspark.studio/blog/reduce-polycount-ai-3d-model-blender-decimate-vs-remesh
- S2 Scenario "Tripo 3.1 Multi View"(앞+뒤가 가장 안정, 생성된 옆면은 비틀림 유발 가능) https://www.scenario.com/models/tripo-p2-multi-view , https://www.scenario.com/blog/tripo-image-to-3d-model-ai-2026
- S3 digitalproduction "Tripo P2.0: Put Quad Mesh Generation to the Test"(독립 검토, 실측은 없음) https://digitalproduction.com/2026/09/29/tripo-p2-0-put-quad-mesh-generation-to-the-test/
- R1 Roblox Creator Hub 일반 메시 사양(20,000 삼각형) https://create.roblox.com/docs/en-us/art/modeling/specifications
- R2 Roblox 텍스처 사양(1024) https://create.roblox.com/docs/art/modeling/texture-specifications
- R3 Roblox 메시 폴리곤·충돌 참고(Meshy M7와 같은 수치) — 위 M7
- Y1 YouTube "Turn Any Image into a Realistic 3D Model in Minutes with Tripo 3.1"(2026-03, 단일 이미지 위주, 채널 미확인, 자막 못 읽음) https://www.youtube.com/watch?v=7o-ZqlsfnhA — Meshy/Tripo 멀티뷰 전용 영상은 검색에서 못 찾음.
