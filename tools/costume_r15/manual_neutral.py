"""Offline, explicitly inferred Neutral R15 candidates; never an original/validated skeleton.

py tools/costume_r15/manual_neutral.py NeutralWarriorF --dry
py tools/costume_r15/manual_neutral.py NeutralWarriorF --out build/manual_partition_candidates/NeutralWarriorF
blender --background --factory-startup --python tools/costume_r15/manual_neutral.py -- --render LANDMARKS.json OUT_DIR
py tools/costume_r15/manual_neutral.py --bind-continuous LANDMARKS.json NEW.glb --canonical-height 5.5
blender --background --factory-startup --python tools/costume_r15/manual_neutral.py -- --render-skin NEW.glb NEW_QA_DIR

The approved fixed GLB is read only. No network, upload, texture re-encoding, or source writes.
Each existing triangle receives exactly one mechanical owner; anatomy needs actual motion QA.
Continuous skin candidates preserve all original static accessors and add only weights/bones
plus an optional global game-coordinate wrapper. Never run these through the rigid converter.
"""
import argparse
from collections import Counter, defaultdict
import copy
import hashlib
import json
import math
from pathlib import Path
import sys
import struct

sys.path.insert(0, str(Path(__file__).resolve().parent))
from constraints import PRIMARY, PARENTS, RigError, adjacent_regions
from glb_io import accessor_values, image_bytes, read_glb, write_glb

ROOT = Path(__file__).resolve().parents[2]
TUNING = {
    "NeutralWarriorF": {
        "neck": .557, "waist": .398, "hip": .305,
        "shoulder": (.145, .482), "elbow": (.193, .420), "wrist": (.237, .353),
        "hand_tip": (.277, .283), "leg_x": .094, "knee": .226, "ankle": .072,
        "head_plane": .570, "hair_y": .530, "hair_back": -.042,
        "reason": "정면 장갑의 위/아래 금색 띠·무릎판·부츠 발등과 측면 팔 방향을 읽은 후보",
    },
    "NeutralArcherM": {
        "neck": .590, "waist": .397, "hip": .296,
        "shoulder": (.137, .543), "elbow": (.177, .460), "wrist": (.225, .383),
        "hand_tip": (.250, .310), "leg_x": .110, "knee": .216, "ankle": .070,
        "head_plane": .605, "hair_y": .590, "hair_back": -.048,
        "reason": "정면 털 소매/가죽 장갑 경계·무릎 덮개·부츠 발등과 측면 코트 아래 다리 방향을 읽은 후보",
    },
}


def length(v):
    return math.sqrt(sum(x*x for x in v))


def segment_distance(point, first, second):
    direction = [b-a for a, b in zip(first, second)]
    size = sum(v*v for v in direction)
    if size < 1e-14:
        raise RigError("Degenerate inferred limb segment")
    t = max(0.0, min(1.0, sum((p-a)*d for p, a, d in zip(point, first, direction))/size))
    return length([p-(a+t*d) for p, a, d in zip(point, first, direction)])


def quantile(values, fraction):
    values = sorted(values)
    return values[round((len(values)-1)*fraction)]


def coherent_small_islands(rows, assignments):
    """Reassign only tiny disconnected owner islands to a touching adjacent region.

    This changes no triangle/attribute. Keep each owner's largest component and
    all substantial original garment components; inferred seams remain pending QA.
    """
    labels, edges = [], defaultdict(list)
    for row, assignment in zip(rows, assignments):
        for offset, owner in zip(range(0,len(row["indices"]),3),assignment["owners"]):
            keys=[tuple(round(c,6) for c in row["points"][i]) for i in row["indices"][offset:offset+3]]
            face=len(labels);labels.append(owner)
            for first,second in zip(keys,keys[1:]+keys[:1]):
                edges[tuple(sorted((first,second)))].append(face)
    neighbors=[set() for _ in labels]
    for faces in edges.values():
        for face in faces:neighbors[face].update(set(faces)-{face})
    changes=[]
    for iteration in range(3):
        seen=set(); groups=defaultdict(list)
        for seed,part in enumerate(labels):
            if seed in seen:continue
            todo=[seed];seen.add(seed);group=[]
            while todo:
                face=todo.pop();group.append(face)
                for neighbor in neighbors[face]:
                    if neighbor not in seen and labels[neighbor]==part:
                        seen.add(neighbor);todo.append(neighbor)
            groups[part].append(group)
        edits=[]
        for part,components in groups.items():
            components.sort(key=len,reverse=True)
            for group in components[1:]:
                if len(group)>32:continue
                group_set=set(group)
                touching=Counter(labels[neighbor] for face in group for neighbor in neighbors[face]
                                 if neighbor not in group_set and adjacent_regions(part,labels[neighbor]))
                if touching:
                    target=sorted(touching,key=lambda item:(-touching[item],item))[0]
                    edits.append((group,part,target))
        if not edits:break
        for group,part,target in edits:
            for face in group:labels[face]=target
            changes.append({"pass":iteration+1,"from":part,"to":target,"triangles":len(group),"reason":"Small disconnected source-edge island joins a touching adjacent R15 region; no surface edit."})
    offset=0
    for assignment in assignments:
        size=len(assignment["owners"]);assignment["owners"]=labels[offset:offset+size];offset+=size
    return changes


def prepare(name):
    if name not in TUNING:
        raise RigError("Only the two authorized Neutral fixed originals are supported")
    source = ROOT / "art/models/costume/fixed" / ("Costume_"+name+".glb")
    gltf, binary, raw = read_glb(source)
    if gltf.get("skins") or gltf.get("animations"):
        raise RigError("This manual tool accepts a static original, never replaces an existing skin")
    roots = gltf.get("scenes", [])[gltf.get("scene", 0)].get("nodes", [])
    if len(roots) != len(gltf.get("meshes", [])):
        raise RigError("Expected the verified fixed Body/Head root nodes")
    for node in gltf.get("nodes", []):
        if "mesh" not in node or set(node)-{"mesh", "name"}:
            raise RigError("Only the inspected identity-transform fixed nodes are supported")
    rows, all_points = [], []
    for mesh_i, mesh in enumerate(gltf["meshes"]):
        for primitive_i, primitive in enumerate(mesh["primitives"]):
            if primitive.get("mode", 4) != 4 or "indices" not in primitive:
                raise RigError("Expected indexed original triangles")
            attributes = primitive["attributes"]
            if not {"POSITION", "NORMAL", "TEXCOORD_0"} <= set(attributes):
                raise RigError("Original position/UV/normal accessors are required")
            points = accessor_values(gltf, binary, attributes["POSITION"])
            indices = [v[0] for v in accessor_values(gltf, binary, primitive["indices"])]
            if len(indices)%3 or any(i >= len(points) for i in indices):
                raise RigError("Invalid source triangle indices")
            rows.append({"mesh": mesh_i, "primitive": primitive_i, "material": primitive.get("material"), "points": points, "indices": indices})
            all_points.extend(points)
    if not all(math.isfinite(v) for p in all_points for v in p):
        raise RigError("Nonfinite source geometry")
    low = [min(p[i] for p in all_points) for i in range(3)]
    high = [max(p[i] for p in all_points) for i in range(3)]
    height = high[1]-low[1]
    if height <= 0:
        raise RigError("Zero source height")
    center_x = (low[0]+high[0])/2
    tune = TUNING[name]
    body_points = rows[0]["points"]
    landmarks, evidence, anchors = {}, {}, {}

    def joint(part, x_frac, y_frac, width=.044, prefer_body=True):
        # Visible height bands are selected by a human from the front/side renders.
        # The hidden center is only a midpoint of actual local surface extents.
        x, y = center_x+x_frac*height, low[1]+y_frac*height
        pool = body_points if prefer_body else all_points
        samples = [p for p in pool if abs(p[0]-x)<=width*height and abs(p[1]-y)<=.011*height]
        if len(samples)<4:
            samples = [p for p in all_points if abs(p[0]-x)<=width*height and abs(p[1]-y)<=.017*height]
        if len(samples)<4:
            raise RigError("No actual local surface support for "+part)
        x0, x1 = quantile([p[0] for p in samples], .05), quantile([p[0] for p in samples], .95)
        z0, z1 = quantile([p[2] for p in samples], .05), quantile([p[2] for p in samples], .95)
        pos = [(x0+x1)/2, y, (z0+z1)/2]
        landmarks[part] = pos
        near = sorted(samples, key=lambda p:length([a-b for a,b in zip(p,pos)]))[:4]
        anchors[part] = {"sample_count":len(samples), "source_surface_points":[list(p) for p in near], "surface_extent_x":[x0,x1], "surface_extent_z":[z0,z1], "height_band":[y-.011*height,y+.011*height], "selected_height_fraction":y_frac, "center_is_inferred":True}
        evidence[part] = tune["reason"]+". 원본 표면 "+str(len(samples))+"점의 양쪽 단면 중간을 임시 회전 중심으로 사용. 옷 안 실제 뼈/정확한 해부학 관절이 아니며 동작 검증 전 게임 등록 불가."

    joint("LowerTorso",0,tune["hip"],.055)
    joint("UpperTorso",0,tune["waist"],.055)
    joint("Head",0,tune["neck"],.047,False)
    for side, sign in [("Left",1),("Right",-1)]:
        for suffix, key in [("UpperArm","shoulder"),("LowerArm","elbow"),("Hand","wrist")]:
            x,y = tune[key]
            joint(side+suffix,sign*x,y)
        joint(side+"UpperLeg",sign*tune["leg_x"],tune["hip"]-.010,.048)
        joint(side+"LowerLeg",sign*tune["leg_x"],tune["knee"],.048)
        joint(side+"Foot",sign*tune["leg_x"],tune["ankle"],.048)
    if set(landmarks) != set(PRIMARY):
        raise RigError("Missing inferred primary joint")

    def owner(point, mesh):
        x,y,z = point
        fy = (y-low[1])/height
        ax = abs(x-center_x)/height
        # Use the neck plane/actual back-hair geometry, never all HeadMat faces.
        # Fur collars/central low head-material triangles stay with the torso.
        rear_hair = name=="NeutralWarriorF" and fy>.425 and z<-.10*height
        if fy >= tune["head_plane"] or rear_hair or (mesh==1 and fy>=tune["hair_y"] and ax>.10 and z<tune["hair_back"]*height):
            return "Head"
        side = "Left" if x>=center_x else "Right"
        shoulder, elbow, wrist = [landmarks[side+p] for p in ["UpperArm","LowerArm","Hand"]]
        tip = [center_x+(1 if side=="Left" else -1)*tune["hand_tip"][0]*height, low[1]+tune["hand_tip"][1]*height,wrist[2]]
        # A connected chain separates actual outboard limbs from central bags/tails.
        chain = [shoulder,elbow,wrist,tip]
        cx = abs(shoulder[0]-center_x)/height
        for first,second in zip(chain,chain[1:]):
            if min(first[1],second[1])<=y<=max(first[1],second[1]):
                t = (y-first[1])/(second[1]-first[1])
                cx = abs(first[0]+t*(second[0]-first[0])-center_x)/height
                break
        if tune["hand_tip"][1]-.025<=fy<=tune["shoulder"][1]+.055 and ax>=max(.115,cx-.045):
            choices = [(side+"UpperArm",shoulder,elbow),(side+"LowerArm",elbow,wrist),(side+"Hand",wrist,tip)]
            nearest=min(choices,key=lambda item:segment_distance(point,item[1],item[2]))
            # Front waist pouches can lie at the hand's X/Y but are outside the
            # measured limb depth. Do not make those original bag faces fly with an arm.
            if segment_distance(point,nearest[1],nearest[2])<=.085*height:
                return nearest[0]
        if fy>=tune["hip"]-.014:
            return "UpperTorso" if fy>=tune["waist"] else "LowerTorso"
        # Coat/apron extensions keep their original rigid parent, not a guessed knee.
        if name=="NeutralArcherM" and fy>.20 and (ax<.048 or abs(z)>.09*height):
            return "LowerTorso"
        if ax>.18 and fy>.235:
            return "LowerTorso"
        hip,knee,ankle = [landmarks[side+p] for p in ["UpperLeg","LowerLeg","Foot"]]
        toe = [ankle[0],low[1]+.025*height,ankle[2]+.075*height]
        choices=[(side+"UpperLeg",hip,knee),(side+"LowerLeg",knee,ankle),(side+"Foot",ankle,toe)]
        return min(choices,key=lambda item:segment_distance(point,item[1],item[2]))[0]

    triangle_owners, counts, material_counts = [], Counter(), {}
    for row in rows:
        owners=[]
        for offset in range(0,len(row["indices"]),3):
            vertices=[row["points"][i] for i in row["indices"][offset:offset+3]]
            centroid=[sum(p[i] for p in vertices)/3 for i in range(3)]
            part=owner(centroid,row["mesh"])
            if part not in PRIMARY:
                raise RigError("Unassigned original face")
            owners.append(part); counts[part]+=1
        triangle_owners.append({"mesh":row["mesh"],"primitive":row["primitive"],"owners":owners})
        material_counts[str(row["material"])]=dict(Counter(owners))
    coherent_changes=coherent_small_islands(rows,triangle_owners)
    counts=Counter(part for assignment in triangle_owners for part in assignment["owners"])
    material_counts={str(row["material"]):dict(Counter(assignment["owners"])) for row,assignment in zip(rows,triangle_owners)}
    if any(counts[part]==0 for part in PRIMARY):
        raise RigError("Empty inferred candidate part: "+str(dict(counts)))
    if sum(counts.values()) != sum(len(row["indices"])//3 for row in rows):
        raise RigError("Original triangle count changed")
    return {"schema":1,"name":"Costume_"+name,"source":source.relative_to(ROOT).as_posix(),"source_sha256":hashlib.sha256(raw).hexdigest(),"coordinates":"gltf_world_y_up","rig_origin":"inferred_manual_candidate","rig_ready_for_game":False,"original_skeleton":False,"landmarks":landmarks,"landmark_evidence":evidence,"landmark_surface_support":anchors,"triangle_owners":triangle_owners,"original_triangle_count":sum(counts.values()),"part_triangle_counts":dict(counts),"material_part_counts":material_counts,"small_island_owner_repairs":coherent_changes,"source_bounds":{"min":low,"max":high},"source_images":[{"sha256":hashlib.sha256(image_bytes(gltf,binary,img)).hexdigest(),"bytes":len(image_bytes(gltf,binary,img))} for img in gltf.get("images",[])],"geometry_policy":"Every original triangle once; no topology/UV/corner-normal/material/texture edits. Face ownership is explicitly inferred, not original bone weights.","limitations":["Clothed joint centers are inferred from visible garment/limb surfaces, not captured bones.","Hair and coat rigid ownership may visibly separate at joints; render and engine motion QA are required.","All outputs stay local candidates; no playable registry/Studio/API calls."]}


def render(manifest_path, output):
    import bpy
    from mathutils import Vector
    doc=json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    if doc.get("rig_ready_for_game") is not False or doc.get("rig_origin")!="inferred_manual_candidate":
        raise RigError("Only an explicit unregistered candidate can be rendered")
    source=ROOT/doc["source"]
    if hashlib.sha256(source.read_bytes()).hexdigest()!=doc["source_sha256"]:
        raise RigError("Source changed after landmark selection")
    output=Path(output).resolve()
    output.relative_to((ROOT/"build").resolve())
    output.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    original_meshes=[obj for obj in bpy.context.scene.objects if obj.type=="MESH"]
    points=[obj.matrix_world@v.co for obj in original_meshes for v in obj.data.vertices]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    height=high.z-low.z; center=(low+high)/2
    material=bpy.data.materials.new("InferredLandmarkGizmo")
    material.diffuse_color=(.02,.55,1,1)
    for part,pos in doc["landmarks"].items():
        # glTF world (x,y,z) becomes Blender (x,-z,y).
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=height*.013,location=(pos[0],-pos[2],pos[1]))
        gizmo=bpy.context.object;gizmo.name="INFERRED_"+part;gizmo.data.materials.append(material);gizmo.show_in_front=True
    scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH"
    scene.display.shading.light="FLAT";scene.display.shading.color_type="TEXTURE"
    scene.display.shading.background_type="VIEWPORT";scene.display.shading.background_color=(.85,.85,.85)
    scene.display.shading.show_shadows=False
    cam_data=bpy.data.cameras.new("CandidateCamera");cam_data.type="ORTHO";cam_data.ortho_scale=max(high-low)*1.1
    cam=bpy.data.objects.new("CandidateCamera",cam_data);scene.collection.objects.link(cam);scene.camera=cam
    scene.render.resolution_x=scene.render.resolution_y=768;scene.render.resolution_percentage=100
    for label,direction in [("front",Vector((0,-1,0))),("side",Vector((-1,0,0)))]:
        cam.location=center+direction*10
        cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(output/("inferred_gizmos_"+label+".png"));bpy.ops.render.render(write_still=True)
    print("inferred gizmo preview saved",output,flush=True)


def bind_continuous(config_path, output, canonical_height=None):
    """Keep the original two surfaces intact and add continuous vertex weights.

    The only added binary arrays are JOINTS/WEIGHTS and inverse bind matrices.
    Equal original positions receive identical weights, including UV/normal seams.
    This is an inferred local experiment, never a playable template registration.
    """
    from manual_bind import validate_config, face_counter
    from restore_material_regions import append_accessor, append_view, primitives
    config_path, output = Path(config_path).resolve(), Path(output).resolve()
    config = json.loads(config_path.read_text(encoding="utf-8"))
    name = config.get("name","").removeprefix("Costume_")
    source = (ROOT / config["source"]).resolve()
    if name not in TUNING or source != ROOT / "art/models/costume/fixed" / ("Costume_"+name+".glb"):
        raise RigError("Continuous binding accepts only the two approved Neutral originals")
    gltf, binary, original = read_glb(source)
    if hashlib.sha256(original).hexdigest() != config["source_sha256"]:
        raise RigError("The approved static source changed")
    output.relative_to((ROOT / "build/manual_partition_candidates").resolve())
    audit = output.with_suffix(".skin.json")
    if output.exists() or audit.exists():
        raise RigError("Existing skin candidates are never overwritten")
    rows, owners, counts = validate_config(config, gltf, binary)
    votes, neighbors = defaultdict(Counter), defaultdict(set)
    def key(point):
        return tuple(round(axis, 6) for axis in point)
    for row in rows:
        points = row["values"]["POSITION"]
        for triangle, owner in zip(row["triangles"], owners[(row["mesh"], row["primitive"])]):
            keys = [key(points[index]) for index in triangle]
            for vertex in keys:
                votes[vertex][owner] += 1
                neighbors[vertex].update(set(keys) - {vertex})
    # Smooth only a narrow source-edge band. Interior garment/face points remain
    # rigid; boundary vertices and their neighbors form a continuous transition.
    seeds = {vertex for vertex, values in votes.items() if len(values) > 1}
    band = set(seeds)
    frontier = seeds
    for _ in range(4):
        frontier = {neighbor for vertex in frontier for neighbor in neighbors[vertex]} - band
        band.update(frontier)
    weights = {vertex: {part: count / sum(values.values()) for part, count in values.items()}
               for vertex, values in votes.items()}
    original_weights = copy.deepcopy(weights)
    for _ in range(16):
        next_weights = dict(weights)
        for vertex in band:
            mixed = Counter({part: value * .2 for part, value in original_weights[vertex].items()})
            adjacent = neighbors[vertex]
            if not adjacent:
                continue
            for neighbor in adjacent:
                for part, value in weights[neighbor].items():
                    mixed[part] += value * .8 / len(adjacent)
            selected = sorted(mixed.items(), key=lambda item: (-item[1], item[0]))[:4]
            total = sum(value for _, value in selected)
            next_weights[vertex] = {part: value / total for part, value in selected}
        weights = next_weights
    result, rebuilt = copy.deepcopy(gltf), binary
    parts = list(PRIMARY)
    bone_index = {part: index for index, part in enumerate(parts)}
    joint_start = len(result["nodes"])
    for part in parts:
        parent = PARENTS[part]
        point = config["landmarks"][part]
        local = point if parent == "HumanoidRootPart" else [a-b for a,b in zip(point, config["landmarks"][parent])]
        node = {"name": part, "translation": local,
                "extras": {"HHC_ManualInferredJoint": True, "HHC_ManualPart": part}}
        children = [joint_start + bone_index[child] for child in parts if PARENTS[child] == part]
        if children:
            node["children"] = children
        result["nodes"].append(node)
    matrices = [(1,0,0,0,0,1,0,0,0,0,1,0,-point[0],-point[1],-point[2],1)
                for point in (config["landmarks"][part] for part in parts)]
    view, rebuilt = append_view(result, rebuilt, b"".join(struct.pack("<16f", *matrix) for matrix in matrices))
    inverse_accessor = len(result["accessors"])
    result["accessors"].append({"bufferView": view, "componentType": 5126, "count": 15, "type": "MAT4"})
    result["skins"] = [{"name": config["name"] + "_ContinuousInferredSkin",
                        "skeleton": joint_start, "joints": list(range(joint_start, joint_start+15)),
                        "inverseBindMatrices": inverse_accessor}]
    for row in rows:
        joints, values = [], []
        for point in row["values"]["POSITION"]:
            selected = sorted(weights[key(point)].items(), key=lambda item: (-item[1], item[0]))
            joints.append(tuple([bone_index[part] for part,_ in selected] + [0]*(4-len(selected))))
            values.append(tuple([weight for _,weight in selected] + [0.]*(4-len(selected))))
        primitive = result["meshes"][row["mesh"]]["primitives"][row["primitive"]]
        primitive["attributes"]["JOINTS_0"], rebuilt = append_accessor(result, rebuilt, joints, 5123, "VEC4", 34962)
        primitive["attributes"]["WEIGHTS_0"], rebuilt = append_accessor(result, rebuilt, values, 5126, "VEC4", 34962)
        result["nodes"][row["node"]]["skin"] = 0
    # Keep visual skin names distinct from the 15 physical R15 proxy parts.
    # The bones intentionally use the standard R15 part names for retargeting.
    for mesh_index,mesh in enumerate(result["meshes"]):
        mesh["name"] = "CostumeSkin" + ("Body" if mesh_index == 0 else "Head")
    for node in result["nodes"]:
        if "mesh" in node:
            node["name"] = result["meshes"][node["mesh"]]["name"]
    root = len(result["nodes"])
    result["nodes"].append({"name": config["name"] + "_SkinCandidate",
                            "children": list(dict.fromkeys(row["node"] for row in rows)) + [joint_start]})
    affine = [[1.,0.,0.,0.],[0.,1.,0.,0.],[0.,0.,1.,0.],[0.,0.,0.,1.]]
    if canonical_height is not None:
        if not math.isfinite(canonical_height) or not 1. <= canonical_height <= 10.:
            raise RigError("Canonical height must be finite within 1-10 studs")
        points = [point for row in rows for point in row["values"]["POSITION"]]
        height = max(point[1] for point in points)-min(point[1] for point in points)
        scale = canonical_height/height
        origin = config["landmarks"]["LowerTorso"]
        affine = [[-scale,0.,0.,scale*origin[0]],[0.,scale,0.,-scale*origin[1]],
                  [0.,0.,-scale,scale*origin[2]],[0.,0.,0.,1.]]
        result["nodes"][root]["matrix"] = [affine[row][column] for column in range(4) for row in range(4)]
    result["scenes"], result["scene"] = [{"name":"ContinuousSkinCandidate", "nodes":[root]}], 0
    result["buffers"][0]["byteLength"] = len(rebuilt)
    provenance = {"rig_origin":"inferred_manual_candidate", "original_bones_claimed":False,
                  "rig_ready_for_game":False, "source":str(source), "source_sha256":config["source_sha256"],
                  "landmark_config":str(config_path), "weight_policy":"continuous_original_surface_edges_4ring_16passes",
                  "bone_names":parts, "original_geometry_accessors_reused":True,
                  "surface_or_uv_design_changed":False, "requires_studio_skin_motion_validation":True,
                  "source_to_game_affine":[affine[row][column] for column in range(4) for row in range(4)],
                  "affine_layout":"gltf_column_major_16","target_height_studs":canonical_height,
                  "source_frame_policy":"gltf-positive-z","source_original_local_vertex_bytes_preserved":True}
    result.setdefault("extras", {})["HHC_ManualBind"] = provenance
    validation_result = copy.deepcopy(result)
    # The verified global similarity changes only game placement/scale. The
    # surface proof compares the immutable original local corner attributes.
    validation_result["nodes"][root].pop("matrix",None)
    after = primitives(validation_result, rebuilt, True)
    for row in after:
        row["values"].pop("JOINTS_0"); row["values"].pop("WEIGHTS_0")
    if face_counter(rows) != face_counter(after) or not rebuilt.startswith(binary):
        raise RigError("Skin changed an approved source triangle or attribute")
    for old,new in zip(gltf.get("images",[]),result.get("images",[])):
        if image_bytes(gltf,binary,old) != image_bytes(result,rebuilt,new):
            raise RigError("Skin changed an original texture image")
    if source.read_bytes() != original:
        raise RigError("The source was modified")
    output.parent.mkdir(parents=True,exist_ok=True)
    write_glb(output,result,rebuilt)
    report = dict(provenance,output=str(output),output_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
                  original_triangles=sum(counts.values()),original_images_preserved=True,
                  source_file_unchanged=True,unique_surface_positions=len(weights),boundary_positions=len(seeds),
                  smoothing_band_positions=len(band),maximum_influences=4,shared_position_weight_error=0,
                  meshes=len(result["meshes"]),images=len(result.get("images",[])),api_calls=0,studio_calls=0)
    audit.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"name":config["name"],"skin_candidate":str(output),"triangles":sum(counts.values()),
                      "shared_position_weight_error":0,"source_changed":False,"rig_ready_for_game":False}))


def render_skin(path, output):
    """Render actual imported armature deformation and check it against LBS."""
    import bpy
    from mathutils import Matrix, Vector
    from mathutils.kdtree import KDTree
    path, output = Path(path).resolve(), Path(output).resolve()
    output.relative_to((ROOT/"build/manual_partition_candidates").resolve())
    if output.exists():
        raise RigError("Existing skin QA is never overwritten")
    gltf,binary,_ = read_glb(path)
    meta = gltf.get("extras",{}).get("HHC_ManualBind",{})
    if meta.get("rig_ready_for_game") is not False or meta.get("weight_policy") is None:
        raise RigError("Only an inferred continuous candidate can use skin QA")
    config = json.loads(Path(meta["landmark_config"]).read_text(encoding="utf-8"))
    parts = meta["bone_names"]
    by_position = {}
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            arrays = [accessor_values(gltf,binary,attributes[name]) for name in ("POSITION","JOINTS_0","WEIGHTS_0")]
            for point,joints,values in zip(*arrays):
                key = tuple(round(axis,6) for axis in point)
                weights = tuple((parts[int(joint)],weight) for joint,weight in zip(joints,values) if weight > 0)
                if key in by_position and by_position[key] != weights:
                    raise RigError("A shared original surface vertex has discontinuous weights")
                by_position[key] = weights
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    bpy.context.view_layer.update()
    position_keys = list(by_position)
    nearest = KDTree(len(position_keys))
    for index,key in enumerate(position_keys): nearest.insert(Vector(key),index)
    nearest.balance()
    to_blender = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    inverse = to_blender.inverted()
    affine_values = meta["source_to_game_affine"]
    affine = (Matrix([[affine_values[column*4+row] for column in range(4)] for row in range(4)])
              if len(affine_values)==16 else Matrix(affine_values))
    affine_inverse = affine.inverted()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"
              and any(modifier.type == "ARMATURE" for modifier in obj.modifiers)]
    if len(meshes) != len(gltf["meshes"]):
        raise RigError("The imported skinned surface count changed")
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1 or set(parts)-set(armatures[0].pose.bones.keys()):
        raise RigError("Imported skin lost an inferred R15 bone")
    armature = armatures[0]
    rest = [(obj,[obj.matrix_world@vertex.co for vertex in obj.data.vertices]) for obj in meshes]
    points = [point for _,array in rest for point in array]
    low = Vector(tuple(min(point[i] for point in points) for i in range(3)))
    high = Vector(tuple(max(point[i] for point in points) for i in range(3)))
    center = (low+high)/2
    scene = bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH"
    scene.display.shading.light="STUDIO";scene.display.shading.color_type="TEXTURE"
    scene.display.shading.background_type="VIEWPORT";scene.display.shading.background_color=(.83,.83,.83)
    camera_data=bpy.data.cameras.new("ContinuousSkinCamera");camera_data.type="ORTHO";camera_data.ortho_scale=max(high-low)*1.35
    camera=bpy.data.objects.new("ContinuousSkinCamera",camera_data);scene.collection.objects.link(camera);scene.camera=camera
    scene.render.resolution_x=scene.render.resolution_y=768;scene.render.resolution_percentage=100
    poses={"rest":{},
           "walk_left":{"LeftUpperLeg":[("X",.35)],"RightUpperLeg":[("X",-.35)],"RightLowerLeg":[("X",.45)],"LeftUpperArm":[("X",-.25)],"RightUpperArm":[("X",.25)]},
           "walk_right":{"LeftUpperLeg":[("X",-.35)],"RightUpperLeg":[("X",.35)],"LeftLowerLeg":[("X",.45)],"LeftUpperArm":[("X",.25)],"RightUpperArm":[("X",-.25)]},
           "arm_bend":{"LeftUpperArm":[("X",-.6),("Z",-.25)],"RightUpperArm":[("X",-.6),("Z",.25)],"LeftLowerArm":[("X",-.8)],"RightLowerArm":[("X",-.8)]},
           "attack_stress":{"UpperTorso":[("Y",.16)],"LeftUpperArm":[("X",-.8)],"RightUpperArm":[("X",-1.)],"RightLowerArm":[("X",-.8)],"LeftUpperLeg":[("X",-.15)],"RightUpperLeg":[("X",.15)]},
           "head_turn":{"Head":[("Y",.4)]}}
    output.mkdir(parents=True)
    metrics={};maximum_import_match=0.
    for label,rotations in poses.items():
        transform={"HumanoidRootPart":Matrix.Identity(4)}
        for part in parts:
            rotation=Matrix.Identity(4)
            for axis,angle in rotations.get(part,[]): rotation=rotation@Matrix.Rotation(angle,4,axis)
            point=Vector(config["landmarks"][part])
            transform[part]=transform[PARENTS[part]]@Matrix.Translation(point)@rotation@Matrix.Translation(-point)
        for part in parts:
            bone = armature.pose.bones[part]
            bone.matrix = (armature.matrix_world.inverted()@to_blender@affine@transform[part]@affine_inverse@inverse
                           @armature.matrix_world@bone.bone.matrix_local)
            bpy.context.view_layer.update()
        shared={};maximum_seam=0.;maximum_rest=0.;maximum_evaluated_error=0.
        depsgraph = bpy.context.evaluated_depsgraph_get()
        for obj,array in rest:
            evaluated = obj.evaluated_get(depsgraph)
            if len(evaluated.data.vertices) != len(array):
                raise RigError("The actual armature changed source vertex topology")
            for vertex,point in zip(evaluated.data.vertices,array):
                original_point=affine_inverse@(inverse@point); key=tuple(round(axis,6) for axis in original_point)
                if key not in by_position:
                    _,index,distance=nearest.find(original_point)
                    maximum_import_match=max(maximum_import_match,distance)
                    if distance>3e-6: raise RigError("Imported original vertex could not be identified: "+str(distance))
                    key=position_keys[index]
                deformed=sum(((transform[part]@original_point)*weight for part,weight in by_position[key]),Vector((0,0,0)))
                if key in shared: maximum_seam=max(maximum_seam,(shared[key]-deformed).length)
                else: shared[key]=deformed
                if label=="rest": maximum_rest=max(maximum_rest,(deformed-original_point).length)
                actual=affine_inverse@(inverse@(evaluated.matrix_world@vertex.co))
                maximum_evaluated_error=max(maximum_evaluated_error,(actual-deformed).length)
        bpy.context.view_layer.update()
        if maximum_seam>1e-5 or maximum_rest>1e-5 or maximum_evaluated_error>1e-5:
            raise RigError("Continuous skin seam/rest/evaluated-armature invariant failed: "+str(maximum_evaluated_error))
        metrics[label]={"maximum_shared_position_gap":maximum_seam,"maximum_rest_position_error":maximum_rest,
                        "maximum_actual_armature_vs_lbs_error":maximum_evaluated_error,"rotations_radians":rotations}
        rays=[("front",(to_blender.to_3x3()@affine.to_3x3()@Vector((0,0,1))).normalized()),
              ("side",(to_blender.to_3x3()@affine.to_3x3()@Vector((-1,0,0))).normalized())]
        for direction,ray in rays:
            camera.location=center+ray*20;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(output/(label+"_"+direction+".png"));bpy.ops.render.render(write_still=True)
    (output/"skin_motion_qa.json").write_text(json.dumps({"schema":1,"skin":str(path),"skin_sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
       "rig_origin":"inferred_manual_candidate","rig_ready_for_game":False,"studio_motion_validated":False,
       "offline_linear_blend_skinning":True,"actual_imported_armature_rendered":True,
       "source_or_texture_edits":0,"maximum_import_position_match_error":maximum_import_match,"poses":metrics,
       "limitations":["Continuity does not prove good anatomical deformation, collisions, exact Animate or class combat timing.","Full skin Importer and R15 proxy/shared-joint integration still require Studio validation."]},indent=2)+"\n",encoding="utf-8")
    print("continuous skin QA saved",output,flush=True)


def main(argv):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name",nargs="?",choices=list(TUNING));parser.add_argument("--dry",action="store_true")
    parser.add_argument("--out",type=Path);parser.add_argument("--render",nargs=2,metavar=("MANIFEST","OUTPUT"))
    parser.add_argument("--bind-continuous",nargs=2,metavar=("MANIFEST","GLB"))
    parser.add_argument("--render-skin",nargs=2,metavar=("GLB","OUTPUT"))
    parser.add_argument("--canonical-height",type=float)
    args=parser.parse_args(argv)
    if args.render:
        render(*args.render);return
    if args.bind_continuous:
        bind_continuous(*args.bind_continuous,args.canonical_height);return
    if args.render_skin:
        render_skin(*args.render_skin);return
    if not args.name:parser.error("name is required")
    doc=prepare(args.name)
    if not args.dry:
        if not args.out:parser.error("--out is required for a new candidate")
        output=args.out.resolve();output.relative_to((ROOT/"build/manual_partition_candidates").resolve())
        audit=ROOT/"build/manual_partition_audit"/(output.name+"_manual_landmarks.json")
        if output.exists() or audit.exists():raise RigError("Existing candidate/audit is never overwritten")
        output.mkdir(parents=True)
        (output/"manual_landmarks.json").write_text(json.dumps(doc,ensure_ascii=False,indent=2),encoding="utf-8")
        audit.parent.mkdir(parents=True,exist_ok=True)
        audit.write_text(json.dumps(doc,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"name":doc["name"],"dry":args.dry,"joints":len(doc["landmarks"]),"triangles":doc["original_triangle_count"],"parts":doc["part_triangle_counts"],"rig_origin":doc["rig_origin"],"rig_ready_for_game":False,"source_changed":False},ensure_ascii=False))


if __name__=="__main__":
    try:
        main(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:])
    except (RigError,ValueError) as error:
        print("manual_neutral refused:",str(error),file=sys.stderr);sys.exit(1)
