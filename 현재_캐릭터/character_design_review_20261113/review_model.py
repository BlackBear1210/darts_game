from pathlib import Path
import zipfile,json
import bpy
from mathutils import Vector
out=Path(r"C:/Users/아버지/Desktop/다트/output/character_design_review_20261113")
out.mkdir(parents=True,exist_ok=True)
src=Path(r"C:/Users/아버지/Downloads/tripo_convert_954d3209-6b1c-413f-9c5c-acc1b483b08f.zip")
unpack=out/"source"
unpack.mkdir(exist_ok=True)
with zipfile.ZipFile(src) as z:
    for info in z.infolist():
        dest=(unpack/info.filename).resolve()
        assert dest.is_relative_to(unpack.resolve())
    z.extractall(unpack)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(next(unpack.glob("*.fbx"))))
scene=bpy.context.scene
rigs=[o for o in scene.objects if o.type=="ARMATURE"]
for rig in rigs: rig.data.pose_position="REST"
scene.frame_set(1)
bpy.context.view_layer.update()
meshes=[o for o in scene.objects if o.type=="MESH"]
pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
h=hi.z-lo.z
center=(hi+lo)*.5
info={"file":src.name,"mesh_objects":[{"name":o.name,"verts":len(o.data.vertices),"faces":len(o.data.polygons)} for o in meshes],"rigs":[{"name":o.name,"bones":len(o.data.bones)} for o in rigs],"bounds":[list(lo),list(hi)],"actions":[a.name for a in bpy.data.actions]}
(out/"inspection.json").write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(info,ensure_ascii=False),flush=True)
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=1100
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.world=bpy.data.worlds.new("ReviewWorld")
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.19,.19,.19,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.7
scene.view_settings.view_transform="AgX"
for name,offset,energy in [("Key",(-2,-3,4),450),("Fill",(3,-2,2),220),("Back",(0,3,3),250)]:
    data=bpy.data.lights.new(name,"AREA");data.energy=energy*h*h;data.shape="DISK";data.size=3*h
    light=bpy.data.objects.new(name,data);scene.collection.objects.link(light)
    light.location=center+Vector(offset)*h
    light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
data=bpy.data.cameras.new("ReviewCamera");data.type="ORTHO"
cam=bpy.data.objects.new("ReviewCamera",data);scene.collection.objects.link(cam);scene.camera=cam
clay=bpy.data.materials.new("DiagnosticClay");clay.use_nodes=True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.45,.45,.45,1)
clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.8
for name,z,scale,offset in [
    ("face_front",.865,.32,(-4,0,.02)),
    ("face_quarter",.865,.32,(-4,-2,.03)),
    ("torso_front",.66,.50,(-4,0,0)),
    ("torso_underarm",.65,.50,(-3,-3,-.3)),
]:
    target=Vector((center.x,center.y,lo.z+h*z))
    data.ortho_scale=h*scale
    cam.location=target+Vector(offset)*h
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"))
    bpy.ops.render.render(write_still=True)
    if name in ("face_front","torso_underarm"):
        scene.view_layers[0].material_override=clay
        scene.render.filepath=str(out/(name+"_clay.png"))
        bpy.ops.render.render(write_still=True)
        scene.view_layers[0].material_override=None
print("REVIEW_RENDERS_COMPLETE",flush=True)

