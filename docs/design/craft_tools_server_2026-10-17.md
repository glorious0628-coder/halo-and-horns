# 제작 도구 강화 ① — 서버 계약 (게임성 개발 2, 2026-10-17)

근거: SPEC A23-219, `build/codex/craft_tools_r1.md` §1·§2 축복. ②(제작품 일반 옵션 = 저장 모양 바뀜)는 최종 검수 결정 뒤.

## 무엇
- 직업마다 도구 하나: 대장장이 **Craft Hammer**, 연금술사 **Mixing Kit**, 조련사 **Care Kit**. 처음부터 +0(첫 제작에 필요 없음), +0~+10, 거래 X.
- 저장: `data.Craft.ToolSmith / ToolAlch / ToolTame` = 0~10 **평평한 숫자**(옛 서버의 keepExtra는 표를 버리고 숫자는 남김). 없으면 +0.
- 강화 한 번(그 직업의 작업대 Range 안, 제작 Lv ≥ 표의 Lv): 매번 골드 + Common + 직업 재료(+1~3 / +4~6 / +7~10 = 대장장이 Jelly·GoblinTooth·KnightCrest, 연금술사 Herb·Glowcap·Bone, 조련사 Herb·OakLog·Petal), **성공할 때만** Extra(+7 KingJelly 1 … +10 ClatterGem 2 + DeepMoonShard 4 + TrialCore 1 — 시도 전에 가지고 있어야 함). 성공률 100/100/90/80/70/60/50/40/35/30%, 매번 같음(보정 X). **실패 = 단계 그대로**(하락·파괴 X). 제작 XP·주간 XP 0. 평균 +0→+10 = 18.15번·골드 109,590.
- **축복 주문서 Enh70B**(Blessed Scroll 70%: 성공 +2, 실패 규칙 Enh70와 같음, 제작으로만, 거래 가능): AS1 제작 **시작 때 한 번** Mixing Kit +N의 확률(+0 0% → +1 0.5% … +10 5%)로 굴려 `Craft.Pend.Bless`에 저장 → 끝날 때 주문서 한 장만 축복으로(망치 +N 추가분은 일반). 끊기거나 다시 들어와도 같은 결과.

## 원격 (개발 1 화면 몫)
- c→s `CraftTool` () — 내 직업 도구 한 번 강화 시도.
- s→c `CraftToolResult` { Role, Tool = 지금 +N, Ok = true | false, Name } — 성공 = "reward" 소리, 실패 = "info" 소리만(글 X, A23-191). 화면이 결과를 보여 줌(글 키 `Config.Craft.Text.ToolUp` "%s +%d!" / `ToolSame` "Not this time. Your %s stays +%d.").
- `CraftInfo`에 `Tool`(지금 +N) 추가. `CraftResult`에 `Blessed = true`(축복 나온 판) 추가 — 글 키 `Config.Craft.Text.Blessed`.
- 강화 비용 미리보기: `Config.Craft.Tools.Steps[target]` + `RoleMats` (서버 `CraftService.ToolCost(role, target)`와 같은 계산).
- 거절 글은 기존 키(NotArtisan·Busy·Far·NeedLevel·NeedMats·NeedGold) + `ToolMax`.

## 시험
`py tools/test_craft.py` — 묶음 'tools'(표·평균·+0→+1 비용·Lv 문·실패 유지·성공 때만 Extra·Extra 없음 거절·+10·거리·골드·진영·원격·축복 4%/6%·Pend.Bless·저장 수리) + 변이 15.
