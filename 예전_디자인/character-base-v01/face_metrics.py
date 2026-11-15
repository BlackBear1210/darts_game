"""시트 얼굴과 모델 렌더를 같은 좌표계로 놓고 높이별 수치와 비교 이미지를 만든다.

실행: python face_metrics.py <렌더 폴더>
출력: review/_same_scale.png (위 시트, 가운데 모델, 아래 윤곽 겹침), 표준 출력의 높이별 표
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).parent
FEET_Y = (579 + 17) * 1024 / 620
PX_PER_UNIT = 569 * 1024 / 620
SPAN = 0.3 * 0.9995
CENTER_Z = -0.4998 + 0.9995 * 0.865
SIZE = 1024
BACKGROUND = (201, 202, 203)
FRONT_OFFSET_PX = 3.9
fit = json.loads((HERE / "head_detail_fit.json").read_text())
sheet = np.asarray(Image.open(HERE.parent / "character-reference/pub-character-01.png").convert("RGB")).astype(np.float32)


def frame_u(px):
    return (px + 0.5 - SIZE / 2) * SPAN / SIZE


def frame_px_z(z):
    return int(SIZE / 2 - (z - CENTER_Z) / SPAN * SIZE)


def sheet_frame(view):
    info = fit[view]
    box = info["box"]
    u = (np.arange(SIZE) + 0.5 - SIZE / 2) * SPAN / SIZE
    z = CENTER_Z + (SIZE / 2 - np.arange(SIZE) - 0.5) * SPAN / SIZE
    ix = 512 + u * PX_PER_UNIT + (FRONT_OFFSET_PX if view == "front" else 0.0)
    iy = FEET_Y - (z + 0.5) * PX_PER_UNIT
    dx = box[0] + (ix - info["x"]) / info["scale"]
    dy = box[1] + (iy - info["y"]) / info["scale"]
    xi = np.clip(dx.astype(int), 0, sheet.shape[1] - 1)
    yi = np.clip(dy.astype(int), 0, sheet.shape[0] - 1)
    return sheet[yi][:, xi]


def model_frame(path):
    image = Image.open(path).convert("RGBA").resize((SIZE, SIZE))
    base = Image.new("RGBA", image.size, (*BACKGROUND, 255))
    base.alpha_composite(image)
    return np.asarray(base.convert("RGB")).astype(np.float32)


def skin_mask(a):
    return (a[..., 0] > 165) & (a[..., 0] - a[..., 2] > 38)


def figure_mask(a):
    return np.abs(a - np.array(BACKGROUND, dtype=np.float32)).max(axis=-1) > 22


def largest_run(flags):
    best, start, run = (0, 0), None, 0
    for index, flag in enumerate(flags):
        if flag:
            if start is None:
                start = index
            run = index - start + 1
            if run > best[0]:
                best = (run, start)
        else:
            start = None
    return best[1], best[1] + best[0] - 1


def front_table(target, model):
    print("정면: 높이별 살 구간 왼쪽/오른쪽 끝과 폭 (시트 | 모델 | 폭 차이)")
    for z in (0.43, 0.42, 0.40, 0.38, 0.36, 0.34, 0.32, 0.31, 0.30, 0.29, 0.28, 0.27, 0.26, 0.25):
        row = frame_px_z(z)
        a0, a1 = largest_run(skin_mask(target)[row])
        b0, b1 = largest_run(skin_mask(model)[row])
        print(f"  z {z:.2f}: {frame_u(a0):+.3f} {frame_u(a1):+.3f} 폭 {frame_u(a1) - frame_u(a0):.3f} | "
              f"{frame_u(b0):+.3f} {frame_u(b1):+.3f} 폭 {frame_u(b1) - frame_u(b0):.3f} | {(frame_u(b1) - frame_u(b0)) - (frame_u(a1) - frame_u(a0)):+.3f}")


def side_table(target, model):
    print("옆면: 높이별 앞쪽 끝 x (시트 | 모델 | 차이)")
    for z in (0.44, 0.42, 0.40, 0.38, 0.36, 0.35, 0.34, 0.33, 0.32, 0.31, 0.30, 0.29, 0.28, 0.27, 0.26, 0.25):
        row = frame_px_z(z)
        a = np.where(skin_mask(target)[row])[0]
        b = np.where(skin_mask(model)[row])[0]
        if len(a) and len(b):
            print(f"  z {z:.2f}: {frame_u(a.max()):+.3f} | {frame_u(b.max()):+.3f} | {frame_u(b.max()) - frame_u(a.max()):+.3f}")
    print("옆면: 머리 뒤쪽 끝 x (시트 | 모델)")
    for z in (0.46, 0.42, 0.38, 0.34, 0.30):
        row = frame_px_z(z)
        a = np.where(figure_mask(target)[row])[0]
        b = np.where(figure_mask(model)[row])[0]
        print(f"  z {z:.2f}: {frame_u(a.min()):+.3f} | {frame_u(b.min()):+.3f}")
    for name, mask in (("시트", figure_mask(target)), ("모델", figure_mask(model))):
        rows = np.where(mask.any(axis=1))[0]
        print(f"  {name} 머리 꼭대기 z {CENTER_Z + (SIZE / 2 - rows.min()) * SPAN / SIZE:.3f}")


def outline(mask):
    edge = mask ^ np.roll(mask, 1, axis=0) | mask ^ np.roll(mask, 1, axis=1)
    return edge


folder = Path(sys.argv[1])
views = (("front", "head_front"), ("right", "head_right"))
canvas = Image.new("RGB", (SIZE * 2, SIZE * 3), BACKGROUND)
for column, (view, name) in enumerate(views):
    target = sheet_frame(view)
    model = model_frame(folder / f"{name}.png")
    (front_table if view == "front" else side_table)(target, model)
    canvas.paste(Image.fromarray(target.astype(np.uint8)), (column * SIZE, 0))
    canvas.paste(Image.fromarray(model.astype(np.uint8)), (column * SIZE, SIZE))
    mix = (target * 0.5 + model * 0.5).astype(np.uint8)
    mix[outline(figure_mask(target))] = (255, 0, 0)
    mix[outline(figure_mask(model))] = (0, 90, 255)
    canvas.paste(Image.fromarray(mix), (column * SIZE, SIZE * 2))
canvas.resize((SIZE * 2 // 2 * 2 // 2, SIZE * 3 // 2)).save(HERE / "review/_same_scale.png")
