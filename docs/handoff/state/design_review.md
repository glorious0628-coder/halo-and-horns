# 디자인 검수 — 상태 (2026-10-12 밤, 새 세션 local_2137d284)

보고처: 이미지 생성 2·3·Blender 손보기 → 나 → 최종 검수(local_8166f268). 옛 10/12 점심 큐(돔·NPC de-light·바깥선)는 다 바뀜 = 기록일 뿐(git log 참고).

## 판정 규칙 (최종 검수 10/12 밤 + 사용자)
- **사용자(내 창에 직접): "시트 보지 말고 너가 직접 트리포에서 봐 내장 웹에서"** → 흰 모델·텍스처는 앱 브라우저 **내 탭**에서 직접 돌려 봄(Blender의 seed 탭은 건드리지 않음, 끝나면 seed 앞으로 + 내 탭 닫기). 조작: canvas에 JS PointerEvent(왼 = 돌리기, 오른 = 옮기기), WheelEvent ±240 = 한 칸 확대, 아래 바 x≈613 버튼 = 선(와이어) 끄기, 창 숨김이면 스샷 전마다 1440x900 다시.
- 2D 4면: 한 장씩 전체 크기, 그림자·어두운 면 없음, 4면 같은 카메라 높이, 한쪽 보는 것(꽃·얼굴·방패) 방향 맞음, 옛 그림과 모양·개수·색 같음, 빛살 없음, 게임에서 쓰는 법(분수 물줄기 = FountainFx).
- Tripo 흰 모델 관문: 후보 4개 약한 곳(받침 옆·얇은 장식·물 면·구멍) + 고른 것 사방·위·아래 → 내 통과 뒤 텍스처.
- 순서(SPEC A23-150 2번, 1cd1bf4c): 텍스처(앞면 1장·조명 제거·8K, 30) → 고장은 Tripo 안에서(스마트 메시 수정·다시 뽑기) → 내 확인 → PBR 맨 마지막(5) → Blender는 크기·피벗·방향만. 색 고친 곳은 전·후 100%.
- 사람(NPC·주민·MailBoy)은 맨 마지막(보지도 않음).
- 점수: 빛 마을 승인 목록(noshadow_redo 빛 마을 줄 + art/prompts/house_chunks_queue_2026-10-13.json) 안이면 내가 OK(하나 135, 다시 하기도), 밖은 최종 검수.

## 지금 (10/12 23시쯤)
- 동상 흰 모델 = **B 1a0812be 통과**, 분수 = **C cd70436c 통과**(D 네모 물·B 바닥 없음·A 물 높음) → Blender 손보기 텍스처 중 → PBR 전에 내가 Tripo에서 금 공·물 색 확인.
- 화분 5종 흰 모델 통과: Daisy c9df2ff9, Lavender fd15be73, Rose 9e0487cc, Sunflower 5f8780fb, Tulip f75480d2 → 텍스처 OK, PBR 전 내가 다시 봄. (창 숨김이면 Tripo가 안 그려짐 → store의 model_url로 FBX 받아 Blender 7면 렌더로 판정, 최종 검수 OK 방법.) 잎 한쪽 면 → Roblox DoubleSided(이미지 생성 3에 알림).
- 최종 검수 상시(사용자 10/12 22:30): 이미지→Tripo 먼저, 4면·흰 모델 관문이 다른 판정보다 먼저. 4면 공급 = 이미지 생성 2(집 덩어리 43 큐) + 이미지 생성 3(빛 마을 소품: 벤치부터).
- 텍스처: 동상 B(뒤 앞치마 파랑→흰, 발 사이 얼룩)·분수 C(2단 물 번짐) → Tripo 편집 30점 이하 OK, 고친 뒤 내가 보고 PBR. 크롭 art/review/design/*_tex_*_1012.jpg.
- 4면 판정: BenchA 왼·오른 손질(오른 기준 크기 770px, 왼=뒤집기). 덩어리: DoorSingle·ConeTree 통과→Blender 넘김. LampArm(right=flip left)·WingL(right=flip left)·DomeRibbed(left=front)·DoorDouble(front=flip back)·WindowBoxA(right=flip left + 옆 높이 1015px) 손질 뒤 통과. WingR = WingL 3D Blender 좌우 뒤집기 제안(최종 검수 결정 대기). CastleRose 4면 대기.
- 4면 흔한 고장: 좌우 옆면이 서로 다름 / 옆면이 1.2~1.3배 크게 그려짐 / 한 면만 연한 빛 띠 → PIL 뒤집기·복사·크기로 고침(새 생성 X).
- 이미지 생성 3: 동상·분수·화분 새 판 모이면 3D 가져오기(최종 검수 경유) → SA → WorldKit 자리·재질·낮밤 사진. 낮 빛 = 위도 35 + 따뜻한 OA.
