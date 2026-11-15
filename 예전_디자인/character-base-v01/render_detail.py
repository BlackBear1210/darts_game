"""손을 바깥쪽에서 보고, 각진(flat) 음영으로 다시 렌더링한다. 원본 GLB는 바꾸지 않는다.

실행: blender -b --factory-startup --python render_detail.py -- <model.glb> <출력폴더> [앞방향 각도]
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
model_path, out_dir = Path(args[0]), Path(args[1])
facing_deg = float(args[2]) if len(args) > 2 else 0.0
out_dir.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
if model_path.suffix.lower() == ".fbx":
    bpy.ops.wm.fbx_import(filepath=str(model_path))
else:
    bpy.ops.import_scene.gltf(filepath=str(model_path))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for obj in meshes:
    obj.data.polygons.foreach_set("use_smooth", [False] * len(obj.data.polygons))
    obj.data.update()

lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for obj in meshes:
    for corner in obj.bound_box:
        world = obj.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, world))
        hi = Vector(map(max, hi, world))
height = hi.z - lo.z
center = (lo + hi) / 2

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = scene.render.resolution_y = 1024
world = bpy.data.worlds.new("Gray")
world.color = (0.8, 0.8, 0.8)
scene.world = world
scene.display.shading.show_shadows = False
camera_data = bpy.data.cameras.new("Cam")
camera_data.type = "ORTHO"
camera = bpy.data.objects.new("Cam", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera


def look(azimuth_deg, target, ortho_scale, name):
    angle = math.radians(facing_deg + azimuth_deg)
    offset = Vector((math.sin(angle), -math.cos(angle), 0)) * (height * 4)
    camera.location = target + offset
    camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = ortho_scale
    scene.render.filepath = str(out_dir / f"{name}.png")
    bpy.ops.render.render(write_still=True)


body = Vector((center.x, center.y, center.z))
head = Vector((center.x, center.y, lo.z + height * 0.865))
side_dir = Vector((math.cos(math.radians(facing_deg)), math.sin(math.radians(facing_deg)), 0))
half_span = abs((hi - center).dot(side_dir))
hand_z = lo.z + height * 0.36
hand_left = Vector((center.x, center.y, hand_z)) + side_dir * half_span * 0.93
hand_right = Vector((center.x, center.y, hand_z)) - side_dir * half_span * 0.93

for shading, suffix in (("TEXTURE", ""), ("SINGLE", "_clay")):
    scene.display.shading.color_type = shading
    scene.display.shading.light = "STUDIO" if shading == "SINGLE" else "FLAT"
    scene.display.shading.single_color = (0.75, 0.75, 0.75)
    look(0, body, height * 1.1, "flat_front" + suffix)
    look(35, body, height * 1.1, "flat_threequarter" + suffix)
    look(35, head, height * 0.3, "flat_head" + suffix)
    look(90, hand_left, height * 0.16, "hand_left_outer" + suffix)
    look(-90, hand_left, height * 0.16, "hand_left_inner" + suffix)
    look(-90, hand_right, height * 0.16, "hand_right_outer" + suffix)
