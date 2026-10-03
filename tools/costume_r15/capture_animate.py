"""GoodEvil Play 서버의 기본 R15 Animate를 읽어 저장한다. Studio 상태를 바꾸지 않는다."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from studio_mcp import Client

CODE = r'''
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players:FindFirstChild(__PLAYER__)
if not player then error("지정한 플레이어가 없습니다.") end
local character = player.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then error("기본 R15 캐릭터가 아닙니다.") end
if character:GetAttribute("HHC_CostumeId") ~= nil then error("코스튬 캐릭터 Animate는 기본 원본으로 캡처하지 않습니다.") end
if character:GetAttribute("HHC_OriginalRestore") ~= nil then error("복원한 캐릭터 Animate는 최초 기본 원본으로 캡처하지 않습니다.") end
local animate = character:FindFirstChild("Animate")
if not animate or not animate:IsA("LocalScript") then error("Animate LocalScript가 없습니다.") end
local starter = game:GetService("StarterPlayer")
if starter.StarterCharacterScripts:FindFirstChild("Animate") then error("StarterCharacterScripts의 사용자 Animate가 존재합니다.") end
if starter:FindFirstChild("StarterCharacter") then error("사용자 StarterCharacter가 존재합니다.") end
local function value(v)
    local kind = typeof(v)
    if kind == "string" or kind == "number" or kind == "boolean" or kind == "nil" then return v end
    if kind == "EnumItem" then return { Type = kind, Enum = tostring(v.EnumType), Name = v.Name, Value = v.Value } end
    if kind == "Instance" then return { Type = kind, Path = v:GetFullName() } end
    if kind == "Vector3" then return { Type = kind, X = v.X, Y = v.Y, Z = v.Z } end
    if kind == "Vector2" then return { Type = kind, X = v.X, Y = v.Y } end
    if kind == "Color3" then return { Type = kind, R = v.R, G = v.G, B = v.B } end
    if kind == "CFrame" then return { Type = kind, Components = { v:GetComponents() } } end
    if kind == "BrickColor" then return { Type = kind, Number = v.Number } end
    if kind == "UDim" then return { Type = kind, Scale = v.Scale, Offset = v.Offset } end
    if kind == "UDim2" then return { Type = kind, XS = v.X.Scale, XO = v.X.Offset, YS = v.Y.Scale, YO = v.Y.Offset } end
    if kind == "NumberRange" then return { Type = kind, Min = v.Min, Max = v.Max } end
    if kind == "Rect" then return { Type = kind, MinX = v.Min.X, MinY = v.Min.Y, MaxX = v.Max.X, MaxY = v.Max.Y } end
    error("직렬화하지 못한 값 종류: " .. kind)
end
local function tree(inst)
    local attributes = {}
    for key, v in inst:GetAttributes() do attributes[key] = value(v) end
    local node = { Name = inst.Name, ClassName = inst.ClassName, Archivable = inst.Archivable,
                   Attributes = attributes, Properties = {}, Children = {} }
    if inst:IsA("LuaSourceContainer") then node.Properties.Source = inst.Source end
    if inst:IsA("BaseScript") then
        node.Properties.Disabled = inst.Disabled
        local ok, context = pcall(function() return inst.RunContext end)
        if ok then node.Properties.RunContext = value(context) end
    end
    if inst:IsA("Animation") then node.Properties.AnimationId = inst.AnimationId end
    if inst:IsA("ValueBase") then node.Properties.Value = value(inst.Value) end
    local children = inst:GetChildren()
    table.sort(children, function(a, b) return a.Name == b.Name and a.ClassName < b.ClassName or a.Name < b.Name end)
    for _, child in children do table.insert(node.Children, tree(child)) end
    return node
end
local sourceAssetId
pcall(function() sourceAssetId = animate.SourceAssetId end)
return HttpService:JSONEncode({
    Schema = 1, Datamodel = "Server", Player = player.Name, Character = character.Name,
    AnimatePath = animate:GetFullName(), RigType = humanoid.RigType.Name,
    CostumeMarkerAbsent = character:GetAttribute("HHC_CostumeId") == nil,
    OriginalRestoreMarkerAbsent = character:GetAttribute("HHC_OriginalRestore") == nil,
    StarterCharacterAnimateAbsent = starter.StarterCharacterScripts:FindFirstChild("Animate") == nil,
    StarterCharacterAbsent = starter:FindFirstChild("StarterCharacter") == nil,
    SourceAssetId = sourceAssetId, Tree = tree(animate)
})
'''


def parse_result(result):
    if result.get("isError"):
        raise RuntimeError("Studio의 읽기 실행이 실패했습니다.")
    for part in result.get("content", []):
        if part.get("type") != "text":
            continue
        text = part.get("text", "")
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            first, last = text.find("{"), text.rfind("}")
            if first < 0 or last < first:
                continue
            try:
                data = json.loads(text[first:last + 1])
            except json.JSONDecodeError:
                continue
        if isinstance(data, dict) and data.get("Schema") == 1 and "Tree" in data:
            return data
    raise RuntimeError("직렬화 JSON 응답을 찾지 못했습니다.")


def walk(node):
    yield node
    for child in node.get("Children", []):
        yield from walk(child)


def normalize_tree(node):
    # HttpService encodes empty Lua dictionaries as [] rather than {}.
    for field in ("Attributes", "Properties"):
        if node.get(field) == []:
            node[field] = {}
        if not isinstance(node.get(field), dict):
            raise ValueError(f"잘못된 캡처 필드: {field}")
    for child in node.get("Children", []):
        normalize_tree(child)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--player", default="Darugi_S2")
    parser.add_argument("--output", default="build/roblox_r15_animate_capture.json")
    args = parser.parse_args()
    target = (ROOT / args.output).resolve()
    if ROOT / "build" not in target.parents:
        raise ValueError("캡처 출력은 build/ 안에만 저장합니다.")
    client = Client()
    try:
        client.start()
        studio_id = client.studio_id()
        result = client.call("execute_luau", {"code": CODE.replace("__PLAYER__", json.dumps(args.player)),
                                              "datamodel_type": "Server", "studio_id": studio_id})
    finally:
        client.close()
    data = parse_result(result)
    normalize_tree(data["Tree"])
    source = data["Tree"]["Properties"]["Source"]
    if not isinstance(source, str) or not source.strip():
        raise ValueError("Animate Source가 비어 있습니다.")
    nodes = list(walk(data["Tree"]))
    classes = {}
    for node in nodes:
        classes[node["ClassName"]] = classes.get(node["ClassName"], 0) + 1
    data["CapturedAtUTC"] = datetime.now(timezone.utc).isoformat()
    data["StudioId"] = studio_id
    data["SourceSHA256"] = hashlib.sha256(source.encode("utf-8")).hexdigest()
    data["NodeCount"] = len(nodes)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    target.with_suffix(".client.luau").write_text(source, encoding="utf-8", newline="")
    print(json.dumps({"file": target.relative_to(ROOT).as_posix(), "source_chars": len(source),
                      "sha256": data["SourceSHA256"], "nodes": len(nodes), "classes": classes,
                      "rig": data["RigType"], "default_character_evidence": {
                          key: data[key] for key in ("CostumeMarkerAbsent", "OriginalRestoreMarkerAbsent",
                                                    "StarterCharacterAnimateAbsent", "StarterCharacterAbsent")}},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
