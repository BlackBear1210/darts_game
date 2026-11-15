from pathlib import Path
import bpy
import json
from mathutils import Vector

out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/'character_left_only.blend'))
bpy.context.preferences.filepaths.save_version=0
obj=next(o for o in bpy.data.objects if o.type=='MESH')
report=json.loads((out/'removal_report.json').read_text(encoding='utf-8'))
lo=report['bounds_local_min'];hi=report['bounds_local_max']
points=[obj.matrix_world@Vector((x,y,z)) for x in (lo[0],hi[0]) for y in (lo[1],hi[1]) for z in (lo[2],hi[2])]
world_min=Vector(tuple(min(v[i] for v in points) for i in range(3)))
world_max=Vector(tuple(max(v[i] for v in points) for i in range(3)))
center=(world_min+world_max)*.5
report['bounds_world_min']=list(world_min);report['bounds_world_max']=list(world_max)
(out/'removal_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':area.spaces.active.region_3d.view_location=center
bpy.ops.wm.save_as_mainfile(filepath=str(out/'character_left_only.blend'))
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=900;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world=bpy.data.worlds.new('preview_world');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.23,.23,.23,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='AgX'
for name,offset,energy in [('key',(-2,-3,4),450),('fill',(3,-2,2),200),('back',(0,3,3),250)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=3
    light=bpy.data.objects.new(name,data);scene.collection.objects.link(light);light.location=center+Vector(offset)
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('preview_camera');data.type='ORTHO';data.ortho_scale=1.10
cam=bpy.data.objects.new('preview_camera',data);scene.collection.objects.link(cam);scene.camera=cam
for name,offset in [('kept_front',(0,-4,.10)),('kept_three_quarter',(-2,-4,.10)),('kept_back',(0,4,.10))]:
    cam.location=center+Vector(offset);cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
