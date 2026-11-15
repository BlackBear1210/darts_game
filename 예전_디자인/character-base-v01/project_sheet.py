"""시트 픽셀을 P2 메시의 UV에 직접 투영해 새 텍스처를 만든다. 원본 모델 파일은 바꾸지 않는다.

실행: blender -b --factory-startup --python project_sheet.py -- <model.fbx> <작업폴더> <출력.glb> [앞방향 각도]
작업폴더에는 inputs/*.png, head_detail_fit.json 이 있어야 한다.
"""
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
model_path, work_dir, out_path = Path(args[0]), Path(args[1]), Path(args[2])
out_path.parent.mkdir(parents=True, exist_ok=True)

ATLAS = 2048
IMAGE = 1024
FIGURE_PX = 569 * IMAGE / 620        # 입력 이미지 안의 인물 키
FEET_Y = (579 + 17) * IMAGE / 620    # 입력 이미지 안의 발바닥 위치
NAMES = ["pants", "shirt", "eye_r", "eye_l", "hair", "arm_r", "arm_l", "shoe_r", "shoe_l", "head",
         "ear_r", "ear_l", "brow_r", "brow_l", "small_14", "small_15", "small_16", "small_17"]
HEAD_PARTS = {"hair", "head", "ear_r", "ear_l", "eye_r", "eye_l", "brow_r", "brow_l", "small_16", "small_17"}
PALETTE = {"shirt": (77, 53, 70), "pants": (68, 67, 78), "hair": (80, 50, 38), "skin": (243, 178, 132),
           "shoes": (72, 55, 47), "eye": (236, 228, 218), "dark": (25, 20, 22), "mouth": (120, 75, 60)}
ALLOWED = {"pants": ["pants"], "shirt": ["shirt"], "hair": ["hair"], "arm_r": ["skin"], "arm_l": ["skin"],
           "shoe_r": ["shoes", "hair"], "shoe_l": ["shoes", "hair"], "head": ["skin", "mouth", "dark"],
           "ear_r": ["skin"], "ear_l": ["skin"], "eye_r": ["eye", "dark", "skin"], "eye_l": ["eye", "dark", "skin"],
           "brow_r": ["hair", "dark", "mouth"], "brow_l": ["hair", "dark", "mouth"],
           "small_14": ["skin"], "small_15": ["skin"], "small_16": ["skin"], "small_17": ["skin"]}


def load_image(path: Path) -> np.ndarray:
    image = bpy.data.images.load(str(path))
    image.colorspace_settings.name = "Non-Color"
    w, h = image.size
    data = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    return data.reshape(h, w, 4)[::-1, :, :3].copy()   # 위에서 아래 순서


def to_lab(rgb: np.ndarray) -> np.ndarray:
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]], dtype=np.float32)
    xyz = lin @ m.T / np.array([0.9505, 1.0, 1.089], dtype=np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.fbx_import(filepath=str(model_path))
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
mesh = obj.data
mesh.calc_loop_triangles()
vert_count = len(mesh.vertices)
co = np.empty(vert_count * 3, dtype=np.float32)
mesh.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
matrix = np.array(obj.matrix_world, dtype=np.float32)
world = co @ matrix[:3, :3].T + matrix[:3, 3]
lo, hi = world.min(axis=0), world.max(axis=0)
height = hi[2] - lo[2]
center = (lo + hi) / 2
px_per_unit = FIGURE_PX / height

# 부위 번호: 점 개수 내림차순으로 list_islands.py 와 같다.
parent = np.arange(vert_count)


def find(i: int) -> int:
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i


for edge in mesh.edges:
    a, b = find(edge.vertices[0]), find(edge.vertices[1])
    if a != b:
        parent[a] = b
roots = np.array([find(i) for i in range(vert_count)])
unique, counts = np.unique(roots, return_counts=True)
order = unique[np.argsort(-counts, kind="stable")]
root_to_part = {int(r): i for i, r in enumerate(order)}
vert_part = np.array([root_to_part[int(r)] for r in roots])
print("parts", len(order), sorted(counts.tolist(), reverse=True)[:6])

tri_verts = np.empty(len(mesh.loop_triangles) * 3, dtype=np.int32)
mesh.loop_triangles.foreach_get("vertices", tri_verts)
tri_verts = tri_verts.reshape(-1, 3)
tri_loops = np.empty(len(mesh.loop_triangles) * 3, dtype=np.int32)
mesh.loop_triangles.foreach_get("loops", tri_loops)
tri_loops = tri_loops.reshape(-1, 3)
uv_data = np.empty(len(mesh.loops) * 2, dtype=np.float32)
mesh.uv_layers.active.data.foreach_get("uv", uv_data)
uv_data = uv_data.reshape(-1, 2)

# --- UV 공간에 위치·법선·부위 기록 ---
pos = np.zeros((ATLAS, ATLAS, 3), dtype=np.float32)
nrm = np.zeros((ATLAS, ATLAS, 3), dtype=np.float32)
part_map = np.full((ATLAS, ATLAS), -1, dtype=np.int16)
for verts, loops in zip(tri_verts, tri_loops):
    p = world[verts]
    n = np.cross(p[1] - p[0], p[2] - p[0])
    length = np.linalg.norm(n)
    if length < 1e-12:
        continue
    n = n / length
    t = uv_data[loops] * ATLAS
    x0, x1 = int(np.floor(t[:, 0].min())) - 1, int(np.ceil(t[:, 0].max())) + 2
    y0, y1 = int(np.floor(t[:, 1].min())) - 1, int(np.ceil(t[:, 1].max())) + 2
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, ATLAS), min(y1, ATLAS)
    if x1 <= x0 or y1 <= y0:
        continue
    gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    d = (t[1, 1] - t[2, 1]) * (t[0, 0] - t[2, 0]) + (t[2, 0] - t[1, 0]) * (t[0, 1] - t[2, 1])
    if abs(d) < 1e-9:
        continue
    w0 = ((t[1, 1] - t[2, 1]) * (gx - t[2, 0]) + (t[2, 0] - t[1, 0]) * (gy - t[2, 1])) / d
    w1 = ((t[2, 1] - t[0, 1]) * (gx - t[2, 0]) + (t[0, 0] - t[2, 0]) * (gy - t[2, 1])) / d
    w2 = 1 - w0 - w1
    inside = (w0 >= -0.03) & (w1 >= -0.03) & (w2 >= -0.03)
    if not inside.any():
        continue
    ys, xs = np.where(inside)
    ys, xs = ys + y0, xs + x0
    bary = np.stack([w0[inside], w1[inside], w2[inside]], -1)
    pos[ys, xs] = bary @ p
    nrm[ys, xs] = n
    part_map[ys, xs] = vert_part[verts[0]]
covered = part_map >= 0
print("atlas coverage", round(float(covered.mean()), 3))

# --- 뷰 정의: 이미지 가로축, 카메라 쪽 방향 ---
VIEWS = {
    "front": (np.array([0, 1, 0], np.float32), np.array([1, 0, 0], np.float32), "front.png"),
    "right": (np.array([1, 0, 0], np.float32), np.array([0, -1, 0], np.float32), "right.png"),
    "back": (np.array([0, -1, 0], np.float32), np.array([-1, 0, 0], np.float32), "back.png"),
    "left": (np.array([-1, 0, 0], np.float32), np.array([0, 1, 0], np.float32), "left.png"),
}


def project(points: np.ndarray, axis: np.ndarray):
    x = IMAGE / 2 + ((points - center) @ axis) * px_per_unit
    y = FEET_Y - (points[..., 2] - lo[2]) * px_per_unit
    return x, y


def depth_buffer(axis: np.ndarray, toward: np.ndarray) -> np.ndarray:
    buffer = np.full((IMAGE, IMAGE), -1e9, dtype=np.float32)
    x, y = project(world, axis)
    depth = world @ toward
    for verts in tri_verts:
        tx, ty, tz = x[verts], y[verts], depth[verts]
        x0, x1 = max(int(tx.min()), 0), min(int(tx.max()) + 2, IMAGE)
        y0, y1 = max(int(ty.min()), 0), min(int(ty.max()) + 2, IMAGE)
        if x1 <= x0 or y1 <= y0:
            continue
        d = (ty[1] - ty[2]) * (tx[0] - tx[2]) + (tx[2] - tx[1]) * (ty[0] - ty[2])
        if abs(d) < 1e-9:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        w0 = ((ty[1] - ty[2]) * (gx - tx[2]) + (tx[2] - tx[1]) * (gy - ty[2])) / d
        w1 = ((ty[2] - ty[0]) * (gx - tx[2]) + (tx[0] - tx[2]) * (gy - ty[2])) / d
        w2 = 1 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        z = w0 * tz[0] + w1 * tz[1] + w2 * tz[2]
        tile = buffer[y0:y1, x0:x1]
        tile[inside] = np.maximum(tile[inside], z[inside])
    return buffer


def bilinear(image: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    h, w = image.shape[:2]
    x = np.clip(x - 0.5, 0, w - 1.001)
    y = np.clip(y - 0.5, 0, h - 1.001)
    x0, y0 = x.astype(np.int32), y.astype(np.int32)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    return (image[y0, x0] * (1 - fx) * (1 - fy) + image[y0, x0 + 1] * fx * (1 - fy)
            + image[y0 + 1, x0] * (1 - fx) * fy + image[y0 + 1, x0 + 1] * fx * fy)


palette_names = list(PALETTE)
palette_lab = to_lab(np.array([PALETTE[k] for k in palette_names], dtype=np.float32) / 255)
allowed_masks = np.zeros((len(NAMES), len(palette_names)), dtype=bool)
for index, name in enumerate(NAMES):
    for key in ALLOWED[name]:
        allowed_masks[index, palette_names.index(key)] = True


def accepted(colors: np.ndarray, parts: np.ndarray) -> np.ndarray:
    lab = to_lab(colors)
    delta = lab[:, None, :] - palette_lab[None, :, :]
    distance = np.sqrt((delta[..., 0] * 0.35) ** 2 + delta[..., 1] ** 2 + delta[..., 2] ** 2)
    nearest = distance.argmin(axis=1)
    return allowed_masks[parts, nearest]


fit = json.loads((work_dir / "head_detail_fit.json").read_text())
sheet = load_image(work_dir.parent / "character-reference" / "pub-character-01.png")


def detail_sample(view: str, x: np.ndarray, y: np.ndarray):
    # 입력 이미지 좌표를 시트의 큰 얼굴 그림 좌표로 바꾼다. left 는 right 를 좌우 반전한 그림이다.
    source = "right" if view == "left" else view
    info = fit[source]
    box = info["box"]
    sx = IMAGE - x if view == "left" else x
    dx = box[0] + (sx - info["x"]) / info["scale"]
    dy = box[1] + (y - info["y"]) / info["scale"]
    valid = (dx >= box[0] + 1) & (dx < box[2] - 1) & (dy >= box[1] + 1) & (dy < box[3] - 1)
    return bilinear(sheet, dx, dy), valid


ys, xs = np.where(covered)
points = pos[ys, xs]
normals = nrm[ys, xs]
parts = part_map[ys, xs].astype(np.int32)
is_head = np.isin(parts, [NAMES.index(n) for n in HEAD_PARTS])
acc = np.zeros((len(ys), 3), dtype=np.float32)
weight_sum = np.zeros(len(ys), dtype=np.float32)
for view, (axis, toward, filename) in VIEWS.items():
    image = load_image(work_dir / "inputs" / filename)
    buffer = depth_buffer(axis, toward)
    x, y = project(points, axis)
    depth = points @ toward
    ix = np.clip(x.astype(np.int32), 0, IMAGE - 1)
    iy = np.clip(y.astype(np.int32), 0, IMAGE - 1)
    visible = depth >= buffer[iy, ix] - 0.012 * height
    facing = normals @ toward
    weight = np.where(facing > 0.12, facing ** 3, 0).astype(np.float32) * visible
    colors = bilinear(image, x, y)
    use_detail = np.zeros(len(ys), dtype=bool)
    if view in ("front", "right", "left"):
        detail, valid = detail_sample(view, x, y)
        use_detail = valid & is_head
        colors[use_detail] = detail[use_detail]
    is_background = colors.min(axis=1) > 0.97
    good = accepted(colors, parts) & ~is_background & (weight > 0)
    weight = weight * good
    weight[use_detail] *= 2.0
    acc += colors * weight[:, None]
    weight_sum += weight
    print(view, "good", int(good.sum()), "detail", int(use_detail.sum()))

painted = weight_sum > 1e-4
atlas = np.zeros((ATLAS, ATLAS, 3), dtype=np.float32)
known = np.zeros((ATLAS, ATLAS), dtype=bool)
atlas[ys[painted], xs[painted]] = acc[painted] / weight_sum[painted, None]
known[ys[painted], xs[painted]] = True
print("painted", round(float(painted.mean()), 3))

# 시트에 안 보이는 곳은 같은 부위의 중간색에서 시작해 주변 색으로 번지게 한다.
for index in range(len(NAMES)):
    mask = part_map == index
    if not mask.any():
        continue
    source = mask & known
    fallback = np.median(atlas[source], axis=0) if source.any() else np.array(PALETTE["skin"], np.float32) / 255
    atlas[mask & ~known] = fallback
unknown = covered & ~known
for _ in range(48):
    blurred = np.zeros_like(atlas)
    samples = np.zeros((ATLAS, ATLAS, 1), dtype=np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        same = (np.roll(part_map, (dy, dx), axis=(0, 1)) == part_map) & covered
        blurred += np.roll(atlas, (dy, dx), axis=(0, 1)) * same[..., None]
        samples[..., 0] += same
    update = unknown & (samples[..., 0] > 0)
    atlas[update] = blurred[update] / samples[update]

# UV 경계 바깥으로 색을 넓혀 틈이 보이지 않게 한다.
filled = covered.copy()
for _ in range(6):
    grown = atlas.copy()
    grown_mask = filled.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        neighbor = np.roll(filled, (dy, dx), axis=(0, 1))
        take = neighbor & ~grown_mask
        grown[take] = np.roll(atlas, (dy, dx), axis=(0, 1))[take]
        grown_mask |= take
    atlas, filled = grown, grown_mask

result = bpy.data.images.new("SheetPaint", ATLAS, ATLAS, alpha=False)
rgba = np.ones((ATLAS, ATLAS, 4), dtype=np.float32)
rgba[..., :3] = np.clip(atlas, 0, 1)
result.colorspace_settings.name = "Non-Color"
result.pixels.foreach_set(rgba.ravel())
png_path = out_path.with_suffix(".png")
result.filepath_raw = str(png_path)
result.file_format = "PNG"
result.save()
print("saved", png_path)

texture = bpy.data.images.load(str(png_path))
texture.colorspace_settings.name = "sRGB"
for slot in obj.material_slots:
    for node in slot.material.node_tree.nodes:
        if node.type == "TEX_IMAGE":
            node.image = texture
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB", export_image_format="AUTO")
print("exported", out_path)
