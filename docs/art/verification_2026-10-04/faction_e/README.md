# 승인 E 진영 선택 적용·실제 클라이언트 검사

## 최신 상태: 새 설명판 승인·게임 적용, 재제작1/6 완료

사용자가 확대 글자 얼룩을 지적하고 모든 구성요소를 한 장씩 새로 그리라고 요청했다. 새 빈 판+실제 Jua 조판 설명판은 **“ㅇㅇㅇ”로 승인받아 게임에 적용**했다. 재제작은 설명판1/6 완료, 카드3장·제목·하단 안내5종은 미완료다. 다음은 빛 카드 개별 생성이다. 원래 사용자 문제의 해결 집계1/6, 스토리 감사0/8은 별도이며 그대로 유지한다.

- 생산 PNG: `art/ui/UIP_FactionPremise_FreshTyped.png` **1024×174**, ID `105024415024705`, Config 키 `FactionPremiseFreshTyped`. 기존9개+이번1개로 성공 업로드 **누적10개·현재 활성6개**다.
- 방식: 실제 Jua TTF를 **출력 해상도에서 래스터 조판**하고 새 GPT 빈 판 원본과 합성한 PNG 한 장이다. Roblox 네이티브 Jua 설정이나 HTML을 게임에 띄우는 방식이 아니다. 생성 원본은 별도 보존했다.
- 최신 PC `fresh_desktop.json/.jpeg`: **793×451**,6개 ready, 카드 캔버스243px 동일, 버튼47.4px. 최신 폰 `fresh_phone.json/.jpeg`: **749×361**,6개 ready, 카드261.75px, 버튼48px, 전체 페이지 세로 스크롤. `fresh_phone_cards.jpeg`에서 스크롤 후 전체 카드를 확인했다.
- `fresh_device_restored.json`: 기기 에뮬레이션 **default 복원**. 승인·업로드 기록은 `fresh_premise_blank_type.json`, `fresh_premise_upload.json`을 따른다.

## 설명판 거절·조판 이력

- 기존 그림 참조 독립 생성본 `UI_FactionPremise_E_Standalone.png`: 사용자 거절, 업로드0. `user_report_text_mottling.png`와 `standalone_premise.json`에 기록.
- 참조 이미지 없이 새로 생성한 `UI_FactionPremise_E_Fresh.png`: 4배 확대에서 글자 내부 색 얼룩·밝은 테두리가 남아 로컬 검사 불합격. 부분 보정하지 않았으며 업로드0.
- 새 빈 판 `UI_FactionPremise_E_BlankFresh.png`: GPT 신규 생성, 입력 이미지0, 생성 PNG 원본 바이트 보존. 글자는 별도 HTML의 Jua Regular 실제 글꼴로 조판했다. 새 판과 글꼴의 합성 시안은 `fresh_premise_typed.png`, 밝고 어두운 배경은 `fresh_premise_typed_light_dark.png`, 6배 최근접 확대는 `fresh_premise_typed_600pct.png`다. 이 판·글꼴을 승인받은 뒤 위의1024×174 생산 PNG를 적용했다.
- `fresh_premise_blank_type.json`: 가장자리1px를 제외한 실제 글자 내부33,026픽셀은 RGB(71,32,8) 한 색이다. 같은 영역에서 생성 글자 내부는5,000개 색이었다. 이 검사는 내부 색 균일성이지 Roblox 로딩·선명도 합격이 아니다.
- Jua는 [Google Fonts 공식 파일](https://github.com/google/fonts/tree/main/ofl/jua)을 원본과 OFL 라이선스 그대로 `art/fonts/jua/`에 보존했다. 검증된 Roblox 네이티브 Jua FontFamily는 없으며 실제 적용은 위의 고정 글씨 PNG다. HTML 시안을 네이티브 글꼴 지원 증거로 쓰지 않는다.
- `tools/render_faction_type_preview.cjs`는 로컬 HTML/글꼴 렌더와 출력 PNG 준비에 사용했다. GPT 그림 원본은 보존한다. 새 설명판 Roblox 업로드1개, Tripo0cr.

## 설명판 교체 전 E 구현의 기능 검사 이력

설명판 교체 전 결과는 `desktop_fixed.jpeg`, `phone_cards.jpeg`, `phone_fixed.jpeg`와 `metrics.json`이다. 이 파일의 PC256.8px·업로드9개 수치는 당시 값이며 최신은 위의 `fresh_*` 증거다. 이름에 final이 들어간 파일도 전체 구성요소의 최종 사용자 승인을 뜻하지 않는다.

- 사용자 승인: “이걸로 적용하자.” 승인 E의 RGB·둥근 한글을 사용했다. 투명 GPT 생성물은 알파 가이드만 사용했다.
- 카드 3장: 동일 380×636 캔버스, 보이는 높이620/620/619px. 원본 비율을 보존했고 세로로 늘이지 않았다.
- 첫 누끼는 잘못됐다. 사용자 `user_report_alpha.png`와 같이 설명판 금테가 잘리고 옆 장식이 남았다. 패널3장의 원본 외곽 알파를 다시 만들고, 마지막 연결 성분 검사·푸른 배경 가장자리 제거 후 재업로드했다. 글씨나 장식 RGB를 새로 그리지 않았다.
- PC793×451에서 카드 전체가 한 화면에 표시된다. 이미지6/6 로드 성공, 카드 캔버스 높이256.8px로 동일, 실제 장식 높이 차이0.41px 이내. 버튼 최소47.4px.
- iPhone17 Pro 에뮬레이션750×362에서 전체 내용이 세로 스크롤된다. 카드 줄 자체의 세로 스크롤/작은 잘림창은 제거했다. 세 카드 전체가 한 스크롤 위치에 들어오며 버튼48px. 하단 안내도 스크롤 후 승인 글꼴로 로드된다.
- 로딩 전 Visible=false 때문에 IsLoaded가 오지 않는 순환을 수정했다. 거의 투명한 상태로 로드한 뒤 성공한 그림만 표시한다. 스크롤 후 로드 신호 누락은 기존0.5초 갱신으로 보완했다. 오류·문구 불일치 시 읽을 수 있는 기존 텍스트를 유지한다.
- 열린 동안 월드 이름표·간판·채팅·터치 조작을 숨기고 닫으면 원래 true/false 상태를 복원한다. Roblox 메뉴는 유지한다.

## 실제 게임 흐름

`choice_play.json`: 진영 선택→직업 선택→창 닫힘, 카메라 대상, 배경 true/false 복원, 진영 중복 선택 거부 확인.

`travel_play.json`, `hunt_play.json`, `hunt_finish_play.json`: 일반 Travel 요청으로 초원 도착, Humanoid 이동·Swing 요청으로6마리 처치. 첫1마리가 안내 단계를 넘기고 뒤5마리가 첫 퀘스트로 집계됐다. 카메라 표본24/24 정상.

`reward_play.json`: 120골드1회, 중복 요청0골드, 기존 다음 무기 구매150골드·티어1→2. 이 검사는 새 무기 강화 구현이 아니다. 사용자는 이후 **기본 장비는 대장간, 현재 무기 강화는 몬스터 드롭 주문서, 희귀 장비는 드롭·고난도 퀘스트·보스 재료**로 바꾸라고 지시했다. 새 계약은 별도 문서에 있으며 이 UI 라운드에 구현 완료로 포함하지 않는다.

## 검증 한계와 보존

- 화면 제어 없이 MCP의 클라이언트 실행을 사용했다. 실제 마우스·키보드·터치 감각까지 합격으로 보고하지 않는다.
- MCP 캡처의3D 배경은 회색/흰색이므로 이번 캡처는 UI 검증이다. 사용자가 준 오류 사진에서는3D 배경이 정상 렌더된다. 캐릭터/맵 외형 합격이 아니다.
- Studio DataStore 비활성으로 메모리 데이터만 사용했다. 재접속 저장 검증이 아니다.
- `place_update.json`: build/place의 Config·FactionPicker Source만 바꿨고 나머지4501개 인스턴스 구조·520개 에셋 필드는 보존했다.
- 최초6장, 테두리 정리3장, 새 조판 설명판1장으로 나누어 성공 업로드 누적10개다. 중간 로컬 서버 중단 오류는 새ID가 반환되지 않았으며 다시 연 뒤3장이 성공했다. 현재6개 활성, 사용 Tripo 크레딧0.
