"""조명 렌더와 시트를 비교해 v3.1 머리의 색 보정값을 계산한다. 값은 기존 보정값에 곱해 누적한다."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
review = Path(sys.argv[1])
SPOTS = {
    "skin": [("front", 516, 125), ("front", 450, 215), ("front", 560, 215), ("right", 640, 225), ("back", 500, 262)],
    "hair": [("front", 500, 75), ("back", 500, 140), ("back", 470, 90), ("right", 440, 120)],
}


def linear(values):
    c = np.asarray(values, dtype=float) / 255
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def patch(path, x, y, radius=9):
    image = np.asarray(Image.open(path).convert("RGBA").resize((1024, 1024))).astype(float)
    area = image[y - radius:y + radius, x - radius:x + radius]
    keep = area[..., 3] > 200
    return np.median(area[keep][:, :3], axis=0) if keep.sum() > 40 else np.full(3, np.nan)


gains_path = HERE / "head_gains.json"
gains = json.loads(gains_path.read_text()) if gains_path.exists() else {}
for key, spots in SPOTS.items():
    sheet = np.nanmedian([patch(HERE / "inputs" / f"{v}.png", x, y) for v, x, y in spots], axis=0)
    render = np.nanmedian([patch(review / f"{v}.png", x, y) for v, x, y in spots], axis=0)
    step = linear(sheet) / np.maximum(linear(render), 1e-3)
    gains[key] = [round(float(a * b), 3) for a, b in zip(gains.get(key, [1, 1, 1]), step)]
    print(key, "시트", sheet.round(), "렌더", render.round(), "보정", gains[key])
sheet_skin = np.nanmedian([patch(HERE / "inputs" / f"{v}.png", x, y) for v, x, y in SPOTS["skin"]], axis=0)
gains["scalp_rgb"] = [round(float(c), 3) for c in linear(sheet_skin) * 0.98]
gains_path.write_text(json.dumps(gains, indent=1))
