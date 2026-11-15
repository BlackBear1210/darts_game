# v01 .blend 를 열어 기본색·노멀 맵만 v02 로 바꾸고 저장·내보내기·검사·미리보기 렌더
from pathlib import Path
import bpy,json,hashlib,numpy as np
from mathutils import Vector
SRC=Path(r"C:/Users/아버지/Desktop/다트/output/character_texture_fix_20261113_v01/character_texture_fixed.blend")
OUT=Path(r"C:/Users/아버지/Desktop/다트/output/character_texture_fix_20261114_v02")
bpy.ops.wm.open_mainfile(filepath=str(SRC))
sc=bpy.context.scene
obj=next(o for o in sc.objects if o.type=="MESH");rig=next(o for o in sc.objects if o.type=="ARMATURE")
me=obj.data
def hashes():
    a=np.empty(len(me.vertices)*3,np.float32);me.vertices.foreach_get("co",a)
    l=np.empty(len(me.loops),np.int32);me.loops.foreach_get("vertex_index",l)
    u=np.empty(len(me.uv_layers.active.data)*2,np.float32);me.uv_layers.active.data.foreach_get("uv",u)
    w=[[(g.group,round(g.weight,6)) for g in v.groups] for v in me.vertices]
    b=[(x.name,[list(r) for r in x.matrix_local]) for x in rig.data.bones]
    H=lambda x:hashlib.sha256(x).hexdigest()
    return dict(verts=H(a.tobytes()),topo=H(l.tobytes()),uv=H(u.tobytes()),weights=H(json.dumps(w).encode()),bones=H(json.dumps(b).encode()))
before=hashes()
mat=me.materials[0];nt=mat.node_tree
P=next(n for n in nt.nodes if n.type=="BSDF_PRINCIPLED")
base_node=P.inputs["Base Color"].links[0].from_node
nmn=next(n for n in nt.nodes if n.type=="NORMAL_MAP");nrm_node=nmn.inputs["Color"].links[0].from_node
old_base,old_nrm=base_node.image,nrm_node.image
bc=bpy.data.images.load(str(OUT/"character_basecolor_v02.png"));bc.name="character_basecolor_v02"
nm=bpy.data.images.load(str(OUT/"character_normal_v02.png"));nm.name="character_normal_v02";nm.colorspace_settings.name="Non-Color"
base_node.image=bc;nrm_node.image=nm
mat.name="Character_Texture_v02"
for im in (old_base,old_nrm):
    if im.users==0:bpy.data.images.remove(im)
bc.pack();nm.pack()
after=hashes();assert before==after,"geometry changed"
rig.data.pose_position="POSE"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"character_v02.blend"))
print("SAVED_BLEND",flush=True)
for o in sc.objects:o.select_set(False)
obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/"character_v02.glb"),export_format="GLB",use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
bpy.ops.export_scene.fbx(filepath=str(OUT/"character_v02.fbx"),use_selection=True,object_types={"MESH","ARMATURE"},bake_anim=False,add_leaf_bones=False,path_mode="COPY",embed_textures=True)
print("EXPORTED",flush=True)
# previews (same cameras/settings as v01 render_fixed.py, so before/after compare 1:1)
sc.render.engine="BLENDER_EEVEE";sc.render.resolution_x=1100;sc.render.resolution_y=1100;sc.render.resolution_percentage=100
cam=sc.camera;h=.9987189173698425
for name,z,scale,off in [("v02_face_front",.865,.32,(-4,0,.02)),("v02_face_quarter",.865,.32,(-4,-2,.03)),("v02_full_front",.50,1.12,(-4,0,.02)),("v02_face_side",.865,.32,(0,4,.02))]:
    t=Vector((0,0,h*z));cam.data.ortho_scale=h*scale;cam.location=t+Vector(off)*h
    cam.rotation_euler=(t-cam.location).to_track_quat("-Z","Y").to_euler()
    sc.render.filepath=str(OUT/(name+".png"));bpy.ops.render.render(write_still=True)
# reopen exports
rep={"geometry_hashes_unchanged":before==after,"hashes":after}
for ext in ("glb","fbx"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    f=OUT/("character_v02."+ext)
    (bpy.ops.import_scene.gltf if ext=="glb" else bpy.ops.import_scene.fbx)(filepath=str(f))
    rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    helpers={pb.custom_shape for r in rigs for pb in r.pose.bones if pb.custom_shape}
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH" and o not in helpers]
    rep[ext]=dict(bytes=f.stat().st_size,meshes=len(meshes),bones=sum(len(r.data.bones) for r in rigs),
        triangles=sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),
        weighted=all(bool(v.groups) for o in meshes for v in o.data.vertices),
        images=sorted({im.name for im in bpy.data.images if im.source in ("FILE","GENERATED") and im.size[0]>0}))
(OUT/"verification.json").write_text(json.dumps(rep,ensure_ascii=False,indent=1),encoding="utf-8")
print("VERIFY",json.dumps(rep,ensure_ascii=False),flush=True)
