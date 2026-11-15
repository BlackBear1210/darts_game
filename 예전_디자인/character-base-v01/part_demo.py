"""P2 모델 부위 시험: 벗겨 보기, 손가락 단면 세기, 단색 재질 미리보기. 원본 파일은 바꾸지 않는다.

실행: blender -b --factory-startup --python part_demo.py -- <model.fbx> <출력폴더> <색 json> [앞방향 각도]
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
model_path, out_dir, color_path = Path(args[0]), Path(args[1]), Path(args[2])
facing_deg = float(args[3]) if len(args) > 3 else 0.0
out_dir.mkdir(parents=True, exist_ok=True)
sheet_colors = json.loads(color_path.read_text())

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.fbx_import(filepath=str(model_path))
source = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = source
source.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE")
bpy.ops.object.mode_set(mode="OBJECT")
parts = sorted((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: -len(o.data.vertices))
# list_islands.py 와 같은 순서(점 개수 내림차순)로 부위 이름을 붙였다.
NAMES = ["pants", "shirt", "eye_r", "eye_l", "hair", "arm_r", "arm_l", "shoe_r", "shoe_l", "head",
         "ear_r", "ear_l", "brow_r", "brow_l", "small_14", "small_15", "small_16", "small_17"]
by_name = dict(zip(NAMES, parts))
for name, obj in by_name.items():
    obj.name = name
    obj.data.polygons.foreach_set("use_smooth", [False] * len(obj.data.polygons))
    obj.data.update()

lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for obj in parts:
    for v in obj.data.vertices:
        world = obj.matrix_world @ v.co
        lo = Vector(map(min, lo, world))
        hi = Vector(map(max, hi, world))
height = hi.z - lo.z
center = (lo + hi) / 2

for name, obj in by_name.items():
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    open_edges = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    bad_edges = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    print("PART", name, "verts", len(bm.verts), "faces", len(bm.faces), "open_edges", open_edges, "nonmanifold", bad_edges)
    bm.free()


def count_loops(obj, z_world):
    mesh = obj.data
    z = [(obj.matrix_world @ v.co).z for v in mesh.vertices]
    parent = {}

    def find(key):
        parent.setdefault(key, key)
        while parent[key] != key:
            parent[key] = parent[parent[key]]
            key = parent[key]
        return key

    for poly in mesh.polygons:
        crossing = []
        for a, b in poly.edge_keys:
            if (z[a] - z_world) * (z[b] - z_world) < 0:
                crossing.append((min(a, b), max(a, b)))
        for key in crossing:
            find(key)
        for key in crossing[1:]:
            parent[find(key)] = find(crossing[0])
    return len({find(k) for k in list(parent)})


for name in ("arm_l", "arm_r"):
    obj = by_name[name]
    rows = []
    for percent in [31.5 + 0.5 * i for i in range(24)]:
        rows.append((percent, count_loops(obj, lo.z + height * percent / 100)))
    print("SLICE", name, rows)

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.display.shading.show_shadows = False
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.light = "STUDIO"
world = bpy.data.worlds.new("Gray")
world.color = (0.8, 0.8, 0.8)
scene.world = world
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


def hide(names, hidden=True):
    for name in names:
        by_name[name].hide_render = hidden


body = Vector((center.x, center.y, center.z))
head = Vector((center.x, center.y, lo.z + height * 0.865))
hide(["hair"])
look(35, head, height * 0.34, "bald_threequarter")
look(180, head, height * 0.34, "bald_back")
hide(["hair"], False)
hide(["shirt"])
look(35, body, height * 1.1, "no_shirt")
hide(["shirt"], False)
hide(["pants"])
look(35, body, height * 1.1, "no_pants")
hide(["shirt"])
look(35, body, height * 1.1, "no_shirt_no_pants")
hide(["shirt", "pants"], False)
hide(["shoe_l", "shoe_r"])
look(35, Vector((center.x, center.y, lo.z + height * 0.08)), height * 0.3, "no_shoes")
hide(["shoe_l", "shoe_r"], False)


def srgb_to_linear(value):
    c = value / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def solid(name, rgb):
    material = bpy.data.materials.new("M_" + name)
    material.diffuse_color = (*[srgb_to_linear(c) for c in rgb], 1)
    return material


palette = {key: solid(key, value) for key, value in sheet_colors.items()}
assign = {"shirt": "shirt", "pants": "pants", "hair": "hair", "brow_l": "hair", "brow_r": "hair",
          "shoe_l": "shoes", "shoe_r": "shoes", "arm_l": "skin", "arm_r": "skin", "ear_l": "skin", "ear_r": "skin",
          "small_14": "pants", "small_15": "pants", "small_16": "skin", "small_17": "skin"}
for name, key in assign.items():
    by_name[name].data.materials.clear()
    by_name[name].data.materials.append(palette[key])
look(0, body, height * 1.1, "solid_front")
look(35, body, height * 1.1, "solid_threequarter")
look(-90, body, height * 1.1, "solid_right")
look(35, head, height * 0.34, "solid_head")
