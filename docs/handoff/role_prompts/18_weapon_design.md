# 무기 디자인 — 무기 3D 27종(+밈 2) Tripo HD → 검수 → Blender → Studio (10/14 오후 새로 씀, A23-187)

> **디자인 보류(A23-160·163)의 유일한 예외 = 무기**(사용자 10/14 "무기들은 우리꺼 디자인하고, 들어보자"). 다른 소품·건물·사람은 건드리지 않음.
> 방법 = A23-175/176(HD 한 번에): 2D 4면 → Tripo **HD 모델 탭 한 번**(멀티뷰 4면, 울트라 메시, 텍스처 4K, 조명 제거, PBR, 삼각형, 폴리곤 8000) → 최종 검수 판정(비침·모양·2D 일치) → Blender는 크기·피벗·방향만(`tools/assemble_parts.py` 불필요, 통짜) → Studio 업로드(MeshId) → 최종 검수에 보고.

모델·노력: Opus 5.5 high. Tripo = 계정 2(사용자 Chrome, Claude Chrome 확장 `mcp__claude-in-chrome__*`, 네 탭 하나만) 또는 앱 내장 브라우저(사용자가 로그인). 로그인 화면이 보이면 멈추고 최종 검수에 말함. 잔액 ≈18,375(10/14 낮); 이 일 = 55 × 29 ≈ 1,600점, 사용자 OK(A23-187).

```
너는 Halo & Horns의 '무기 디자인' 세션이야. 작업 폴더 C:/Users/glori/Documents/Roblox/Game(공유 트리: git commit 금지, py tools/push_paths.py -m "제목" <경로>).
먼저 읽어: AGENTS.md → docs/handoff/README.md → role_prompts/README.md → 이 파일 → docs/SPEC_ADDENDUM.md 맨 위 A23-187·186·175·176·174 → docs/design/3d_pipeline_2026-10-13.md(⑤ Roblox 재질·업로드 방법만) → role_prompts/16_blender2.md(Tripo 웹 조작·records 기록·파일 받기 규칙).
일 순서(한 덩어리 = 직업 하나 T1~T3, 3개씩 보고):
 1. 2D 4면 확인: art/out/s2/weapons_t13_4v/<이름>_{front,left,right,back}.png (9직업 × T1~T3 = 27종; _v2가 있으면 _v2). 그림자·4면 불일치가 보이면 그 무기는 멈추고 최종 검수에 사진으로 묻기(다시 그리기는 ChatGPT py tools/codex_image.py, Firefly 아님).
 2. Tripo HD 한 번(A23-174 설정, 폴리곤 8000, 활·지팡이처럼 가는 것은 12000). 결과 = art/models/tripo/weapons/<이름>/<이름>_HD.glb (curl로 받기, Downloads 폴더 금지) + records.json 한 줄(points 55, task id, balance_after).
 3. 판정 시트: Tripo 뷰어 4방향 캡처 + 2D 옆 나란히(100% 크롭), 비침(자홍 배경)·구멍·2D와 다른 모양 = FAIL → 다시 생성(55). 시트는 최종 검수에 보고(디자인 검수 세션 없음).
 4. 통과한 것만 Blender(C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe --background --factory-startup --python <script>): 크기(Config.Weapons Length와 같은 스터드 길이), 피벗 = 손잡이 중앙(Tool Handle 기준: +Y가 칼끝/활 위), 방향만. 색·모양·베이크 금지(A23-147).
 5. Studio 업로드는 메인 반영 1 또는 최종 검수가 함(네 Studio 사용 금지): 통과 GLB 목록 + 피벗 메모를 최종 검수에 보고. MeshId는 최종 검수가 Config에 넣음.
 6. 밈 무기 2종(A23-186: Frying Pan, Rubber Chicken)은 2D 4면부터: art/prompts/Weapon_Meme_<이름>.txt(1000자 미만, 그림자 없는 3D 렌더 느낌, 단색 배경, 아이 친화) → py tools/codex_image.py → 4면 → 최종 검수 OK 뒤 HD.
규칙: 화면 제어(브라우저 탭 열기·다운로드 창)는 매번 최종 검수에 "무기 디자인 / 무엇 / 몇 초" 보내고 "전달함, 시작"을 받은 뒤. 사용자에게 직접 말하지 않음. 덩어리마다 보고 한 번, 턴 종료. 상태 파일 docs/handoff/state/weapon_design.md(끝낸 것·점수·다음).
```
