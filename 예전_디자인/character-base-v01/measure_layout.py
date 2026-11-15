"""시트, v3.1, P2의 얼굴 배치와 몸 길이를 같은 기준으로 잰다. 값은 키 대비 %."""
import numpy as np
from PIL import Image

SOURCES = {"시트": None, "v3.1": "review/lit-v31", "P2": "review/lit-p2"}


def load(folder, view):
    if folder is None:
        rgb = np.asarray(Image.open(f"inputs/{view}.png").convert("RGB")).astype(float)
        return rgb, (rgb < 245).any(-1)
    rgba = np.asarray(Image.open(f"{folder}/{view}.png").convert("RGBA").resize((1024, 1024))).astype(float)
    return rgba[..., :3], rgba[..., 3] > 200


results = {}
masks = {}
for name, folder in SOURCES.items():
    rgb, mask = load(folder, "front")
    rows = np.where(mask.any(1))[0]
    top, bottom = rows.min(), rows.max()
    height = bottom - top
    pct = lambda v: 100 * v / height
    r = {}
    # 눈: 얼굴 구간에서 밝고 채도가 낮은 영역
    bright = (rgb.min(-1) > 185) & (rgb.max(-1) - rgb.min(-1) < 45) & mask
    band = np.zeros_like(bright)
    band[top + int(.08 * height):top + int(.25 * height)] = True
    bright &= band
    xs_all = np.where(mask[top + int(.17 * height)])[0]
    mid = (xs_all.min() + xs_all.max()) / 2
    eyes = []
    for side in (bright[:, :int(mid)], bright[:, int(mid):]):
        ys, xs = np.where(side)
        offset = 0 if side is not None and side.shape[1] == int(mid) else int(mid)
        eyes.append((xs.min() + offset, xs.max() + offset, ys.min(), ys.max()))
    r["눈 지름"] = pct(np.mean([e[1] - e[0] for e in eyes]))
    r["눈 사이 거리"] = pct(((eyes[1][0] + eyes[1][1]) - (eyes[0][0] + eyes[0][1])) / 2)
    r["눈 높이(위에서)"] = pct(np.mean([(e[2] + e[3]) / 2 for e in eyes]) - top)
    # 머리 폭: 귀 높이의 폭
    ear_row = top + int(.165 * height)
    xs = np.where(mask[ear_row])[0]
    r["귀 포함 머리 폭"] = pct(xs.max() - xs.min())
    # 몸: 가운데 세로줄에서 옷 경계, 가랑이
    col = int(mid)
    ys = np.where(mask[:, col])[0]
    gaps = np.where(np.diff(ys) > 3)[0]
    r["가랑이 높이(위에서)"] = pct(ys[gaps[0]] - top) if len(gaps) else pct(ys.max() - top)
    dark = rgb[:, col].sum(1) < 330
    r["목 아래 옷 시작(위에서)"] = pct(np.where(dark & (np.arange(1024) > top + .2 * height))[0].min() - top)
    r["양팔 폭"] = pct(np.where(mask.any(0))[0].max() - np.where(mask.any(0))[0].min())
    left_cols = np.where(mask.any(0))[0].min() + 60
    hand_rows = np.where(mask[:, :left_cols].any(1))[0]
    r["손끝 높이(위에서)"] = pct(hand_rows.max() - top)
    # 측면: 코 끝 돌출, 머리 앞뒤 길이
    rgb_s, mask_s = load(folder, "right")
    rows = np.where(mask_s.any(1))[0]
    top_s, height_s = rows.min(), rows.max() - rows.min()
    head = mask_s[top_s:top_s + int(.27 * height_s)]
    cols = np.where(head.any(0))[0]
    r["머리 앞뒤 길이(코 포함)"] = 100 * (cols.max() - cols.min()) / height_s
    r["코끝 높이(위에서)"] = 100 * np.where(head[:, cols.max() - 2])[0].mean() / height_s
    results[name] = r
    masks[name] = (mask[:300], load(folder, "right")[1][:300])

keys = list(results["시트"])
print(f"{'항목':24s}{'시트':>7s}{'v3.1':>7s}{'P2':>7s}   더 가까운 쪽")
score = {"v3.1": 0, "P2": 0}
errors = {"v3.1": [], "P2": []}
for k in keys:
    s, a, b = results["시트"][k], results["v3.1"][k], results["P2"][k]
    near = "v3.1" if abs(a - s) < abs(b - s) else "P2"
    score[near] += 1
    errors["v3.1"].append(abs(a - s))
    errors["P2"].append(abs(b - s))
    print(f"{k:24s}{s:7.1f}{a:7.1f}{b:7.1f}   {near}")
print("가까운 항목 수", score, "평균 오차", {k: round(float(np.mean(v)), 2) for k, v in errors.items()})
for view, i in (("정면", 0), ("측면", 1)):
    s = masks["시트"][i]
    print(view, "머리 구간 겹침", {n: round(float((s & masks[n][i]).sum() / (s | masks[n][i]).sum()), 3) for n in ("v3.1", "P2")})
