from pathlib import Path
import bpy
import numpy as np
import hashlib
import json
import tempfile
import gc
from mathutils import Vector

out=Path(__file__).resolve().parent
tempfile.tempdir=str((out/'export_tmp').resolve())
report=json.loads((out/'removal_report.json').read_text(encoding='utf-8'))
result={}

def inspect(label):
    objects=[o for o in bpy.data.objects if o.type=='MESH']
    assert len(objects)==1,(label,'not a single mesh',len(objects))
    obj=objects[0]
    assert len(obj.data.polygons)==report['retained_faces'],(label,'face count changed')
    points=[obj.matrix_world@Vector(v) for v in obj.bound_box]
    lo=np.array([min(v[i] for v in points) for i in range(3)])
    hi=np.array([max(v[i] for v in points) for i in range(3)])
    assert np.allclose(lo,report['bounds_world_min'],atol=1e-5),(label,lo)
    assert np.allclose(hi,report['bounds_world_max'],atol=1e-5),(label,hi)
    assert hi[0]<0,'Right-side geometry remains'
    result[label]={'mesh_objects':1,'vertices':len(obj.data.vertices),'faces':len(obj.data.polygons),
                   'bounds_match_retained_character':True,'right_character_absent':True}
    return obj

bpy.ops.wm.open_mainfile(filepath=str(out/'character_left_only.blend'))
obj=inspect('blend')
coords=np.empty(len(obj.data.vertices)*3,dtype=np.float32)
obj.data.vertices.foreach_get('co',coords)
assert hashlib.sha256(coords.tobytes()).hexdigest()==report['kept_geometry_sha256']
for layer in obj.data.uv_layers:
    uv=np.empty(len(layer.data)*2,dtype=np.float32)
    layer.data.foreach_get('uv',uv)
    assert hashlib.sha256(uv.tobytes()).hexdigest()==report['uv_sha256'][layer.name]
    del uv
for image in bpy.data.images:
    if image.type=='RENDER_RESULT':continue
    assert image.packed_file is not None,('Missing packed texture',image.name)
    name=Path(image.filepath).name
    if name in report['texture_sha256']:
        assert hashlib.sha256(image.packed_file.data).hexdigest()==report['texture_sha256'][name]
result['native_fidelity']={'original_kept_vertices_exact':True,'original_kept_uv_exact':True,
                           'original_packed_textures_exact':True}
del coords,obj
for label in ['glb','fbx']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    gc.collect()
    if label=='glb':bpy.ops.import_scene.gltf(filepath=str(out/'character_left_only.glb'))
    else:bpy.ops.import_scene.fbx(filepath=str(out/'character_left_only.fbx'))
    inspect(label)
source=out/'source'/report['source_fbx']
assert hashlib.sha256(source.read_bytes()).hexdigest()==report['source_fbx_sha256']
result['source_fbx_unchanged']=True
(out/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('VERIFIED',json.dumps(result),flush=True)
