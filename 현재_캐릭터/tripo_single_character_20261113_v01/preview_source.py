from pathlib import Path
import bpy
import numpy as np
import json
from mathutils import Vector

out=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(next((out/'source').glob('*.fbx'))))
model=next(o for o in bpy.data.objects if o.type=='MESH')
coords=np.empty(len(model.data.vertices)*3,dtype=np.float32)
model.data.vertices.foreach_get('co',coords)
coords=coords.reshape(-1,3)
hist,edges=np.histogram(coords[:,0],bins=80)
print('X_HIST',list(zip([round(float(x),4) for x in edges[:-1]],hist.tolist())))
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1200
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world=bpy.data.worlds.new('preview_world')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.23,.23,.23,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='AgX'
for name,loc,energy,size in [('key',(-2,-3,4),450,3),('fill',(3,-2,2),200,3),('back',(0,3,3),250,3)]:
    light=bpy.data.lights.new(name,'AREA');light.energy=energy;light.shape='DISK';light.size=size
    obj=bpy.data.objects.new(name,light);scene.collection.objects.link(obj);obj.location=loc
    obj.rotation_euler=(Vector((0,0,.5))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('preview_camera');data.type='ORTHO';data.ortho_scale=1.16
cam=bpy.data.objects.new('preview_camera',data);scene.collection.objects.link(cam);scene.camera=cam
for name,loc in [('source_front',(0,-4,.65)),('source_back',(0,4,.65))]:
    cam.location=loc;cam.rotation_euler=(Vector((0,0,.49))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
