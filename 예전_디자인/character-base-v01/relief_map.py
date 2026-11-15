"""시트와 모델의 얼굴 명암을 같은 좌표에서 비교해 입체감 차이를 찾는다.

실행: python relief_map.py <렌더 폴더>
출력: review/_relief_front.png, _relief_right.png (왼쪽 시트, 가운데 모델, 오른쪽 차이), 부위별 밝기표
입체 지도 색: 파랑 = 어두움(꺾이거나 들어간 면), 빨강 = 밝음(빛을 정면으로 받는 면).
차이 지도 색: 빨강 = 모델이 시트보다 밝음, 파랑 = 모델이 시트보다 어두움.
"""
import contextlib
import importlib.util
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).parent
folder = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("fm", HERE / "face_metrics.py")
fm = importlib.util.module_from_spec(spec)
arguments = sys.argv
sys.argv = ["face_metrics.py", str(folder)]
with contextlib.redirect_stdout(io.StringIO()):
    spec.loader.exec_module(fm)
sys.argv = arguments
SIZE = fm.SIZE
LUMA = np.array([0.3, 0.59, 0.11], dtype=np.float32)
# 부위 이름, 좌우 또는 앞뒤 좌표, 높이. 얼굴 가운데 y 0.0115 기준의 왼쪽 절반과 오른쪽 절반을 함께 잰다.
FRONT = [("이마 가운데", 0.0, 0.425), ("이마 옆", 0.045, 0.425), ("미간", 0.0, 0.398), ("콧대 위", 0.0, 0.375),
         ("콧대 아래", 0.0, 0.345), ("코 옆면", 0.022, 0.35), ("눈 밑", 0.04, 0.345), ("눈 바깥", 0.066, 0.372),
         ("광대", 0.055, 0.335), ("볼", 0.04, 0.312), ("볼 아래", 0.042, 0.285), ("입 위", 0.0, 0.295),
         ("입 옆", 0.033, 0.272), ("턱 가운데", 0.0, 0.26), ("턱 옆", 0.033, 0.255)]
SIDE = [("이마", 0.055, 0.425), ("눈썹뼈", 0.065, 0.41), ("코 시작", 0.068, 0.39), ("눈 앞", 0.074, 0.375),
        ("콧등", 0.088, 0.355), ("코 옆 아래", 0.085, 0.33), ("눈 아래", 0.05, 0.345), ("눈 뒤 관자", 0.02, 0.38),
        ("광대 앞", 0.05, 0.325), ("광대 뒤", 0.015, 0.335), ("볼 앞", 0.06, 0.30), ("볼 뒤", 0.02, 0.305),
        ("턱선 앞", 0.05, 0.268), ("턱선 뒤", 0.02, 0.285), ("턱끝", 0.068, 0.255), ("목 앞", 0.008, 0.245)]


def luminance(image):
    return image @ LUMA


def smooth(values, radius=4):
    image = Image.fromarray(np.clip(values, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(image).astype(np.float32)


def sample(values, u, z):
    px = int(SIZE / 2 + u / fm.SPAN * SIZE)
    py = fm.frame_px_z(z)
    return float(values[py - 5:py + 6, px - 5:px + 6].mean())


def ramp(values, reference):
    """피부 평균을 가운데로 놓고 어두우면 파랑, 밝으면 빨강으로 칠한다."""
    t = np.clip((values - reference) / 28.0, -1, 1)
    out = np.zeros((*values.shape, 3), dtype=np.float32)
    out[..., 0] = np.where(t > 0, 255, 255 * (1 + t))
    out[..., 1] = 255 * (1 - np.abs(t))
    out[..., 2] = np.where(t < 0, 255, 255 * (1 - t))
    return out


for view, name, spots in (("front", "head_front", FRONT), ("right", "head_right", SIDE)):
    target = fm.sheet_frame(view)
    model = fm.model_frame(folder / f"{name}.png")
    ls, lm = smooth(luminance(target)), smooth(luminance(model))
    skin = fm.skin_mask(target) & fm.skin_mask(model)
    rs, rm = float(np.median(ls[skin])), float(np.median(lm[skin]))
    print("정면" if view == "front" else "옆면", f"피부 중간 밝기 시트 {rs:.0f} 모델 {rm:.0f}. 값은 피부 평균에서의 차이")
    rows = []
    for label, u, z in spots:
        if view == "front":
            pairs = [(0.0115 + u, z), (0.0115 - u, z)] if u else [(0.0115, z)]
        else:
            pairs = [(u, z)]
        a = np.mean([sample(ls, *p) for p in pairs]) - rs
        b = np.mean([sample(lm, *p) for p in pairs]) - rm
        rows.append((label, a, b))
        print(f"  {label}: 시트 {a:+.0f} 모델 {b:+.0f} 차이 {b - a:+.0f}")
    canvas = Image.new("RGB", (SIZE * 3, SIZE), (255, 255, 255))
    for index, (values, reference) in enumerate(((ls, rs), (lm, rm))):
        colored = ramp(values, reference)
        colored[~(fm.skin_mask(target if index == 0 else model))] = (235, 235, 235)
        canvas.paste(Image.fromarray(colored.astype(np.uint8)), (index * SIZE, 0))
    difference = ramp((lm - rm) - (ls - rs) + 128, 128)
    difference[~skin] = (235, 235, 235)
    canvas.paste(Image.fromarray(difference.astype(np.uint8)), (SIZE * 2, 0))
    draw = ImageDraw.Draw(canvas)
    for label, u, z in spots:
        px = (SIZE / 2 + (0.0115 + u if view == "front" else u) / fm.SPAN * SIZE) + SIZE * 2
        py = fm.frame_px_z(z)
        draw.ellipse((px - 4, py - 4, px + 4, py + 4), outline=(0, 0, 0))
    canvas.resize((SIZE * 2, SIZE * 2 // 3)).save(HERE / f"review/_relief_{view}.png")
