import numpy as np
from PIL import Image
SRC=r"C:/Users/아버지/Desktop/다트/output/character_texture_fix_20261113_v01/character_basecolor_repaired.png"
d=np.load(r"C:/Users/아버지/AppData/Local/Temp/claude/a20be7e080516bad/c1f1ed85-1c5b-4bc8-93b8-2b3433a2c49f/scratchpad/posmap.npz")
pos=d["pos"][::-1].copy();nrm=d["nrm"][::-1].copy()
tex=np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)/255
cov=pos[:,:,0]>-8
X,Y,Z=pos[:,:,0],pos[:,:,1],pos[:,:,2]
def fit_sphere(P):
    A=np.c_[2*P,np.ones(len(P))];b=(P**2).sum(1)
    s=np.linalg.lstsq(A,b,rcond=None)[0];c=s[:3];r=np.sqrt(s[3]+c@c);return c,r
def hsv(t):
    r,g,b=t[...,0],t[...,1],t[...,2];mx=t.max(-1);mn=t.min(-1);d=mx-mn+1e-6
    h=np.where(mx==r,((g-b)/d)%6,np.where(mx==g,(b-r)/d+2,(r-g)/d+4))*60
    return h,d/(mx+1e-6),mx
def proj(mask,col,name,view="front",res=0.0004,box=None):
    P=pos[mask];C=col[mask] if col.ndim==3 else col[mask]
    if view=="front":u,v,dep=P[:,1],P[:,2],-P[:,0];box=box or (-0.1,0.1,0.74,1.0)
    elif view=="side":u,v,dep=-P[:,0],P[:,2],P[:,1];box=box or (-0.13,0.13,0.74,1.0)
    elif view=="side2":u,v,dep=P[:,0],P[:,2],-P[:,1];box=box or (-0.13,0.13,0.74,1.0)
    elif view=="back":u,v,dep=-P[:,1],P[:,2],P[:,0];box=box or (-0.1,0.1,0.74,1.0)
    W=int((box[1]-box[0])/res);H=int((box[3]-box[2])/res)
    iu=((u-box[0])/res).astype(int);iv=((box[3]-v)/res).astype(int)
    ok=(iu>=0)&(iu<W)&(iv>=0)&(iv<H)
    iu,iv,dep,C=iu[ok],iv[ok],dep[ok],C[ok]
    o=np.argsort(dep);img=np.zeros((H,W,3),np.float32)
    img[iv[o],iu[o]]=C[o]  # later (nearer) overwrite
    Image.fromarray((np.clip(img,0,1)*255).astype(np.uint8)).save(name)
