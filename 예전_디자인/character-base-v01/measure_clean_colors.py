"""조명 렌더와 시트를 비교해 단색 재질 값을 맞춘다. 첫 실행은 시트 색을 그대로 시작값으로 쓴다."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
PATH = HERE / "clean_colors.json"
SPOTS = {
    "skin": [("front", 516, 125), ("front", 450, 215), ("front", 560, 215), ("back", 500, 262)],
    "hair": [("front", 500, 75), ("back", 500, 140), ("back", 470, 90)],
    "top": [("front", 500, 430), ("front", 500, 520), ("back", 500, 430)],
    "bottom": [("front", 450, 740), ("front", 560, 740), ("back", 450, 740)],
    "shoes": [("front", 412, 935), ("front", 585, 935)],
}


def linear(values):
    c = np.asarray(values, dtype=float) / 255
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def patch(path, x, y, radius=9):
    image = np.asarray(Image.open(path).convert("RGBA").resize((1024, 1024))).astype(float)
    area = image[y - radius:y + radius, x - radius:x + radius]
    keep = area[..., 3] > 200
    return np.median(area[keep][:, :3], axis=0) if keep.sum() > 40 else np.full(3, np.nan)


def sheet_color(spots):
    return np.nanmedian([patch(HERE / "inputs" / f"{v}.png", x, y) for v, x, y in spots], axis=0)


if len(sys.argv) < 2:
    colors = {key: [round(float(c), 4) for c in linear(sheet_color(spots))] for key, spots in SPOTS.items()}
    colors["brow"] = [round(float(c), 4) for c in linear([62, 40, 32])]
    colors["mouth"] = [round(float(c), 4) for c in linear([110, 66, 52])]
    print("start", colors)
else:
    review = Path(sys.argv[1])
    colors = json.loads(PATH.read_text())
    for key, spots in SPOTS.items():
        sheet = sheet_color(spots)
        render = np.nanmedian([patch(review / f"{v}.png", x, y) for v, x, y in spots], axis=0)
        step = linear(sheet) / np.maximum(linear(render), 1e-3)
        colors[key] = [round(float(min(a * b, 1.0)), 4) for a, b in zip(colors[key], step)]
        print(key, "시트", sheet.round(), "렌더", render.round())
PATH.write_text(json.dumps(colors, indent=1))
