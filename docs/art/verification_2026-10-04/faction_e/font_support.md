# 승인 E 한글 글씨 지원 조사

> 기록용(2026-10-09 검수): 2026-10-04 조사 기록이다. 그 뒤 게임 글은 영어만(SPEC A23-48, 글꼴 Denk One + Montserrat — A23-63)이고 E 카드는 꺼졌다. 한국어는 별도 게임이 아니라 같은 게임 안의 한국어 모드로 빛 마을 뒤에 넣는다(A23-111, A23-89의 '따로 낸다'를 대체).

2026-10-04. 읽기 전용 조사이며 게임 코드·폰트 파일·PNG를 변경하지 않았다. Studio 호출·폰트 다운로드·유료 호출 0. 원자료와 SHA는 [font_support.json](font_support.json)에 저장했다.

| 후보 | Google 공식 메타데이터 | Roblox 공개 FontFamily 검색 |
|---|---|---|
| Jua·주아 | Korean 포함, 400 | `Jua`: HTTP 200, 0건 |
| Gowun Dodum | Korean 포함, 400 | `Gowun`: HTTP 200, 0건 |
| Gaegu | Korean 포함, 300·400·700 | `Gaegu`: HTTP 200, 0건 |

- 같은 API의 대조 검색은 `Nanum` 1건, `Noto` 6건이었다. 실제 공식 에셋은 Nanum Gothic `12187361718`, Noto Sans `12187370747`로 확인했다. 세 후보의 사용 가능한 Roblox ID는 찾지 못했다. 비공개·미래 에셋까지 없다는 뜻은 아니다.
- 설치된 Roblox 두 버전의 `content/fonts/families`는 각각 **43개**이며 세 후보 이름이 없다.
- 설치된 **FredokaOne-Regular.ttf·Nunito-Regular.ttf**의 Unicode cmap을 읽었다. 한글 음절 U+AC00–U+D7A3과 겹치는 범위는 각각 **0개**다. 둥근 영문 폰트로 바꿔도 해당 폰트의 둥근 한글이 표시된다고 보장할 수 없다. 다른 굵기 파일 전체나 Roblox의 실제 대체 글꼴 렌더를 검사한 것은 아니다.
- Roblox 공식 문서는 외부 폰트 가져오기를 지원하지 않는다고 명시한다. `Font.fromName()`도 로컬 font-family 경로를 만들며 Google Fonts를 가져오지 않는다. Font 객체 생성·글자 크기 측정 성공만으로 특정 한글 글꼴 로드 성공을 판정하지 않는다. [에셋 문서](https://create.roblox.com/docs/projects/assets), [Font 문서](https://create.roblox.com/docs/reference/engine/datatypes/Font).

**권장 구현:** 승인 E의 고정 제목·진영명·버튼 글자는 원본 RGB를 보존한 E 전용 이미지로 연결한다. 동적 값·문구 변경·이미지 로드 실패에는 실제 글자를 표시한다. 기존 C 스타일 PNG를 일괄 다시 켜지 않는다. 이미지 로드와 현재 문구 일치를 확인한 뒤에만 대체 글자를 숨긴다.

**언어 처리:** 언어와 현재 문구가 일치하는 승인 이미지가 있을 때만 사용한다. 영어 이미지가 없으면 번역된 실제 글자를 유지하고, 영어 이미지 제작은 기존 GPT 시안·사용자 선택 절차를 따른다.

Google 공식 근거: [Jua](https://raw.githubusercontent.com/google/fonts/main/ofl/jua/METADATA.pb), [Gowun Dodum](https://raw.githubusercontent.com/google/fonts/main/ofl/gowundodum/METADATA.pb), [Gaegu](https://raw.githubusercontent.com/google/fonts/main/ofl/gaegu/METADATA.pb). 파일 내용의 한국어 지원과 Roblox에서의 사용 가능성은 서로 다른 확인 항목이다.
