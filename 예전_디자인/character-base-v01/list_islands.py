"""메시의 분리된 덩어리를 찾아 위치·크기를 출력하고 덩어리마다 색을 칠해 렌더링한다.

실행: blender -b --factory-startup --python list_islands.py -- <model> <출력폴더> [앞방향 각도]
"""
import colorsys
import json
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
bpy.context.view_layer.objects.active = meshes[0]
meshes[0].select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE")
bpy.ops.object.mode_set(mode="OBJECT")
parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]

lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
boxes = {}
for obj in parts:
    world = [obj.matrix_world @ v.co for v in obj.data.vertices]
    a = Vector((min(p[i] for p in world) for i in range(3)))
    b = Vector((max(p[i] for p in world) for i in range(3)))
    boxes[obj.name] = (a, b)
    lo = Vector(map(min, lo, a))
    hi = Vector(map(max, hi, b))
height = hi.z - lo.z
rows = []
parts.sort(key=lambda o: -len(o.data.vertices))
for index, obj in enumerate(parts):
    a, b = boxes[obj.name]
    rows.append({
        "i": index, "verts": len(obj.data.vertices), "faces": len(obj.data.polygons),
        "z_pct": [round((a.z - lo.z) / height * 100, 1), round((b.z - lo.z) / height * 100, 1)],
        "x": [round(a.x, 3), round(b.x, 3)], "y": [round(a.y, 3), round(b.y, 3)],
    })
    material = bpy.data.materials.new(f"I{index}")
    hue = (index * 0.618) % 1.0
    material.diffuse_color = (*colorsys.hsv_to_rgb(hue, 0.75, 0.95), 1)
    obj.data.materials.clear()
    obj.data.materials.append(material)
(out_dir / "islands.json").write_text(json.dumps(rows, indent=0), encoding="utf-8")
for row in rows:
    print("ISLAND", json.dumps(row))

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.light = "STUDIO"
scene.display.shading.show_shadows = False
world = bpy.data.worlds.new("Gray")
world.color = (0.8, 0.8, 0.8)
scene.world = world
camera_data = bpy.data.cameras.new("Cam")
camera_data.type = "ORTHO"
camera = bpy.data.objects.new("Cam", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
center = (lo + hi) / 2


def look(azimuth_deg, name):
    angle = math.radians(facing_deg + azimuth_deg)
    offset = Vector((math.sin(angle), -math.cos(angle), 0)) * (height * 4)
    camera.location = center + offset
    camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = height * 1.1
    scene.render.filepath = str(out_dir / f"{name}.png")
    bpy.ops.render.render(write_still=True)


look(0, "islands_front")
look(-90, "islands_right")
look(180, "islands_back")
