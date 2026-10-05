# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Prepare a temporary continuous facial UV chart and close mouth recess geometry.

Only the new copy is exported. Original GLB, textures, non-facial UVs and body
geometry are preserved. No raster image editing is performed. Output textures
are Blender CG renders/bakes intended as input to GPT image editing.
"""

raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import colorsys
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector, geometry

args=sys.argv[sys.argv.index('--')+1:]
source=Path(args[0]).resolve();out_dir=Path(args[1]).resolve()
asset_name=source.stem
profile=json.loads(Path(args[2]).read_text(encoding='utf-8')) if len(args)>2 else {}
if asset_name!='Costume_HaloWarriorM' and not profile:
    raise RuntimeError('Each other avatar requires a reviewed facial alignment profile')
mouth_center=profile.get('mouth_center_screen',[385,614])
screen_scale=profile.get('screen_scale',[1,1])
flatten_radius=profile.get('mouth_flatten_radius',[48,40])
cap_radius=profile.get('mouth_cap_radius',[43,32])
out_dir.mkdir(parents=True,exist_ok=True)
source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
if profile and (not profile.get('reviewed') or profile.get('source_sha256')!=source_sha):
    raise RuntimeError('Facial profile must be reviewed for this exact source GLB')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
head=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.name.startswith('HeadMat') for m in o.data.materials))
me=head.data;me.calc_loop_triangles()
original_coords=[v.co.copy() for v in me.vertices]
original_corner_normals=[normal.vector.copy() for normal in me.corner_normals]
original_uv=[point.uv.copy() for point in me.uv_layers.active.data]
source_uv_name=me.uv_layers.active.name
head_mat=next(mat for mat in me.materials if mat.name.startswith('HeadMat'))
tex=next(node for node in head_mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image)
src_image=tex.image;src_width,src_height=src_image.size
src_pixels=np.empty(src_width*src_height*4,dtype=np.float32)
src_image.pixels.foreach_get(src_pixels);src_pixels=src_pixels.reshape(src_height,src_width,4)
pts=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
zmin,zmax=min(p.z for p in pts),max(p.z for p in pts)
xmin,xmax=min(p.x for p in pts),max(p.x for p in pts)
z0=zmin+float(profile.get('crop_start_fraction',.58))*(zmax-zmin)
scale=(zmax-z0)*1.15;camx,camz=(xmin+xmax)/2,(z0+zmax)/2
depsgraph=bpy.context.evaluated_depsgraph_get()


def screen_physical(world):
    return Vector(((world.x-camx)/scale*768+384,384-(world.z-camz)/scale*768))


def screen(world):
    physical=screen_physical(world)
    return Vector(((physical.x-mouth_center[0])/screen_scale[0]+385,(physical.y-mouth_center[1])/screen_scale[1]+614))


def to_physical(sx,sy):
    return ((sx-385)*screen_scale[0]+mouth_center[0],(sy-614)*screen_scale[1]+mouth_center[1])


def ray(sx,sy):
    sx,sy=to_physical(sx,sy)
    x=camx+(sx/768-.5)*scale;z=camz+(.5-sy/768)*scale
    return bpy.context.scene.ray_cast(depsgraph,Vector((x,-10,z)),Vector((0,1,0)))


def visible(point,tolerance=.0015):
    p=screen(point);hit,loc,*_=ray(p.x,p.y)
    return hit and abs(loc.y-point.y)<tolerance


def uv_color(uv):
    x=max(0,min(src_width-1,int(uv.x*src_width)))
    y=max(0,min(src_height-1,int(uv.y*src_height)))
    return src_pixels[y,x,:3]


def physical_boxes(world,boxes):
    point=screen_physical(world)
    return any(left<point.x<right and top<point.y<bottom for left,top,right,bottom in boxes)


def skin_color(h,s,v):
    rule=profile.get('skin_hsv')
    if not rule:return (h<.09 or h>.95) and v>.35
    return any(lo<=h<=hi for lo,hi in rule['hue_ranges']) and s<rule['saturation_max'] and v>rule['value_min']


def triangle_has_skin(face):
    """Read source UV colors on a small grid; do not alter texture pixels."""
    uv_points=[original_uv[i] for i in face.loop_indices]
    if len(uv_points)!=3:return False
    for a,b,c in [(1,0,0),(0,1,0),(0,0,1),(.5,.5,0),(.5,0,.5),(0,.5,.5),(1/3,1/3,1/3),(.6,.2,.2),(.2,.6,.2),(.2,.2,.6)]:
        u=uv_points[0]*a+uv_points[1]*b+uv_points[2]*c
        if skin_color(*colorsys.rgb_to_hsv(*uv_color(u))):return True
    return False


# Fit surrounding unmodified front facial skin, excluding the open mouth.
surface=[]
surface_hits={}
for sy in range(574,658,3):
    for sx in range(330,441,3):
        if 343<=sx<=427 and 583<=sy<=645:
            continue
        hit,point,normal,index,obj,_=ray(sx,sy)
        if hit:
            hit_label=obj.name+'/'+obj.data.materials[obj.data.polygons[index].material_index].name
            surface_hits[hit_label]=surface_hits.get(hit_label,0)+1
        if hit and obj==head and normal.y*profile.get('surface_normal_sign',1)<-.35:
            surface.append(point)
if len(surface)<20:
    print('[surface_sample_diagnostic] '+json.dumps({'samples':len(surface),'objects':surface_hits,'selected_head':head.name}),flush=True)
    raise RuntimeError('Too few adjacent facial surface samples')
design=np.array([[1,p.x,p.z,p.x*p.x,p.x*p.z,p.z*p.z] for p in surface])
values=np.array([p.y for p in surface])
coef=np.linalg.lstsq(design,values,rcond=None)[0]


def surface_y(point):
    return float(np.dot(coef,[1,point.x,point.z,point.x*point.x,point.x*point.z,point.z*point.z]))


mouth_vertices=[]
for vertex in me.vertices:
    world=head.matrix_world@vertex.co;p=screen(world)
    radius=math.sqrt(((p.x-385)/flatten_radius[0])**2+((p.y-614)/flatten_radius[1])**2)
    if radius>=1:
        continue
    # Fill only the existing recess toward the surrounding skin surface.
    target=surface_y(world)
    if world.y>target+.07 or world.y<target-.015:
        continue
    blend=1 if radius<=.85 else (1-radius)/.15
    world.y=world.y+(target-world.y)*blend
    vertex.co=head.matrix_world.inverted()@world
    mouth_vertices.append(vertex.index)
me.update();bpy.context.view_layer.update()
revised_corner_normals=list(original_corner_normals)
changed_set=set(mouth_vertices)
for loop in me.loops:
    if loop.vertex_index not in changed_set:
        continue
    world=head.matrix_world@me.vertices[loop.vertex_index].co
    dx=coef[1]+2*coef[3]*world.x+coef[4]*world.z
    dz=coef[2]+coef[4]*world.x+2*coef[5]*world.z
    world_normal=Vector((dx,-1,dz)).normalized()
    revised_corner_normals[loop.index]=(head.matrix_world.to_3x3().transposed()@world_normal).normalized()
me.normals_split_custom_set(revised_corner_normals)
depsgraph=bpy.context.evaluated_depsgraph_get()
mouth_residuals=[]
for sy in range(598,636,4):
    for sx in range(359,413,4):
        hit,point,normal,index,obj,_=ray(sx,sy)
        if hit and obj==head:
            mouth_residuals.append(point.y-surface_y(point))
print('[mouth_residual] '+json.dumps({'min':min(mouth_residuals),'max':max(mouth_residuals),'mean':float(np.mean(mouth_residuals)),'surface_coef':list(coef)}),flush=True)

# Find actual visible eyebrow pixels before applying centroid visibility tests.
# A skin triangle may have its centroid behind a fringe although its visible
# edge contains the old eyebrow. Omitting that triangle leaves a second brow.
# Sample original UV color at ray intersections rather than painting pixels.
brow_surface_faces=set()
brow_surface_faces.update(profile.get('verified_eyebrow_face_indices',[]))
brow_boxes=profile.get('brow_boxes')
if brow_boxes:
    brow_ray_points=[(sx,sy) for left,top,right,bottom in brow_boxes for sy in range(int(top),int(bottom),2) for sx in range(int(left),int(right),2)]
else:
    brow_ray_points=[to_physical(sx,sy) for sy in range(425,470,2) for sx in list(range(263,319,2))+list(range(423,499,2))]
for physical_sx,physical_sy in brow_ray_points:
        sx=(physical_sx-mouth_center[0])/screen_scale[0]+385
        sy=(physical_sy-mouth_center[1])/screen_scale[1]+614
        hit,point,normal,index,obj,_=ray(sx,sy)
        if not hit or obj!=head or normal.y*profile.get('surface_normal_sign',1)>-.05:
            continue
        face=me.polygons[index]
        world_points=[head.matrix_world@me.vertices[i].co for i in face.vertices]
        if len(world_points)!=3:
            raise RuntimeError('Eyebrow source must be triangulated')
        sample_uv=geometry.barycentric_transform(point,*world_points,*(Vector((*original_uv[i],0)) for i in face.loop_indices))
        h,s,v=colorsys.rgb_to_hsv(*uv_color(sample_uv))
        center_uv=sum((original_uv[i] for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
        center_h,center_s,center_v=colorsys.rgb_to_hsv(*uv_color(center_uv))
        # True brow/peach triangles differ from the golden fringe's hue. This
        # intentionally excludes hair even where it overlaps the brow region.
        brow_rule=profile.get('brow_hsv',{'hue_min':.05,'hue_max':.084,'saturation_min':.25,'value_min':.15,'value_max':.9,'center_hue_max':.084})
        brow_color_match=brow_rule['hue_min']<=h<brow_rule['hue_max'] and (s>brow_rule['saturation_min'] or v<.15) and 0<=v<brow_rule['value_max'] and center_h<brow_rule['center_hue_max']
        if brow_color_match or (profile and triangle_has_skin(face)):
            brow_surface_faces.add(index)

# Choose front-facing facial skin and features. Hair, rear head and ears keep
# their original material and UVs. Texture colors identify skin independently
# of the fragmented UV layout; eyes/eyebrows remain part of the facial chart.
facial_faces=[]
verified_expression_faces=set(profile.get('verified_expression_face_indices',[]))
face_boundary=profile.get('facial_boundary_polygon')
verified_brow_boundary_exceptions=set(profile.get('verified_eyebrow_face_indices',[]))

def inside_face_boundary(world):
    if not face_boundary:return True
    p=screen_physical(world);inside=False
    for a,b in zip(face_boundary,face_boundary[1:]+face_boundary[:1]):
        if (a[1]>p.y)!=(b[1]>p.y) and p.x<(b[0]-a[0])*(p.y-a[1])/(b[1]-a[1])+a[0]:
            inside=not inside
    return inside

for face in me.polygons:
    world_points=[head.matrix_world@me.vertices[index].co for index in face.vertices]
    # Exact original brow triangle evidence can include a partly hidden corner
    # beyond the conservative inner-face boundary; never exempt hair by color.
    if not all(inside_face_boundary(point) for point in world_points) and face.index not in verified_brow_boundary_exceptions:continue
    centroid=sum(world_points,Vector())/len(world_points);p=screen(centroid)
    if not (220<p.x<560 and 365<p.y<676):
        continue
    uv=sum((original_uv[index] for index in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
    color=uv_color(uv);h,s,v=colorsys.rgb_to_hsv(*color)
    # Include adjoining peach skin across the new angled eyebrow's extent.
    # A partly hidden corner must not cut an eyebrow into triangular fragments.
    if brow_boxes:
        eyebrow_skin=physical_boxes(centroid,brow_boxes) and triangle_has_skin(face)
    else:
        eyebrow_skin=(248<p.x<343 or 416<p.x<525) and 410<p.y<490 and h<.083 and v>.88 and s<.5
    old_brow=face.index in brow_surface_faces or eyebrow_skin
    verified_expression=face.index in verified_expression_faces
    if not old_brow and not verified_expression and not visible(centroid,.003):
        continue
    if not old_brow and not verified_expression and not all(visible(point,.002) for point in world_points):
        continue
    skin=skin_color(h,s,v)
    # Original cheek/chin shadows can be yellower than forehead skin. Limit
    # this relaxed color range to the visible lower central face, below brows;
    # using it over the upper head would incorrectly reproject pale golden hair.
    if profile and 250<p.x<520 and 490<p.y<676:
        skin=skin or ((h<.11 or h>.95) and s<.7 and v>.7)
    if profile.get('eye_boxes'):
        eye_area=physical_boxes(centroid,profile['eye_boxes'])
    else:
        eye_area=(245<p.x<343 or 416<p.x<525) and 433<p.y<582
    brow_or_eye=eye_area and (v<.60 or s<.24)
    mouth=340<p.x<431 and 580<p.y<650
    if skin or brow_or_eye or mouth or old_brow or verified_expression:
        facial_faces.append(face.index)
if len(facial_faces)<50:
    raise RuntimeError('Too few front facial triangles selected: '+str(len(facial_faces)))

chart=me.uv_layers.new(name='FaceExpressionUV')
facial_set=set(facial_faces)
for face in me.polygons:
    for loop_index in face.loop_indices:
        chart.data[loop_index].uv=original_uv[loop_index]
        if face.index in facial_set:
            world=head.matrix_world@me.vertices[me.loops[loop_index].vertex_index].co
            p=screen_physical(world)
            chart.data[loop_index].uv=(p.x/768,1-p.y/768)

# Render the original coloration in the same orthographic frame. This contains
# one readable face; GPT can now change expression without interpreting UV islands.
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.view_settings.exposure=0
scene.view_settings.gamma=1
scene.display.shading.light='FLAT'
scene.display.shading.color_type='TEXTURE'
scene.display.shading.background_type='VIEWPORT'
scene.display.shading.background_color=(.82,.82,.82)
scene.display.shading.show_shadows=False
cam_data=bpy.data.cameras.new('FaceProjectionCamera');cam_data.type='ORTHO'
cam=bpy.data.objects.new('FaceProjectionCamera',cam_data);scene.collection.objects.link(cam)
cam_data.ortho_scale=scale;cam.location=(camx,-10,camz);cam.rotation_euler=(math.radians(90),0,0)
scene.camera=cam
scene.render.resolution_x=scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(out_dir/'FaceExpression_source.png')
me.uv_layers.active=me.uv_layers[source_uv_name]
head_mat.node_tree.nodes.active=tex
bpy.ops.render.render(write_still=True)

# Add a thin curved surface over the old recessed mouth's overlapping inner
# triangles. This avoids open-mouth cracks without removing original polygons.
# The cap uses the same continuous facial chart and the same expression material.
old_face_count=len(me.polygons)
old_loop_count=len(me.loops)
saved_materials=list(me.materials)
saved_normals=[normal.vector.copy() for normal in me.corner_normals]
saved_source_uv=[point.uv.copy() for point in me.uv_layers[source_uv_name].data]
saved_chart_uv=[point.uv.copy() for point in chart.data]
coords=[v.co.copy() for v in me.vertices]
polys=[list(face.vertices) for face in me.polygons]
material_indices=[face.material_index for face in me.polygons]
cap_start=len(coords)


def cap_point(sx,sy):
    sx,sy=to_physical(sx,sy)
    x=camx+(sx/768-.5)*scale;z=camz+(.5-sy/768)*scale
    point=Vector((x,0,z));point.y=surface_y(point)-.001
    return head.matrix_world.inverted()@point


coords.append(cap_point(385,614))
segments=32;rings=4
for ring in range(1,rings+1):
    r=ring/rings
    for index in range(segments):
        theta=index/segments*math.tau
        coords.append(cap_point(385+cap_radius[0]*r*math.cos(theta),614-cap_radius[1]*r*math.sin(theta)))
cap_polys=[]
for index in range(segments):
    cap_polys.append([cap_start,cap_start+1+index,cap_start+1+(index+1)%segments])
for ring in range(1,rings):
    inner=cap_start+1+(ring-1)*segments;outer=cap_start+1+ring*segments
    for index in range(segments):
        nxt=(index+1)%segments
        cap_polys.append([inner+index,outer+index,outer+nxt])
        cap_polys.append([inner+index,outer+nxt,inner+nxt])
polys.extend(cap_polys)
new_mesh=bpy.data.meshes.new('Head_ExpressionGeometry')
new_mesh.from_pydata(coords,[],polys)
new_mesh.update()
for material in saved_materials:new_mesh.materials.append(material)
new_source_uv=new_mesh.uv_layers.new(name=source_uv_name)
new_chart=new_mesh.uv_layers.new(name='FaceExpressionUV')
new_normals=[]
for face in new_mesh.polygons:
    if face.index<old_face_count:
        face.material_index=material_indices[face.index]
    for loop_index in face.loop_indices:
        if loop_index<old_loop_count:
            new_source_uv.data[loop_index].uv=saved_source_uv[loop_index]
            new_chart.data[loop_index].uv=saved_chart_uv[loop_index]
            new_normals.append(saved_normals[loop_index])
        else:
            world=head.matrix_world@new_mesh.vertices[new_mesh.loops[loop_index].vertex_index].co
            p=screen_physical(world)
            new_source_uv.data[loop_index].uv=(0,0)
            new_chart.data[loop_index].uv=(p.x/768,1-p.y/768)
            dx=coef[1]+2*coef[3]*world.x+coef[4]*world.z
            dz=coef[2]+coef[4]*world.x+2*coef[5]*world.z
            new_normals.append((head.matrix_world.to_3x3().transposed()@Vector((dx,-1,dz)).normalized()).normalized())
new_mesh.normals_split_custom_set(new_normals)
head.data=new_mesh;me=new_mesh;chart=new_chart
facial_faces.extend(range(old_face_count,len(me.polygons)))
facial_set=set(facial_faces)

# Create a separate expression material only for selected face triangles.
# The PNG is a CG projection, not a hand-painted or programmatically edited image.
face_image=bpy.data.images.load(str(out_dir/'FaceExpression_source.png'),check_existing=False)
face_mat=bpy.data.materials.new('FaceExpressionMat');face_mat.use_nodes=True
face_bsdf=face_mat.node_tree.nodes.get('Principled BSDF')
face_tex=face_mat.node_tree.nodes.new('ShaderNodeTexImage');face_tex.image=face_image
face_uv=face_mat.node_tree.nodes.new('ShaderNodeUVMap');face_uv.uv_map='FaceExpressionUV'
face_mat.node_tree.links.new(face_uv.outputs['UV'],face_tex.inputs['Vector'])
face_mat.node_tree.links.new(face_tex.outputs['Color'],face_bsdf.inputs['Base Color'])
face_mat.node_tree.nodes.active=face_tex
face_bsdf.inputs['Roughness'].default_value=.8
me.materials.append(face_mat);face_mat_index=len(me.materials)-1
for face in me.polygons:
    if face.index in facial_set:
        face.material_index=face_mat_index

# Bake source facial color directly into the continuous UV chart. Rendering the
# whole head would project foreground hair onto skin partly hidden by the fringe.
# This separate face-only bake preserves true original skin behind the hair.
bake_mesh=bpy.data.meshes.new('FaceExpression_BakeMesh')
bake_mesh.from_pydata([v.co.copy() for v in me.vertices],[],[list(me.polygons[index].vertices) for index in facial_faces])
bake_mesh.update()
bake_obj=bpy.data.objects.new('FaceExpression_BakeObject',bake_mesh)
scene.collection.objects.link(bake_obj);bake_obj.matrix_world=head.matrix_world.copy()
bake_src_uv=bake_mesh.uv_layers.new(name='SourceUV')
bake_dst_uv=bake_mesh.uv_layers.new(name='ProjectionUV')
loop_cursor=0
for original_face_index in facial_faces:
    original_face=me.polygons[original_face_index]
    for original_loop_index in original_face.loop_indices:
        bake_src_uv.data[loop_cursor].uv=me.uv_layers[source_uv_name].data[original_loop_index].uv
        bake_dst_uv.data[loop_cursor].uv=chart.data[original_loop_index].uv
        loop_cursor+=1
baked_image=bpy.data.images.new('FaceExpression_ContinuousSource',1024,1024,alpha=False)
for source_image,source_uv in [(src_image,'SourceUV'),(face_image,'ProjectionUV')]:
    material=bpy.data.materials.new('FaceBake_'+source_uv);material.use_nodes=True
    nodes=material.node_tree.nodes;links=material.node_tree.links;nodes.clear()
    out=nodes.new('ShaderNodeOutputMaterial');emission=nodes.new('ShaderNodeEmission')
    source_texture=nodes.new('ShaderNodeTexImage');source_texture.image=source_image
    source_map=nodes.new('ShaderNodeUVMap');source_map.uv_map=source_uv
    target=nodes.new('ShaderNodeTexImage');target.image=baked_image
    links.new(source_map.outputs['UV'],source_texture.inputs['Vector'])
    links.new(source_texture.outputs['Color'],emission.inputs['Color'])
    links.new(emission.outputs['Emission'],out.inputs['Surface'])
    nodes.active=target;bake_mesh.materials.append(material)
for face,index in zip(bake_mesh.polygons,facial_faces):
    face.material_index=1 if index>=old_face_count else 0
bake_mesh.uv_layers.active=bake_dst_uv
bpy.ops.object.select_all(action='DESELECT');bake_obj.select_set(True)
bpy.context.view_layer.objects.active=bake_obj
scene.render.engine='CYCLES';scene.cycles.samples=1;scene.cycles.device='CPU'
scene.render.bake.margin=4
bpy.ops.object.bake(type='EMIT',margin=4)
baked_image.file_format='PNG'
baked_image.filepath_raw=str(out_dir/'FaceExpression_continuous_source.png')
baked_image.save()
# Keep the full continuous color projection as the runtime source. The bake is
# diagnostic; sparse empty texels are too sensitive to GPT border movement.
face_tex.image=face_image
bpy.data.objects.remove(bake_obj,do_unlink=True)

# Blender workbench displays active UVs globally. The glTF node UV map indices
# preserve the independent original and facial UVs in the exported copy.
me.uv_layers.active=chart
for node in head_mat.node_tree.nodes:
    if node.type=='UVMAP':
        node.uv_map=source_uv_name
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':obj.select_set(True)
copy_path=out_dir/(asset_name+'_FaceExpression_prepared.glb')
bpy.ops.export_scene.gltf(filepath=str(copy_path),export_format='GLB',use_selection=True,export_yup=True)

unchanged_uv_count=0
for face in me.polygons:
    if face.index not in facial_set:
        for loop_index in face.loop_indices:
            if tuple(me.uv_layers[source_uv_name].data[loop_index].uv)!=tuple(original_uv[loop_index]):
                raise RuntimeError('Non-facial original UV changed')
            unchanged_uv_count+=1
changed_vertex_indices=[i for i,v in enumerate(me.vertices[:len(original_coords)]) if (v.co-original_coords[i]).length>1e-9]
if set(changed_vertex_indices)-set(mouth_vertices):
    raise RuntimeError('Unexpected non-mouth vertex mutation')
if hashlib.sha256(source.read_bytes()).hexdigest()!=source_sha:
    raise RuntimeError('Original GLB changed')
report={'source':str(source),'source_sha256':source_sha,'source_file_unchanged':True,'body_unchanged':True,'hair_rear_ear_original_uv_preserved':True,'original_uv_layer':source_uv_name,'new_uv_layer':'FaceExpressionUV','facial_uv_scope':'front-visible skin/features, plus visible original eyebrow surface hits whose centroid may be under the fringe; original UV layer retained','original_eyebrow_faces_in_expression_uv':sorted(brow_surface_faces),'facial_faces':len(facial_faces),'total_head_faces':len(me.polygons),'mouth_geometry_modified_vertices':len(changed_vertex_indices),'mouth_vertex_indices':changed_vertex_indices,'mouth_cap_added_vertices':len(coords)-cap_start,'mouth_cap_added_triangles':len(cap_polys),'non_facial_uv_loops_unchanged':unchanged_uv_count,'mesh_objects':[(obj.name,len(obj.data.polygons)) for obj in bpy.context.scene.objects if obj.type=='MESH'],'exported_materials':['HeadMat','FaceExpressionMat','BodyMat'],'expected_gltf_head_primitives':2,'copy':str(copy_path),'expression_input':str(out_dir/'FaceExpression_source.png'),'camera_scale':scale,'camera_center':[camx,camz]}
report['reviewed_profile']=profile
report['original_facial_uv_signatures']=[tuple(sorted((round(saved_source_uv[i].x,6),round(saved_source_uv[i].y,6)) for i in me.polygons[index].loop_indices)) for index in facial_faces if index<old_face_count]
cap_world=[head.matrix_world@me.vertices[index].co for index in range(cap_start,len(me.vertices))]
report['mouth_cap_source_gltf_positions']=[[point.x,point.z,-point.y] for point in cap_world]
report['mouth_cap_source_indices']=[[index-cap_start for index in face] for face in cap_polys]
report['mouth_cap_face_uv']=[[(point.x-camx)/scale+.5,(point.z-camz)/scale+.5] for point in cap_world]
report['mouth_cap_source_normals']=[]
for point in cap_world:
 dx=coef[1]+2*coef[3]*point.x+coef[4]*point.z
 dz=coef[2]+coef[4]*point.x+2*coef[5]*point.z
 n=Vector((dx,dz,1)).normalized()
 report['mouth_cap_source_normals'].append(list(n))
(out_dir/'prepare_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('[prepare_face_uv] '+json.dumps(report),flush=True)
