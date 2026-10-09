# 홈페이지 1 — 최종 인계 (2026-10-08, 세션 종료 전)
> 2026-10-09 검수: '홈페이지 1' 세션은 지워졌다. 사이트를 고칠 때는 검수가 맡기는 세션이 이 문서의 '고치는 방법'(`docs/website/index.html` → `build_site.py`)대로 한다.

## 지금 상태: 사이트 공개됨 ✅
- **https://glorious.ai.kr** 열림(2026-10-08 확인).
  - http → https로 넘어감(Enforce HTTPS 켜짐).
  - www.glorious.ai.kr → glorious.ai.kr로 넘어감.
  - 올라간 index.html이 `docs/website/site/index.html`과 같음: ~~push a08a7ac(md5 2b295210…)~~ → 10/09 설립·사업자등록번호를 넣은 7f92fce3(md5 8d16b7be…, 2026-10-09 검수가 사이트와 대조).
  - og.jpg와 글꼴 응답 200, 깨진 그림 0개, 글꼴 3종 loaded.
- 호스팅: GitHub Pages(공개 저장소, 계정 glorious0628-coder, 검수가 만듦). 게임 저장소는 비공개 그대로.
- 가비아 DNS(사용자가 입력, 8.8.8.8로 확인):
  - @ A 185.199.108.153 / .109.153 / .110.153 / .111.153
  - www CNAME → glorious0628-coder.github.io
  - **MX = smtp.google.com(구글 메일) 그대로** → 건드리지 말 것.
- 미리보기 artifact(비공개): https://claude.ai/artifact/LH4VHoH9n6KB4q6eujfw2S (v7 = 10/08 사이트와 같은 내용; 10/09 7f92fce3 줄을 넣어 다시 올렸는지는 확인 안 됨).

## 파일
| 파일 | 뜻 |
|---|---|
| `docs/website/index.html` | **원본**(artifact용, doctype 없음, 구글 글꼴 링크). 고칠 때는 이것만 고친다. 맨 위 주석에 숫자를 센 기준(origin/main 5cd9d282, 10/08 14:21)과 배지 출처가 있음 |
| `docs/website/build_site.py` | 원본 → `site/` 생성: 완전한 문서, 로컬 글꼴, CNAME, og/twitter 태그, 왕관 파비콘, mailto 버튼 |
| `docs/website/site/` | 공개 저장소에 그대로 올리는 내용(21개 파일, 약 1.8MB, 외부 연결 0) |
| `docs/website/img/` | 사진 7장(인계 §4) + `og.jpg`(1200×630) + `deco/` 배지 5장(art/ui 승인 Firefly 배지를 512→192px로 줄임) |
| `docs/website/UPLOAD_KO.md` | GitHub Pages + 가비아 DNS 안내, 신청 체크리스트 |
| `docs/website/review_2026-10-08/` | v5 스크린샷 4장(1366/390 × 라이트/다크), 로컬 전용(push 안 함) |
| `docs/website/README_handoff_2026-10-08.md`, `content_2026-10-08.json` | 처음 인계(조사·사실·사진 근거) |

## 고치는 방법
1. `docs/website/index.html`을 고친다(영어/한국어는 요소마다 `lang="en"`/`lang="ko"` 쌍).
2. `py docs/website/build_site.py <글꼴 폴더>`를 실행한다.
   - 글꼴 폴더 = `*-latin.woff2` 3개 + `OFL-*.txt` 3개. `docs/website/site/fonts/`를 그대로 쓰면 된다.
3. 헤드리스 Edge로 1366·390에서 확인한다.
   - iframe 탐침으로 가로 넘침 0, 깨진 그림 0, 글꼴 loaded인지 본다.
   - 헤드리스 창은 최소 폭이 약 500이라, 390은 iframe 안에서 재야 한다.
4. `py tools/push_paths.py -m "…" <경로들>`로 올린다.
   - 폴더 경로는 안 펼쳐지니, 파일을 하나씩 넘긴다.
5. 공개 저장소에 `site/` 내용을 다시 올린다(검수 담당).

## 지킨 규칙(다음 세션도)
- 게임은 아직 공개 전: live·players·매출·수상·지어낸 숫자 금지.
  - 계속 늘어나는 숫자는 내림해서 "1,000+"처럼 쓴다.
  - 효과음은 "57 sound effects made".
- 'Lost Lunchbox!'는 Config에서 Points = 0이다.
  - 그래서 저울 데모에는 Points = 1인 실제 서브 퀘스트 선택 3개만 쓴다.
- 스킬: ZEnabled·XEnabled = false다.
  - "First skill at Lv5"만 Built에 둔다. Lv15·25 스킬은 In progress.
- 빛살 무늬 금지. 휴대폰에서는 지도를 배경으로 확대하지 않는다(교차로가 크게 잘림).
- 'rob' 대신 'play the villain'(아이 게임·심사용).

## 남은 일
- shot1(10/06 호박왕, 이름표 겹침·배너 잘림)을 메인 Studio 새 Play 사진으로 바꾸기.
  - ~~개발 1이~~ 메인 반영 1이(메인 Studio Play 사진 담당, `docs/handoff/role_prompts/01_mainapply.md`) 사진을 주면 `img/shot1.jpg`를 교체하고 build → push → 저장소를 갱신한다.
- 사이트의 세션 수 9(10/08 14:21 기준, "nine Claude Code sessions")는 지금 10개다(메인 반영 1 추가, `docs/handoff/role_prompts/README.md`). 역할 표의 '게임성 개발 1 = 메인 Studio'도 지금은 메인 반영 1 몫 → 고칠지는 검수가 정한다(2026-10-09 검수 확인).
- "Days until the beta" 카드는 베타 뒤 자동으로 숨는다.
  - 베타 뒤에는 "Not public yet"과 "nothing has been sold" 문구를 고쳐야 한다(사실이 바뀜).
- Claude Startups 신청은 사용자가 직접 한다.
  - 필요한 것: Console 계정, jian@glorious.ai.kr, https://glorious.ai.kr, 짧은 설명(UPLOAD_KO.md에 예시).
  - ~~설립일·사업자등록 여부는 신청할 때 사용자에게 묻는다.~~ → 사용자가 10/09에 알려 줘 사이트 아래쪽에 넣었다(설립 2025년 12월 + 사업자등록번호, 7f92fce3; `docs/handoff/review_handoff_2026-10-09.md` §5).
  - 신청 전에 jian@ 메일이 실제로 받아지는지 확인한다.
