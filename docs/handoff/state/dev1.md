# 게임성 개발 1 — 인계 상태 (2026-10-11)

클라 코드만(창·HUD·Config·Fx). worktree `C:/Users/glori/Documents/Roblox/Game-wtc` (브랜치 `invite`, 일 전에 `git merge --ff-only origin/main`, 커밋은 pathspec, push는 `git push origin HEAD:main`). Studio sync는 메인 반영 1에게 부탁.

## 오늘까지 main에 올린 것 (메인 반영 sync·사진 대기)
- A23-113: 메뉴 칸 6칸 + 자물쇠(443f5944, 순서 가방·지도·영웅·스킬·펫·순위 de8b71d9), 바닥 그림자 원 LandShadow(5d5f1130), 마을 말풍선 TownReact(5d5f1130·ebc591b7), 직업별 맞는 소리(5d5f1130), 몬스터별 죽는 소리(de8b71d9), 이야기 토스트 끔(de8b71d9), 드롭 배수 줄(9e3f7626), 빛 마을 새소리 낮만(1d511042).
- A23-116 스킬 18개: SkillFx.luau — Q 6(55bbdcb3), Z 6(10b8d7e9), X 6(bf6db295) + 새 몸짓 12 + 몸짓 고침 4. Z·X는 Config.Skills.ZEnabled/XEnabled 꺼진 채(10/20 결정).
- A23-110 첫 KO King 떨어지는 그림 + 남의 King 쿵 없음(ae592b44, 서버 DropAt 없으면 무동작).
- A23-108 무기 쥐는 법 9개(dev1-grips2, 검수 병합 390918f1).
- 서버 대상 힌트 켜기 `Config.AutoFace.ServerHint = true` + auto_face 시험(이 인계 커밋에 같이; 브랜치 dev1-hint c4d86650와 같은 내용).
- (새 세션 10/11) BB9 스킬 창 SkillBook.luau + 진영 줄(dfea1c5d, test_skill_book 56·22/22): 칸 잠김 동안 K는 칸만 흔듦.
- (새 세션 10/11) 걷는 바닥: Config.Ground.Tag = "WalkGround", Config.GroundRoots, Shared/Ground.luau; LandShadow·SkillFx·Fx 사용(c45ed8c6, test_ground_rays 23·17/17). 서버 3곳은 개발 2 몫(공유 노트 dev1_walkground_contract_2026-10-11.md).

## 다음 큐 (순서대로)
1. 메인 반영 사진 확인 뒤 고칠 것: Q·Z·X 6키트 1초 검사, 쥐기 9조합, 메뉴 칸 자물쇠, King 떨어지기.
2. 스킬 소리 41개 연결(소리 만들기가 id 보내면): Config.Audio.Files/Sounds + Audio.luau(시전·맞음, 같은 슬롯 같은 음량, 장판 틱 -6dB).
3. ~~스킬 창 진영 줄~~ 끝(dfea1c5d). 사진 확인 뒤 손볼 것만.
4. 개발 2가 Z·X 패킷에 ContactDelay·LaunchDelay·HitDelay, Q·Z·X에 Healed·Stole을 넣으면 SkillFx가 바로 씀(필드 이름 그대로).
5. 장인 기능 클라(채집·제작·망치질·장비 칸·물약·펫 연구) — 빛 마을 끝난 뒤 검수가 순서 줌.
6. 나중: 광전사 대검 두 손 쥐기, 슬롯별 화면 흔들림 세기, 한국어 모드(docs/design/l10n_client_2026-10-10.md, 빛 마을 뒤).

## 브랜치 / worktree
- Game-wtc(invite): 메인 작업. 커밋 안 된 것은 시험이 다시 쓴 docs/art 보고서뿐(올리지 않음).
- ../Game-dev1-tiles(dev1-hint): ServerHint 브랜치 — main에 같은 내용이 들어가면 지워도 됨.
- ../Game-dev1-grips(dev1-grips2): 병합됨, 지워도 됨. ../Game-dev1-zonelook: 병합됨.
- 옛 브랜치 dev1-tilereveal(숨기기 방식)은 쓰지 않음.

## 알아둘 것
- 시험은 동시에 3개까지(PC 메모리). Luau 오프라인: build/luau_cli_0_741/luau.exe.
- Bash 도구는 문자열 속 \n을 줄바꿈으로 바꿈 → 시험 파일 수정은 Write/Edit로.
- 그림자 원·King 낙하 약속: 공유 노트 dev1_land_shadow_contract_2026-10-10.md(DropAt·DropTime·DropRadius·DropPos).
- HUD.luau·Fx.luau는 지역 변수 200개 한도 근처 → 새 값은 L / MOTION / WOBBLE 표에.
