"""생성 GLB를 시트와 같은 정사영·같은 축척으로 렌더링하고 메시 수치를 출력한다.

실행: blender -b --factory-startup --python render_compare.py -- <model.glb> <출력폴더> [앞방향 각도]
앞방향 각도: Blender 위에서 내려다본 기준, 캐릭터 정면이 바라보는 방위(도). -Y 가 0.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
model_path = Path(args[0])
out_dir = Path(args[1])
facing_deg = float(args[2]) if len(args) > 2 else 0.0
out_dir.mkdir(parents=True, exist_ok=True)

# 입력 이미지: 620px 칸에서 인물 키가 569px 이고 시트 픽셀 기준 발바닥이 y=579 (+17 여백).
FRAME_PX = 620.0
FIGURE_PX = 569.0
FEET_FROM_TOP_PX = 579.0 + 17.0

bpy.ops.wm.read_factory_settings(use_empty=True)
if model_path.suffix.lower() == ".fbx":
    bpy.ops.wm.fbx_import(filepath=str(model_path))
else:
    bpy.ops.import_scene.gltf(filepath=str(model_path))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for obj in meshes:
    for corner in obj.bound_box:
        world = obj.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, world))
        hi = Vector(map(max, hi, world))
height = hi.z - lo.z
center = (lo + hi) / 2

stats = {"objects": len(meshes), "bbox": [round(v, 4) for v in (hi - lo)]}
tris = verts = 0
islands = 0
smooth_faces = flat_faces = 0
materials = set()
images = set()
for obj in meshes:
    mesh = obj.data
    mesh.calc_loop_triangles()
    tris += len(mesh.loop_triangles)
    verts += len(mesh.vertices)
    for poly in mesh.polygons:
        side_count = "tri" if poly.loop_total == 3 else ("quad" if poly.loop_total == 4 else "ngon")
        stats[side_count + "_faces"] = stats.get(side_count + "_faces", 0) + 1
        if poly.use_smooth:
            smooth_faces += 1
        else:
            flat_faces += 1
    # glTF 는 UV 경계에서 점을 쪼개므로 같은 위치의 점을 합쳐서 센다.
    weld = {}
    weld_id = [weld.setdefault(tuple(round(c, 5) for c in v.co), len(weld)) for v in mesh.vertices]
    stats["welded_verts"] = len(weld)
    parent = list(range(len(weld)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for edge in mesh.edges:
        a, b = find(weld_id[edge.vertices[0]]), find(weld_id[edge.vertices[1]])
        if a != b:
            parent[a] = b
    counts = {}
    for i in range(len(weld)):
        root = find(i)
        counts[root] = counts.get(root, 0) + 1
    islands += len(counts)
    stats.setdefault("island_vertex_counts", []).extend(sorted(counts.values(), reverse=True)[:12])
    for slot in obj.material_slots:
        if slot.material:
            materials.add(slot.material.name)
            if slot.material.use_nodes:
                for node in slot.material.node_tree.nodes:
                    if node.type == "TEX_IMAGE" and node.image:
                        images.add((node.image.name, tuple(node.image.size)))
stats.update(tris=tris, verts=verts, islands=islands, smooth_faces=smooth_faces, flat_faces=flat_faces,
             materials=sorted(materials), images=sorted(images))
(out_dir / "stats.json").write_text(json.dumps(stats, ensure_ascii=False, indent=1), encoding="utf-8")
print("STATS", json.dumps(stats, ensure_ascii=False))

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
# 기본값 AgX 는 색을 바꾸므로 텍스처 색 그대로 보이게 한다.
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.film_transparent = False
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_shadows = False
scene.display.shading.background_type = "VIEWPORT" if hasattr(scene.display.shading, "background_type") else None
world = bpy.data.worlds.new("White")
world.color = (1, 1, 1)
scene.world = world

camera_data = bpy.data.cameras.new("Cam")
camera_data.type = "ORTHO"
camera = bpy.data.objects.new("Cam", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera

full_scale = height * FRAME_PX / FIGURE_PX
# 이미지 중심의 높이: 발바닥이 위에서 FEET_FROM_TOP_PX 인 곳에 오도록 맞춘다.
full_center_z = lo.z + (FEET_FROM_TOP_PX - FRAME_PX / 2) / FRAME_PX * full_scale


def look(azimuth_deg: float, target: Vector, ortho_scale: float, name: str) -> None:
    # azimuth 0 = 캐릭터 정면에서 바라본 카메라.
    angle = math.radians(facing_deg + azimuth_deg)
    offset = Vector((math.sin(angle), -math.cos(angle), 0)) * (height * 4)
    camera.location = target + offset
    camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = ortho_scale
    scene.render.filepath = str(out_dir / f"{name}.png")
    bpy.ops.render.render(write_still=True)


body_target = Vector((center.x, center.y, full_center_z))
head_target = Vector((center.x, center.y, lo.z + height * 0.865))
# right = 코가 화면 오른쪽(시트의 LEFT SIDE와 같은 방향), threequarter = 시트처럼 코가 화면 왼쪽.
views = {"front": 0, "right": -90, "back": 180, "left": 90, "threequarter": 35}
for shading, suffix in (("TEXTURE", ""), ("SINGLE", "_clay")):
    scene.display.shading.color_type = shading
    scene.display.shading.light = "FLAT" if shading == "TEXTURE" else "STUDIO"
    scene.display.shading.single_color = (0.75, 0.75, 0.75)
    for name, azimuth in views.items():
        look(azimuth, body_target, full_scale, name + suffix)
    look(0, head_target, height * 0.3, "head_front" + suffix)
    look(-90, head_target, height * 0.3, "head_right" + suffix)
    look(35, head_target, height * 0.3, "head_threequarter" + suffix)
    # 양손: 정면 기준 좌우 끝에서 안쪽, 시트에서 손 높이는 키의 약 35%.
    hand_z = lo.z + height * 0.345
    side_dir = Vector((math.cos(math.radians(facing_deg)), math.sin(math.radians(facing_deg)), 0))
    half_span = max(abs((hi - center).dot(side_dir)), 0.001)
    look(0, center * 0 + Vector((center.x, center.y, hand_z)) + side_dir * half_span * 0.9, height * 0.16, "hand_a" + suffix)
    look(0, center * 0 + Vector((center.x, center.y, hand_z)) - side_dir * half_span * 0.9, height * 0.16, "hand_b" + suffix)
