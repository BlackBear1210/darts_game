from pathlib import Path
import bpy,bmesh,collections
out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/'character_midpoint_v02.blend'))
o=bpy.data.objects['shirt_connected'];m=o.data

def count(tag):
 b=bmesh.new();b.from_mesh(m);c=collections.Counter(len(e.link_faces) for e in b.edges);b.free();print(tag,c,flush=True);return set(c)=={2}
for n in range(5):
 m.validate(verbose=True)
 b=bmesh.new();b.from_mesh(m);bmesh.ops.triangulate(b,faces=list(b.faces))
 for i in range(64):
  edges=[e for e in b.edges if e.is_boundary]
  if not edges:break
  e=min(edges,key=lambda e:e.calc_length());assert e.calc_length()<.0002
  bmesh.ops.collapse(b,edges=[e])
 wire=[e for e in b.edges if not e.link_faces]
 if wire:bmesh.ops.delete(b,geom=wire,context='EDGES')
 loose=[v for v in b.verts if not v.link_faces]
 if loose:bmesh.ops.delete(b,geom=loose,context='VERTS')
 bmesh.ops.recalc_face_normals(b,faces=list(b.faces));b.to_mesh(m);b.free()
 changed=m.validate(verbose=True);closed=count('ROUND_'+str(n))
 if closed and not changed:break
assert closed
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.collections['CHARACTER_midpoint'].objects:obj.select_set(True)
bpy.context.view_layer.objects.active=o
count('BEFORE_EXPORT')
bpy.ops.export_scene.gltf(filepath=str(out/'character_midpoint_v02.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
assert count('AFTER_EXPORT')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(out/'character_midpoint_v02.blend'))
bpy.ops.wm.open_mainfile(filepath=str(out/'character_midpoint_v02.blend'))
m=bpy.data.objects['shirt_connected'].data
assert count('REOPENED')
