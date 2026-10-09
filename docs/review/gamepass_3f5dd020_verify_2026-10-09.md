# origin/dev2-gamepass 3f5dd020 (A23-75 게임 패스) 독립 검증 — 게임성 개발 3, 2026-10-09

방법: 개발 2가 아니라 반박하는 쪽으로 읽음. 임시 worktree(`Game-gpverify`, origin/main 87463f12 + `git merge origin/dev2-gamepass`)에서 코드를 읽고 전체 시험을 돌림. 고치지 않음(개발 2 몫).

## 병합
- `git merge-tree`: **src 충돌 0**(Config·QuestService·StoryQuestService·WarService 자동 병합). 충돌 49개는 전부 `docs/art/**/offline_*.json` 보고서(시험이 다시 쓰는 파일) — 병합 때 ours로 정리했고 병합 뒤 시험이 다시 만듦.

## real 문제
1. **(중간) 구매 직후 Roblox가 "아니오"라고 답하면 결제한 사람이 아무것도 못 받음** — `MonetizationService.luau` `PASS.Purchased`: `purchased == true`인데 `PASS.Ask`가 `false`를 주면 경고만 하고 `continue`(다시 묻지 않음). 시험(`gamepass_offline` 754줄 부근)은 "false → 무시"만 확인하고 "나중에 true가 되면?"은 없음. 위험: Roblox `UserOwnsGamePassAsync`가 접속 때 한 번 false를 줬다면 서버 캐시 때문에 구매 직후에도 false일 수 있음(공식 동작은 게시된 곳에서만 확인 가능 — **실제 게시 장소에서 한 번 사 보기 전엔 단정 못 함**). 제안(개발 2): false를 받으면 즉시 무시하지 말고 N초 뒤 한두 번 더 묻고, 그래도 false면 무시. 아니면 "이번 접속만" 켜는 길로 보내고 다음 접속에 정정.
2. **(낮음, 설계 확인) 2배 골드가 플레이어 현상금(`Bounty`)·`War`에도 적용** — `GoldSources`에 `Bounty`, `War`가 있음. A23-75("골드는 랭킹·레벨에 들어간다, 능력치만 안 판다")와는 맞지만, 플레이어를 잡아 받는 골드가 패스 소유자만 2배 → PvP 보상 격차. 위반은 아니고 사용자·검수가 알고 정한 것인지 한 번 확인할 항목.

## 반박됨 (깨 보려 했지만 고쳐져 있음)
- **구매 신호 → Roblox 재확인**: `purchased ~= true`·Player 아님·`Parent == nil`은 무시. 답 `false`는 무시(경고), `nil`(전부 실패)은 이번 접속만 켬(저장·공유 명단·`PassBought` 없음), `true`만 저장·명단·지표. `PassBought`는 접속 확인·Studio·Id 0에서 안 나감. 변이 시험이 각각 잡음.
- **Studio 시험 구매**: `RunService:IsStudio()`면 실제 질문 없이 `DebugSetPass(on)` + `DebugTainted`, 저장·명단 없음. 후원자 명단 DataStore 이름은 Studio에서 `…_STUDIO`(시험이 live 0 / STUDIO 1을 확인). `DebugCommand`도 `IsStudio()` 안에서만 만들어짐.
- **이야기 선택 골드 2배 아님**: `StoryQuestService:804` 출처 `"Choice"`, `GoldSources`에 없음. `Sale·Refund·Plunder·KaijuBank·KaijuTransfer·KaijuBonus·Penalty·Other·Choice·Finisher`는 시험이 2배 안 됨을 확인. 퀘스트 자체 보상(`Quest`)은 2배(결정대로).
- **후원자 이름이 확인된 닉네임을 따라감**: `Util.PlayerDisplayName`(Nickname + NicknameVerified, 아니면 DisplayName). `Nickname`·`NicknameVerified` 둘 다 감시, 같은 이름이면 쓰지 않음, 확인 전→후, 변경 뒤에 따라감, 한글 20자(60바이트) OK. 확인 안 된 VIP는 이 서버 판에만.
- **규칙 위반 찾기**: ① 능력치 판매 — `GamePasses`는 XP2/Gold2/VIP만, 능력치 변경 코드 없음. 구매 버튼은 `ShopUI`의 `PromptGamePassPurchase` 하나뿐이고 멈춤 카드·KO·강화 실패 화면(`PauseCard.luau`, `Panels.luau`의 강화 결과 등)에는 없음(`test_pause_card`도 "구매 팝업 없음" 정적 검사 통과). ② 번 모양 ≠ 산 모양 — 판매 룩 `HaloIce/HaloGold/HornsLava/HornsShadow`와 출석 룩 `*Sprout/*Starlight/*Platinum`은 id·이름·아이콘이 모두 다름. ③ 2배 패스가 아이템까지 2배 — XP는 `AddXP`, 골드는 `AddBankGold/AddCarriedGold`의 `boostGold`뿐. 드롭·아이템 개수 경로(`LootService`)는 골드 한 줄 외에 바뀐 곳 없음; `NOT_DOUBLED` 정적 검사 통과. ④ 2배 XP가 A23-27(낮은 레벨 한 칸 상한)을 넘음 — `AddXP(..., cap)`이 2배 뒤에 상한을 적용.
- 퀘스트·게시판 알림 글은 "실제로 더해진 값"으로 바뀌어 있음(2배인데 1배로 보이는 줄 없음).

## 시험 결과 (병합 상태 87463f12 + dev2-gamepass, `TEMP` 분리해 한 줄로 83개)
- gamepass: **180/180 검사, 변이 82/82**.
- attendance: **98/98, 변이 36/36** — 단, 이 시험은 `withLooks`로 `Config.Looks`·`GrantLook`을 **가짜로 주입**함. 병합 상태 실제 연결은 코드로 대조: `AttendanceService.grantLooks`가 `Config.Looks[id].Unlock.Attendance`(표 모양 `{Attendance = 14}`)를 읽고 `MonetizationService.GrantLook(player, id)`(새로 열면 true)를 부름 — 이름·모양·반환값 일치, 출석 룩 6개(14/50/100일 × 두 진영)가 켜짐. 실제 두 서비스를 한 세계에서 같이 올리는 시험은 아직 없음(제안: 개발 2 또는 나중에 한 줄 추가).
- 나머지: 83개 중 **79개 통과, 4개 exit≠0**:
  - `test_costume_physics`, `test_skin_binding_studio`: 은퇴한 도구("costumes removed A23-5, must not be run") — 의도된 실패.
  - `test_board`, `test_weapon_first`: **내 실수** — A23-84 Slime Prince 글 바꿈(42984947) 뒤 시험 데이터에 옛 글이 남음(`board_offline.luau`의 'King Slime' 글, `test_weapon_first.py`의 변이 자리 "The King Slimes ate…"). gamepass와 무관하고 main에서도 실패하던 것. 고침: board 6e9bc706(93/93, 변이 26/26), weapon_first 이 문서와 같은 커밋(변이 47/47).
- 실제 Roblox에서만 알 수 있는 것(시험 불가): 구매 직후 `UserOwnsGamePassAsync` 값, 개인 서버, DataStore 실제 한도. 게시 장소에서 사 보기 필요.

## 결론
병합은 깨끗하고 3차 고친 4건은 진짜 고쳐져 있음. 병합 전에 개발 2가 정해 줄 것: 위 1번(구매 직후 false 처리). 2번은 설계 확인만.
