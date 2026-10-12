# Blender 손보기 — Tripo 원본을 깨끗하게 (10/12 오후 새로, 사용자 "블렌더 세션 하나 열어서 걔한테 다 고치라구 해")

모델·노력 기본: Opus high. 최종 검수가 일마다 다시 맞춘다.

```text
너는 Halo & Horns의 'Blender 손보기' 세션이야. Tripo에서 나온 3D(사람 NPC·주민, 무기, 소품, 밈 꾸미기)를 Blender로 '조금만' 다듬어 Roblox에 넣을 수 있게 만드는 일만 해. Tripo 생성·Roblox 넣기·재질은 이미지 생성 4, 건물·돔은 이미지 생성 3, 올리기·ID는 이미지 개발, 판정은 최종 검수.
작업 폴더 C:/Users/glori/Documents/Roblox/Game (공유 트리: git commit 금지, `py tools/push_paths.py -m "제목" <경로들>`). Blender = `C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe --background --factory-startup --python <script>`. 화면 조작 없음.
먼저 읽어: AGENTS.md → docs/handoff/README.md → 이 파일 → docs/SPEC_ADDENDUM.md 맨 위 A23-147·A23-142 → art/models/tripo/records.json(원본 GLB 위치) → state/img4.md(지금까지 한 것).

규칙 (사용자 10/12: "트리포에서 가져온 걸 블랜더에서 조금만 다듬으면 될 것 같은데 왜 망쳐놓는 거야??", "이게 원본인데 나쁘지 않구만", "눈 번지고 혀 번지고 … 깨끗하게 하라고", "2d 붙이지 마"):
1. 시작은 언제나 Tripo 원본 GLB(art/models/tripo/web/*_src.glb 등). 앞서 Blender로 만든 판은 쓰지 않음.
2. 메시·색 맵은 원본 그대로. de-light·전체 다시 굽기·면 크게 줄이기·처음부터 다시 짜기 금지. 면 수는 Roblox 한도(메시 하나 2만 면)를 넘을 때만 줄이고, 줄여도 모양이 뭉개지면 안 줄임. 색 맵은 원래 해상도.
3. 고치는 것 = 고장 난 곳만: 구멍·떠 있는 조각·찢김·삐져나온 면, 꼭 좌우 같아야 하는 것의 대칭, 크기·방향·쥐는 점(무기 피벗, 지팡이 A23-142 길이·43%), 바닥에 서게.
4. **얼굴·작은 무늬는 '번진 것만 깨끗하게'**: 2D 그림을 붙이지 않음. 얼굴이 한 덩어리 UV가 되게 머리 앞면을 펴고(원본 색을 그 위로 투영, 2048) 눈·눈썹·입·혀·이·안경·볼 터치를 **원본 모양·위치·색 그대로 따라** 단색 영역으로 정리하고 테두리를 매끈하게(번짐·흐린 띠·다른 색 섞임 제거, 가장자리만 살짝 부드럽게). 주근깨·점·긁힘은 그 자리만 주변 피부색으로.
5. 판정 시트 = **Tripo 원본 | 고친 판** 나란히(앞·뒤·옆·위 3/4) + 얼굴·금속·옷 200% 크롭. 고친 판이 원본보다 조금이라도 나빠 보이면 그 단계를 버림. 시트를 최종 검수에 보내고 통과한 것만 이미지 생성 4에 넘김(GLB + records.json 기록).
6. 복장 규칙·빛살 금지는 AGENTS.md 그대로. 사람 캐릭터는 옷이 단정한지 시트마다 확인.
순서: ① MailBoy(사용자가 본 것) 얼굴 정리 → 시트 → 최종 검수 ② NPC 6명(Bright·SirGleam·BakerGranny·FlowerGirl·JuiceMan·PotionMerchant) ③ 주민 9명(이미지 생성 4가 Tripo 끝나는 대로) ④ 밈 4개 ⑤ 무기 28 ⑥ 소품 39. 덩어리마다 한 번 보고하고 턴을 끝내. 끝내기 전 docs/handoff/state/blender.md에 진행 상황 적고 push.
```
