from pathlib import Path
import bpy,json
from mathutils import Vector,Matrix
out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/"character_texture_fixed.blend"))
scene=bpy.context.scene
rig=next(o for o in scene.objects if o.type=="ARMATURE");obj=next(o for o in scene.objects if o.type=="MESH")
rig.data.pose_position="POSE"
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
cam=scene.camera;target=Vector((0,0,.5));cam.data.ortho_scale=1.12
cam.location=target+Vector((-4,0,.02));cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=str(out/"fixed_full_front.png")
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        space=area.spaces.active
        space.region_3d.view_location=target
        space.region_3d.view_distance=1.5
        space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
        space.shading.type="MATERIAL"
        space.overlay.show_relationship_lines=False
for ob in scene.objects:ob.select_set(False)
obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"character_texture_fixed.blend"))

