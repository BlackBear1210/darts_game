"""열린 Blender에서 얼굴을 시트 수치에 맞춘다. 수치는 overlay_face.py 겹침에서 읽었다.

실행: python blender_live.py run fix_face.py
처음 실행할 때 수정 전 메시를 *_orig 로 보관하고, 매번 그 메시에서 다시 계산하므로 여러 번 돌려도 된다.
시트의 정면과 옆면은 코끝·입 높이가 서로 약 0.02 달라, 두 값 사이를 쓴다.
"""
import json
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

FACE_Y = 0.0115           # 얼굴 좌우 가운데
NOSE_Y = 0.0119
EYE_GAP = 0.0403          # 가운데에서 눈 중심까지
EYE_Z = 0.3765
EYE_RADIUS = 0.0200
EYE_X = 0.0420            # 얼굴 표면 근처에 두어 절반만 나오게 한다.
SLIT_PAIRS = ((22, 21), (87, 133), (25, 24), (88, 94))  # 눈 바깥쪽 세로 틈의 양쪽 점
# 코 점: 번호 -> (앞뒤 x 또는 None, 가운데에서 좌우 거리 또는 None, 높이 z 또는 None)
NOSE = {
    64: (0.1135, -0.0165, 0.3265), 67: (0.1135, 0.0165, 0.3265),
    65: (0.1125, -0.0165, 0.3240), 69: (0.1125, 0.0165, 0.3240),
    72: (0.1095, -0.0165, 0.3215), 71: (0.1095, 0.0165, 0.3215),
    62: (0.0983, -0.0125, 0.3510), 59: (0.0983, 0.0125, 0.3510),
    63: (0.0963, -0.0150, 0.3505), 70: (0.0963, 0.0150, 0.3505),
    60: (0.0788, None, None),
    61: (0.0788, -0.0100, None), 58: (0.0788, 0.0100, None),
    91: (0.0768, -0.0130, None), 56: (0.0768, 0.0130, None),
    92: (0.0700, -0.0125, None), 55: (0.0700, 0.0125, None),
    52: (0.0715, None, None),
    66: (0.0790, -0.0215, 0.3140), 68: (0.0790, 0.0215, 0.3140),
}
# 옆모습 뼈대 점: 번호 -> (앞뒤 x, 높이 z 또는 None). 왼쪽과 오른쪽 짝을 함께 적는다.
BONES = {
    # 눈썹뼈: 코 시작점보다 앞으로 나온 각
    51: (0.0746, None), 49: (0.0735, None), 53: (0.0735, None), 90: (0.0650, None), 54: (0.0650, None),
    89: (0.0570, None), 29: (0.0570, None),
    # 눈 바깥 뼈: 안구 뒤쪽을 가린다
    22: (0.0350, None), 21: (0.0350, None), 87: (0.0350, None), 133: (0.0350, None),
    25: (0.0420, None), 24: (0.0420, None), 88: (0.0420, None), 94: (0.0420, None),
    # 광대
    20: (0.0370, None), 132: (0.0370, None), 17: (0.0300, 0.3400), 131: (0.0300, 0.3400),
    74: (0.0520, None), 85: (0.0520, None),
    # 코 양옆: 눈구멍 쪽을 뒤로 빼서 코를 기둥처럼 세운다
    57: (0.0350, None), 86: (0.0350, None),
    # 턱선
    16: (0.0400, None), 128: (0.0400, None), 15: (0.0155, 0.2790), 126: (0.0155, 0.2790),
}
# 광대에서 턱으로 내려오는 면 경계와 턱 밑 경계. 시트 옆면에 뚜렷하게 보인다.
SHARP_EDGES = ((21, 17), (17, 16), (133, 131), (131, 128), (15, 16), (16, 12), (126, 128), (128, 3),
               (92, 91), (91, 63), (63, 64), (55, 56), (56, 70), (70, 67), (66, 64), (68, 67))
# 광대 능선 뒤쪽 면: 귀 쪽으로 좁혀 어둡게 꺾이게 한다. 번호 -> 좌우 폭 비율
REAR_CHEEK = {19: 0.86, 130: 0.86, 18: 0.76, 129: 0.76}
# 시트의 명암을 얼굴 점의 밝기로 넣는다. 1 이 피부색 그대로다. 면을 따라 부드럽게 번진다.
VERTEX_SHADE = {
    # 눈 안쪽과 아래
    57: 0.78, 86: 0.78,
    # 눈 바깥
    22: 0.82, 21: 0.82, 87: 0.82, 133: 0.82, 25: 0.86, 24: 0.86, 88: 0.86, 94: 0.86,
    # 코 옆 위쪽과 미간
    91: 0.90, 56: 0.90, 92: 0.95, 55: 0.95, 52: 0.95,
    # 코 밑 그늘
    72: 0.74, 71: 0.74, 65: 0.86, 69: 0.86, 66: 0.95, 68: 0.95, 73: 0.80, 80: 0.84, 77: 0.92, 78: 0.92,
    # 턱 가운데
    5: 0.94, 6: 0.94, 134: 0.94,
}
# 뒷머리 윤곽: measure_back.py 가 잰 각도별 비율. 뒤쪽 점에만 적용해 앞머리는 그대로 둔다.
BACK_CENTER_Y = 0.0106
BACK_CENTER_Z = 0.405
BACK_RATIO_PATH = r"C:\Users\아버지\Desktop\다트\output\character-base-v01\back_outline.json"
# 머리카락 명암: 시트 세 뷰의 밝기를 점으로 옮긴다. 렌더 조명이 더해지므로 강도를 낮춘다.
INPUT_DIR = r"C:\Users\아버지\Desktop\다트\output\character-base-v01\inputs"
INPUT_PX = 569 * 1024 / 620
INPUT_FEET = (579 + 17) * 1024 / 620
HAIR_TONE_STRENGTH = 0.8
HAIR_TONE_LIMITS = (0.6, 1.5)
# 얼굴을 갸름하게 하는 높이별 좌우 비율
SLIM = ((0.25, 0.95), (0.30, 0.955), (0.335, 1.0))
FORWARD = ((0.245, 0.007), (0.27, 0.015), (0.285, 0.0175), (0.30, 0.0175), (0.315, 0.0))
LIFT = ((0.236, 0.0185), (0.25, 0.0085), (0.2576, 0.0015), (0.2654, 0.0), (0.27, 0.0))
CHIN_WIDEN = 1.2
JAW_WIDEN = 1.1
JAW_SIDE_POINTS = (2, 10)
CHIN_POINTS = (0, 8, 3, 12, 4, 11, 135, 14)
CHIN_SIDE_POINTS = (8, 12, 0, 3)   # 턱 윗줄. 더 넓혀서 턱 옆면을 세운다.
CHIN_SIDE_WIDEN = 1.18
JAW_FORWARD = {121: 0.006, 125: 0.006}
# 턱 밑이 목으로 꺾이는 점. 시트의 목 앞선은 z 0.264 에서 x 0.024 쯤이다.
UNDER_CHIN = {124: (0.0285, 0.2675), 123: (0.0300, 0.2675), 13: (0.0300, 0.2675)}
# 코 아래 V자 선을 없애려고 코와 입 사이를 평평하게 편다.
PHILTRUM_POINTS = (73, 80, 77, 78, 84, 75, 76, 79, 81, 7, 82, 83, 1, 9)
PHILTRUM_X = 0.0825
PHILTRUM_CURVE = 8.0
HEAD_SHIFT = 0.0          # 몸통 기준으로 재면 시트와 머리 위치가 같다(시트 이미지 전체가 약 0.004 치우쳐 있다).
HEAD_PARTS = ("head", "hair", "eye_l", "eye_r", "pupil_l", "pupil_r", "brow_l", "brow_r", "mouth", "ear_l", "ear_r")
MOUTH_Z = 0.2808          # P2 메시의 입 틈 자리. 틈이 어두운 선으로 보이므로 입 선을 이 위에 얹어 덮는다.
MOUTH_Y = 0.0091
MOUTH_HALF_WIDTH = 0.0268
MOUTH_HALF_THICK = 0.0020
MOUTH_LIFT = 0.0022
MOUTH_SAMPLES = 13
EAR_FRONT_LIMIT = 0.006
EAR_SHIFT = {"ear_l": 0.004, "ear_r": 0.001}
EAR_DROP = 0.004
HEAD_SHARP_DEG = 33
TEMPLE_FORWARD = 0.006
PUPIL_RADIUS = 0.0040
PUPIL_SIDES = 14
PUPIL_LIFT = 0.0004
PUPIL_YAW = 4.0
EYE_WHITE = (0.90, 0.83, 0.74)
PUPIL_COLOR = (0.012, 0.009, 0.010)
# 눈썹: 가운데에서 좌우 거리, 높이. 바깥쪽에서 안쪽 순서. 시트의 곧고 얇은 선이다.
BROW_LINE = ((0.0604, 0.4002), (0.0460, 0.4040), (0.0320, 0.4058), (0.0190, 0.4057))
BROW_HALF_THICK = 0.0022
BROW_OFFSET = 0.0016


def keep_original(name):
    obj = bpy.data.objects[name]
    original = bpy.data.meshes.get(name + "_orig")
    if original is None:
        original = obj.data.copy()
        original.name = name + "_orig"
        original.use_fake_user = True
    return obj, original


def read(mesh):
    data = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
    mesh.vertices.foreach_get("co", data)
    return data.reshape(-1, 3)


def write(obj, points):
    obj.data.vertices.foreach_set("co", points.ravel())
    obj.data.update()


def table(values, heights):
    z, amount = zip(*values)
    return np.interp(heights, z, amount)


def solid(name, color, roughness):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.15
    return material


def mesh_object(name):
    obj = bpy.data.objects.get(name)
    if obj is None:
        obj = bpy.data.objects.new(name, bpy.data.meshes.new(name))
        bpy.data.objects["head"].users_collection[0].objects.link(obj)
    return obj


def pupil(name, center, radius, material, side):
    """안구 앞쪽 표면에 붙는 작은 원판."""
    bm = bmesh.new()
    tilt = math.asin(PUPIL_RADIUS / radius)
    surface = radius + PUPIL_LIFT
    tip = bm.verts.new((center[0] + surface, center[1], center[2]))
    rim = []
    for index in range(PUPIL_SIDES):
        angle = 2 * math.pi * index / PUPIL_SIDES
        rim.append(bm.verts.new((center[0] + surface * math.cos(tilt),
                                 center[1] + surface * math.sin(tilt) * math.cos(angle),
                                 center[2] + surface * math.sin(tilt) * math.sin(angle))))
    for index in range(PUPIL_SIDES):
        bm.faces.new((tip, rim[index], rim[(index + 1) % PUPIL_SIDES]))
    yaw = math.radians(PUPIL_YAW) * side
    for vert in bm.verts:
        dx, dy = vert.co.x - center[0], vert.co.y - center[1]
        vert.co.x = center[0] + dx * math.cos(yaw) - dy * math.sin(yaw)
        vert.co.y = center[1] + dx * math.sin(yaw) + dy * math.cos(yaw)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_object(name)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.update()


def brow(name, side, tree, material):
    """시트의 눈썹 선을 얼굴 표면에 붙인 얇은 띠로 만든다."""
    samples = []
    for index in range(len(BROW_LINE) - 1):
        for step in range(3):
            t = step / 3
            a, b = BROW_LINE[index], BROW_LINE[index + 1]
            samples.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    samples.append(BROW_LINE[-1])
    depths = []
    for offset, z in samples:
        location = tree.ray_cast(Vector((0.3, FACE_Y + side * offset, z)), Vector((-1, 0, 0)))[0]
        depths.append(location.x if location else (depths[-1] if depths else 0.05))
    depths = np.array(depths)
    for _ in range(3):
        depths[1:-1] = (depths[:-2] + depths[1:-1] * 2 + depths[2:]) / 4
    bm = bmesh.new()
    upper, lower = [], []
    for index, (offset, z) in enumerate(samples):
        t = index / (len(samples) - 1)
        half = BROW_HALF_THICK * (0.55 + 0.45 * math.sin(math.pi * min(t * 1.2, 1.0) / 2))
        x = float(depths[index]) + BROW_OFFSET
        y = FACE_Y + side * offset
        upper.append(bm.verts.new((x, y, z + half)))
        lower.append(bm.verts.new((x, y, z - half)))
    for index in range(len(samples) - 1):
        bm.faces.new((upper[index], lower[index], lower[index + 1], upper[index + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = bpy.data.objects[name]
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.update()


# --- 머리 메시 ---
head, head_original = keep_original("head")
points = read(head_original)
for a, b in SLIT_PAIRS:
    middle = (points[a] + points[b]) / 2
    points[a] = middle
    points[b] = middle

before = points.copy()
lower_face = (before[:, 0] > 0.02)
weight = np.clip((before[:, 0] - 0.02) / 0.03, 0, 1)
points[:, 0] += table(FORWARD, before[:, 2]) * weight
points[:, 2] += table(LIFT, before[:, 2]) * lower_face
points[:, 1] = FACE_Y + (points[:, 1] - FACE_Y) * table(SLIM, before[:, 2])
for index in CHIN_POINTS:
    points[index, 1] = FACE_Y - 0.002 + (points[index, 1] - FACE_Y + 0.002) * CHIN_WIDEN
for index in CHIN_SIDE_POINTS:
    points[index, 1] = FACE_Y - 0.002 + (points[index, 1] - FACE_Y + 0.002) * CHIN_SIDE_WIDEN
for index in JAW_SIDE_POINTS:
    points[index, 1] = FACE_Y + (points[index, 1] - FACE_Y) * JAW_WIDEN
for index, amount in JAW_FORWARD.items():
    points[index, 0] += amount
for index, (x, offset, z) in NOSE.items():
    if x is not None:
        points[index, 0] = x
    if offset is not None:
        points[index, 1] = NOSE_Y + offset
    if z is not None:
        points[index, 2] = z
for index, (x, z) in UNDER_CHIN.items():
    points[index, 0] = x
    points[index, 2] = z
for index, (x, z) in BONES.items():
    points[index, 0] = x
    if z is not None:
        points[index, 2] = z
for index, ratio in REAR_CHEEK.items():
    points[index, 1] = FACE_Y + (points[index, 1] - FACE_Y) * ratio
for index in PHILTRUM_POINTS:
    points[index, 0] = PHILTRUM_X - PHILTRUM_CURVE * (points[index, 1] - FACE_Y) ** 2
write(head, points)
head.data.set_sharp_from_angle(angle=np.radians(HEAD_SHARP_DEG))
sharp = head.data.attributes.get("sharp_edge") or head.data.attributes.new("sharp_edge", "BOOLEAN", "EDGE")
wanted = {tuple(sorted(pair)) for pair in SHARP_EDGES}
for index, edge in enumerate(head.data.edges):
    if tuple(sorted(edge.vertices)) in wanted:
        sharp.data[index].value = True
head.data.update()

# --- 눈 ---
eye_white = solid("M_EyeWhite", EYE_WHITE, 0.55)
pupil_material = solid("M_Pupil", PUPIL_COLOR, 0.4)
for name, pupil_name, side in (("eye_r", "pupil_r", -1), ("eye_l", "pupil_l", 1)):
    eye, eye_original = keep_original(name)
    eye_points = read(eye_original)
    center = (eye_points.min(axis=0) + eye_points.max(axis=0)) / 2
    radius = float((eye_points.max(axis=0) - eye_points.min(axis=0)).max() / 2)
    target = np.array([EYE_X, FACE_Y + side * EYE_GAP, EYE_Z])
    eye_points = target + (eye_points - center) * (EYE_RADIUS / radius)
    write(eye, eye_points)
    eye.data.materials.clear()
    eye.data.materials.append(eye_white)
    pupil(pupil_name, target, EYE_RADIUS, pupil_material, side)
old_eye = bpy.data.materials.get("M_Eye")
if old_eye is not None and old_eye.users == 0:
    bpy.data.materials.remove(old_eye)

# --- 눈썹 ---
depsgraph = bpy.context.evaluated_depsgraph_get()
tree = BVHTree.FromObject(head, depsgraph)
brow_material = bpy.data.materials["M_Brow"]
mouth = bpy.data.objects["mouth"]
depths = []
for index in range(MOUTH_SAMPLES):
    y = MOUTH_Y + (-1 + 2 * index / (MOUTH_SAMPLES - 1)) * MOUTH_HALF_WIDTH
    depths.append(tree.ray_cast(Vector((0.3, y, MOUTH_Z)), Vector((-1, 0, 0)))[0].x)
depths = np.array(depths)
for _ in range(2):
    depths[1:-1] = np.maximum(depths[1:-1], (depths[:-2] + depths[1:-1] * 2 + depths[2:]) / 4)
bm = bmesh.new()
upper, lower = [], []
for index in range(MOUTH_SAMPLES):
    t = -1 + 2 * index / (MOUTH_SAMPLES - 1)
    y = MOUTH_Y + t * MOUTH_HALF_WIDTH
    half = MOUTH_HALF_THICK * (1 - 0.3 * abs(t) ** 3)
    x = float(depths[index]) + MOUTH_LIFT
    upper.append(bm.verts.new((x, y, MOUTH_Z + half)))
    lower.append(bm.verts.new((x, y, MOUTH_Z - half)))
for index in range(MOUTH_SAMPLES - 1):
    bm.faces.new((upper[index], lower[index], lower[index + 1], upper[index + 1]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mouth.data)
bm.free()
mouth.data.update()

keep_original("brow_l")
keep_original("brow_r")

# --- 얼굴 점 밝기 ---
for name in ("socket_l", "socket_r"):
    leftover = bpy.data.objects.get(name)
    if leftover is not None:
        bpy.data.objects.remove(leftover, do_unlink=True)
old_socket = bpy.data.materials.get("M_Socket")
if old_socket is not None and old_socket.users == 0:
    bpy.data.materials.remove(old_socket)
skin_bsdf = next(n for n in bpy.data.materials["M_Skin"].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
skin_color = tuple(skin_bsdf.inputs["Base Color"].default_value[:3])
head_material = bpy.data.materials.get("M_Skin_Head") or bpy.data.materials.new("M_Skin_Head")
head_material.use_nodes = True
head_tree = head_material.node_tree
head_bsdf = next(n for n in head_tree.nodes if n.type == "BSDF_PRINCIPLED")
head_bsdf.inputs["Roughness"].default_value = 0.85
head_bsdf.inputs["Metallic"].default_value = 0.0
head_bsdf.inputs["Specular IOR Level"].default_value = 0.15
attribute = next((n for n in head_tree.nodes if n.type == "VERTEX_COLOR"), None) or head_tree.nodes.new("ShaderNodeVertexColor")
attribute.layer_name = "Col"
head_tree.links.new(attribute.outputs["Color"], head_bsdf.inputs["Base Color"])
head.data.materials.clear()
head.data.materials.append(head_material)
colors = head.data.color_attributes.get("Col") or head.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
for index in range(len(head.data.vertices)):
    shade = VERTEX_SHADE.get(index, 1.0)
    colors.data[index].color = (skin_color[0] * shade, skin_color[1] * shade, skin_color[2] * shade, 1.0)
head.data.update()

leftover = bpy.data.objects.get("nose_shadow")
if leftover is not None:
    bpy.data.objects.remove(leftover, do_unlink=True)

brow("brow_r", -1, tree, brow_material)
brow("brow_l", 1, tree, brow_material)

# --- 귀: 얼굴 쪽으로 따라온 얇은 조각을 잘라 내고 좌우 폭을 맞춘다 ---
for name in ("ear_l", "ear_r"):
    ear, ear_original = keep_original(name)
    bm = bmesh.new()
    bm.from_mesh(ear_original)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().x > EAR_FRONT_LIMIT], context="FACES")
    seen, groups = set(), []
    for start in bm.faces:
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
        bmesh.ops.delete(bm, geom=group, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for vert in bm.verts:
        vert.co.y += EAR_SHIFT[name]
        vert.co.z -= EAR_DROP
    bm.to_mesh(ear.data)
    bm.free()
    ear.data.polygons.foreach_set("use_smooth", [True] * len(ear.data.polygons))
    ear.data.set_sharp_from_angle(angle=math.radians(35))
    ear.data.update()

# --- 머리 전체를 시트의 얼굴 위치로 옮긴다 ---
keep_original("hair")
hair_points = read(bpy.data.meshes["hair_orig"])
# 관자놀이 옆머리를 앞으로 내린다. 시트는 옆모습에서 머리선이 더 앞에 있다.
temple = (np.clip((hair_points[:, 2] - 0.385) / 0.02, 0, 1) * np.clip((0.465 - hair_points[:, 2]) / 0.02, 0, 1)
          * np.clip((np.abs(hair_points[:, 1] - FACE_Y) - 0.045) / 0.02, 0, 1)
          * np.clip((0.05 - hair_points[:, 0]) / 0.02, 0, 1) * np.clip((hair_points[:, 0] + 0.03) / 0.02, 0, 1))
hair_points[:, 0] += TEMPLE_FORWARD * temple
with open(BACK_RATIO_PATH, encoding="utf-8") as file:
    back_ratio = {int(k): v for k, v in json.load(file).items()}
angles = np.array(sorted(back_ratio))
values = np.array([back_ratio[a] for a in angles])
u = -(hair_points[:, 1] - BACK_CENTER_Y)      # 뒤에서 보면 화면 오른쪽이 -y 다.
v = hair_points[:, 2] - BACK_CENTER_Z
angle = np.degrees(np.arctan2(v, u)) % 360
ratio = np.interp(angle, np.r_[angles, 360], np.r_[values, values[0]])
back_weight = np.clip((0.01 - hair_points[:, 0]) / 0.05, 0, 1)
scale = 1 + (ratio - 1) * back_weight
hair_points[:, 1] = BACK_CENTER_Y + (hair_points[:, 1] - BACK_CENTER_Y) * scale
hair_points[:, 2] = BACK_CENTER_Z + (hair_points[:, 2] - BACK_CENTER_Z) * scale
write(bpy.data.objects["hair"], hair_points)
def input_luma(name):
    image = bpy.data.images.load(INPUT_DIR + "\\" + name, check_existing=True)
    image.colorspace_settings.name = "Non-Color"
    w, h = image.size
    data = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    rgb = data.reshape(h, w, 4)[::-1, :, :3]
    return rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32), rgb


hair_object = bpy.data.objects["hair"]
hair_object.data.update()
normals = np.array([tuple(v.normal) for v in hair_object.data.vertices])
tones = np.zeros(len(hair_points))
weights = np.zeros(len(hair_points))
views = (
    ("front.png", lambda p: 512 + p[:, 1] * INPUT_PX + 3.9, np.clip(normals[:, 0], 0, 1)),
    ("back.png", lambda p: 518.5 - (p[:, 1] - BACK_CENTER_Y) * INPUT_PX, np.clip(-normals[:, 0], 0, 1)),
    ("right.png", lambda p: 512 + p[:, 0] * INPUT_PX, np.abs(normals[:, 1])),
)
for filename, to_x, weight in views:
    luma, rgb = input_luma(filename)
    is_hair = (rgb[..., 0] < 0.5) & (rgb[..., 0] > 0.12) & (rgb[..., 0] - rgb[..., 2] > 0.05)
    reference = float(np.median(luma[:320][is_hair[:320]]))
    x = np.clip(to_x(hair_points).astype(int), 2, 1021)
    y = np.clip((INPUT_FEET - (hair_points[:, 2] + 0.5) * INPUT_PX).astype(int), 2, 1021)
    sample = np.zeros(len(hair_points))
    found = np.zeros(len(hair_points))
    for dy in (-2, 0, 2):
        for dx in (-2, 0, 2):
            ok = is_hair[y + dy, x + dx]
            sample += luma[y + dy, x + dx] * ok
            found += ok
    usable = found > 0
    ratio = np.where(usable, sample / np.maximum(found, 1) / reference, 1.0)
    tones += ratio * weight * usable
    weights += weight * usable
tone = np.where(weights > 1e-3, tones / np.maximum(weights, 1e-3), 1.0)
tone = np.clip(1 + (tone - 1) * HAIR_TONE_STRENGTH, *HAIR_TONE_LIMITS)
hair_bsdf = next(n for n in bpy.data.materials["M_Hair"].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
hair_color = next((n for n in bpy.data.materials["M_Hair"].node_tree.nodes if n.type == "VERTEX_COLOR"), None)
if hair_color is None:
    base_hair = tuple(hair_bsdf.inputs["Base Color"].default_value[:3])
    bpy.data.materials["M_Hair"]["base_color"] = base_hair
    hair_color = bpy.data.materials["M_Hair"].node_tree.nodes.new("ShaderNodeVertexColor")
    hair_color.layer_name = "Col"
    bpy.data.materials["M_Hair"].node_tree.links.new(hair_color.outputs["Color"], hair_bsdf.inputs["Base Color"])
base_hair = tuple(bpy.data.materials["M_Hair"]["base_color"])
tone_colors = hair_object.data.color_attributes.get("Col") or hair_object.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
for index, value in enumerate(tone):
    tone_colors.data[index].color = (base_hair[0] * value, base_hair[1] * value, base_hair[2] * value, 1.0)
hair_object.data.update()
print("hair tone", round(float(tone.min()), 2), round(float(tone.max()), 2))

for name in HEAD_PARTS:
    obj = bpy.data.objects[name]
    moved = read(obj.data)
    # 목 아래쪽은 칼라 안에 그대로 두고 위로 갈수록 옮긴다.
    moved[:, 1] += HEAD_SHIFT * np.clip((moved[:, 2] - 0.20) / 0.06, 0, 1)
    write(obj, moved)

for window in bpy.context.window_manager.windows:
    for area in window.screen.areas:
        area.tag_redraw()
print("nose tip", points[:, 0].max().round(4), "chin z", round(float(points[points[:, 0] > 0.05][:, 2].min()), 4))
