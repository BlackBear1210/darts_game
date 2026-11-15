from pathlib import Path
import bpy,json,hashlib,tempfile,runpy
import numpy as np
from mathutils import Vector
out=Path(__file__).resolve().parent
worktemp=out/"export_temp";worktemp.mkdir(exist_ok=True)
tempfile.tempdir=str(worktemp)
bpy.ops.wm.open_mainfile(filepath=str(out/"character_texture_fixed.blend"))
bpy.context.preferences.filepaths.temporary_directory=str(worktemp)
scene=bpy.context.scene
obj=next(o for o in scene.objects if o.type=="MESH")
rig=next(o for o in scene.objects if o.type=="ARMATURE")
for o in scene.objects:o.select_set(False)
obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
expected_triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
def bounds(meshes):
    pts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    return np.array([[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]])
expected_bounds=bounds([obj])
bpy.ops.export_scene.gltf(filepath=str(out/"character_texture_fixed.glb"),export_format="GLB",use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
bpy.ops.export_scene.fbx(filepath=str(out/"character_texture_fixed.fbx"),use_selection=True,object_types={"MESH","ARMATURE"},bake_anim=False,add_leaf_bones=False,path_mode="COPY",embed_textures=True)
print("EXPORTS_SAVED",flush=True)
exports={}
for ext in ("glb","fbx"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    f=out/("character_texture_fixed."+ext)
    if ext=="glb":bpy.ops.import_scene.gltf(filepath=str(f))
    else:bpy.ops.import_scene.fbx(filepath=str(f))
    rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    helpers={pb.custom_shape for r in rigs for pb in r.pose.bones if pb.custom_shape is not None}
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH" and o not in helpers]
    for r in rigs:r.data.pose_position="REST"
    bpy.context.view_layer.update()
    triangles=sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)
    b=bounds(meshes)
    images=[im for im in bpy.data.images if im.type=="IMAGE" and im.source=="FILE"]
    record={"bytes":f.stat().st_size,"sha256":hashlib.sha256(f.read_bytes()).hexdigest(),"meshes":len(meshes),"bones":sum(len(r.data.bones) for r in rigs),"triangles":triangles,"vertices":sum(len(o.data.vertices) for o in meshes),"bounds":b.tolist(),"bounds_max_error":float(np.abs(b-expected_bounds).max()),"images":[{"name":im.name,"size":list(im.size),"packed":im.packed_file is not None} for im in images],"weighted_vertices":sum(bool(v.groups) for o in meshes for v in o.data.vertices),"actions":len(bpy.data.actions)}
    record["bone_names"]=[b.name for r in rigs for b in r.data.bones]
    record["importer_display_helpers"]=[o.name for o in helpers]
    print("EXPORT_INSPECT",ext,json.dumps({k:record[k] for k in ("meshes","bones","triangles","vertices","bounds_max_error","weighted_vertices","importer_display_helpers")},ensure_ascii=False),flush=True)
    assert len(meshes)==1 and len(rigs)==1 and record["bones"]==65
    assert triangles==expected_triangles
    assert record["bounds_max_error"]<.00001
    assert record["weighted_vertices"]==record["vertices"]
    assert len(images)>=(3 if ext=="glb" else 4) and all(min(im.size)>0 for im in images)
    exports[ext]=record
(out/"export_verification.json").write_text(json.dumps(exports,ensure_ascii=False,indent=2),encoding="utf-8")
print("EXPORT_VERIFICATION_PASSED",json.dumps({e:{k:r[k] for k in ("meshes","bones","triangles","weighted_vertices","bounds_max_error")} for e,r in exports.items()}),flush=True)
runpy.run_path(str(out/"render_fixed.py"),run_name="__main__")

