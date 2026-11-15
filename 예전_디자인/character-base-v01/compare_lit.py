"""조명 렌더를 시트 배경색 위에 올려 시트와 비교한다."""
from pathlib import Path
import sys
import numpy as np
from PIL import Image

HERE = Path(__file__).parent
BG = (201, 202, 203)
PX = 512
folders = [Path(p) for p in sys.argv[1:]]


def on_bg(path):
    image = Image.open(path).convert("RGBA")
    base = Image.new("RGBA", image.size, (*BG, 255))
    base.alpha_composite(image)
    return base.convert("RGB")


sheet = Image.open(HERE.parent / "character-reference/pub-character-01.png").convert("RGB")
crops = [(205, 610, 505, 970), (620, 610, 920, 970), (1050, 610, 1350, 970)]
head = Image.new("RGB", (PX * 3, PX * (1 + len(folders))), BG)
for col, box in enumerate(crops):
    head.paste(sheet.crop(box).resize((PX, int(PX * 360 / 300))).crop((0, 0, PX, PX)), (col * PX, 0))
for row, folder in enumerate(folders, start=1):
    for col, view in enumerate(["head_front", "head_right", "head_threequarter"]):
        head.paste(on_bg(folder / f"{view}.png").resize((PX, PX)), (col * PX, row * PX))
head.save(HERE / "review/_lit_head.png")

views = ["front", "right", "back", "threequarter"]
body = Image.new("RGB", (PX * 4, PX * (1 + len(folders))), BG)
for col, view in enumerate(views):
    src = Image.open(HERE / "inputs" / f"{view}.png").convert("RGB")
    arr = np.asarray(src).copy()
    arr[(arr > 247).all(axis=2)] = BG
    body.paste(Image.fromarray(arr).resize((PX, PX)), (col * PX, 0))
for row, folder in enumerate(folders, start=1):
    for col, view in enumerate(views):
        body.paste(on_bg(folder / f"{view}.png").resize((PX, PX)), (col * PX, row * PX))
body.save(HERE / "review/_lit_body.png")
