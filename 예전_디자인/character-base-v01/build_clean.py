"""깨끗한 P2 메시로 캐릭터 베이스를 만든다. 얼룩이 없도록 눈을 뺀 모든 부위는 단색 재질을 쓴다.

v3.1 에서는 눈 배치와 귀 모양만 가져온다. 원본 모델 파일은 바꾸지 않는다.
실행: blender -b --factory-startup --python build_clean.py -- <p2.fbx> <v3.1.glb> <작업폴더> <출력.blend>
작업폴더의 clean_colors.json(선형 색), sheet_face.json(입 위치), tune_gains.json(눈 색)을 읽는다.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
p2_path, v31_path, work_dir, out_blend = args[0], args[1], Path(args[2]), Path(args[3])
out_blend.parent.mkdir(parents=True, exist_ok=True)

NAMES = ["pants", "shirt", "eye_r", "eye_l", "hair", "arm_r", "arm_l", "shoe_r", "shoe_l", "head",
         "ear_r", "ear_l", "brow_r", "brow_l", "ankle_r", "ankle_l", "socket_a", "socket_b"]
PART_COLOR = {"pants": "bottom", "shirt": "top", "hair": "hair", "arm_r": "skin", "arm_l": "skin", "shoe_r": "shoes",
              "shoe_l": "shoes", "head": "skin", "ear_r": "skin", "ear_l": "skin", "ankle_r": "skin", "ankle_l": "skin",
              "brow_r": "brow", "brow_l": "brow"}
SHARP_DEG = {"hair": 6, "head": 27, "shirt": 42, "pants": 42, "arm_r": 40, "arm_l": 40, "shoe_r": 30, "shoe_l": 30,
             "ear_r": 35, "ear_l": 35, "eye_r": 180, "eye_l": 180}
MATERIAL_NAME = {"skin": "M_Skin", "hair": "M_Hair", "top": "M_Top", "bottom": "M_Bottom", "shoes": "M_Shoes",
                 "brow": "M_Brow", "mouth": "M_Mouth"}
# v3.1 에서 맞춘 눈 구(캐릭터 얼굴 가운데 기준). 사용자가 좋다고 한 눈 배치다.
EYE_HALF_GAP = 0.0393
EYE_X = 0.0465
EYE_Z = 0.3750
EYE_RADIUS = 0.0220
NOSE_WIDEN = 0.26       # 코가 시트보다 좁아 앞쪽으로 갈수록 넓힌다.
EAR_CUT = 0.052         # v3.1 머리 가운데에서 이만큼 바깥의 면을 귀로 쓴다.
EAR_SINK = 0.006        # 귀 뿌리가 머리 안으로 들어가게 하는 거리
MOUTH_OFFSET = 0.0022
# P2 메시의 입 틈 자리. 틈이 어두운 선으로 보이므로 입 선을 이 위에 얹어 덮는다.
MOUTH_Z = 0.2808
MOUTH_Y = 0.0091
MOUTH_HALF_WIDTH = 0.0268
MOUTH_HALF_THICK = 0.0024
BROW_THIN = 0.8        # 눈썹이 시트보다 두꺼워 세로로 줄인다.
BROW_RAISE = 0.004

colors = json.loads((work_dir / "clean_colors.json").read_text())
gains = json.loads((work_dir / "tune_gains.json").read_text())
face = json.loads((work_dir / "sheet_face.json").read_text())


def solid_material(key):
    material = bpy.data.materials.new(MATERIAL_NAME[key])
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*colors[key], 1)
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.15
    return material


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def set_shading(obj, degrees):
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.set_sharp_from_angle(angle=math.radians(degrees))
    obj.data.update()


def vertex_array(obj):
    data = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("co", data)
    return data.reshape(-1, 3)


def store_vertices(obj, points):
    obj.data.vertices.foreach_set("co", points.ravel())
    obj.data.update()


def fit_sphere(points):
    a = np.c_[2 * points, np.ones(len(points))]
    solution = np.linalg.lstsq(a, (points ** 2).sum(axis=1), rcond=None)[0]
    center = solution[:3]
    return center, float(np.sqrt(solution[3] + center @ center))


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.fbx_import(filepath=p2_path)
source = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
activate(source)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE")
bpy.ops.object.mode_set(mode="OBJECT")
parts = sorted((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: -len(o.data.vertices))
original_material = parts[0].material_slots[0].material
by_name = {}
for obj, name in zip(parts, NAMES):
    if name.startswith("socket"):
        bpy.data.objects.remove(obj, do_unlink=True)
        continue
    obj.name = name
    obj.data.name = name
    by_name[name] = obj

materials = {key: solid_material(key) for key in MATERIAL_NAME}
for name, key in PART_COLOR.items():
    by_name[name].data.materials.clear()
    by_name[name].data.materials.append(materials[key])

# 눈은 눈동자가 그려진 P2 텍스처를 쓴다.
eye_material = original_material.copy()
eye_material.name = "M_Eye"
tree = eye_material.node_tree
image_node = next(n for n in tree.nodes if n.type == "TEX_IMAGE")
bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
mix = tree.nodes.new("ShaderNodeMix")
mix.data_type = "RGBA"
mix.blend_type = "MULTIPLY"
mix.inputs[0].default_value = 1.0
tree.links.new(image_node.outputs["Color"], mix.inputs[6])
mix.inputs[7].default_value = (*gains["eye"], 1)
tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.6
bsdf.inputs["Specular IOR Level"].default_value = 0.2
for name in ("eye_r", "eye_l"):
    by_name[name].data.materials.clear()
    by_name[name].data.materials.append(eye_material)

# --- 머리 다듬기: 얼굴 가운데를 잡고 코를 넓힌다 ---
head = by_name["head"]
points = vertex_array(head)
low_all = min(vertex_array(o)[:, 2].min() for o in by_name.values())
face_center_y = float(np.median(vertex_array(by_name["eye_r"])[:, 1]) + np.median(vertex_array(by_name["eye_l"])[:, 1])) / 2
print("face center y", round(face_center_y, 4), "head x range", points[:, 0].min().round(4), points[:, 0].max().round(4))
weight = np.clip((points[:, 0] - 0.052) / 0.03, 0, 1)
points[:, 1] = face_center_y + (points[:, 1] - face_center_y) * (1 + NOSE_WIDEN * weight)

# 입 주변의 메시 꺾임을 없앤다. 입은 아래에서 얇은 메시로 다시 만든다.
bm = bmesh.new()
bm.from_mesh(head.data)
bm.verts.ensure_lookup_table()
links = [[e.other_vert(v).index for e in v.link_edges] for v in bm.verts]
bm.free()
# 코 아래부터 턱 위까지 앞뒤 굴곡만 주변에 맞춰 편다. 높이와 좌우 위치는 그대로 둔다.
mouth_zone = ((points[:, 2] > face["mouth_z"] - 0.03) & (points[:, 2] < face["mouth_z"] + 0.034)
              & (np.abs(points[:, 1] - face_center_y) < 0.055) & (points[:, 0] > 0.02) & (points[:, 0] < 0.085))
print("mouth zone verts", int(mouth_zone.sum()))
for _ in range(60):
    updated = points[:, 0].copy()
    for index in np.where(mouth_zone)[0]:
        updated[index] = points[links[index], 0].mean()
    points[:, 0] = updated
store_vertices(head, points)

# --- 눈: 시트에 맞는 v3.1 배치로 옮기고 좌우를 맞춘다 ---
for name, sign in (("eye_r", -1), ("eye_l", 1)):
    obj = by_name[name]
    co = vertex_array(obj)
    center, radius = fit_sphere(co)
    target = np.array([EYE_X, face_center_y + sign * EYE_HALF_GAP, EYE_Z])
    store_vertices(obj, target + (co - center) * (EYE_RADIUS / radius))
    print(name, "center", center.round(4), "->", target.round(4), "radius", round(radius, 4))

# --- 눈썹: 시트처럼 얇게 줄이고 눈 위로 조금 올린다 ---
for name in ("brow_r", "brow_l"):
    co = vertex_array(by_name[name])
    middle = np.median(co[:, 2])
    co[:, 2] = middle + (co[:, 2] - middle) * BROW_THIN + BROW_RAISE
    store_vertices(by_name[name], co)

# --- 귀: v3.1 의 굴곡 있는 귀 모양을 잘라 온다 ---
bpy.ops.import_scene.gltf(filepath=v31_path)
known = set(by_name.values())
v31 = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o not in known)
activate(v31)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
image = next(n for n in v31.material_slots[0].material.node_tree.nodes if n.type == "TEX_IMAGE").image
image.colorspace_settings.name = "Non-Color"
width, tall = image.size
pixels = np.empty(width * tall * 4, dtype=np.float32)
image.pixels.foreach_get(pixels)
pixels = pixels.reshape(tall, width, 4)[..., :3]
bm = bmesh.new()
bm.from_mesh(v31.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
bm.faces.ensure_lookup_table()
uv_layer = bm.loops.layers.uv.active
v31_center_y = 0.0035
ear_faces = {"ear_r": [], "ear_l": []}
for f in bm.faces:
    center = f.calc_center_median()
    if not (-0.12 < center.z - 0.5 + 0.5 and 0.30 < center.z < 0.41):
        continue
    offset = center.y - v31_center_y
    if abs(offset) < EAR_CUT or center.x > 0.03 or center.x < -0.06:
        continue
    uv = sum((l[uv_layer].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
    rgb = pixels[min(int((uv.y % 1) * tall), tall - 1), min(int((uv.x % 1) * width), width - 1)]
    if rgb @ np.array([0.3, 0.59, 0.11]) < 0.43:
        continue
    ear_faces["ear_l" if offset > 0 else "ear_r"].append(f.index)
for name, indexes in ear_faces.items():
    print(name, "v3.1 faces", len(indexes))
    keep = set(indexes)
    new_bm = bmesh.new()
    mapping = {}
    for index in keep:
        f = bm.faces[index]
        verts = []
        for v in f.verts:
            if v.index not in mapping:
                sign = 1 if name == "ear_l" else -1
                shifted = v.co + Vector((0, face_center_y - v31_center_y - sign * EAR_SINK, 0))
                mapping[v.index] = new_bm.verts.new(shifted)
            verts.append(mapping[v.index])
        new_bm.faces.new(verts)
    # 가장 큰 덩어리만 귀로 남긴다.
    seen, groups = set(), []
    for start in new_bm.faces:
        if start in seen:
            continue
        seen.add(start)
        stack, group = [start], []
        while stack:
            current = stack.pop()
            group.append(current)
            for edge in current.edges:
                for other in edge.link_faces:
                    if other not in seen:
                        seen.add(other)
                        stack.append(other)
        groups.append(group)
    groups.sort(key=len, reverse=True)
    for group in groups[1:]:
        bmesh.ops.delete(new_bm, geom=group, context="FACES")
    ear = by_name[name]
    new_bm.to_mesh(ear.data)
    new_bm.free()
    ear.data.update()
bm.free()
bpy.data.objects.remove(v31, do_unlink=True)

# --- 입: 시트의 얇은 선을 얼굴 표면에 붙인 메시로 만든다 ---
depsgraph = bpy.context.evaluated_depsgraph_get()
tree_head = BVHTree.FromObject(head, depsgraph)
half = MOUTH_HALF_WIDTH
thick = MOUTH_HALF_THICK
mouth_center_y = MOUTH_Y
samples = 13
depths = []
for index in range(samples):
    y = mouth_center_y + (-1 + 2 * index / (samples - 1)) * half
    location, _, _, _ = tree_head.ray_cast(Vector((0.3, y, MOUTH_Z)), Vector((-1, 0, 0)))
    if location is None:
        raise SystemExit("mouth ray missed the face")
    depths.append(location.x)
# 면의 꺾임을 따라가면 선이 꼬이므로 깊이를 부드럽게 펴서 곧은 띠로 만든다.
depths = np.array(depths)
for _ in range(4):
    depths[1:-1] = (depths[:-2] + depths[1:-1] * 2 + depths[2:]) / 4
mouth_bm = bmesh.new()
top_row, bottom_row = [], []
for index in range(samples):
    t = -1 + 2 * index / (samples - 1)
    y = mouth_center_y + t * half
    tip = thick * (1 - 0.3 * abs(t) ** 3)
    x = float(depths[index]) + MOUTH_OFFSET
    top_row.append(mouth_bm.verts.new((x, y, MOUTH_Z + tip)))
    bottom_row.append(mouth_bm.verts.new((x, y, MOUTH_Z - tip)))
for index in range(samples - 1):
    mouth_bm.faces.new((top_row[index], bottom_row[index], bottom_row[index + 1], top_row[index + 1]))
bmesh.ops.recalc_face_normals(mouth_bm, faces=mouth_bm.faces)
mouth_mesh = bpy.data.meshes.new("mouth")
mouth_bm.to_mesh(mouth_mesh)
mouth_bm.free()
mouth = bpy.data.objects.new("mouth", mouth_mesh)
bpy.context.scene.collection.objects.link(mouth)
mouth_mesh.materials.append(materials["mouth"])
by_name["mouth"] = mouth

for name, obj in by_name.items():
    set_shading(obj, SHARP_DEG.get(name, 28))
    print("PART", name, "verts", len(obj.data.vertices), "faces", len(obj.data.polygons))
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(out_blend))
print("saved", out_blend)
