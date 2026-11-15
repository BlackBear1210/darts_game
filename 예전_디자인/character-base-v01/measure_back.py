"""뒷면 머리 윤곽을 각도별로 재서 시트와 모델의 반지름을 비교한다.

실행: python measure_back.py <렌더 폴더> [save]
save 를 주면 각도별 비율을 back_outline.json 으로 저장한다. 값은 모델 좌표(가로 y, 세로 z)다.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
PX = 569 * 1024 / 620
FEET = (579 + 17) * 1024 / 620
CENTER_Z = 0.405          # 머리 뒷면 중심 높이
SHEET_SHIFT_PX = 4.0      # 시트 뒷면도 몸통 기준 약 4px 치우쳐 있다.


def hair_mask(a):
    return (a[..., 0] < 130) & (a[..., 0] > 30) & (a[..., 0] - a[..., 2] > 12)


def outline(mask, center_px):
    cy = FEET - (CENTER_Z + 0.5) * PX
    result = {}
    for angle in range(0, 360, 10):
        rad = np.radians(angle)
        best = 0.0
        for radius in np.arange(10, 180, 0.5):
            x = int(center_px + radius * np.cos(rad))
            y = int(cy - radius * np.sin(rad))
            if 0 <= x < 1024 and 0 <= y < 1024 and mask[y, x]:
                best = radius
        result[angle] = best / PX
    return result


folder = Path(sys.argv[1])
sheet = np.asarray(Image.open(HERE / "inputs/back.png").convert("RGB")).astype(float)
render_rgba = np.asarray(Image.open(folder / "back.png").convert("RGBA").resize((1024, 1024))).astype(float)
render = render_rgba[..., :3]
sheet_hair = hair_mask(sheet)
render_hair = hair_mask(render) & (render_rgba[..., 3] > 200)
xs = np.where(sheet_hair[:310].any(axis=0))[0]
xm = np.where(render_hair[:310].any(axis=0))[0]
sheet_center = (xs.min() + xs.max()) / 2
model_center = (xm.min() + xm.max()) / 2
print("머리카락 가로 범위 시트", xs.min(), xs.max(), "모델", xm.min(), xm.max(), "중심", sheet_center, model_center)
a = outline(sheet_hair, sheet_center)
b = outline(render_hair, model_center)
ratios = {}
for angle in range(0, 360, 30):
    print(f"  {angle:3d}도: 시트 {a[angle]:.3f} 모델 {b[angle]:.3f} 비율 {a[angle] / max(b[angle], 1e-3):.3f}")
for angle in a:
    ratios[str(angle)] = a[angle] / max(b[angle], 1e-3) if b[angle] > 0.02 and a[angle] > 0.02 else 1.0
print("평균 윤곽 차이", round(float(np.mean([abs(a[k] - b[k]) for k in a])), 4))
if len(sys.argv) > 2 and sys.argv[2] == "save":
    (HERE / "back_outline.json").write_text(json.dumps(ratios, indent=0))
