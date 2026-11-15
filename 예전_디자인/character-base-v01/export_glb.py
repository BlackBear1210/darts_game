"""캐릭터 .blend 를 부위가 분리된 GLB 로 내보낸다.

색 보정값은 GLB 재질에 1보다 큰 값으로 담을 수 없어 부위별 텍스처에 구워 넣는다.
.blend 원본은 바꾸지 않는다.

실행: blender -b --python export_glb.py -- <입력.blend> <출력.glb>
"""
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
TEXTURE_STEP = 2   # 4096 텍스처를 2048 로 줄인다.

bpy.ops.wm.open_mainfile(filepath=args[0])


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 1e-8), 1 / 2.4) - 0.055)


cache = {}


def source_pixels(image):
    if image.name not in cache:
        keep = image.colorspace_settings.name
        image.colorspace_settings.name = "Non-Color"
        w, h = image.size
        data = np.empty(w * h * 4, dtype=np.float32)
        image.pixels.foreach_get(data)
        image.colorspace_settings.name = keep
        cache[image.name] = data.reshape(h, w, 4)[::TEXTURE_STEP, ::TEXTURE_STEP, :3].copy()
    return cache[image.name]


for material in bpy.data.materials:
    if not material.use_nodes:
        continue
    tree = material.node_tree
    mix = next((n for n in tree.nodes if n.type == "MIX" and n.blend_type == "MULTIPLY"), None)
    if mix is None:
        continue
    texture = next(n for n in tree.nodes if n.type == "TEX_IMAGE")
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    gain = np.array(mix.inputs[7].default_value[:3], dtype=np.float32)
    baked = to_srgb(np.clip(to_linear(source_pixels(texture.image)) * gain, 0, 1)).astype(np.float32)
    h, w = baked.shape[:2]
    result = bpy.data.images.new(f"T_{material.name[2:]}", w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = baked
    result.pixels.foreach_set(rgba.ravel())
    result.pack()
    texture.image = result
    tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    tree.nodes.remove(mix)
    print("baked", material.name, "gain", gain.round(3))

bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", export_apply=False,
                          export_image_format="JPEG", export_jpeg_quality=92)
print("exported", args[1])
