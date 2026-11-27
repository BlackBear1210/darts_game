"""12방향 묶음. usage: turn_sheet.py <dir> <kind body|face|hand> <out.png> id...  (흰 배경 합성)"""
import os, sys
from PIL import Image
D, kind, out = sys.argv[1], sys.argv[2], sys.argv[3]
ids = sys.argv[4:]
rows = []
for cid in ids:
    ims = []
    angs = range(0, 360, 45) if kind == 'hand' else range(0, 360, 30)
    for a in angs:
        name = f'{cid}_hand_{a:03d}.png' if kind == 'hand' else f'{cid}_t_{kind}_{a:03d}.png'
        im = Image.open(os.path.join(D, name)).convert('RGBA')
        bg = Image.new('RGBA', im.size, 'white'); bg.alpha_composite(im)
        im = bg.convert('RGB')
        if kind == 'body':
            im = im.crop((300, 0, 900, 1600)).resize((225, 600), Image.LANCZOS)
        elif kind == 'face':
            im = im.resize((300, 300), Image.LANCZOS)
        else:
            im = im.resize((300, 300), Image.LANCZOS)
        ims.append(im)
    row = Image.new('RGB', (sum(i.width for i in ims), ims[0].height), 'white')
    x = 0
    for i in ims:
        row.paste(i, (x, 0)); x += i.width
    rows.append(row)
sheet = Image.new('RGB', (max(r.width for r in rows), sum(r.height for r in rows)), 'white')
y = 0
for r in rows:
    sheet.paste(r, (0, y)); y += r.height
sheet.save(out)
print('ok', sheet.size)
