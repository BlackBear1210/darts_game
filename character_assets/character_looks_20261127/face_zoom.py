import os, sys
from PIL import Image
D, out = sys.argv[1], sys.argv[2]
ids = sys.argv[3].split(',')
angs = [int(a) for a in sys.argv[4].split(',')]
size = 420
sheet = Image.new('RGB', (size * len(angs), size * len(ids)), 'white')
for r, cid in enumerate(ids):
    for c, a in enumerate(angs):
        im = Image.open(os.path.join(D, f'{cid}_t_face_{a:03d}.png')).convert('RGBA')
        bg = Image.new('RGBA', im.size, 'white'); bg.alpha_composite(im)
        sheet.paste(bg.convert('RGB').resize((size, size), Image.LANCZOS), (c * size, r * size))
sheet.save(out)
