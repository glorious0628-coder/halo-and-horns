"""Read-only original mesh coordinate diagnostics for front-face partition."""
import bpy,numpy as np,json,sys
from pathlib import Path
from mathutils import Vector
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);meta=json.loads(source.with_suffix('.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
face=bpy.data.objects['FaceExpression'];head=bpy.data.objects['HeadBase']
back=Vector(meta['camera_front_direction']).normalized();up=Vector(meta['camera_front_up']).normalized();right=up.cross(back).normalized();up=back.cross(right).normalized();center=Vector(meta['camera_target'])
def p(v,obj):
    point=obj.matrix_world@obj.data.vertices[v].co-center
    return [right.dot(point),up.dot(point),back.dot(point)]
def basis(x):return np.column_stack([np.ones(len(x)),x[:,0],x[:,1],x[:,0]**2,x[:,0]*x[:,1],x[:,1]**2,x[:,0]**3,x[:,1]**3])
ids={v for f in face.data.polygons for v in f.vertices};points=np.asarray([p(i,face) for i in ids]);coef=np.linalg.lstsq(basis(points),points[:,2],rcond=None)[0]
records=[]
for f in head.data.polygons:
    arr=np.asarray([p(v,head) for v in f.vertices]);cen=arr.mean(axis=0);depth=cen[2]-float(basis(cen[None,:])@coef)
    screen=[(cen[0]/meta['source_front_camera_scale']+.5)*768,(.5-cen[1]/meta['source_front_camera_scale'])*768]
    if 170<screen[0]<620 and 420<screen[1]<715:
      records.append({'head_index':f.index,'screen':screen,'depth_residual':depth,'normal_dot_front':(head.matrix_world.to_3x3()@f.normal).normalized().dot(back)})
out.write_text(json.dumps({'source_face_fit_residual_quantiles':np.quantile(points[:,2]-basis(points)@coef,[0,.05,.5,.95,1]).tolist(),'records':records},indent=2)+'\n')
print(json.dumps({'fit_quantiles':np.quantile(points[:,2]-basis(points)@coef,[0,.05,.5,.95,1]).tolist()}))
