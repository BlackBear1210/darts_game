"""옆모습 윤곽을 시트와 숫자로 비교한다. 인자: 렌더 폴더"""
import sys

import numpy as np
from PIL import Image

FEET = (579 + 17) * 1024 / 620
PX = 569 * 1024 / 620


def to_x(ix):
    return (ix - 512) / PX


def to_z(iy):
    return (FEET - iy) / PX - 0.5


def is_skin(a):
    return (a[..., 0] > 170) & (a[..., 0] - a[..., 2] > 40)


sheet = np.asarray(Image.open("inputs/right.png").convert("RGB")).astype(float)
render = np.asarray(Image.open(sys.argv[1] + "/right.png").convert("RGBA").resize((1024, 1024))).astype(float)
sheet_skin = is_skin(sheet) & (sheet < 245).any(-1)
render_skin = is_skin(render[..., :3]) & (render[..., 3] > 200)
errors = []
print("앞쪽 윤곽 x")
for z in (0.33, 0.31, 0.30, 0.29, 0.28, 0.27, 0.26, 0.25):
    iy = int(FEET - (z + 0.5) * PX)
    a, b = np.where(sheet_skin[iy])[0], np.where(render_skin[iy])[0]
    if len(a) and len(b):
        errors.append(abs(to_x(a.max()) - to_x(b.max())))
        print(f"  z {z}: 시트 {to_x(a.max()):.3f} 모델 {to_x(b.max()):.3f}")
print("턱 아래 윤곽 z")
for x in (0.07, 0.06, 0.05, 0.04, 0.03):
    ix = int(512 + x * PX)
    a, b = np.where(sheet_skin[:330, ix])[0], np.where(render_skin[:330, ix])[0]
    if len(a) and len(b):
        errors.append(abs(to_z(a.max()) - to_z(b.max())))
        print(f"  x {x}: 시트 {to_z(a.max()):.3f} 모델 {to_z(b.max()):.3f}")
print("평균 오차", round(float(np.mean(errors)), 4))
