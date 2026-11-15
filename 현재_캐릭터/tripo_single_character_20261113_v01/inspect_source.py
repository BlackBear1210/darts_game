from pathlib import Path
import bpy
import json
from mathutils import Vector

out=Path(__file__).resolve().parent
source=next((out/'source').glob('*.fbx'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source))
info=[]
for obj in bpy.data.objects:
    if obj.type!='MESH':continue
    points=[obj.matrix_world@Vector(v) for v in obj.bound_box]
    lo=[min(v[i] for v in points) for i in range(3)]
    hi=[max(v[i] for v in points) for i in range(3)]
    info.append({'name':obj.name,'vertices':len(obj.data.vertices),'faces':len(obj.data.polygons),
                 'bounds_min':lo,'bounds_max':hi,'location':list(obj.location),
                 'rotation':list(obj.rotation_euler),'scale':list(obj.scale),
                 'materials':[m.name for m in obj.data.materials]})
for mat in bpy.data.materials:
    if not mat.use_nodes:continue
    print('MATERIAL',mat.name)
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE':print('IMAGE',node.name,node.image.filepath if node.image else None)
print('SOURCE_INFO',json.dumps(info,ensure_ascii=True))
(out/'source_info.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
