from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
p=Path(__file__).parent
files=[p/'reference.png',p.parent/'character_v07'/'turnaround.png',p/'turnaround.png']
ims=[Image.open(f).convert('RGB').resize((1536,1024)) for f in files]
out=Image.new('RGB',(1200,610),'#eee');d=ImageDraw.Draw(out)
font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',23)
for k,(im,lab) in enumerate(zip(ims,['원본 도안','이전 모델 v07','세부 수정 v08'])):
    d.text((k*400+20,12),lab,font=font,fill='#222')
    crop=im.crop((238,610,478,964)).resize((385,568))
    out.paste(crop,(k*400,45))
out.save(p/'detail_comparison.png')
