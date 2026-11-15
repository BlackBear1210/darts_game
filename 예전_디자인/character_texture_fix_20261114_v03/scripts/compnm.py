from common import *
import sys
nm=Image.open(r"C:/Users/아버지/Desktop/다트/output/character_texture_fix_20261113_v01/textures/normal.jpg").convert("RGB").resize((2048,2048),Image.BICUBIC)
nm=np.asarray(nm).astype(np.float32)/255
t=np.clip(np.load("tan_nw_clean.npy")[::-1],0,1)
head=cov&(Z>0.66)&(np.abs(Y)<0.14)
m=head.copy()
for _ in range(10):  # grow head mask into gutters only
    g=m.copy()
    for dy,dx in [(-1,0),(1,0),(0,-1),(0,1)]:g|=np.roll(np.roll(m,dy,0),dx,1)
    m=m|(g&~cov)
# blend gutters: in gutter pixels, take baked where baked was dilated from head... baked has margin 0; fill gutters by dilation from head texels
def dilate(img,have,free,iters):
    img=img.copy();have=have.copy()
    for _ in range(iters):
        acc=np.zeros_like(img);cnt=np.zeros(have.shape,np.float32)
        for dy,dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
            cnt+=np.roll(np.roll(have,dy,0),dx,1);acc+=np.roll(np.roll(img*have[...,None],dy,0),dx,1)
        g=free&~have&(cnt>0);img[g]=acc[g]/cnt[g][:,None];have|=g
    return img
outn=nm.copy();outn[cov]=nm[cov];outn[head]=t[head]
# regenerate gutters from all covered texels (original for non-head)
full=dilate(outn,cov,~cov,10)
outn[m&~cov]=full[m&~cov]
Image.fromarray((outn*255+0.5).astype(np.uint8)).save(sys.argv[1])
print("ok")
