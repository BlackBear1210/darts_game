from pathlib import Path
import bpy,json,sys
from mathutils import Vector,Matrix
out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/"character_texture_fixed.blend"))
scene=bpy.context.scene;rig=next(o for o in scene.objects if o.type=="ARMATURE")
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
cam=scene.camera;h=.9987189173698425
specs=[
    ("fixed_face_front",.865,.32,(-4,0,.02)),
    ("fixed_face_quarter",.865,.32,(-4,-2,.03)),
    ("fixed_full_front",.50,1.12,(-4,0,.02)),
]
if "--face-only" in sys.argv:specs=specs[:1]
for name,z,scale,offset in specs:
    target=Vector((0,0,h*z));cam.data.ortho_scale=h*scale
    cam.location=target+Vector(offset)*h;cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
if "--face-only" in sys.argv:raise SystemExit(0)
rig.data.pose_position="POSE"
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
for side,sign in [("Right",1),("Left",-1)]:
    pb=rig.pose.bones["mixamorig:"+side+"Arm"]
    target_local=(rig.matrix_world.inverted().to_3x3()@Vector((0,sign,.12))).normalized()
    target_bone_local=(pb.bone.matrix_local.inverted().to_3x3()@target_local).normalized()
    pb.rotation_mode="QUATERNION";pb.rotation_quaternion=Vector((0,1,0)).rotation_difference(target_bone_local)
    bpy.context.view_layer.update()
scene.render.resolution_x=1200;scene.render.resolution_y=1000
for name,target,scale,offset in [
    ("fixed_arms_raised",(.02,0,.65),.65,(-4,0,-.1)),
    ("fixed_right_underarm",(.03,.085,.635),.32,(-3,3,-.8)),
    ("fixed_left_underarm",(.03,-.085,.635),.32,(-3,-3,-.8)),
]:
    target=Vector(target);cam.data.ortho_scale=scale;cam.location=target+Vector(offset)
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
print("FIXED_PREVIEWS_COMPLETE",flush=True)

