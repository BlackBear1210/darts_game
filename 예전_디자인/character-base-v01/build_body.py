"""열린 Blender 장면에 옷 아래 몸통·다리·맨발을 만든다. 다시 실행해도 같은 결과가 나온다.

실행: python blender_live.py run build_body.py
좌표: 앞 = +X, 캐릭터 왼쪽 = +Y, 키 1, 발바닥 z = -0.5. 표의 높이는 키 대비 %다.
"""
import math

import bmesh
import bpy
from mathutils import Vector

SIDES = 10
ROUNDNESS = 2.3
# 높이%, 중심 x, 앞뒤 반폭, 좌우 반폭. 티셔츠·바지 단면을 재서 그보다 안쪽으로 잡았다.
TORSO = [
    (72.5, -0.040, 0.022, 0.048),
    (71.0, -0.036, 0.036, 0.080),
    (69.5, -0.031, 0.046, 0.102),
    (67.5, -0.028, 0.051, 0.104),
    (65.5, -0.027, 0.052, 0.090),
    (63.5, -0.026, 0.052, 0.083),
    (62.0, -0.024, 0.052, 0.080),  # 겨드랑이 아래 티셔츠 몸판 끝은 y=0.087 이다.
    (60.0, -0.021, 0.051, 0.078),
    (56.0, -0.018, 0.052, 0.075),
    (52.0, -0.017, 0.052, 0.076),
    (48.0, -0.017, 0.052, 0.080),
    (45.0, -0.018, 0.049, 0.081),
    (43.0, -0.020, 0.045, 0.078),
    (41.5, -0.020, 0.037, 0.070),
    (40.7, -0.020, 0.022, 0.040),  # 바지 가랑이 위에서 끝낸다.
]
# 왼쪽 다리. 높이%, 중심 x, 중심 y, 앞뒤 반폭, 좌우 반폭. 오른쪽은 y 를 뒤집는다.
LEG = [
    (42.0, -0.019, 0.045, 0.034, 0.031),
    (40.0, -0.019, 0.047, 0.034, 0.031),
    (36.0, -0.021, 0.054, 0.032, 0.028),
    (32.0, -0.023, 0.059, 0.031, 0.026),
    (29.0, -0.024, 0.061, 0.029, 0.026),
    (27.0, -0.026, 0.063, 0.028, 0.025),
    (25.0, -0.029, 0.065, 0.028, 0.024),
    (23.0, -0.033, 0.068, 0.027, 0.024),
    (20.0, -0.038, 0.072, 0.026, 0.023),
    (16.0, -0.042, 0.077, 0.024, 0.022),
    (13.0, -0.046, 0.081, 0.022, 0.021),
    (11.5, -0.047, 0.082, 0.0215, 0.0205),
]
ARM_ROOT_TARGET = Vector((-0.032, 0.088, 0.168))  # 어깨 쪽으로 올려 겨드랑이 틈을 지나지 않게 한다.
ARM_ROOT_SCALE = 0.9
FOOT_SCALE = (0.93, 0.88, 0.88)  # 신발 안쪽에 들어가는 비율(앞뒤, 좌우, 높이)
BODY_PARTS = ("torso", "leg_l", "leg_r", "foot_l", "foot_r")

skin = bpy.data.materials["M_Skin"]
collection = bpy.data.objects["shirt"].users_collection[0]


def height(percent):
    return -0.5 + percent / 100


def ring(bm, cx, cy, z, hx, hy):
    verts = []
    power = 2 / ROUNDNESS
    for index in range(SIDES):
        angle = 2 * math.pi * index / SIDES
        c, s = math.cos(angle), math.sin(angle)
        x = cx + hx * math.copysign(abs(c) ** power, c)
        y = cy + hy * math.copysign(abs(s) ** power, s)
        verts.append(bm.verts.new((x, y, z)))
    return verts


def loft(name, rings_data):
    bm = bmesh.new()
    rings = [ring(bm, *data) for data in rings_data]
    for upper, lower in zip(rings, rings[1:]):
        for index in range(SIDES):
            following = (index + 1) % SIDES
            bm.faces.new((upper[index], upper[following], lower[following], lower[index]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return store(name, bm)


def store(name, bm):
    obj = bpy.data.objects.get(name)
    if obj is None:
        mesh = bpy.data.meshes.new(name)
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(skin)
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.set_sharp_from_angle(angle=math.radians(40))
    obj.data.update()
    return obj


def extend_arm(name, sign):
    """팔 뿌리의 열린 고리를 몸통 안까지 늘린다."""
    obj = bpy.data.objects[name]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    open_edges = [e for e in bm.edges if e.is_boundary]
    center = sum((v.co for e in open_edges for v in e.verts), Vector()) / (2 * len(open_edges))
    target = Vector((ARM_ROOT_TARGET.x, ARM_ROOT_TARGET.y * sign, ARM_ROOT_TARGET.z))
    if obj.get("root_extended"):
        # 이미 늘린 팔은 끝 고리의 위치만 다시 맞춘다.
        for vert in {v for e in open_edges for v in e.verts}:
            vert.co = target + (vert.co - center)
    else:
        result = bmesh.ops.extrude_edge_only(bm, edges=open_edges)
        for vert in (g for g in result["geom"] if isinstance(g, bmesh.types.BMVert)):
            vert.co = target + (vert.co - center) * ARM_ROOT_SCALE
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.set_sharp_from_angle(angle=math.radians(40))
    obj.data.update()
    obj["root_extended"] = True


def foot(name, shoe_name):
    bm = bmesh.new()
    bm.from_mesh(bpy.data.objects[shoe_name].data)
    low = min(v.co.z for v in bm.verts)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    for vert in bm.verts:
        vert.co.x = cx + (vert.co.x - cx) * FOOT_SCALE[0]
        vert.co.y = cy + (vert.co.y - cy) * FOOT_SCALE[1]
        vert.co.z = low + 0.002 + (vert.co.z - low) * FOOT_SCALE[2]
    return store(name, bm)


loft("torso", [(cx, 0.0, height(p), hx, hy) for p, cx, hx, hy in TORSO])
loft("leg_l", [(cx, cy, height(p), hx, hy) for p, cx, cy, hx, hy in LEG])
loft("leg_r", [(cx, -cy, height(p), hx, hy) for p, cx, cy, hx, hy in LEG])
extend_arm("arm_l", 1)
extend_arm("arm_r", -1)
foot("foot_l", "shoe_l")
foot("foot_r", "shoe_r")

for window in bpy.context.window_manager.windows:
    for area in window.screen.areas:
        area.tag_redraw()
for name in BODY_PARTS:
    obj = bpy.data.objects[name]
    print(name, "verts", len(obj.data.vertices), "faces", len(obj.data.polygons))
print("objects", len([o for o in bpy.data.objects if o.type == "MESH"]))
