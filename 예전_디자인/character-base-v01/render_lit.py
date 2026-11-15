"""시트처럼 부드러운 조명과 회색 배경으로 렌더링한다. 원본 모델 파일은 바꾸지 않는다.

실행: blender -b --factory-startup --python render_lit.py -- <model> <출력폴더> [앞방향 각도] [각진 경계 각도]
"""
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
model_path, out_dir = Path(args[0]), Path(args[1])
facing_deg = float(args[2]) if len(args) > 2 else 0.0
sharp_deg = float(args[3]) if len(args) > 3 else 28.0
tune_path = Path(args[4]) if len(args) > 4 else None  # 부위별 색 보정 json: 있으면 P2 부위 조정을 적용한다.
out_dir.mkdir(parents=True, exist_ok=True)
FRAME_PX, FIGURE_PX, FEET_FROM_TOP_PX = 620.0, 569.0, 596.0

bpy.ops.wm.read_factory_settings(use_empty=True)
if model_path.suffix.lower() == ".blend":
    bpy.ops.wm.open_mainfile(filepath=str(model_path))
elif model_path.suffix.lower() == ".fbx":
    bpy.ops.wm.fbx_import(filepath=str(model_path))
else:
    bpy.ops.import_scene.gltf(filepath=str(model_path))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for name in filter(None, os.environ.get("HIDE_PARTS", "").split(",")):
    bpy.data.objects[name].hide_render = True  # 벗긴 모습 확인용
for obj in meshes if sharp_deg > 0 else []:  # 음수면 파일에 저장된 음영을 그대로 쓴다.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.set_sharp_from_angle(angle=math.radians(sharp_deg))
    obj.data.update()
    for slot in obj.material_slots:
        bsdf = next((n for n in slot.material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Roughness"].default_value = 0.85
            bsdf.inputs["Metallic"].default_value = 0.0
            bsdf.inputs["Specular IOR Level"].default_value = 0.15

if tune_path:
    gains = json.loads(tune_path.read_text())
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = meshes[0]
    meshes[0].select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    meshes = sorted((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: -len(o.data.vertices))
    NAMES = ["pants", "shirt", "eye_r", "eye_l", "hair", "arm_r", "arm_l", "shoe_r", "shoe_l", "head",
             "ear_r", "ear_l", "brow_r", "brow_l", "ankle_r", "ankle_l", "small_16", "small_17"]
    CLASS = {"pants": "pants", "shirt": "shirt", "eye_r": "eye", "eye_l": "eye", "hair": "hair", "arm_r": "skin",
             "arm_l": "skin", "shoe_r": "shoes", "shoe_l": "shoes", "head": "skin", "ear_r": "skin", "ear_l": "skin",
             "brow_r": "hair", "brow_l": "hair", "ankle_r": "skin", "ankle_l": "skin", "small_16": "skin", "small_17": "skin"}
    # 각진 경계 각도: 작을수록 면이 또렷하다. 머리카락은 시트처럼 면을 살리고 옷은 세로줄이 안 보이게 넓힌다.
    SHARP = {"hair": 4, "head": 20, "shirt": 42, "pants": 42, "arm_r": 40, "arm_l": 40, "eye_r": 180, "eye_l": 180}
    materials = {}
    for obj, name in zip(meshes, NAMES):
        obj.name = name
        obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
        obj.data.set_sharp_from_angle(angle=math.radians(SHARP.get(name, 28)))
        obj.data.update()
        key = CLASS[name]
        if key not in materials:
            material = obj.material_slots[0].material.copy()
            tree = material.node_tree
            image = next(n for n in tree.nodes if n.type == "TEX_IMAGE")
            bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
            mix = tree.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            if key == "hair" and "hair_image" in gains:
                # 시트에서 입힌 텍스처는 P2 와 UV 가 같아서 머리카락에만 바꿔 쓸 수 있다.
                image.image = bpy.data.images.load(gains["hair_image"])
            tree.links.new(image.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*gains[key], 1)
            tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
            materials[key] = material
        obj.material_slots[0].material = materials[key]
    for name in ("eye_r", "eye_l"):
        eye = bpy.data.objects[name]
        pivot = sum((v.co for v in eye.data.vertices), Vector()) / len(eye.data.vertices)
        for v in eye.data.vertices:
            v.co = pivot + (v.co - pivot) * gains.get("eye_scale", 1.0)
    bpy.context.view_layer.update()

lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for obj in meshes:
    for corner in obj.bound_box:
        world = obj.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, world))
        hi = Vector(map(max, hi, world))
height = hi.z - lo.z
center = (lo + hi) / 2
# 모델이 바뀌어도 화면 틀이 움직이지 않게 좌우·앞뒤 중심은 원점에 고정한다.
center.x = 0.0
center.y = 0.0

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.film_transparent = True
world = bpy.data.worlds.new("Soft")
world.use_nodes = True
background = world.node_tree.nodes["Background"]
background.inputs[0].default_value = (1, 1, 1, 1)
background.inputs[1].default_value = 0.72
scene.world = world
sun = bpy.data.lights.new("Key", "SUN")
sun.energy = 1.1
sun.angle = math.radians(40)
key = bpy.data.objects.new("Key", sun)
scene.collection.objects.link(key)

camera_data = bpy.data.cameras.new("Cam")
camera_data.type = "ORTHO"
camera = bpy.data.objects.new("Cam", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
full_scale = height * FRAME_PX / FIGURE_PX
full_center_z = lo.z + (FEET_FROM_TOP_PX - FRAME_PX / 2) / FRAME_PX * full_scale


def look(azimuth_deg, target, ortho_scale, name):
    angle = math.radians(facing_deg + azimuth_deg)
    offset = Vector((math.sin(angle), -math.cos(angle), 0)) * (height * 4)
    camera.location = target + offset
    camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = ortho_scale
    # 조명은 카메라를 따라 위쪽 앞에서 비춘다. 어느 뷰에서나 같은 느낌이 된다.
    # 시트의 빛: 카메라 쪽에서 오되 캐릭터 앞쪽 오른편으로 치우쳐 있다(정면에서 화면 왼쪽, 옆면에서 얼굴 앞쪽).
    light_dir = (offset.normalized() + Vector((0.45, -0.38, 0.18))).normalized()
    key.rotation_euler = light_dir.to_track_quat("Z", "Y").to_euler()
    scene.render.filepath = str(out_dir / f"{name}.png")
    bpy.ops.render.render(write_still=True)


body = Vector((center.x, center.y, full_center_z))
head = Vector((center.x, center.y, lo.z + height * 0.865))
for name, azimuth in {"front": 0, "right": -90, "back": 180, "threequarter": 35}.items():
    look(azimuth, body, full_scale, name)
look(0, head, height * 0.3, "head_front")
look(-90, head, height * 0.3, "head_right")
look(35, head, height * 0.3, "head_threequarter")
