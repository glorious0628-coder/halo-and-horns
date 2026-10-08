"""Build docs/website/site/ (the self-contained glorious.ai.kr upload) from docs/website/index.html (the artifact page).

The artifact page has no doctype/head (the artifact host adds them) and loads Google Fonts. The site version
gets a full document, local latin woff2 fonts (fonts/, OFL), system fonts for Korean, and a mailto button.
Run: py docs/website/build_site.py <font_dir>   (font_dir holds the three *-latin.woff2 files and OFL-*.txt)
"""
import pathlib, re, shutil, sys

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE / "index.html"
OUT = HERE / "site"
FONTS = ["Fredoka-latin.woff2", "Figtree-latin.woff2", "JetBrainsMono-latin.woff2"]
OFL = ["OFL-fredoka.txt", "OFL-figtree.txt", "OFL-jetbrainsmono.txt"]
IMGS = ["hero.jpg", "shot1.jpg", "shot2.jpg", "shot3.png", "shot4.png", "shot5.png", "shot6.jpg", "og.jpg",
        "deco/halo.png", "deco/horns.png", "deco/lunchbox.png", "deco/choseside.png", "deco/firstslime.png"]

FONT_FACES = """@font-face { font-family: "Fredoka"; font-style: normal; font-weight: 500 700; font-display: swap; src: url("fonts/Fredoka-latin.woff2") format("woff2"); }
@font-face { font-family: "Figtree"; font-style: normal; font-weight: 400 700; font-display: swap; src: url("fonts/Figtree-latin.woff2") format("woff2"); }
@font-face { font-family: "JetBrains Mono"; font-style: normal; font-weight: 400 500; font-display: swap; src: url("fonts/JetBrainsMono-latin.woff2") format("woff2"); }
"""

FAVICON = ("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='-1 0 33 30'%3E"
           "%3Cpath d='M4 27 L4 8.5 L10.2 16 L16 7 L14.6 13 L17.2 18 L15 22.5 L16.4 27 Z' fill='%23E8B23A'/%3E"
           "%3Ccircle cx='4' cy='7.4' r='2.3' fill='%23E8B23A'/%3E"
           "%3Cpath d='M17.2 7 L22 16 L28 8.5 L28 27 L17.6 27 L16.2 22.5 L18.4 18 L15.8 13 Z' fill='%23C8364A'/%3E"
           "%3Cpath d='M26.3 10.5 C25.8 6.8 27.1 4 30.2 2.4 C29.2 5 29.4 7.6 30.1 10.2 Z' fill='%23C8364A'/%3E%3C/svg%3E")


def main():
    font_dir = pathlib.Path(sys.argv[1])
    s = SRC.read_text(encoding="utf-8")

    title = re.search(r"<title>.*?</title>\n", s).group(0)
    desc = re.search(r'<meta name="description"[^>]*>\n', s).group(0)
    s = s.replace(title, "", 1).replace(desc, "", 1)
    # drop the internal counting note and the Google Fonts links
    s = re.sub(r"<!-- Numbers counted.*?-->\n", "", s, count=1, flags=re.S)
    s = re.sub(r'<link rel="preconnect"[^>]*>\n', "", s)
    s = re.sub(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com[^>]*>\n', "", s)
    assert "googleapis" not in s and "gstatic" not in s
    # Korean falls back to system fonts; Noto Sans KR stays in the stack only if the visitor has it installed
    s = s.replace("<style>\n", "<style>\n" + FONT_FACES, 1)
    # the artifact skeleton gave a reset with safe-area padding; keep that behaviour here
    s = s.replace("* { box-sizing: border-box; }",
                  "* { box-sizing: border-box; }\n:root { padding-top: env(safe-area-inset-top, 0px); padding-bottom: env(safe-area-inset-bottom, 0px); }\n[hidden] { display: none !important; }", 1)

    # real site: a mailto link works, so offer it next to the copy button
    copy_btn = '<button type="button" class="btn" id="copy-email"><span lang="en">Copy address</span><span lang="ko">주소 복사</span></button>'
    assert s.count(copy_btn) == 1
    s = s.replace(copy_btn, copy_btn + '\n        <a class="btn ghost" href="mailto:jian@glorious.ai.kr"><span lang="en">Open mail app</span><span lang="ko">메일 앱 열기</span></a>')

    head = ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
            + title + desc +
            "<meta name=\"color-scheme\" content=\"light dark\">\n"
            "<meta property=\"og:title\" content=\"Glorious Studio\">\n"
            "<meta property=\"og:description\" content=\"A game studio in South Korea making Halo &amp; Horns, a Roblox action RPG where every choice tilts you toward angel or devil.\">\n"
            "<meta property=\"og:type\" content=\"website\">\n"
            "<meta property=\"og:url\" content=\"https://glorious.ai.kr/\">\n"
            "<meta property=\"og:image\" content=\"https://glorious.ai.kr/img/og.jpg\">\n"
            "<meta property=\"og:image:width\" content=\"1200\">\n<meta property=\"og:image:height\" content=\"630\">\n"
            "<meta name=\"twitter:card\" content=\"summary_large_image\">\n"
            "<link rel=\"icon\" href=\"" + FAVICON + "\">\n")
    style_end = s.index("</style>") + len("</style>\n")
    page = head + s[:style_end] + "</head>\n<body>\n" + s[style_end:] + "</body>\n</html>\n"

    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "img" / "deco").mkdir(parents=True)
    (OUT / "fonts").mkdir()
    (OUT / "index.html").write_text(page, encoding="utf-8", newline="\n")
    for f in IMGS:
        shutil.copy2(HERE / "img" / f, OUT / "img" / f)
    for f in FONTS + OFL:
        shutil.copy2(font_dir / f, OUT / "fonts" / f)
    ext = re.findall(r'(?:src|href)="(https?:[^"]+)"', page)
    print("written", OUT, "external refs:", [u for u in ext if "glorious.ai.kr" not in u])


if __name__ == "__main__":
    main()
