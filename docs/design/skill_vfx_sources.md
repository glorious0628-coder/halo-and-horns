# 무료 이펙트 출처 장부 (A23-62)

규칙(SPEC A23-62): Roblox Creator Store **무료** 이펙트를 먼저 쓴다. 가져올 때 안의 Script·LocalScript·ModuleScript는 모두 지우고(무료 모델 뒷문 위험), 파티클·빔·트레일·텍스처만 쓴다. 쓴 애셋 id와 만든 사람을 여기에 적는다. 우리 코드는 **텍스처 id만** 가져다 쓰고 모델·스크립트는 place에 넣지 않는다.

| 날짜 | 어디에 | 쓴 것(텍스처 id) | 원본 무료 애셋(id) | 만든 사람 | 메모 |
|---|---|---|---|---|---|
| 2026-10-07 | 분수 물줄기 FountainFx: 꼭대기 물기둥·튀김 | 401407269 (물방울) | Fountain (water) particles (458829107) | SparkleWays | 스크립트 0개. 원본은 Box 모양 물방울 두 개(165·60개/초) — 우리는 34+14개/초로 |
| 2026-10-07 | 분수 물줄기: 그릇에서 떨어지는 가는 물줄기(Beam) | 6045867277 | Water Beam Effect VFX (14582235284) | EvilArtist | 스크립트 0개. 설명: 텍스처는 툴박스, 파티클은 직접 만듦(사용 허락). 넓은 판(5465796644)은 얼음판처럼 보여 바꿈 |
| 2026-10-07 | (시험만, 지금 안 씀) | 5465796644 | Moving Beam Water - Tiny (10610453422) | bluecoolman280 | 넓은 물판 — 분수에는 안 맞음 |
| 2026-10-07 | 분수 물줄기: 떨어지는 곳 물결(바닥에 눕힌 파티클) | 9833214445 | Stylized Water Particles Splash Effect RP (104302188311459) | MoonRocket29609 | 원본에 스크립트 2개 → 넣을 때 샌드박스, 살펴본 뒤 원본 통째로 지움(텍스처 id만 씀) |
| 2026-10-07 | 분수 물줄기: 연못·후광 반짝이 | 244221535 | Sparkles Particle (688891088) | Nanonauts | 스크립트 0개 |

살펴보기 방법: Studio MCP `insert_asset`으로 ServerStorage에 잠깐 넣어 파티클·빔 속성만 읽고 바로 지움(2026-10-07, 메인 Studio Edit, 저장 안 함). 후보 검색 기록: Particle Waterfall Cascade(109227527797309, Sparksh7143)는 큰 안개 텍스처라 이번엔 안 씀.
