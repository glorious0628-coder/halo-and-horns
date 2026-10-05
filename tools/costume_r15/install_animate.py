# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""검토한 Roblox 기본 R15 Animate를 GoodEvil Edit에 재현 설치한다. 기본값/--dry는 Studio에 연결하지 않는다.

py tools/costume_r15/install_animate.py --dry
py tools/costume_r15/install_animate.py --apply [--studio-id <GoodEvil ID>]
"""
from __future__ import annotations

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import hashlib
import json
import math
import re
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VENDOR = Path(__file__).resolve().parent / "vendor"
TARGET = "ServerStorage.CostumeAnimationControllers.R15"
CLASSES = {"LocalScript", "BindableFunction", "NumberValue", "StringValue", "Animation"}


def long_string(value):
    equals = "="
    while "]" + equals + "]" in value:
        equals += "="
    return "[" + equals + "[" + value + "]" + equals + "]"


def reply_text(result):
    text = "".join(part.get("text", "") for part in result.get("content", []) if part.get("type") == "text")
    if result.get("isError"):
        raise RuntimeError("Studio 도구 실행 실패: " + text[:400])
    return text


def reply_json(result):
    text = reply_text(result).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start, end = text.find("{"), text.rfind("}")
        if start < 0 or end < start:
            raise RuntimeError("Studio JSON 응답을 읽지 못했습니다.")
        return json.loads(text[start:end + 1])


def load_vendor():
    source_bytes = (VENDOR / "RobloxR15Animate.client.luau").read_bytes()
    tree_bytes = (VENDOR / "RobloxR15Animate.tree.json").read_bytes()
    metadata = json.loads((VENDOR / "RobloxR15Animate.provenance.json").read_text(encoding="utf-8"))
    if hashlib.sha256(source_bytes).hexdigest() != metadata["source_sha256"]:
        raise ValueError("검토한 Animate Source 해시가 다릅니다.")
    if hashlib.sha256(tree_bytes).hexdigest() != metadata["tree_sha256"]:
        raise ValueError("검토한 Animate 자식 구조 해시가 다릅니다.")
    source = source_bytes.decode("utf-8")
    if re.search(r"\brequire\s*\(|\bloadstring\s*\(|GetAsync|PostAsync|RequestAsync|FireServer|InvokeServer|DataStore", source):
        raise ValueError("Animate 원본에 예상하지 않은 외부 실행/통신이 있습니다.")
    if metadata.get("rig_type") != "R15" or not all(metadata["default_avatar_checks"].values()):
        raise ValueError("기본 R15 캐릭터 출처 검증이 없습니다.")
    engine = metadata.get("installed_engine_match", {})
    if engine.get("exact_source_match") is not True or engine.get("source_sha256") != metadata["source_sha256"]:
        raise ValueError("설치된 Roblox engine 원본과 일치하는 출처 증거가 없습니다.")
    tree = json.loads(tree_bytes)
    counts = {}

    def validate(node, root=False):
        cls = node.get("ClassName")
        if cls not in CLASSES or (cls == "LocalScript" and not root):
            raise ValueError("예상하지 않은 Animate 자식 클래스입니다.")
        if not isinstance(node.get("Name"), str) or not node["Name"]:
            raise ValueError("잘못된 자식 이름입니다.")
        if not isinstance(node.get("Archivable"), bool):
            raise ValueError("Archivable 값이 없습니다.")
        counts[cls] = counts.get(cls, 0) + 1
        props = node.get("Properties")
        if not isinstance(props, dict) or not isinstance(node.get("Attributes"), dict):
            raise ValueError("잘못된 노드 메타데이터입니다.")
        allowed = {"Disabled", "RunContext"} if root else {"AnimationId"} if cls == "Animation" else {"Value"} if cls.endswith("Value") else set()
        if not set(props).issubset(allowed):
            raise ValueError("예상하지 않은 속성이 있습니다.")
        if cls == "Animation" and not re.fullmatch(r"(?:rbxassetid://|https?://www\.roblox\.com/asset/\?id=)[1-9][0-9]*", props.get("AnimationId", "")):
            raise ValueError("예상하지 않은 애니메이션 주소입니다.")
        if cls == "NumberValue" and (type(props.get("Value")) not in (int, float) or not math.isfinite(props["Value"])):
            raise ValueError("유효하지 않은 NumberValue입니다.")
        if cls == "StringValue" and not isinstance(props.get("Value"), str):
            raise ValueError("유효하지 않은 StringValue입니다.")
        names = set()
        for child in node.get("Children", []):
            if child["Name"] in names:
                raise ValueError("같은 부모 아래 중복 이름이 있습니다.")
            names.add(child["Name"])
            validate(child)

    validate(tree, root=True)
    if tree["ClassName"] != "LocalScript" or tree["Name"] != "Animate" or sum(counts.values()) != metadata["nodes"]:
        raise ValueError("루트 또는 전체 노드 수가 다릅니다.")
    return source, tree, metadata, counts


PRECHECK = r'''
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 설치합니다.") end
local ss = game:GetService("ServerStorage")
local folder = ss:FindFirstChild("CostumeAnimationControllers")
if folder and not folder:IsA("Folder") then error("대상 이름이 Folder가 아닙니다.") end
local root = folder and folder:FindFirstChild("R15")
if root and not root:IsA("LocalScript") then error("기존 R15가 LocalScript가 아닙니다.") end
local function snapshot(inst)
    local props = {}
    if inst:IsA("LuaSourceContainer") then props.Source = inst.Source end
    if inst:IsA("BaseScript") then props.Disabled = inst.Disabled end
    if inst:IsA("Animation") then props.AnimationId = inst.AnimationId end
    if inst:IsA("ValueBase") then props.Value = inst.Value end
    local node = { Name = inst.Name, ClassName = inst.ClassName, Archivable = inst.Archivable,
                   Attributes = inst:GetAttributes(), Properties = props, Children = {} }
    for _, child in inst:GetChildren() do table.insert(node.Children, snapshot(child)) end
    return node
end
return game:GetService("HttpService"):JSONEncode({ Exists = root ~= nil, Previous = root and snapshot(root) or nil })
'''

ENSURE_FOLDER = r'''
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 설치합니다.") end
local ss = game:GetService("ServerStorage")
local folder = ss:FindFirstChild("CostumeAnimationControllers")
if folder and not folder:IsA("Folder") then error("대상 이름이 Folder가 아닙니다.") end
if not folder then folder = Instance.new("Folder"); folder.Name = "CostumeAnimationControllers"; folder.Parent = ss end
return "folder ready"
'''

RESTORE_CHILDREN = r'''
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 설치합니다.") end
local HttpService = game:GetService("HttpService")
local data = HttpService:JSONDecode(__TREE__)
local root = game:GetService("ServerStorage").CostumeAnimationControllers:FindFirstChild("R15")
if not root or not root:IsA("LocalScript") then error("R15 LocalScript가 없습니다.") end
local allowed = { BindableFunction = true, NumberValue = true, StringValue = true, Animation = true }
local function decode(v)
    if type(v) ~= "table" then return v end
    if v.Type == "EnumItem" then return Enum[string.gsub(v.Enum, "^Enum%.", "")][v.Name] end
    error("직렬화 값 종류가 다릅니다.")
end
local function populate(inst, node)
    inst.Archivable = node.Archivable
    for name, value in node.Attributes do inst:SetAttribute(name, decode(value)) end
    for property, value in node.Properties do
        -- LocalScript RunContext is already Legacy; leave the engine default unchanged.
        if property ~= "Source" and property ~= "RunContext" then inst[property] = decode(value) end
    end
    for _, child in node.Children do
        if not allowed[child.ClassName] then error("예상하지 않은 자식 클래스입니다.") end
        local instChild = Instance.new(child.ClassName)
        instChild.Name = child.Name
        populate(instChild, child)
        instChild.Parent = inst
    end
end
for _, child in root:GetChildren() do child:Destroy() end
populate(root, data)
root:SetAttribute("CaptureSourceSHA256", __HASH__)
root:SetAttribute("CaptureRigType", "R15")
root:SetAttribute("CaptureOrigin", "RobloxDefaultCharacter")
root:SetAttribute("CaptureNodeCount", __COUNT__)
local count = 0
local function verify(inst, node, isRoot)
    if inst.ClassName ~= node.ClassName or (not isRoot and inst.Name ~= node.Name) then error("설치된 클래스/이름이 다릅니다.") end
    if inst.Archivable ~= node.Archivable then error("Archivable 값이 다릅니다.") end
    for name, value in node.Attributes do if inst:GetAttribute(name) ~= decode(value) then error("속성 값이 다릅니다.") end end
    for property, value in node.Properties do
        if property ~= "Source" and inst[property] ~= decode(value) then error("직렬화 속성 값이 다릅니다: " .. property) end
    end
    if #inst:GetChildren() ~= #node.Children then error("자식 수가 다릅니다.") end
    count += 1
    for _, child in node.Children do
        local found = inst:FindFirstChild(child.Name)
        if not found then error("설치된 자식이 없습니다.") end
        verify(found, child, false)
    end
end
verify(root, data, true)
return HttpService:JSONEncode({ Path = root:GetFullName(), Nodes = count, Descendants = #root:GetDescendants(), Disabled = root.Disabled })
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--dry", action="store_true")
    parser.add_argument("--studio-id")
    args = parser.parse_args()
    source, tree, metadata, counts = load_vendor()
    summary = {"target": TARGET, "source_chars": len(source), "source_sha256": metadata["source_sha256"],
               "tree_sha256": metadata["tree_sha256"], "nodes": metadata["nodes"], "classes": counts, "applied": False}
    summary["engine_origin"] = metadata["installed_engine_match"]
    if not args.apply:
        print(json.dumps(summary, ensure_ascii=False))
        return
    # Importing/starting MCP occurs only under --apply, after all file checks pass.
    sys.path.insert(0, str(ROOT / "tools"))
    from studio_mcp import Client
    client = Client()
    audit = dict(summary, started_at_utc=datetime.now(timezone.utc).isoformat(), phase="preflight")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    audit_file = ROOT / "build/costume_r15" / ("animate_install_" + stamp + "_" + uuid.uuid4().hex[:8] + ".json")
    audit_file.parent.mkdir(parents=True, exist_ok=True)

    def save_audit():
        audit_file.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    try:
        client.start()
        studios = reply_json(client.call("list_roblox_studios", {})).get("studios", [])
        matching = [s for s in studios if "goodevil" in s["name"].lower() and (not args.studio_id or s["id"] == args.studio_id)]
        if len(matching) != 1:
            raise RuntimeError("GoodEvil 대상이 유일하지 않습니다. --studio-id로 현재 하나를 지정하세요.")
        studio_id = matching[0]["id"]
        audit["studio_id"] = studio_id
        state = reply_text(client.call("get_studio_state", {"studio_id": studio_id}))
        if "Current Studio Mode: Edit" not in state:
            raise RuntimeError("GoodEvil이 Edit 모드가 아닙니다. 플레이 상태는 변경하지 않았습니다.")

        def execute(code):
            return client.call("execute_luau", {"code": code, "datamodel_type": "Edit", "studio_id": studio_id})

        before = reply_json(execute(PRECHECK))
        audit["previous"] = before
        save_audit()
        old_source = before.get("Previous", {}).get("Properties", {}).get("Source", "") if before.get("Exists") else ""
        if before.get("Exists") and old_source != source:
            raise RuntimeError("기존 R15 Source가 검토 원본과 다릅니다. 덮어쓰지 않았습니다.")
        reply_text(execute(ENSURE_FOLDER))
        audit["phase"] = "source"
        save_audit()
        if not before.get("Exists"):
            reply_text(client.call("multi_edit", {"file_path": TARGET, "className": "LocalScript",
                       "edits": [{"old_string": "", "new_string": source}], "datamodel_type": "Edit", "studio_id": studio_id}))
        audit["phase"] = "children"
        save_audit()
        restore = RESTORE_CHILDREN.replace("__TREE__", long_string(json.dumps(tree, ensure_ascii=False)))
        restore = restore.replace("__HASH__", json.dumps(metadata["source_sha256"]))
        restore = restore.replace("__COUNT__", str(metadata["nodes"]))
        verified = reply_json(execute(restore))
        # Read back Source to verify multi_edit preserved every character.
        after = reply_json(execute(PRECHECK))
        actual_source = after["Previous"]["Properties"]["Source"]
        if hashlib.sha256(actual_source.encode("utf-8")).hexdigest() != metadata["source_sha256"]:
            raise RuntimeError("설치 후 Source 해시가 다릅니다.")
        if verified["Nodes"] != metadata["nodes"]:
            raise RuntimeError("설치 후 노드 수가 다릅니다.")
        audit.update(applied=True, phase="complete", verification=verified)
        save_audit()
        print(json.dumps({**summary, "applied": True, "verification": verified,
                          "audit": audit_file.relative_to(ROOT).as_posix()}, ensure_ascii=False))
    except Exception as error:
        audit.update(phase="failed", error=str(error))
        save_audit()
        raise
    finally:
        client.close()


if __name__ == "__main__":
    main()
