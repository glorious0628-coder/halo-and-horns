import sys, os
import xml.etree.ElementTree as ET

path, src_root = sys.argv[1], sys.argv[2]
classes = {"Script", "LocalScript", "ModuleScript"}
stack = []
out = []
for event, el in ET.iterparse(path, events=("start", "end")):
    if el.tag == "Item":
        if event == "start":
            stack.append([el.get("class"), None])
        else:
            cls, name = stack[-1]
            if cls in classes:
                src = ""
                props = el.find("Properties")
                if props is not None:
                    for p in props:
                        if p.get("name") == "Source":
                            src = p.text or ""
                names = [n for c, n in stack]
                out.append((names, cls, src))
            stack.pop()
            el.clear()
    elif event == "end" and el.tag == "string" and el.get("name") == "Name" and stack and stack[-1][1] is None:
        stack[-1][1] = el.text

suffix = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}
same = diff = missing = 0
for names, cls, src in out:
    rel = os.path.join(src_root, *names[:-1], names[-1] + suffix[cls])
    if not os.path.exists(rel):
        # nested module under a script folder?
        alt = os.path.join(src_root, *names[:-1], names[-1], "init" + suffix[cls])
        rel = alt if os.path.exists(alt) else rel
    if not os.path.exists(rel):
        missing += 1
        print("MISSING in src:", "/".join(names), cls)
        continue
    with open(rel, encoding="utf-8") as f:
        disk = f.read()
    norm = lambda s: s.replace("\r\n", "\n").rstrip()
    if norm(disk) == norm(src):
        same += 1
    else:
        diff += 1
        print("DIFF:", "/".join(names))
print("same", same, "diff", diff, "missing", missing)
