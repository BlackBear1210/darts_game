"""시트 정면에서 입의 높이·폭, 코 폭을 재서 모델 좌표로 저장한다."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
FEET_Y = (579 + 17) * 1024 / 620
PX_PER_UNIT = 569 * 1024 / 620  # 키를 1로 볼 때 입력 이미지의 픽셀 수

rgb = np.asarray(Image.open(HERE / "inputs/front.png").convert("RGB")).astype(float)
luma = rgb @ np.array([0.3, 0.59, 0.11])
figure = (rgb < 245).any(-1)
face_col = 512
# 입: 얼굴 아래쪽 구간에서 가운데 줄 근처의 가장 어두운 행
band = slice(235, 290)
rows = luma[band, face_col - 12:face_col + 12].mean(axis=1)
mouth_y = int(np.argmin(rows)) + band.start
line = luma[mouth_y - 1:mouth_y + 2].min(axis=0)
skin = np.median(luma[mouth_y - 12:mouth_y - 6, face_col - 20:face_col + 20])
dark = np.where(line[face_col - 90:face_col + 90] < skin - 25)[0] + face_col - 90
left, right = dark.min(), dark.max()
thick = int((luma[mouth_y - 6:mouth_y + 7, face_col] < skin - 25).sum())
result = {
    "mouth_z": float(-0.5 + (FEET_Y - mouth_y) / PX_PER_UNIT),
    "mouth_y": float(((left + right) / 2 - 512) / PX_PER_UNIT),
    "mouth_half_width": float((right - left) / 2 / PX_PER_UNIT),
    "mouth_thickness": float(max(thick, 2) / PX_PER_UNIT),
}
print("mouth row", mouth_y, "x", left, right, "thick px", thick)
print(result)
(HERE / "sheet_face.json").write_text(json.dumps(result, indent=1))
