from pathlib import Path
import bpy,numpy as np,json,hashlib,bmesh,tempfile
from mathutils import Vector,Matrix
from mathutils.kdtree import KDTree
base=Path(r"C:/Users/아버지/Desktop/다트/output/character_design_review_20261113")
out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(base/"diagnostic_setup.blend"))
scene=bpy.context.scene
obj=next(o for o in scene.objects if o.type=="MESH")
rig=next(o for o in scene.objects if o.type=="ARMATURE")
rig.data.pose_position="REST"
bpy.context.view_layer.update()
mesh=obj.data
workmat=mesh.materials[0]
cleanmat=workmat.copy();cleanmat.name="Character_Local_Texture_Repair"
principled=next(n for n in workmat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
source_node=principled.inputs["Base Color"].links[0].from_node
source_image=source_node.image
source_paths={}
for im in bpy.data.images:
    if im.source=="FILE":
        p=Path(bpy.path.abspath(im.filepath))
        if p.is_file():
            source_paths[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest()
            im.filepath=str(p)

def model_hashes():
    a=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get("co",a)
    l=np.empty(len(mesh.loops),dtype=np.int32);mesh.loops.foreach_get("vertex_index",l)
    u=np.empty(len(mesh.uv_layers.active.data)*2,dtype=np.float32);mesh.uv_layers.active.data.foreach_get("uv",u)
    w=[[(int(g.group),float(g.weight)) for g in v.groups] for v in mesh.vertices]
    bones=[{"name":b.name,"parent":b.parent.name if b.parent else None,"matrix":[list(r) for r in b.matrix_local],"head":list(b.head_local),"tail":list(b.tail_local)} for b in rig.data.bones]
    return {"vertices_sha256":hashlib.sha256(a.tobytes()).hexdigest(),"topology_sha256":hashlib.sha256(l.tobytes()).hexdigest(),"uv_sha256":hashlib.sha256(u.tobytes()).hexdigest(),"weights_sha256":hashlib.sha256(json.dumps(w).encode()).hexdigest(),"skeleton_sha256":hashlib.sha256(json.dumps(bones,sort_keys=True).encode()).hexdigest(),"mesh_transform":[list(r) for r in obj.matrix_world],"rig_transform":[list(r) for r in rig.matrix_world],"vertices":len(mesh.vertices),"faces":len(mesh.polygons),"bones":len(rig.data.bones),"actions":[a.name for a in bpy.data.actions]}

before=model_hashes()
d=np.load(out/"surface_samples.npz")
coords=d["coords"];loops=d["loop_indices"];samples=d["colors"]
count=np.bincount(loops,minlength=len(coords))
avg=np.column_stack([np.bincount(loops,weights=samples[:,i],minlength=len(coords))/np.maximum(count,1) for i in range(3)])
x,y,z=coords.T;yr=np.abs(y+.0039)
def smooth(v,a,b):
    t=np.clip((v-a)/(b-a),0,1)
    return t*t*(3-2*t)
def band(v,a,b,c,d):return smooth(v,a,b)*(1-smooth(v,c,d))
brow=band(z,.8745,.8760,.887,.890)*band(x,-.108,-.101,-.033,-.025)*band(yr,.017,.022,.073,.079)
rim=np.zeros_like(z)
boundary=.081+.12*(z-.56)
torso=band(z,.530,.538,.580,.586)*band(x,.002,.012,.093,.106)*(1-smooth(yr-boundary,-.001,.0015))*smooth(yr,.052,.062)
hem=.5675+.40*(yr-.089)
arm=band(z,.515,.526,.591,.599)*smooth(hem-z,.0008,.003)*smooth(yr-boundary,-.0005,.0025)*band(x,.001,.010,.092,.102)
r,g,b=avg.T
skin=(r>g*1.15)&(g>b*1.05)&(r>b*1.45)
purple=(r>g*1.12)&(b>g*1.10)&(r>b*.80)
white=(np.minimum.reduce([r,g,b])>.55)&(np.maximum.reduce([r,g,b])-np.minimum.reduce([r,g,b])<.22)
donors={
"skin_face":skin&(r>.67)&(g>.34)&(g<r*.76)&(b<r*.48)&(z>.865)&(z<.912)&(x<-.038)&(np.abs(y)<.067),
"white_eye":white&(z>.842)&(z<.870)&(x<-.074),
"purple_shirt":purple&(z>.52)&(z<.605)&(yr<boundary-.007),
"skin_arm":skin&(z>.51)&(z<.585)&(yr>boundary+.004)&(hem-z>.002),
}
def linear(c):
    return np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
def donor_colors(mask,k=8):
    idx=np.flatnonzero(mask)
    assert len(idx)>10
    kd=KDTree(len(idx))
    for j,i in enumerate(idx):kd.insert(Vector(coords[i]),j)
    kd.balance()
    result=np.empty((len(coords),4),dtype=np.float32)
    for i,p in enumerate(coords):
        near=kd.find_n(Vector(p),k)
        indices=np.array([idx[q[1]] for q in near]);dist=np.array([q[2] for q in near])
        weights=1/np.maximum(dist,.0015)**2
        rgb=(linear(avg[indices])*weights[:,None]).sum(axis=0)/weights.sum()
        result[i]=(*rgb,1)
    return result

attrs=[]
def float_attr(name,values):
    a=mesh.attributes.new(name,"FLOAT","POINT");a.data.foreach_set("value",np.asarray(values,dtype=np.float32));attrs.append(name)
def color_attr(name,values):
    a=mesh.color_attributes.new(name=name,type="FLOAT_COLOR",domain="POINT");a.data.foreach_set("color",values.ravel());attrs.append(name)
for n,v in [("FIX_BrowRegion",brow),("FIX_EyeRimRegion",rim),("FIX_ShirtRegion",torso),("FIX_ArmRegion",arm)]:float_attr(n,v)
for n,kind in [("FIX_FaceSkin","skin_face"),("FIX_EyeWhite","white_eye"),("FIX_ShirtPurple","purple_shirt"),("FIX_ArmSkin","skin_arm")]:color_attr(n,donor_colors(donors[kind]))

nodes=workmat.node_tree.nodes;links=workmat.node_tree.links
def mathnode(op,a,b=None):
    n=nodes.new("ShaderNodeMath");n.operation=op
    for i,v in enumerate([a,b] if b is not None else [a]):
        if isinstance(v,(int,float)):n.inputs[i].default_value=v
        else:links.new(v,n.inputs[i])
    return n.outputs[0]
def attr(name,color=False):
    n=nodes.new("ShaderNodeAttribute");n.attribute_name=name
    return n.outputs["Color" if color else "Fac"]
sep=nodes.new("ShaderNodeSeparateColor");sep.mode="RGB";links.new(source_node.outputs["Color"],sep.inputs[0])
rs,gs,bs=[sep.outputs[n] for n in ("Red","Green","Blue")]
skin_filter=mathnode("MULTIPLY",mathnode("GREATER_THAN",rs,mathnode("MULTIPLY",bs,1.45)),mathnode("GREATER_THAN",gs,mathnode("MULTIPLY",bs,1.10)))
purple_filter=mathnode("MULTIPLY",mathnode("GREATER_THAN",bs,mathnode("MULTIPLY",gs,1.13)),mathnode("GREATER_THAN",rs,mathnode("MULTIPLY",gs,1.13)))
white_filter=mathnode("MULTIPLY",mathnode("GREATER_THAN",bs,mathnode("MULTIPLY",rs,.25)),mathnode("GREATER_THAN",mathnode("MINIMUM",rs,mathnode("MINIMUM",gs,bs)),.025))
brown_filter=mathnode("MULTIPLY",mathnode("GREATER_THAN",rs,mathnode("MULTIPLY",bs,1.45)),mathnode("LESS_THAN",gs,mathnode("MULTIPLY",rs,.77)))
final=source_node.outputs["Color"]
for region,color,filter_socket in [
    ("FIX_BrowRegion","FIX_FaceSkin",white_filter),
    ("FIX_EyeRimRegion","FIX_EyeWhite",brown_filter),
    ("FIX_ShirtRegion","FIX_ShirtPurple",skin_filter),
    ("FIX_ArmRegion","FIX_ArmSkin",purple_filter),
]:
    m=nodes.new("ShaderNodeMixRGB");m.blend_type="MIX";m.name=region+"_MaterialCorrection"
    links.new(mathnode("MULTIPLY",attr(region),filter_socket),m.inputs[0])
    links.new(final,m.inputs[1]);links.new(attr(color,True),m.inputs[2]);final=m.outputs[0]
links.new(final,principled.inputs["Base Color"])
# 부분 재질 보정을 원본 UV에 구워 다른 프로그램에서도 동일하게 보이게 한다.
target=bpy.data.images.load(bpy.path.abspath(source_image.filepath),check_existing=False)
target.name="character_basecolor_repaired"
assert len(target.pixels)>0 and target.has_data
bake_node=nodes.new("ShaderNodeTexImage");bake_node.image=target;nodes.active=bake_node
for n in nodes:n.select=(n==bake_node)
material_output=next(n for n in nodes if n.type=="OUTPUT_MATERIAL")
emission=nodes.new("ShaderNodeEmission");links.new(final,emission.inputs["Color"]);links.new(emission.outputs[0],material_output.inputs["Surface"])
patch=obj.copy();patch.data=mesh.copy();patch.name="TEMP_MaterialBakePatches";scene.collection.objects.link(patch)
masks=np.maximum.reduce([brow,rim,torso,arm])
bm=bmesh.new();bm.from_mesh(patch.data);bm.verts.ensure_lookup_table();bm.faces.ensure_lookup_table()
discard=[f for f in bm.faces if max(masks[v.index] for v in f.verts)<.001]
bmesh.ops.delete(bm,geom=discard,context="FACES");bm.to_mesh(patch.data);bm.free()
for mod in patch.modifiers:
    if mod.type=="ARMATURE":mod.show_render=False;mod.show_viewport=False
for o in bpy.context.selected_objects:o.select_set(False)
patch.select_set(True);bpy.context.view_layer.objects.active=patch
scene.render.engine="CYCLES";scene.cycles.device="CPU";scene.cycles.samples=1
scene.render.bake.use_clear=False;scene.render.bake.margin=1
bpy.ops.object.bake(type="EMIT",use_clear=False,margin=1)
target.filepath_raw=str(out/"character_basecolor_repaired.png");target.file_format="PNG"
target.save()
print("MATERIAL_BAKE_COMPLETE",str(out/"character_basecolor_repaired.png"),flush=True)
temp_mesh=patch.data;bpy.data.objects.remove(patch,do_unlink=True);bpy.data.meshes.remove(temp_mesh)
mesh.materials[0]=cleanmat
cleanprincipled=next(n for n in cleanmat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
cleancolor=cleanprincipled.inputs["Base Color"].links[0].from_node
cleancolor.image=target
for name in attrs:
    if mesh.attributes.get(name):mesh.attributes.remove(mesh.attributes[name])
if workmat.users==0:bpy.data.materials.remove(workmat)
for o in bpy.context.selected_objects:o.select_set(False)
obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
rig.data.pose_position="POSE"
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
scene.render.engine="BLENDER_EEVEE"
after=model_hashes()
assert before==after,"모델 구조가 변경됨"
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==v for p,v in source_paths.items()),"원본 텍스처 변경됨"
report={"scope":"localized material color repair only","before":before,"after":after,"model_structure_unchanged":before==after,"source_textures_unchanged":True,"source_texture_sha256":source_paths,"bake_patch_faces":len(temp_mesh.polygons) if False else None,"region_vertex_counts":{"brow":int((brow>.01).sum()),"eye_rim":int((rim>.01).sum()),"shirt":int((torso>.01).sum()),"arm":int((arm>.01).sum())}}
(out/"repair_verification.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
for im in bpy.data.images:
    if im.source=="FILE" and Path(bpy.path.abspath(im.filepath)).is_file():
        im.pack()
bpy.context.preferences.filepaths.save_version=0
scene.render.filepath=str(out/"preview.png")
bpy.ops.wm.save_as_mainfile(filepath=str(out/"character_texture_fixed.blend"))
print("FIXED_MODEL_SAVED",flush=True)

