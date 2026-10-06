# 게임성 개발(1) 인계 — 2026-10-06 멈춤 시점

- **끝난 것(main에 푸시):** 1614575 핼러윈 4종·사탕·호박 대왕 / c6d31ec 안 F10-4 첫 임무 60초 자동 지급 / 6b1e45a 27246d1 검수 수정(상호작용 키 제한, Keybinds.ShowsKeys, 러너 mutationsSkipped, 검사 보강, 황금 몬스터 Fill 0.25, 슬라임 깊이 늘리기 제거) / 78320eb 개발2 5f52534 병합(BB37·BB12) / 5f357b7 병합 뒤 증거.
- **커밋 안 한 파일:** `src/StarterPlayer/StarterPlayerScripts/Fx.luau` 한 개. '땅에 붙는 느낌' 작업이에요(검수 요청 1~3). 컴파일되고 Studio에 동기화했어요.
  - 블롭 그림자: 카메라 140스터드 안 모든 몬스터 밑에 원판 3겹. 슬라임은 몸×1.15, 유령은 작고 옅게.
  - 슬라임 통통: 몸 높이 15%, 최대 0.6.
  - 착지 먼지 3~5개.
  - 슬라임 0.1 묻힘.
  - 확인: 해골·고블린 발밑 그림자는 보여요. 슬라임 그림자를 키운 뒤의 '후' 사진은 아직 못 봤어요. 사진은 scratchpad의 after_fix_6.jpg이고, '전' 사진은 docs/art/verification_2026-10-06/monsters_before_fix_2026-10-06.jpg예요. 사진을 보고 커밋하면 돼요.
- **Studio 상태:** 메인 Studio(악마 키우기, pid 18272)는 Edit 모드이고 Play는 멈췄어요. src 전체가 동기화돼 있어요(Fx 포함). place 저장은 75ad8ef 이후 안 했어요. 다음 place 커밋 전에 `py tools/apply_studio_state.py` → 파일로 저장(Save to File As build/GoodEvil.rbxlx) → place/로 복사해요.
- **다음 할 일 순서:**
  1. Fx '후' 사진 확인 → 커밋. 검수 4번(고블린·해골 걷기 발 닿음 캡처)과 5번(같은 자리 전·후)도 해요.
  2. 1614575 검수 결과 10개(검수 메시지 참고):
     - 대왕 안전: Level<5 또는 플레이 600초 미만, 진영 무관
     - 기여: 3타 + 최대 HP의 0.5%
     - Lv8 미만은 대왕 XP를 XPToNext로 자르기
     - 무기 줄은 MinLevel 이상일 때만 + 장착 레벨 제한
     - 대왕 주문서 확률 절반
     - FRONT_FIX를 매번 적용(멱등)
     - MonsterMotion State 청소
     - 드랍 줄 ×N
     - CrownTrialMiss를 QuestKind로
     - 대왕 안전 오프라인 검사·studio_halloween json
  3. BB13 → BB3: 작업 지시 초안은 scratchpad의 wf_bb13_bb3.js예요. 메뉴 아이콘 키는 Config에 있고, [내 캐릭터]는 UIKit.CharacterIcon을 써요.
  4. 이미지 개발 f0e011a·938c230 동기화·확인, 개발2 다음 덩어리 병합.
- **주의:** 같은 작업 폴더를 여러 세션이 써요. 커밋은 `git commit -- <경로>`로만 해요. 테스트는 변형 포함으로 돌려 증거 json을 남겨요.
