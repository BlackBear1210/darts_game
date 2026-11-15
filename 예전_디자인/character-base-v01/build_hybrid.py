"""v3.1 머리와 P2 몸을 합쳐 부위별 캐릭터 베이스를 만든다. 원본 모델 파일은 바꾸지 않는다.

실행: blender -b --factory-startup --python build_hybrid.py -- <v3.1.glb> <p2.fbx> <작업폴더> <출력.blend>
작업폴더의 tune_gains.json(몸 색), head_gains.json(머리 색)을 읽는다.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
v31_path, p2_path, work_dir, out_blend = args[0], args[1], Path(args[2]), Path(args[3])
out_blend.parent.mkdir(parents=True, exist_ok=True)

CUT_PCT = 70.0          # 이 높이 아래의 v3.1 은 버린다. 그 위의 티셔츠 면은 색으로 지워 턱을 살린다.
NECK_DROP = 0.05        # 잘린 목을 티셔츠 안쪽으로 늘리는 길이
NECK_TAPER = 0.94
SKULL_CUT_PCT = 87.0    # P2 두개골에서 이 높이 위만 쓴다. 대머리일 때 머리카락 자리를 막는다.
SKULL_SCALE = 0.93     # 두개골을 v3.1 머리와 머리카락 안쪽으로 넣는 비율
BODY_NAMES = ["pants", "shirt", "eye_r", "eye_l", "hair", "arm_r", "arm_l", "shoe_r", "shoe_l", "head",
              "ear_r", "ear_l", "brow_r", "brow_l", "ankle_r", "ankle_l", "small_16", "small_17"]
BODY_KEEP = {"pants": "pants", "shirt": "shirt", "arm_r": "skin", "arm_l": "skin", "shoe_r": "shoes",
             "shoe_l": "shoes", "ankle_r": "skin", "ankle_l": "skin", "eye_r": "eye", "eye_l": "eye"}
SHARP_DEG = {"hair": 16, "head": 40, "shirt": 42, "pants": 42, "arm_r": 40, "arm_l": 40, "eye_r": 180, "eye_l": 180}
LUMA = np.array([0.3, 0.59, 0.11], dtype=np.float32)
SIDEBURN_END_PCT = 84.5  # 시트의 구레나룻은 눈 높이쯤에서 끝난다. 이 아래 앞쪽 머리카락 면은 살로 바꾼다.

body_gains = json.loads((work_dir / "tune_gains.json").read_text())
head_gains_path = work_dir / "head_gains.json"
head_gains = json.loads(head_gains_path.read_text()) if head_gains_path.exists() else {}


def gained_material(source, name, gain):
    """이미지 색에 값을 곱하는 재질. glTF 의 baseColorFactor 로 나가고 Godot 의 albedo_color 가 된다."""
    material = source.copy()
    material.name = name
    tree = material.node_tree
    image = next(n for n in tree.nodes if n.type == "TEX_IMAGE")
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    mix = tree.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    tree.links.new(image.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = (*gain, 1)
    tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.15  # 어두운 색이 회색으로 뜨지 않게 한다.
    return material


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_transform(obj):
    activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def set_shading(obj, degrees):
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.set_sharp_from_angle(angle=math.radians(degrees))
    obj.data.update()


def fit_sphere(points):
    """점들에 맞는 구의 중심과 반지름."""
    a = np.c_[2 * points, np.ones(len(points))]
    solution = np.linalg.lstsq(a, (points ** 2).sum(axis=1), rcond=None)[0]
    center = solution[:3]
    return center, float(np.sqrt(solution[3] + center @ center))


def face_neighbors(mesh_bm):
    return [[l.face.index for e in f.edges for l in e.link_loops if l.face != f] for f in mesh_bm.faces]


def components(flags, near_faces):
    seen = np.zeros(len(flags), dtype=bool)
    groups = []
    for start in np.where(flags)[0]:
        if seen[start]:
            continue
        seen[start] = True
        stack, group = [int(start)], []
        while stack:
            index = stack.pop()
            group.append(index)
            for other in near_faces[index]:
                if flags[other] and not seen[other]:
                    seen[other] = True
                    stack.append(other)
        groups.append(group)
    return sorted(groups, key=len, reverse=True)


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- P2 몸: 머리 쪽 부위를 버리고 몸과 눈만 남긴다 ---
bpy.ops.wm.fbx_import(filepath=p2_path)
p2 = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
apply_transform(p2)
activate(p2)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE")
bpy.ops.object.mode_set(mode="OBJECT")
parts = sorted((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: -len(o.data.vertices))
body_source_material = parts[0].material_slots[0].material
body_materials = {}
for obj, name in zip(parts, BODY_NAMES):
    if name == "head":
        obj.name = "skull"
        obj.data.name = "skull"
        continue
    if name not in BODY_KEEP:
        bpy.data.objects.remove(obj, do_unlink=True)
        continue
    obj.name = name
    obj.data.name = name
    key = BODY_KEEP[name]
    if key not in body_materials:
        body_materials[key] = gained_material(body_source_material, f"M_{key.capitalize()}_Body", body_gains[key])
    obj.material_slots[0].material = body_materials[key]
    set_shading(obj, SHARP_DEG.get(name, 28))
body_objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
skull = bpy.data.objects["skull"]

# --- v3.1 머리를 가져온다 ---
bpy.ops.import_scene.gltf(filepath=v31_path)
source = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o not in body_objects)
apply_transform(source)
source.name = "head"
source.data.name = "head"
head_source_material = source.material_slots[0].material

image = next(n for n in head_source_material.node_tree.nodes if n.type == "TEX_IMAGE").image
image.colorspace_settings.name = "Non-Color"
width, tall = image.size
pixels = np.empty(width * tall * 4, dtype=np.float32)
image.pixels.foreach_get(pixels)
pixels = pixels.reshape(tall, width, 4)[..., :3]
image.colorspace_settings.name = "sRGB"


def face_colors(mesh_bm):
    mesh_bm.faces.ensure_lookup_table()
    uv_layer = mesh_bm.loops.layers.uv.active
    colors = np.zeros((len(mesh_bm.faces), 3), dtype=np.float32)
    for face in mesh_bm.faces:
        uvs = [loop[uv_layer].uv for loop in face.loops]
        center = sum(uvs, Vector((0, 0))) / len(uvs)
        samples = [center] + [center.lerp(uv, 0.7) for uv in uvs]
        values = [pixels[min(int((s.y % 1) * tall), tall - 1), min(int((s.x % 1) * width), width - 1)] for s in samples]
        colors[face.index] = np.median(values, axis=0)
    return colors


# --- 티셔츠 색의 면을 지워 목을 남기고, 잘린 목을 티셔츠 안쪽으로 늘린다 ---
bm = bmesh.new()
bm.from_mesh(source.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
low = min(v.co.z for v in bm.verts)
high = max(v.co.z for v in bm.verts)
height = high - low
cut_z = low + height * CUT_PCT / 100
bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=1e-7,
                       plane_co=(0, 0, cut_z), plane_no=(0, 0, 1), clear_inner=True)
rgb = face_colors(bm)
is_shirt = (rgb[:, 2] > rgb[:, 1] + 0.01) & (rgb @ LUMA < 0.42)
near_faces = face_neighbors(bm)
keep = components(~is_shirt, near_faces)[0]
keep_flags = np.zeros(len(bm.faces), dtype=bool)
keep_flags[keep] = True
print("shirt faces removed", int(is_shirt.sum()), "kept", len(keep))
bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep_flags[f.index]], context="FACES")
bm.edges.ensure_lookup_table()
open_edges = [e for e in bm.edges if e.is_boundary]
print("neck ring edges", len(open_edges))
ring_center = sum((v.co for e in open_edges for v in e.verts), Vector()) / (2 * len(open_edges))
result = bmesh.ops.extrude_edge_only(bm, edges=open_edges)
for vert in (g for g in result["geom"] if isinstance(g, bmesh.types.BMVert)):
    flat = vert.co - ring_center
    vert.co = ring_center + Vector((flat.x * NECK_TAPER, flat.y * NECK_TAPER, flat.z - NECK_DROP))
bm.to_mesh(source.data)
bm.free()
source.data.update()

# --- 텍스처 색으로 면을 머리카락 / 눈 / 살로 나눈다 ---
bm = bmesh.new()
bm.from_mesh(source.data)
face_rgb = face_colors(bm)
luma = face_rgb @ LUMA
spread = face_rgb.max(axis=1) - face_rgb.min(axis=1)
is_dark = luma < 0.43
is_white = (face_rgb.min(axis=1) > 0.62) & (spread < 0.14)
neighbors = face_neighbors(bm)

dark_groups = components(is_dark, neighbors)
print("dark groups", [len(g) for g in dark_groups[:8]])
hair = np.zeros(len(bm.faces), dtype=bool)
hair[dark_groups[0]] = True
for _ in range(3):
    # 경계의 들쭉날쭉한 면을 정리한다.
    updated = hair.copy()
    for index, near in enumerate(neighbors):
        count = sum(hair[n] for n in near)
        if not hair[index] and count >= 2 and luma[index] < 0.52:
            updated[index] = True
        elif hair[index] and count <= 1:
            updated[index] = False
    hair = updated
hair_groups = components(hair, neighbors)
hair[:] = False
hair[hair_groups[0]] = True

white_groups = components(is_white & ~hair, neighbors)
print("white groups", [len(g) for g in white_groups[:6]])
eye = np.zeros(len(bm.faces), dtype=bool)
for group in white_groups[:2]:
    eye[group] = True
for _ in range(4):
    # 눈동자처럼 흰자에 둘러싸인 면을 눈에 넣는다.
    updated = eye.copy()
    for index, near in enumerate(neighbors):
        if not eye[index] and not hair[index] and near and sum(eye[n] for n in near) >= max(2, len(near) - 1):
            updated[index] = True
    eye = updated
for group in components(is_dark & ~hair & ~eye, neighbors):
    members = set(group)
    if all(eye[n] or n in members for index in group for n in neighbors[index]):
        eye[group] = True
# 머리카락 사이에 끼인 조각은 머리카락으로 합친다. 가장 큰 덩어리만 얼굴이다.
for group in components(~hair & ~eye, neighbors)[1:]:
    hair[group] = True
# 시트보다 긴 구레나룻과 관자놀이 텍스처 얼룩은 깨끗한 살색 면으로 바꾼다.
bm.faces.ensure_lookup_table()
centers = np.array([tuple(f.calc_center_median()) for f in bm.faces])
heights = (centers[:, 2] - low) / height * 100
patch = hair & (heights < SIDEBURN_END_PCT) & (centers[:, 0] > -0.03)
temple = (~hair & ~eye & (np.abs(centers[:, 1]) > 0.06) & (heights > 82) & (heights < 92)
          & (centers[:, 0] > -0.005) & (luma < 0.62))
patch |= temple
hair &= ~patch
print("faces hair", int(hair.sum()), "eye", int(eye.sum()), "patch", int(patch.sum()), "skin", int((~hair & ~eye & ~patch).sum()))

# --- v3.1 눈 자리에 깨끗한 P2 눈을 맞춰 넣는다. y 가 양수면 캐릭터 왼쪽이다 ---
bm.faces.ensure_lookup_table()
for group in components(eye, neighbors)[:2]:
    verts = {v.index: tuple(v.co) for index in group for v in bm.faces[index].verts}
    target_center, target_radius = fit_sphere(np.array(list(verts.values())))
    name = "eye_l" if target_center[1] > 0 else "eye_r"
    obj = bpy.data.objects[name]
    co = np.array([tuple(v.co) for v in obj.data.vertices])
    own_center, own_radius = fit_sphere(co)
    ratio = target_radius / own_radius
    print(name, "target", target_center.round(4), round(target_radius, 4),
          "own", own_center.round(4), round(own_radius, 4), "ratio", round(ratio, 3))
    moved = target_center + (co - own_center) * ratio
    obj.data.vertices.foreach_set("co", moved.ravel())
    obj.data.update()

# --- 재질 지정 후 머리카락을 따로 뗀다 ---
skin_material = gained_material(head_source_material, "M_Skin_Head", head_gains.get("skin", [1, 1, 1]))
hair_material = gained_material(head_source_material, "M_Hair", head_gains.get("hair", [1, 1, 1]))
source.data.materials.clear()
patch_material = bpy.data.materials.new("M_Skin_Scalp")
patch_material.use_nodes = True
patch_bsdf = next(n for n in patch_material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
patch_bsdf.inputs["Base Color"].default_value = (*head_gains.get("scalp_rgb", [0.85, 0.42, 0.22]), 1)
patch_bsdf.inputs["Roughness"].default_value = 0.85
patch_bsdf.inputs["Specular IOR Level"].default_value = 0.15
source.data.materials.append(skin_material)
source.data.materials.append(hair_material)
source.data.materials.append(patch_material)
for index, face in enumerate(bm.faces):
    face.material_index = 1 if hair[index] else (2 if patch[index] else 0)
bmesh.ops.delete(bm, geom=[f for i, f in enumerate(bm.faces) if eye[i]], context="FACES")
bm.to_mesh(source.data)
bm.free()
source.data.update()

activate(source)
mesh = source.data
hair_flags = [p.material_index == 1 for p in mesh.polygons]
mesh.polygons.foreach_set("select", hair_flags)
mesh.edges.foreach_set("select", [False] * len(mesh.edges))
mesh.vertices.foreach_set("select", [False] * len(mesh.vertices))
mesh.update()
bpy.context.tool_settings.mesh_select_mode = (False, False, True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
hair_object = next(o for o in bpy.context.selected_objects if o != source)
hair_object.name = "hair"
hair_object.data.name = "hair"
hair_object.data.materials.clear()
hair_object.data.materials.append(hair_material)
source.data.materials.pop(index=1)

# --- 두개골: P2 머리의 윗부분을 줄여 머리카락 안쪽에 넣는다. 대머리일 때 보인다 ---
bm = bmesh.new()
bm.from_mesh(skull.data)
skull_cut = low + height * SKULL_CUT_PCT / 100
bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=1e-7,
                       plane_co=(0, 0, skull_cut), plane_no=(0, 0, 1), clear_inner=True)
bm.verts.ensure_lookup_table()
points = np.array([tuple(v.co) for v in bm.verts])
pivot = Vector(tuple((points.min(axis=0) + points.max(axis=0)) / 2))
for vert in bm.verts:
    vert.co = pivot + (vert.co - pivot) * SKULL_SCALE
bm.to_mesh(skull.data)
bm.free()
skull.data.materials.clear()
skull.data.materials.append(patch_material)
set_shading(skull, 30)
set_shading(source, SHARP_DEG["head"])
set_shading(hair_object, SHARP_DEG["hair"])

for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    print("PART", obj.name, "verts", len(obj.data.vertices), "faces", len(obj.data.polygons),
          "materials", [m.name for m in obj.data.materials])
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(out_blend))
print("saved", out_blend)
