"""저장한 Blender/GLB 파일을 다시 열어 모델과 외부 의존성을 확인한다."""
from pathlib import Path
import bpy
import bmesh
import json
import math
import hashlib

out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/'character_midpoint_v02.blend'))
collection=bpy.data.collections['CHARACTER_midpoint']
objects=list(collection.objects)
names={o.name for o in objects}
required={'head_face','nose_wedge','eye_white_l','eye_white_r','pupil_l','pupil_r',
          'eyebrow_l','eyebrow_r','ear_l','ear_r','hair_sculpted_midpoint','neck',
          'shirt_connected','trouser_leg_l','trouser_leg_r','shoe_upper_l','shoe_upper_r'}
assert required <= names, required-names
for side in ['l','r']:
    assert {f'finger_{side}_{i}' for i in range(1,5)} <= names
    assert 'thumb_'+side in names
for obj in objects:
    assert obj.type=='MESH'
    assert len(obj.data.materials)>0, obj.name
    assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co),obj.name
for name in ['head_face','shirt_connected']:
    bm=bmesh.new()
    bm.from_mesh(bpy.data.objects[name].data)
    assert all(edge.is_manifold for edge in bm.edges),name+' has an open or non-manifold edge'
    assert all(len(vertex.link_faces)>0 for vertex in bm.verts),name+' has loose vertices'
    bm.free()
reference=bpy.data.images.get('APPROVED_full_body_reference')
assert reference is not None and reference.packed_file is not None
assert len(bpy.data.scenes)>=2
# 참고 이미지와 글꼴까지 파일에 포함해 다른 PC에서도 열 수 있게 한다.
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(out/'character_midpoint_v02.blend'))
mesh_count=len(objects)
model_report=json.loads((out/'model_report.json').read_text(encoding='utf-8'))
model_report['vertices']=sum(len(obj.data.vertices) for obj in objects)
model_report['triangles']=sum(sum(len(poly.vertices)-2 for poly in obj.data.polygons) for obj in objects)
(out/'model_report.json').write_text(json.dumps(model_report,indent=2),encoding='utf-8')
scene=bpy.context.scene
studio=bpy.data.collections['STUDIO']
cam_data=bpy.data.cameras.new('CAM_face_detail')
cam_data.type='ORTHO'
cam_data.ortho_scale=.64
cam=bpy.data.objects.new('CAM_face_detail',cam_data)
studio.objects.link(cam)
from mathutils import Vector
cam.location=(0,-4,1.55)
cam.rotation_euler=(Vector((0,-.03,1.505))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.camera=cam
scene.render.resolution_x=1100
scene.render.resolution_y=1100
scene.render.filepath=str(out/'face_detail.png')
bpy.ops.render.render(write_still=True)
review=bpy.data.scenes['FRONT_AND_SIDE_review']
review.objects['front_instance'].location.x=-.30
review.objects['side_instance'].location.x=.30
review.camera.data.ortho_scale=1.55
review.camera.location=(0,-6,1.43)
review.camera.rotation_euler=(Vector((0,0,1.35))-review.camera.location).to_track_quat('-Z','Y').to_euler()
review.render.resolution_x=1500
review.render.resolution_y=1100
review.render.filepath=str(out/'face_and_shoulders.png')
bpy.ops.render.render(write_still=True,scene=review.name)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out/'character_midpoint_v02.glb'))
imported=[o for o in bpy.data.objects if o.type=='MESH']
assert len(imported)==mesh_count,(len(imported),mesh_count)
assert not any(o.type=='ARMATURE' for o in bpy.data.objects)
assert len(bpy.data.actions)==0
original=out.parents[1]/'다트-/art/characters/rigged/tripo_character.glb'
assert hashlib.sha256(original.read_bytes()).hexdigest()=='3cca4d5e5a014a447930403b726442d27228ab517702dd376ae04ecc258b45f7'
report={'blend_reopened':True,'glb_reimported':True,'matching_mesh_count':mesh_count,
        'both_hands_five_fingers':True,'reference_packed':True,'materials_present':True,
        'finite_vertices':True,'head_and_shirt_closed_manifold':True,
        'original_game_model_unchanged':True,'rigged':False,'animated':False}
(out/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('VERIFIED',json.dumps(report))
