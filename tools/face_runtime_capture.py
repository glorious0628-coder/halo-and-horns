"""Capture the actual Play viewport through Studio MCP and restore settings."""
import base64
import hashlib
import json
from pathlib import Path
import time
import sys

from studio_mcp import Client
from face_runtime_audit import OUT, run


RESOURCE_DIR = Path(__file__).resolve().with_name('face_runtime_capture_data')


SETUP = '''
local P=game.Players.LocalPlayer
local R=game:GetService("RunService")
local old=_G.HHC_FaceAudit
assert(not old,"Unrestored audit state")
local r=settings().Rendering
_G.HHC_FaceAudit={quality=r.QualityLevel,edit=r.EditQualityLevel,frm=r.EnableFRM,gui={},tracks={}}
for _,v in workspace:GetDescendants() do if v:IsA("BillboardGui") then
 table.insert(_G.HHC_FaceAudit.gui,{v,v.Enabled});v.Enabled=false
end end
local a=P.Character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
for _,v in a:GetPlayingAnimationTracks() do table.insert(_G.HHC_FaceAudit.tracks,{v,v.Speed});v:AdjustSpeed(0) end
return "Billboards hidden and idle tracks frozen for comparison only"
'''

RESTORE = '''
game:GetService("RunService"):UnbindFromRenderStep("FaceSharpAuditCamera")
workspace.CurrentCamera.CameraType=Enum.CameraType.Custom
local old=_G.HHC_FaceAudit
if old then
 local r=settings().Rendering;r.QualityLevel=old.quality;r.EditQualityLevel=old.edit;r.EnableFRM=old.frm
 for _,v in old.gui do if v[1].Parent then v[1].Enabled=v[2] end end
 for _,v in old.tracks do pcall(function() v[1]:AdjustSpeed(v[2]) end) end
 _G.HHC_FaceAudit=nil
end
return "Original quality, billboards, animation speeds and Custom camera restored"
'''


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    camera_template=(RESOURCE_DIR/'camera_default.lua').read_text(encoding='utf-8')
    snapshot=(RESOURCE_DIR/'snapshot.lua').read_text(encoding='utf-8')
    run('comparison_setup', SETUP)
    try:
        for level in ('Automatic','Level21'):
            code=f'''local r=settings().Rendering
r.QualityLevel=Enum.QualityLevel.{level};r.EditQualityLevel=Enum.QualityLevel.{level};r.EnableFRM={str(level=='Automatic').lower()}
return tostring(r.QualityLevel).."/"..tostring(r.EditQualityLevel).."/FRM="..tostring(r.EnableFRM)'''
            run('quality_'+level,code)
            for name,distance in (('default',12.5),('close',3.5)):
                label=f'production_{level}_{name}'+ ('_'+sys.argv[1] if len(sys.argv)>1 else '')
                run(label+'_camera',camera_template.replace('*12.5','*'+str(distance)))
                time.sleep(1)
                metadata=run(label+'_state',snapshot)
                c=Client()
                try:
                    c.start()
                    response=c.call('screen_capture',{'capture_id':label})
                finally:
                    c.close()
                images=[v for v in response.get('content',[]) if v.get('type')=='image']
                if response.get('isError') or not images:
                    raise RuntimeError(str(response)[:1000])
                raw=base64.b64decode(images[0]['data'])
                path=OUT/(label+'.jpeg')
                path.write_bytes(raw)
                from PIL import Image
                metadata['capture']={'tool':'studio_mcp.screen_capture','path':path.name,'sha256':hashlib.sha256(raw).hexdigest(),'size':list(Image.open(path).size),'billboards_hidden':True,'idle_animation_frozen':True,'production_assets_unchanged':True}
                (OUT/(label+'.json')).write_text(json.dumps(metadata,indent=2),encoding='utf-8')
                print('Saved',path.name,flush=True)
    finally:
        run('comparison_restore',RESTORE)


if __name__=='__main__':
    main()
