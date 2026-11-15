"""시트의 큰 얼굴 그림을 모델 좌표로 옮겨 렌더와 겹친다. 눈금은 모델 좌표(0.02 간격)다.

실행: python overlay_face.py <렌더 폴더>
렌더는 render_lit.py 의 head_front / head_right (세로 중심 z=0.365, 가로 폭 0.3)다.
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
fit = json.loads((HERE / "head_detail_fit.json").read_text())
sheet = np.asarray(Image.open(HERE.parent / "character-reference/pub-character-01.png").convert("RGB")).astype(np.float32)


def sheet_in_model_frame(view):
    info = fit[view]
    box = info["box"]
    px = (np.arange(SIZE) + 0.5 - SIZE / 2) * SPAN / SIZE
    py = CENTER_Z + (SIZE / 2 - np.arange(SIZE) - 0.5) * SPAN / SIZE
    # 시트 앞모습은 이미지 전체가 몸통 기준 약 3.9px 오른쪽으로 치우쳐 있다.
    ix = 512 + px * PX_PER_UNIT + (3.9 if view == "front" else 0.0)
    iy = FEET_Y - (py + 0.5) * PX_PER_UNIT
    dx = box[0] + (ix - info["x"]) / info["scale"]
    dy = box[1] + (iy - info["y"]) / info["scale"]
    xi = np.clip(dx.astype(int), 0, sheet.shape[1] - 1)
    yi = np.clip(dy.astype(int), 0, sheet.shape[0] - 1)
    return sheet[yi][:, xi]


def render_on_background(path):
    image = Image.open(path).convert("RGBA").resize((SIZE, SIZE))
    base = Image.new("RGBA", image.size, (*BACKGROUND, 255))
    base.alpha_composite(image)
    return np.asarray(base.convert("RGB")).astype(np.float32)


def grid(image, axis_name):
    draw = ImageDraw.Draw(image)
    for value in np.arange(-0.14, 0.16, 0.02):
        x = SIZE / 2 + value / SPAN * SIZE
        draw.line((x, 0, x, SIZE), fill=(0, 120, 255), width=1)
        draw.text((x + 2, 2), f"{value:+.2f}", fill=(0, 60, 200))
    for value in np.arange(0.22, 0.52, 0.02):
        y = SIZE / 2 - (value - CENTER_Z) / SPAN * SIZE
        draw.line((0, y, SIZE, y), fill=(0, 120, 255), width=1)
        draw.text((2, y + 1), f"{value:.2f}", fill=(0, 60, 200))
    draw.text((SIZE - 60, 2), axis_name, fill=(200, 0, 0))
    return image


folder = Path(sys.argv[1])
for view, name, axis in (("front", "head_front", "y"), ("right", "head_right", "x")):
    target = sheet_in_model_frame(view)
    model = render_on_background(folder / f"{name}.png")
    both = Image.fromarray(((target + model) / 2).astype(np.uint8))
    panels = [Image.fromarray(target.astype(np.uint8)), Image.fromarray(model.astype(np.uint8)), both]
    sheet_image = Image.new("RGB", (SIZE * 3, SIZE), BACKGROUND)
    for index, panel in enumerate(panels):
        sheet_image.paste(grid(panel, axis), (index * SIZE, 0))
    sheet_image.resize((SIZE * 2, int(SIZE * 2 / 3))).save(HERE / f"review/_overlay_{view}.png")
