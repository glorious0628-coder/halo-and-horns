# glorious.ai.kr에 올리는 방법 (2026-10-08, 홈페이지 1)

올릴 것: `docs/website/site/` **폴더 안의 내용 전부** (index.html, img/ 7장, fonts/ 글꼴 3개와 라이선스 3개, 합계 약 1.3MB).
`index.html`이 사이트 맨 위(https://glorious.ai.kr/)에 오도록 올리면 됩니다. 외부 연결(CDN·구글 글꼴)이 없어서 파일만 있으면 그대로 보입니다.

다시 만들기: `docs/website/index.html`(미리보기 원본)을 고친 뒤
`py docs/website/build_site.py <글꼴 폴더>` → `site/`가 새로 만들어짐. (글꼴 폴더 = *-latin.woff2 3개 + OFL-*.txt 3개, 지금 `site/fonts/`에도 있음)

## 어디에 올리나 (사용자가 쓰는 곳 하나만 고르면 됨)
- **가비아·카페24 웹호스팅:** 호스팅 관리 화면의 웹 FTP(또는 FileZilla)로 `site/` 안의 파일을 `www` 또는 `public_html` 폴더에 그대로 올리기. 기존 index 파일이 있으면 바꿔 넣기.
- **GitHub Pages (무료):** 공개 저장소 하나 만들기 → `site/` 안의 파일 올리기 → Settings › Pages에서 main 브랜치 켜기 → Custom domain에 `glorious.ai.kr` → 도메인 회사 DNS에 GitHub이 알려 주는 A 레코드 4개 넣기.
- **Cloudflare Pages (무료):** Workers & Pages › Create › Pages › "Upload assets"에 `site/` 폴더 끌어 놓기 → Custom domains에 `glorious.ai.kr` 추가 → 안내대로 DNS 설정.

로그인·결제·DNS 설정은 사용자가 직접 합니다(세션은 대신하지 않음).

## 올린 뒤 확인
1. https://glorious.ai.kr/ 이 열리고 사진 7장과 글꼴이 보이는지, 위쪽 EN/KO가 바뀌는지.
2. **jian@glorious.ai.kr로 메일이 실제로 받아지는지** (Claude Startups는 회사 메일 도메인 = 홈페이지 도메인이어야 함).
3. 폰에서도 한 번 열어 보기.

## Claude Startups 신청 체크리스트 (인계 §6-4)
- Claude Console 계정 (platform.claude.com) → https://platform.claude.com/offers/startups-application
- 회사 메일: jian@glorious.ai.kr / 사이트: https://glorious.ai.kr
- 짧은 설명 예: "Glorious Studio is a one-person game studio in South Korea. We are building Halo & Horns, a Roblox action RPG, with a team of nine Claude Code sessions directed by the founder. Beta opens 31 Oct 2026."
- 설립 시점, 사업자등록 여부 (신청할 때 사용자에게 물어볼 것)
