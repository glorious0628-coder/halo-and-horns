"""Verify the actual 3D HUD clone in an isolated Studio Play session (MCP only)."""
import base64
import json
import sys
import time
from pathlib import Path

from face_runtime_audit import run, ROOT
from studio_mcp import Client

OUT = ROOT / 'docs/art/verification_2026-10-04/hud_portrait'
PROBE = '''
local p=game.Players.LocalPlayer
local v=p.PlayerGui:FindFirstChild("AvatarPortrait3D",true)
assert(v,"3D viewport missing")
local c=v:FindFirstChild("PortraitCharacter",true)
assert(c,"3D character missing")
local source=p.Character
local face=source:FindFirstChild("FaceExpression",true)
local copy=c:FindFirstChild("FaceExpression",true)
local scripts,parts,bones=0,0,0
for _,d in c:GetDescendants() do
 if d:IsA("LuaSourceContainer") then scripts+=1 end
 if d:IsA("Bone") then bones+=1 end
 if d:IsA("BasePart") then
  parts+=1
  assert(d.Anchored and not d.CanCollide and not d.CanTouch and not d.CanQuery,"Unsafe portrait physics")
 end
end
assert(scripts==0,"Executable scripts in portrait")
assert(v.Visible and v.ImageTransparency==0,"Portrait not displayed")
assert((face==nil)==(copy==nil),"Face existence mismatch")
assert(not face or copy.TextureID==face.TextureID,"Expression texture mismatch")
assert(v:GetAttribute("CostumeId")== (source:GetAttribute("HHC_CostumeId") or ""),"Stale costume")
return game:GetService("HttpService"):JSONEncode({passed=true,scripts=scripts,parts=parts,bones=bones,
 costumeId=v:GetAttribute("CostumeId"),costumeEnabled=p:GetAttribute("CostumeEnabled"),
 costumeApplied=p:GetAttribute("CostumeApplied"),gender=p:GetAttribute("CharacterGender"),
 sourceTexture=face and face.TextureID,portraitTexture=copy and copy.TextureID,
 expression=source:GetAttribute("Expression"),imageTransparency=v.ImageTransparency,
 size={v.AbsoluteSize.X,v.AbsoluteSize.Y},position={v.AbsolutePosition.X,v.AbsolutePosition.Y}})
'''


def call(label, code, model='Client'):
    return run('hud3d_' + label, code, model)


def probe(label):
    row = call(label, PROBE)
    assert row.get('passed'), row
    return row


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    OUT.mkdir(parents=True, exist_ok=True)
    report_path = OUT / 'hud3d_runtime_actual.json'
    if '--expressions-only' in sys.argv:
        old = json.loads(report_path.read_text(encoding='utf-8'))
        (OUT / 'hud3d_runtime_initial_expression_trigger_missed.json').write_text(
            json.dumps({**old, 'expression_verification_valid': False,
                        'correction': 'Attack/Talk calls observed Neutral only; they do not prove expression changes.'},
                       ensure_ascii=False, indent=2), encoding='utf-8')
        old['checks'].pop('serious', None)
        old['checks'].pop('smile', None)
        rows = old['checks']
    else:
        rows = {'neutral': probe('neutral')}
    rows['texture_change_signal'] = call('texture_change_signal', '''
local p=game.Players.LocalPlayer
local v=p.PlayerGui:FindFirstChild("AvatarPortrait3D",true)
local source=p.Character:FindFirstChild("FaceExpression",true)
local copy=v:FindFirstChild("PortraitCharacter",true):FindFirstChild("FaceExpression",true)
local original=source.TextureID
local rows={}
local ok,err=pcall(function()
 for name,id in {Neutral="rbxassetid://114282379234661",Serious="rbxassetid://130810730029380",SoftSmile="rbxassetid://96983789676579"} do
  source.TextureID=id
  task.wait(0.15)
  assert(copy.TextureID==id,"HUD did not follow "..name)
  table.insert(rows,{expression=name,sourceTexture=source.TextureID,portraitTexture=copy.TextureID,passed=true})
 end
end)
source.TextureID=original
task.wait(0.15)
assert(ok,err)
assert(copy.TextureID==original,"Original texture not restored")
return game:GetService("HttpService"):JSONEncode({passed=true,rows=rows,originalRestored=true,scope="Temporary Client Play texture changes, not gameplay event testing"})
''')
    if '--expressions-only' in sys.argv:
        old['checks'] = rows
        old['expression_trigger'] = 'Temporary Client Play TextureID changes; each expected ID asserted and original restored. Gameplay trigger coverage is separate.'
        report_path.write_text(json.dumps(old, ensure_ascii=False, indent=2), encoding='utf-8')
        return
    for label, enabled, gender in [('off', False, 'M'), ('on', True, 'M'),
                                    ('female_missing_template', True, 'F'), ('male_restored', True, 'M')]:
        call(label + '_trigger', f'require(game.ReplicatedStorage.Shared.Net).Get("SetCostume"):FireServer({str(enabled).lower()},"{gender}")\nreturn "SetCostume remote sent"')
        time.sleep(3)
        rows[label] = probe(label)
    call('respawn_trigger', 'local h=game.Players:GetPlayers()[1].Character:FindFirstChildOfClass("Humanoid")\nh.Health=0\nreturn "Play-only death triggered"', 'Server')
    time.sleep(8)
    rows['respawn'] = probe('respawn')
    c = Client()
    try:
        c.start()
        result = c.call('screen_capture', {'capture_id': 'hud3d_verified'})
    finally:
        c.close()
    pictures = [item for item in result.get('content', []) if item.get('type') == 'image']
    assert pictures and not result.get('isError'), 'Studio capture failed'
    screenshot = OUT / 'hud3d_verified.jpeg'
    screenshot.write_bytes(base64.b64decode(pictures[0]['data']))
    # A screenshot crop for visual inspection; this is not a new design or texture.
    from PIL import Image
    image = Image.open(screenshot)
    image.crop((0, 120, 360, 322)).save(OUT / 'hud3d_stats_actual.png')
    report = {'scope': 'Actual single-client Studio Play HUD, existing production character assets',
              'expression_trigger': 'Temporary Client Play TextureID changes; each expected ID asserted and original restored. Gameplay trigger coverage is separate.',
              'costume_trigger': 'real SetCostume remote; missing F template falls back to actual account avatar',
              'face_candidate_applied': False, 'checks': rows,
              'capture': screenshot.name, 'credits_spent': 0}
    (OUT / 'hud3d_runtime_actual.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Verified actual 3D portrait: texture change signals, OFF/ON, gender fallback/restore, respawn')


if __name__ == '__main__':
    main()
