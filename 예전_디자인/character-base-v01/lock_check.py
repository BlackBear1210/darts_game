"""이미 맞춘 수치가 나빠지지 않았는지 검사한다.

실행: python lock_check.py <렌더 폴더> [save]
save 를 주면 현재 값을 기준으로 저장한다. 없으면 기준과 비교해 나빠진 항목을 알려 준다.
"""
import contextlib
import importlib.util
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
BASE = HERE / "lock_base.json"
folder = Path(sys.argv[1])
PX = 569 * 1024 / 620
FEET = (579 + 17) * 1024 / 620


def load_relief():
    spec = importlib.util.spec_from_file_location("rm", HERE / "relief_map.py")
    module = importlib.util.module_from_spec(spec)
    keep = sys.argv
    sys.argv = ["relief_map.py", str(folder)]
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        spec.loader.exec_module(module)
    sys.argv = keep
    table = {}
    section = ""
    for line in buffer.getvalue().splitlines():
        if line.startswith("정면") or line.startswith("옆면"):
            section = line[:2]
        elif "차이" in line and ":" in line:
            name, rest = line.strip().split(":", 1)
            words = rest.split()
            table[f"{section} {name}"] = abs(float(words[-1]))
    return table


def side_error():
    def skin(a):
        return (a[..., 0] > 170) & (a[..., 0] - a[..., 2] > 40)
    sheet = np.asarray(Image.open(HERE / "inputs/right.png").convert("RGB")).astype(float)
    render = np.asarray(Image.open(folder / "right.png").convert("RGBA").resize((1024, 1024))).astype(float)
    a_mask = skin(sheet) & (sheet < 245).any(-1)
    b_mask = skin(render[..., :3]) & (render[..., 3] > 200)
    errors = []
    for z in (0.33, 0.31, 0.30, 0.29, 0.28, 0.27, 0.26, 0.25):
        row = int(FEET - (z + 0.5) * PX)
        a, b = np.where(a_mask[row])[0], np.where(b_mask[row])[0]
        if len(a) and len(b):
            errors.append(abs(int(a.max()) - int(b.max())) / PX)
    for x in (0.07, 0.06, 0.05, 0.04, 0.03):
        col = int(512 + x * PX)
        a, b = np.where(a_mask[:330, col])[0], np.where(b_mask[:330, col])[0]
        if len(a) and len(b):
            errors.append(abs(int(a.max()) - int(b.max())) / PX)
    return float(np.mean(errors))


def overlap(view, shift):
    sheet = np.asarray(Image.open(HERE / f"inputs/{view}.png").convert("RGB")).astype(float)
    render = np.asarray(Image.open(folder / f"{view}.png").convert("RGBA").resize((1024, 1024))).astype(float)
    a = (sheet < 245).any(-1)[:310]
    b = np.roll((render[..., 3] > 200)[:310], shift, axis=1)
    return float((a & b).sum() / (a | b).sum())


values = {"옆 윤곽 오차": side_error(), "정면 머리 겹침": overlap("front", 4), "옆면 머리 겹침": overlap("right", 0),
          "뒷면 머리 겹침": overlap("back", 4)}
values.update(load_relief())
if len(sys.argv) > 2 and sys.argv[2] == "save":
    BASE.write_text(json.dumps(values, ensure_ascii=False, indent=1), encoding="utf-8")
    print("기준 저장", {k: round(v, 4) for k, v in list(values.items())[:4]})
else:
    base = json.loads(BASE.read_text(encoding="utf-8"))
    worse, better = [], []
    for key, value in values.items():
        old = base.get(key)
        if old is None:
            continue
        higher_better = "겹침" in key
        change = (value - old) if higher_better else (old - value)
        limit = 0.004 if "겹침" in key else (0.0004 if "오차" in key else 3.0)
        if change < -limit:
            worse.append(f"{key} {old:.4g}->{value:.4g}")
        elif change > limit:
            better.append(f"{key} {old:.4g}->{value:.4g}")
    print("좋아짐:", better or "없음")
    print("나빠짐:", worse or "없음")
