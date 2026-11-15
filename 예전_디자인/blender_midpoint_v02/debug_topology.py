import bpy,bmesh,collections
p=r'C:/Users/아버지/Desktop/다트/output/blender_midpoint_v02/character_midpoint_v02.blend'
bpy.ops.wm.open_mainfile(filepath=p)
m=bpy.data.objects['shirt_connected'].data
b=bmesh.new();b.from_mesh(m)
def show(tag):print(tag,collections.Counter(len(e.link_faces) for e in b.edges),len(b.verts),len(b.faces),flush=True)
show('LOADED')
bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.000001);show('WELDED')
bmesh.ops.triangulate(b,faces=list(b.faces));show('TRIANGULATED')
b.to_mesh(m);b.free();b=bmesh.new();b.from_mesh(m);show('ROUNDTRIP')
for i in range(12):
 boundary=[e for e in b.edges if e.is_boundary]
 if not boundary:break
 edge=min(boundary,key=lambda e:e.calc_length())
 print('COLLAPSE',edge.calc_length())
 bmesh.ops.collapse(b,edges=[edge])
 show('COLLAPSED')
b.to_mesh(m);b.free();b=bmesh.new();b.from_mesh(m);show('FINAL_ROUNDTRIP')
