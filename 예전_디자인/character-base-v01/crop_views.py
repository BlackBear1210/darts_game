"""캐릭터 시트에서 뷰별 입력 이미지를 같은 축척으로 잘라낸다. 배경·안내선·라벨을 지운다."""
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).parent
SHEET = HERE.parent / "character-reference" / "pub-character-01.png"
OUT = HERE / "inputs"
# 시트 위쪽 전신 뷰의 가로 범위(픽셀). 세로 범위는 모두 같아 축척과 발 높이가 맞는다.
COLUMNS = {"front": (20, 505), "side": (535, 700), "back": (715, 1140), "threequarter": (1145, 1500)}
TOP, BOTTOM = 0, 586
SIDE_PX = 620   # 잘라낼 정사각형 한 변
OUT_PX = 1024   # 출력 크기
BG_DISTANCE = 26.0


def largest_component(mask: np.ndarray) -> np.ndarray:
    seen = np.zeros_like(mask)
    best: list = []
    h, w = mask.shape
    for sy, sx in zip(*np.where(mask)):
        if seen[sy, sx]:
            continue
        seen[sy, sx] = True
        queue, pixels = deque([(sy, sx)]), []
        while queue:
            y, x = queue.popleft()
            pixels.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        if len(pixels) > len(best):
            best = pixels
    out = np.zeros_like(mask)
    ys, xs = zip(*best)
    out[list(ys), list(xs)] = True
    return out


def fill_holes(mask: np.ndarray) -> np.ndarray:
    # 네 변을 1픽셀 넓혀 바깥에서 flood fill 하고, 닿지 못한 곳을 안쪽으로 본다.
    padded = Image.fromarray(np.pad(mask, 1).astype(np.uint8) * 255).copy()  # fromarray 결과는 읽기 전용
    ImageDraw.floodfill(padded, (0, 0), 128)
    return (np.asarray(padded) != 128)[1:-1, 1:-1]


sheet = np.asarray(Image.open(SHEET).convert("RGB")).astype(np.float32)
for name, (x0, x1) in COLUMNS.items():
    region = sheet[TOP:BOTTOM, x0:x1]
    # 시트 배경은 위아래로 밝기가 조금씩 달라 행마다 배경색을 잡는다.
    bg = np.median(np.concatenate([region[:, :6], region[:, -6:]], axis=1), axis=1, keepdims=True)
    fg = np.linalg.norm(region - bg, axis=2) > BG_DISTANCE
    image = Image.fromarray(fg.astype(np.uint8) * 255)
    image = image.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))  # 얇은 안내선 제거
    keep = fill_holes(largest_component(np.asarray(image) > 0))
    ys, xs = np.where(keep)
    print(name, "x", xs.min() + x0, xs.max() + x0, "y", ys.min() + TOP, ys.max() + TOP, "w", xs.max() - xs.min(), "h", ys.max() - ys.min())
    alpha = Image.fromarray(keep.astype(np.uint8) * 255).filter(ImageFilter.GaussianBlur(0.6))
    cut = Image.fromarray(region.astype(np.uint8))
    canvas = Image.new("RGB", (SIDE_PX, SIDE_PX), (255, 255, 255))
    offset_x = SIDE_PX // 2 - (int(xs.min()) + int(xs.max())) // 2
    offset_y = (SIDE_PX - (BOTTOM - TOP)) // 2
    canvas.paste(cut, (offset_x, offset_y), alpha)
    canvas.resize((OUT_PX, OUT_PX), Image.LANCZOS).save(OUT / f"{name}.png")
