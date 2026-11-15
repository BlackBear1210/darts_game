"""시트와 두 렌더의 색 차이를 재고, 머리 비교 이미지를 만든다."""
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).parent
MODELS = {"v3.1": HERE / "review/v31-lowpoly-a", "P2": HERE / "review/p2-quad-a", "P2+시트": HERE / "review/p2-sheet-paint"}
VIEWS = ["front", "right", "back"]
# 키 대비 세로 구간(위에서부터, 입력 1024px 기준)
BANDS = {"head": (40, 260), "shirt": (280, 560), "pants": (570, 900), "all": (0, 1024)}


def to_lab(rgb):
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


for name, folder in MODELS.items():
    for band, (y0, y1) in BANDS.items():
        errors, lightness, spread_s, spread_r = [], [], [], []
        for view in VIEWS:
            s = np.asarray(Image.open(HERE / "inputs" / f"{view}.png").convert("RGB")).astype(float)[y0:y1]
            r = np.asarray(Image.open(folder / f"{view}.png").convert("RGB").resize((1024, 1024))).astype(float)[y0:y1]
            mask = (s < 245).any(-1) & (r > 12).any(-1)
            ls, lr = to_lab(s)[mask], to_lab(r)[mask]
            errors.append(np.linalg.norm(ls - lr, axis=1).mean())
            lightness.append((lr[:, 0] - ls[:, 0]).mean())
            spread_s.append(ls[:, 0].std())
            spread_r.append(lr[:, 0].std())
        print(f"{name:5s} {band:6s} 색차 {np.mean(errors):5.1f}  밝기차 {np.mean(lightness):+5.1f}  명암폭 시트 {np.mean(spread_s):4.1f} 모델 {np.mean(spread_r):4.1f}")

sheet = Image.open(HERE.parent / "character-reference/pub-character-01.png").convert("RGB")
crops = [(205, 610, 505, 970), (620, 610, 920, 970), (1050, 610, 1350, 970)]
PX = 512
out = Image.new("RGB", (PX * 3, PX * (1 + len(MODELS))), (0, 0, 0))
for col, box in enumerate(crops):
    out.paste(sheet.crop(box).resize((PX, int(PX * 360 / 300))).crop((0, 0, PX, PX)), (col * PX, 0))
for row, folder in enumerate(MODELS.values(), start=1):
    for col, view in enumerate(["head_front", "head_right", "head_threequarter"]):
        out.paste(Image.open(folder / f"{view}.png").convert("RGB").resize((PX, PX)), (col * PX, row * PX))
out.save(HERE / "review/_diagnose_head.png")
