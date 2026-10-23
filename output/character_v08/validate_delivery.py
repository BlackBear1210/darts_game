import bpy, os, json, hashlib
OUT=os.path.dirname(os.path.abspath(__file__))
report={}
for file in ['character_reference_hair.blend','character_bald.blend','turnaround_scene.blend']:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,file))
    ref=[im for im in bpy.data.images if im.name.startswith('USER_REFERENCE_TURNAROUND') and im.packed_file]
    head=bpy.data.objects['Head_Master']
    fingerprint=hashlib.sha256(str([tuple(v.co) for v in head.data.vertices]).encode()).hexdigest()
    hair=bpy.data.objects['Hair_ConnectedSculptedLocks']
    report[file]={'packed_reference':bool(ref),'head_geometry_sha256':fingerprint,'hair_hidden':hair.hide_render,'active_camera':bpy.context.scene.camera.name,'bytes':os.path.getsize(os.path.join(OUT,file))}
    assert ref, 'Missing packed user reference'
assert not report['character_reference_hair.blend']['hair_hidden']
assert report['character_bald.blend']['hair_hidden']
assert report['character_reference_hair.blend']['head_geometry_sha256']==report['character_bald.blend']['head_geometry_sha256']
with open(os.path.join(OUT,'delivery_validation.json'),'w',encoding='utf-8') as f:json.dump(report,f,indent=2)
print('DELIVERY_VALIDATED',flush=True)
