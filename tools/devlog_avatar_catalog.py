"""
촬영용 아바타 재료 찾기 (촬영 편집, 2026-10-07): Roblox 카탈로그에서 Roblox가 만든 무료(가격 0) 아이템만 모은다.

  py tools/devlog_avatar_catalog.py            -> build/devlog/avatar/catalog_free_roblox.json (+ 표 출력)

공개 검색 API(로그인 없음, GET만): catalog.roblox.com/v1/search/items/details
조건: CreatorName=Roblox, MaxPrice=0. 이름에 로고·브랜드·유명 캐릭터가 들어간 것은 표에 '제외'로 표시한다.
"""

import json
import os
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "devlog", "avatar", "catalog_free_roblox.json")
API = "https://catalog.roblox.com/v1/search/items/details"
ASSET_TYPES = {2: "TShirt", 8: "Hat", 11: "Shirt", 12: "Pants", 18: "Face", 41: "Hair", 42: "FaceAcc", 43: "Neck", 44: "Shoulder",
               45: "Front", 46: "Back", 47: "Waist", 64: "TShirtLC", 65: "ShirtLC", 66: "PantsLC", 67: "JacketLC", 68: "SweaterLC",
               69: "ShortsLC", 70: "LShoe", 71: "RShoe", 72: "DressSkirtLC", 79: "DynamicHead"}
# a name with these words is a logo / brand / famous-character item: never used
BLOCK = ["roblox", "builderman", "logo", "brand", "rthro", "sponsor", "event", "nike", "gucci", "marvel", "disney", "spongebob",
         "sonic", "star wars", "nfl", "nba", "fifa", "twenty one pilots", "ready player", "ice cube", "nyx", "vans"]
QUERIES = [  # (label, params) — Category 3 = clothing, 11 = accessories, 4 = body parts
    ("clothing", {"Category": 3}),
    ("accessories", {"Category": 11}),
    ("heads", {"Category": 1, "Keyword": "head"}),
    ("hair", {"Category": 11, "Keyword": "hair"}),
    ("backpack", {"Category": 11, "Keyword": "backpack"}),
    ("bag", {"Category": 11, "Keyword": "bag"}),
    ("jacket", {"Category": 3, "Keyword": "jacket"}),
    ("hoodie", {"Category": 3, "Keyword": "hoodie"}),
    ("sweater", {"Category": 3, "Keyword": "sweater"}),
    ("pants", {"Category": 3, "Keyword": "pants"}),
    ("shoes", {"Category": 3, "Keyword": "shoes"}),
    ("face", {"Category": 1, "Keyword": "face"}),
    ("bundles", {"Category": 1, "Keyword": "bundle"}),
]


def get(params):
    q = dict(params, CreatorName="Roblox", MaxPrice=0, Limit=30, SortType=0)
    url = API + "?" + urllib.parse.urlencode(q)
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=25) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # 429 / transient: back off
            time.sleep(2 + attempt * 3)
            err = e
    raise RuntimeError("catalog search failed: %s (%s)" % (url, err))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    items = {}
    for label, params in QUERIES:
        cursor, pages = None, 0
        while pages < 6:
            p = dict(params)
            if cursor:
                p["Cursor"] = cursor
            try:
                js = get(p)
            except RuntimeError as e:
                print("skip", label, e)
                break
            for it in js.get("data", []):
                if it.get("price", 0) not in (0, None) or (it.get("creatorName") or "").lower() != "roblox":
                    continue
                key = "%s:%s" % (it.get("itemType"), it.get("id"))
                if key in items:
                    continue
                name = it.get("name", "")
                items[key] = {
                    "id": it.get("id"), "itemType": it.get("itemType"), "assetType": it.get("assetType"),
                    "type": ASSET_TYPES.get(it.get("assetType"), "Bundle" if it.get("itemType") == "Bundle" else str(it.get("assetType"))),
                    "name": name, "description": (it.get("description") or "")[:160], "price": it.get("price"),
                    "bundled": [b.get("id") for b in it.get("bundledItems", []) if b.get("type") == "Asset"],
                    "blocked": any(w in name.lower() for w in BLOCK), "found_by": label,
                }
            cursor = js.get("nextPageCursor")
            pages += 1
            time.sleep(0.8)
            if not cursor:
                break
    rows = sorted(items.values(), key=lambda r: (r["type"], r["name"]))
    json.dump(rows, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for r in rows:
        print("%-11s %12s %s %s" % (r["type"], r["id"], "X" if r["blocked"] else " ", r["name"]))
    print("total", len(rows), "->", OUT)


if __name__ == "__main__":
    main()
