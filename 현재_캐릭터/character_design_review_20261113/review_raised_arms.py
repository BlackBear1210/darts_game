from pathlib import Path
import bpy,json,math
from mathutils import Vector,Matrix
base=Path(r"C:/Users/아버지/Desktop/다트/output/character_design_review_20261113")
bpy.ops.wm.open_mainfile(filepath=str(base/"diagnostic_setup.blend"))
scene=bpy.context.scene
clay=bpy.data.materials.new("DiagnosticClay");clay.use_nodes=True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.45,.45,.45,1)
clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.8
rig=next(o for o in scene.objects if o.type=="ARMATURE")
rig.data.pose_position="POSE"
for pb in rig.pose.bones: pb.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
pose_report=[]
# 원본을 저장하지 않고 검사용으로만 양팔을 옆으로 들어 올린다.
for side,sign in [("Right",1),("Left",-1)]:
    pb=rig.pose.bones["mixamorig:"+side+"Arm"]
    target_world=Vector((0,sign,.12)).normalized()
    target_local=(rig.matrix_world.inverted().to_3x3()@target_world).normalized()
    target_bone_local=(pb.bone.matrix_local.inverted().to_3x3()@target_local).normalized()
    q=Vector((0,1,0)).rotation_difference(target_bone_local)
    pb.rotation_mode="QUATERNION"
    pb.rotation_quaternion=q
    bpy.context.view_layer.update()
    pose_report.append({"bone":pb.name,"head":list(rig.matrix_world@pb.head),"tail":list(rig.matrix_world@pb.tail)})
scene.render.resolution_x=1200;scene.render.resolution_y=1000
scene.render.resolution_percentage=100
cam=scene.camera
for name,target,scale,offset in [
    ("arms_raised_front",(.02,0,.65),.65,(-4,0,-.1)),
    ("right_underarm_raised",(.03,.085,.635),.32,(-3,3,-.8)),
    ("left_underarm_raised",(.03,-.085,.635),.32,(-3,-3,-.8)),
]:
    target=Vector(target)
    cam.data.ortho_scale=scale
    cam.location=target+Vector(offset)
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(base/(name+".png"))
    bpy.ops.render.render(write_still=True)
    if name=="right_underarm_raised":
        scene.view_layers[0].material_override=bpy.data.materials["DiagnosticClay"]
        scene.render.filepath=str(base/(name+"_clay.png"))
        bpy.ops.render.render(write_still=True)
        scene.view_layers[0].material_override=None
(base/"raised_arm_inspection.json").write_text(json.dumps(pose_report,indent=2),encoding="utf-8")
print("RAISED_ARMS_REVIEW_COMPLETE",json.dumps(pose_report),flush=True)

