"""시트 아래쪽 큰 얼굴 그림이 전신 입력 이미지의 어디에 해당하는지 찾아 json으로 저장한다."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).parent
sheet = Image.open(HERE.parent / "character-reference/pub-character-01.png").convert("L")
# 큰 얼굴 그림에서 어깨를 뺀 머리 부분(시트 픽셀).
DETAIL = {"front": (235, 618, 480, 900), "right": (640, 618, 895, 900)}
# 전신 입력 이미지(1024px)의 머리 탐색 구간
SEARCH = (300, 20, 740, 300)
result = {}
for view, box in DETAIL.items():
    target = Image.open(HERE / "inputs" / f"{view}.png").convert("L")
    t = np.asarray(target.crop(SEARCH)).astype(np.float32)
    best = (-2, None)
    for scale in np.arange(0.70, 1.10, 0.01):
        w = int((box[2] - box[0]) * scale)
        h = int((box[3] - box[1]) * scale)
        d = np.asarray(sheet.crop(box).resize((w, h), Image.LANCZOS)).astype(np.float32)
        d = d - d.mean()
        dn = np.sqrt((d * d).sum())
        if h >= t.shape[0] or w >= t.shape[1]:
            continue
        windows = np.lib.stride_tricks.sliding_window_view(t, (h, w))[::2, ::2]
        wm = windows.mean(axis=(2, 3), keepdims=True)
        num = np.einsum("ijkl,kl->ij", windows - wm, d)
        den = np.sqrt(((windows - wm) ** 2).sum(axis=(2, 3))) * dn + 1e-6
        ncc = num / den
        y, x = np.unravel_index(ncc.argmax(), ncc.shape)
        if ncc[y, x] > best[0]:
            best = (float(ncc[y, x]), {"scale": float(scale), "x": int(x * 2 + SEARCH[0]), "y": int(y * 2 + SEARCH[1])})
    print(view, "ncc", round(best[0], 3), best[1])
    result[view] = {"box": box, **best[1], "ncc": best[0]}
(HERE / "head_detail_fit.json").write_text(json.dumps(result, indent=1))
