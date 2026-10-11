import re, sys, os, collections
import xml.etree.ElementTree as ET

path = sys.argv[1]
src_root = sys.argv[2] if len(sys.argv) > 2 else None

RISK = [
    ("require(number)", re.compile(r"require\s*\(\s*[\d(]")),
    ("require(non-script var)", re.compile(r"require\s*\(\s*(?!script|game|[A-Za-z_][\w.]*\s*[:.]\s*WaitForChild|[A-Za-z_][\w.]*\s*\))")),
    ("loadstring", re.compile(r"loadstring")),
    ("getfenv/setfenv", re.compile(r"[gs]etfenv")),
    ("InsertService", re.compile(r"InsertService")),
    ("LoadAsset", re.compile(r"LoadAsset")),
    ("LinkedSource", re.compile(r"LinkedSource")),
    ("HttpGet/Post/Request", re.compile(r"(GetAsync|PostAsync|RequestAsync|HttpGet|HttpPost)\b")),
    ("webhook/url", re.compile(r"https?://|discord(app)?\.com/api/webhooks", re.I)),
    ("escaped bytes", re.compile(r"(\\\d{2,3}){6,}|(\\x[0-9a-fA-F]{2}){6,}")),
    ("string.char/reverse", re.compile(r"string\.char|:reverse\(|string\.reverse")),
    ("TeleportService", re.compile(r"TeleportService")),
    ("Prompt*Purchase", re.compile(r"Prompt\w*Purchase")),
    ("very long line", None),
]

classes = {"Script", "LocalScript", "ModuleScript"}
stack = []
scripts = []
props_of_interest = {}
backpack_scripts = []

for event, el in ET.iterparse(path, events=("start", "end")):
    if el.tag == "Item":
        if event == "start":
            stack.append([el.get("class"), None])
        else:
            cls, name = stack[-1]
            if cls in classes:
                src = ""
                props = el.find("Properties")
                disabled = None
                if props is not None:
                    for p in props:
                        if p.get("name") == "Source":
                            src = p.text or ""
                        if p.get("name") == "Disabled":
                            disabled = p.text
                        if p.get("name") == "LinkedSource" and (p.text or "").strip() not in ("", "null"):
                            src += "\n--LinkedSource:" + (p.text or "")
                fullpath = "/".join((n or "?") + ":" + c for c, n in stack)
                scripts.append((fullpath, cls, src, disabled))
                if any(c == "Backpack" for c, _ in stack[:-1]):
                    backpack_scripts.append(fullpath)
            if cls in ("ServerScriptService", "HttpService", "Workspace"):
                props = el.find("Properties")
                if props is not None:
                    for p in props:
                        if p.get("name") in ("LoadStringEnabled", "HttpEnabled", "SandboxedInstanceMode"):
                            props_of_interest[cls + "." + p.get("name")] = p.text
            stack.pop()
            el.clear()
    elif el.tag == "Properties" and event == "end":
        pass
    elif event == "end" and el.tag == "string" and el.get("name") == "Name" and stack:
        if stack[-1][1] is None:
            stack[-1][1] = el.text

print("props:", props_of_interest)
print("total scripts:", len(scripts))
by_top = collections.Counter(p.split("/")[0] for p, *_ in scripts)
print("by top service:", dict(by_top))
print("backpack scripts:", backpack_scripts)

# src names
src_names = set()
if src_root:
    for dp, dn, fn in os.walk(src_root):
        for f in fn:
            if f.endswith(".luau") or f.endswith(".lua"):
                src_names.add(f.split(".")[0])

flagged = []
for fullpath, cls, src, disabled in scripts:
    hits = []
    for label, rx in RISK:
        if rx is None:
            if any(len(l) > 1500 for l in src.splitlines()):
                hits.append(label)
        elif rx.search(src):
            hits.append(label)
    # whitespace hiding: lots of spaces before code on a line
    if re.search(r"[ \t]{200,}\S", src):
        hits.append("off-screen whitespace")
    leaf = fullpath.split("/")[-1].split(":")[0]
    in_src = leaf in src_names
    outside_tree = not fullpath.startswith(("?:ServerScriptService", "ServerScriptService"))
    if hits:
        flagged.append((fullpath, cls, hits, in_src, len(src), disabled))

print("\nflagged scripts (path | class | hits | name in src/ | len | Disabled):")
for f in flagged:
    print(" ", f)

print("\nscripts NOT named like a src/ module (first 80):")
n = 0
for fullpath, cls, src, disabled in scripts:
    leaf = fullpath.split("/")[-1].split(":")[0]
    if leaf not in src_names:
        n += 1
        if n <= 80:
            print("  ", cls, fullpath, len(src), "Disabled=" + str(disabled))
print("count not in src:", n)
