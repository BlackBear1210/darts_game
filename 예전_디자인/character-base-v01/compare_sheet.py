"""입력 뷰와 렌더를 나란히 붙이고 실루엣 겹침(IoU)을 잰다."""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).parent
review = Path(sys.argv[1])
pairs = {"front": "front", "right": "right", "back": "back", "threequarter": "threequarter"}
PX = 512


def source_silhouette(image: Image.Image) -> np.ndarray:
    return (np.asarray(image.convert("RGB")).astype(np.float32) < 245).any(axis=2)


def render_silhouette(image: Image.Image) -> np.ndarray:
    # 렌더 배경은 검은색이다.
    return (np.asarray(image.convert("RGB")).astype(np.float32) > 12).any(axis=2)


sheet = Image.new("RGB", (PX * len(pairs), PX * 2), (255, 255, 255))
for col, (src, rendered) in enumerate(pairs.items()):
    source = Image.open(HERE / "inputs" / f"{src}.png").convert("RGB").resize((PX, PX))
    render = Image.open(review / f"{rendered}.png").convert("RGB").resize((PX, PX))
    sheet.paste(source, (col * PX, 0))
    sheet.paste(render, (col * PX, PX))
    a, b = source_silhouette(source), render_silhouette(render)
    print(src, "IoU", round(float((a & b).sum() / max((a | b).sum(), 1)), 3))
sheet.save(review / "_compare_body.png")

heads = ["head_front", "head_right", "head_threequarter"]
strip = Image.new("RGB", (PX * 3, PX * 2), (255, 255, 255))
for col, name in enumerate(heads):
    strip.paste(Image.open(review / f"{name}.png").convert("RGB").resize((PX, PX)), (col * PX, 0))
    strip.paste(Image.open(review / f"{name}_clay.png").convert("RGB").resize((PX, PX)), (col * PX, PX))
strip.save(review / "_compare_head.png")

hands = ["hand_a", "hand_b", "hand_a_clay", "hand_b_clay"]
strip = Image.new("RGB", (PX * 4, PX), (255, 255, 255))
for col, name in enumerate(hands):
    strip.paste(Image.open(review / f"{name}.png").convert("RGB").resize((PX, PX)), (col * PX, 0))
strip.save(review / "_compare_hands.png")
