# HaloArcherM R2 — G2 무료 기준선

상태: **사용자 G2 선택 대기**, 유료 호출0/사용0cr/Roblox 업로드0.
기준 그림 SHA256: `649ce86f007b2762e70bb1fc8d494351520de4f024d1a876c9225b94e6160b0a`.

## 재현

저장소 루트에서 실행한다. API 키는 필요하지 않다.

```powershell
py tools/fidelity_check.py --source-setup
& 'C:/Users/glori/AppData/Local/Temp/claude/blender-run/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/r2_build_halo.py
& 'C:/Users/glori/AppData/Local/Temp/claude/blender-run/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/r2_render_fidelity.py
py tools/fidelity_check.py
```

- `B0/build.json`, `B0H/build.json`은 원본/결과 SHA와 좌표·면 수·재질 기록이다.
- GLB는 선택 전이므로 깃 제외 `art/models/costume/raw/r2/B0/`, `B0H/`에 저장한다. 원본 R1 GLB에서 무료 재생성할 수 있다.
- `eval/B0H_sheet.png`: 원화, 정면 flat, 정면 lit, 3/4 lit, 옆, 뒤.
- 각 후보 `eval/`에는 4방향 flat, 귀±60도, 손 확대, 실루엣 겹침, 해부학 지점, 옆 헤일로 측정, GLB 독립 재질 검사와 렌더 조건이 있다.
- `eval/metrics.json`의 null은 미검증/미해당이다. 통과로 집계하지 않는다. `scoreboard.png`도 같은 결과다.
- `records/`에는 읽기 전용 REST GET 결과와 과거95cr 장부 보정의 근거가 있다. R1 CLI payload의 pbr:true/JPEG/seed 누락은 고쳐 쓴 기록이 아니라 그대로 남긴 과거 증거다.

## 검토할 한계

1. T1 정렬은 아호게71행–발바닥1203행 높이와 몸 중심620열만 이용했다. 손 폭을 맞춰 실루엣을 보정하지 않았다. 0/90/180/270도 중 최대 IoU인 +X를 정면으로 선택했다.
2. 턱은 가운데60열의 피부가30픽셀 이상 남는 마지막 행으로 측정한다. 피부 HSV/RGB 조건과430–485행 검색 범위를 소스에 공개했다. 초기 넓은 피부 백분위가 금색 브로치를 포함하는 문제를 제외했다. 원화도 동일한 함수로 다시 측정했다.
3. 수평 원형 링은 정면 정사영에서 선처럼 보인다. 원화의 타원은 원근이 들어간 표현이다. 원형 깊이 가정과 원화 실측 두께16px를 기록했으며 새 장식을 추가하지 않았다.
4. T7은 실제 옆 렌더 금색 기둥의 중심선으로 측정했다. B0 약10.33도, B0H 약0.35도다. B0H 생성 평면 자체는0도다.
5. T8은 결과 GLB의 재질과 MR B채널을 다시 읽었다. B0/B0H 모든 재질에서 metallicFactor0이 명시되어 금색 외 텍셀도 실효 metallic0이다. normalTexture는 지시된 B0 범위대로 보존했다.
6. **T10 불합격:** 지정 studio.exr/strength1/Standard/EEVEE에서 금발 평균 채도가 약0.142다. flat 색상 통과를 lit 통과로 대신하지 않는다. 조명 아래 남은 밝기·채도 문제를 숨기지 않는다.
7. **T11 미완료:** 현재 정적 GLB의 Body17,421+Halo784면은 각각20k 미만이지만 실제 선택 리그의15부위 변환 검사는 아직이다. G2에서 B0H 선택 후 기존rig96aa4858을 무료 재사용하여 H를 Head100%로 적용할 때 수행한다.
8. **얼굴200텍셀 미완료:** G2 몸체 기준선에는 전용 얼굴이 없다. 기존8K 전체 아틀라스를 Roblox용으로 줄여 쓰는 상태를 최종 승인하지 않는다.
9. 귀·손·등은 이미지로 사람이 판정한다. T13은 유료C1/C2와 승인 입력뷰가 아직 없어서 해당하지 않는다.

다음 순서는 사용자 G2 답변 → 입력뷰 및G1 승인 → 후보 생성 및G3 선택이다. 답변을 대신 결정하지 않는다.
