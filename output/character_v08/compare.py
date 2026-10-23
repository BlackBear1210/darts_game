from PIL import Image,ImageDraw
from pathlib import Path
p=Path(__file__).parent
r=Image.open(p/'reference.png').convert('RGB')
b=Image.open(p.parent/'character_v07'/'turnaround.png').convert('RGB').resize(r.size)
canvas=Image.new('RGB',(1800,470),'#eeeeee');d=ImageDraw.Draw(canvas)
for i,(box,title) in enumerate([((230,620,490,964),'FRONT FACE'),((625,620,905,964),'SIDE FACE'),((1070,620,1330,964),'3/4 FACE')]):
    for j,im in enumerate([r,b]):
        crop=im.crop(box);crop.thumbnail((295,400));crop=crop.resize((295,int(crop.height*295/crop.width)))
        canvas.paste(crop,(i*600+j*300,60));d.text((i*600+j*300,35),'REFERENCE' if j==0 else 'V07',fill='black')
    d.text((i*600,12),title,fill='black')
canvas.save(p/'comparison_before.png')
