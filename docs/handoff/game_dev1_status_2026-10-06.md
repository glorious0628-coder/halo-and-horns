# 게임성 개발(1) 인계 — 2026-10-06 멈춤 시점

- **최신(2026-10-06 저녁):** 유령 3D(왕 111999674841692·똘마니 84018800442559) CustomModels 연결·정면 확인(devlog 16, 검수 통과), 크기 똘마니 3·왕 9(Config Scale 0.6/1.8). 이름표는 같은 종류 5칸 안이면 하나(MonsterLabels). **BB13** Panels.Register(kit·Cleanup·FixedBody·Rebuild 거르기·RENDER Arg·뒤로 = 온 창·Esc/패드 B 닫기) + **BB3** SettingsUI.luau(설정 창 영어: 직업·환생·오프닝·이름 숨기기·휴가·닉네임(BB8 전까지)·키 설정 탭·효과음·흔들림·키 표시·버전 줄·저장 꺼짐) + Fx 효과음 배수·흔들림 끄기 + SettingsService가 GameState SaveOK. 메인 Studio에 a0e8098·052c7b4와 함께 동기화, 자기 Play로 Settings·Keys 탭 확인(docs/art/verification_2026-10-06/bb13/). **남은 것:** Config.Help(BB15 도움말·새 소식, 규칙 조사 중) → 등록 확인 → 오프라인 keys_settings 재검사 → 커밋. 그다음 A23-34 맨손 병합(검수 OK 오면, 클라이언트 §6 + HUD doUpgrade 서버 경유), A23-48 내 창 글자 영어.

- **최신(새 계정, 한도로 멈춤):** 개발 2 병합 끝 = main **dfefaaa**(푸시, eac036f·ff38ce4·e078bf5, 충돌 5곳 해결, 병합 트리 오프라인 16종 변형 포함 통과). 이미지 개발 미완성 HUD v2는 worktree `Game-imgdev`로 옮겨져 작업 폴더 src는 HEAD와 같음. 임시 worktree `Game-wtc`는 병합용(지워도 됨).
- **Studio:** 메인 Studio(창 이름 '악마 키우기 (placeId: 81671223175574)') 열림·Edit 모드. dfefaaa src 동기화(74개 씀·6개 지움) + `apply_studio_state.py`(몬스터 모델 10종 다시 넣음) 끝. **플레이 확인·Save As·place 커밋은 아직.**
- **다음:** 플레이로 랭킹·게시판 서버 확인(오류 0) → Save As build/GoodEvil.rbxlx → place/ 커밋 → b9ada3b 땅·조명·나무 메인 적용 → 호박밭 배치 4개 → BB13(A23-38 + A23-40 B안: 아이콘 줄 끝 [메뉴]에서 위로 펼침) → BB3 → BB6 → BB7. 개발 2 BB14는 rebase 끝 = **65e2ba6**(dev2, 푸시됨; 500f60d는 옛 해시라 쓰지 않음) → 병합 뒤 몬스터·플레이어·낙하 쓰러짐에 본인만 Net.Fx 'KO' 확인. A23-39 펫 조련사 클라이언트는 PET-3와 10/17~18(검수에 알림).

(아래는 이전 기록)

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
