import numpy as np
from PIL import Image
O=r"C:/Users/아버지/AppData/Local/Temp/claude/a20be7e080516bad/c1f1ed85-1c5b-4bc8-93b8-2b3433a2c49f/scratchpad/"
tex=np.asarray(Image.open(r"C:/Users/아버지/Desktop/다트/output/character_texture_fix_20261115_v04/character_basecolor_v04.png").convert("RGB")).astype(np.float32)/255
fidx=np.load(O+"fidx.npy");d=np.load(O+"faces.npz");fc,fn=d["fc"],d["fn"];F=len(fc)
FL=np.load(O+"facelab.npz");hairlab=FL["lab"]
ok=fidx>=0;t=fidx[ok];cnt=np.bincount(t,minlength=F)
mean=np.stack([np.bincount(t,weights=tex[...,i][ok],minlength=F) for i in range(3)],1)/np.maximum(cnt,1)[:,None]
r,g,b=mean.T;mx=mean.max(1);mn=mean.min(1);dd=mx-mn+1e-6
h=np.where(mx==r,((g-b)/dd)%6,np.where(mx==g,(b-r)/dd+2,(r-g)/dd+4))*60;s=dd/(mx+1e-6);v=mx
np.savez("facecolor.npz",mean=mean,h=h,s=s,v=v,cnt=cnt)
Z=fc[:,2]
for lo,hi in [(0,0.05),(0.05,0.1),(0.1,0.3),(0.3,0.45),(0.45,0.5),(0.5,0.55),(0.55,0.6),(0.6,0.7),(0.7,0.76)]:
    m=(Z>=lo)&(Z<hi)&(cnt>0)
    print(f"Z {lo}-{hi} n={m.sum()}", "h50",np.percentile(h[m],[10,50,90]).round(0),"s",np.percentile(s[m],[10,50,90]).round(2),"v",np.percentile(v[m],[10,50,90]).round(2), "purple",(h[m]>250).mean().round(2),"skinlike",((h[m]>12)&(h[m]<40)&(v[m]>0.55)&(s[m]>0.4)).mean().round(2))
