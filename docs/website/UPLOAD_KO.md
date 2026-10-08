# glorious.ai.kr 올리기 — GitHub Pages(무료) + 가비아 DNS (2026-10-08, 홈페이지 1)

정한 것(사용자, 검수 경유): 무료 **GitHub Pages**. 도메인은 **가비아**. 메일은 손대지 않음.
로그인·DNS 입력은 사용자가 직접 합니다. 세션은 대신하지 않습니다.

## 순서
1. **(검수)** 새 **공개** 저장소를 만들고 `docs/website/site/` 안의 파일만 올림. 게임 저장소는 비공개 그대로.
   - 올라가는 것: `index.html`, `CNAME`(내용 `glorious.ai.kr`), `img/`(사진 7장 + 링크 미리보기 `og.jpg` + `deco/` 배지 5장), `fonts/`(글꼴 3개 + OFL 라이선스 3개). 합계 약 1.8MB, 외부 연결 없음.
   - 공개는 사용자가 최종 디자인을 본 뒤에.
2. **(사용자, GitHub)** 그 저장소 › **Settings › Pages**
   - Source = `Deploy from a branch`, 브랜치 `main`, 폴더 `/ (root)` → Save
   - **Custom domain**에 `glorious.ai.kr`이 들어 있는지 확인(없으면 넣고 Save)
   - DNS보다 이것을 **먼저** 해 두는 게 안전합니다(남이 내 도메인을 가로채지 못하게).
3. **(사용자, 가비아)** My가비아 › 서비스 관리 › 도메인 `glorious.ai.kr` › **DNS 관리**(DNS 설정) › 레코드 수정/추가
   - 아래 표의 6줄을 넣고 저장.
4. 10분~몇 시간 기다리면 https://glorious.ai.kr 이 열립니다(최대 24시간).
5. **(사용자, GitHub)** Settings › Pages로 돌아가 **Enforce HTTPS**에 체크.
   - 체크 칸이 회색이면 아직 인증서를 만드는 중이니, 조금 뒤에 다시 봅니다(최대 24시간).

## 가비아 DNS에 넣을 것 (GitHub 공식 문서 값, 2026-10-08 확인)
| 타입 | 호스트 | 값 |
|---|---|---|
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |
| CNAME | www | glorious0628-coder.github.io |

- TTL은 기본값 그대로 둡니다.
- CNAME 값 끝에 점(.)을 붙이라는 안내가 화면에 보이면 붙입니다.
- 저장소 이름은 값에 넣지 않습니다.
- (선택) IPv6도 쓰려면 AAAA 레코드를 호스트 `@`로 4개 넣습니다: `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`.
- 출처: docs.github.com › Pages › "Managing a custom domain for your GitHub Pages site"

## ⚠ 꼭 지킬 것
- **MX 레코드와 TXT 레코드(메일)는 지우거나 바꾸지 마세요.** 바꾸면 jian@glorious.ai.kr 메일이 안 받아집니다.
- 이미 `@`의 **A 레코드**나 `www` 레코드가 있으면(가비아 기본 주차 페이지 등), **그 줄만** 지우고 위 값으로 바꿉니다.
- `*` (와일드카드) 레코드는 만들지 않습니다(GitHub 권고).
- DNS 관리 화면에 "가비아 네임서버를 쓰지 않음" 같은 안내가 나오면, 멈추고 검수에게 알려 주세요(다른 곳에서 넣어야 함).

## 다 된 뒤 확인
1. https://glorious.ai.kr 과 https://www.glorious.ai.kr 둘 다 열리는지(www는 자동으로 앞 주소로 넘어감).
2. 주소창에 자물쇠(https)가 보이는지.
3. jian@glorious.ai.kr로 메일이 실제로 받아지는지.
   - Claude Startups 신청 조건이 "회사 메일 도메인 = 홈페이지 도메인"이라서입니다.
4. 폰에서도 한 번 열어 보고, 카톡에 주소를 보내 미리보기 그림(지도 + 깨진 왕관)이 뜨는지.

## 파일 다시 만들기
`docs/website/index.html`(미리보기 원본)을 고친 뒤, 아래 명령을 실행합니다.

```
py docs/website/build_site.py <글꼴 폴더>
```

- `site/`를 새로 만듭니다(CNAME 포함).
- 글꼴 폴더 = `*-latin.woff2` 3개 + `OFL-*.txt` 3개(`site/fonts/`에 있는 것과 같음).

## Claude Startups 신청 체크리스트 (인계 §6-4)
- Claude Console 계정(platform.claude.com) → https://platform.claude.com/offers/startups-application
- 회사 메일: jian@glorious.ai.kr / 사이트: https://glorious.ai.kr
- 짧은 설명 예: "Glorious Studio is a one-person game studio in South Korea. We are building Halo & Horns, a Roblox action RPG, with a team of nine Claude Code sessions directed by the founder. Beta opens 31 Oct 2026."
- 설립 시점, 사업자등록 여부: 신청할 때 사용자에게 묻기.
