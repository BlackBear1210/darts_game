import sys,json,time
from common import *
from vox import Grid,blur
OUTPNG=sys.argv[1]
T0=time.time()
h,s,v=hsv(tex);mn=tex.min(-1)
def lin(c):return np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
def srgb(c):c=np.clip(c,0,1);return np.where(c<=.0031308,c*12.92,1.055*c**(1/2.4)-.055)
def ss(x,a,b):t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
new=tex.copy();edited=np.zeros(cov.shape,bool);report={}
# ---------- 1. eyes (sphere fit) ----------
EYE_WHITE=np.array([0.94,0.92,0.88]);PUPIL=np.array([0.09,0.07,0.07])
eye_any=np.zeros(cov.shape,bool);eye_geo=[]
for side in [-1,1]:
    white=cov&(mn>0.62)&(s<0.25)&(Z>0.83)&(Z<0.90)&(X<-0.02)&(Y*side>0)
    P=pos[white]
    for it in range(3):
        c,R=fit_sphere(P);dd=np.linalg.norm(P-c,axis=1);P=P[np.abs(dd-R)<0.002]
    rel=pos-c;D=np.linalg.norm(rel,axis=-1);u=rel/np.maximum(D,1e-9)[...,None]
    radial=(u*nrm).sum(-1)
    shell=cov&(D>0.9*R)&(D<R*1.06)&(radial>0.85)
    dark=shell&(v<0.55)&(u[...,0]<-0.5)
    ax=u[dark].mean(0);ax/=np.linalg.norm(ax)
    ang=np.degrees(np.arccos(np.clip((u*ax).sum(-1),-1,1)))
    pupilzone=cov&(D>0.95*R)&(D<R*1.08)&(ang<14)
    eye=(shell&(D<R+0.0012))|pupilzone
    t=ss(ang,11.0,12.2)[...,None]
    col=srgb(lin(PUPIL)*(1-t)+lin(EYE_WHITE)*t)
    new[eye]=col[eye];edited|=eye;eye_any|=eye;eye_geo.append((c,R,ax))
    report[f"eye{side}"]={"center":c.round(5).tolist(),"R":float(R),"pupil_axis":ax.round(4).tolist(),"texels":int(eye.sum())}
np.save("eye_mask.npy",eye_any)
# ---------- 2. head classes ----------
HEAD=cov&(Z>0.74)&(np.abs(Y)<0.14)
G=Grid((-0.125,-0.15,0.73),(0.125,0.15,1.0),0.001)
def vote(ind,base,sigma_mm):
    P=pos[base];vals=np.c_[ind[base].astype(np.float32),np.ones(base.sum(),np.float32)]
    A=blur(G.splat(P,vals),sigma_mm)
    o=G.sample(A,P);p=np.zeros(cov.shape,np.float32);p[base]=o[:,0]/np.maximum(o[:,1],1e-6);return p
browbox=HEAD&(Z>0.85)&(Z<0.91)&(np.abs(Y)<0.10)&(X<-0.015)&~eye_any
browc=(h<17)|(v<0.5)
near=vote(browc,browbox,2.0)
def unit(a):return a/np.maximum(np.linalg.norm(a,axis=-1,keepdims=True),1e-9)
Pb=pos[browbox];Nb=unit(nrm[browbox])
A=blur(G.splat(Pb,np.c_[Pb,np.ones(len(Pb))]),5.0);o=G.sample(A,Pb)
hgt=np.zeros(cov.shape,np.float32);hgt[browbox]=((Pb-o[:,:3]/np.maximum(o[:,3:],1e-6))*Nb).sum(1)
raw=browbox&(near>0.15)&(hgt>0.0003)&(np.abs(Y)<0.09)
pb=vote(raw,browbox,0.6)
brow=browbox&(pb>0.35)
# keep only the two largest 3D-connected pieces (the brow bars)
gb=Grid((-0.125,-0.15,0.73),(0.125,0.15,1.0),0.0007)
vi=np.rint(gb.idx(pos[brow])).astype(np.int64)
occ={}
for k,t in enumerate(map(tuple,vi)):occ.setdefault(t,[]).append(k)
lab={};comps=[]
for start in occ:
    if start in lab:continue
    stack=[start];lab[start]=len(comps);members=[]
    while stack:
        c=stack.pop();members.append(c)
        for dx in (-1,0,1):
            for dy in (-1,0,1):
                for dz in (-1,0,1):
                    n=(c[0]+dx,c[1]+dy,c[2]+dz)
                    if n in occ and n not in lab:lab[n]=len(comps);stack.append(n)
    comps.append(members)
sizes=sorted([(sum(len(occ[c]) for c in m),i) for i,m in enumerate(comps)],reverse=True)
print("brow comps",[sz for sz,_ in sizes[:6]])
bi0=np.flatnonzero(brow.ravel());px=pos.reshape(-1,3)
def cmeanx(i):return float(np.mean([px[bi0[k]][0] for c in comps[i] for k in occ[c]]))
big=[i for sz,i in sizes if sz>1000]
keep=set(sorted(big,key=cmeanx)[:2])
print("brow comps meanX",[(round(cmeanx(i),4)) for i in big])
kidx=[k for i in keep for c in comps[i] for k in occ[c]]
bi=np.flatnonzero(brow.ravel());newb=np.zeros(brow.size,bool);newb[bi[kidx]]=True
brow=newb.reshape(brow.shape)
browt=ss(pb,0.35,0.65)
haircol=(h<17)|(v<0.45)
base=HEAD&~eye_any&~brow
ph=vote(haircol,base,2.5)
hairish=base&(ph>0.5)
phbig=vote(haircol,base,6.0)
hairzone=base&(phbig>0.3)&~(np.abs(Y)<0.0)
mouthbox=HEAD&(Z<0.84)&(Z>0.76)&(np.abs(Y)<0.035)&(X<-0.04)
keepdark=mouthbox&(v<0.6)
skin=HEAD&~eye_any&~brow&~hairish&~keepdark&~hairzone&(Z<0.935)&(h<60)
hairish=hairish&~brow
print("classes",dict(brow=int(brow.sum()),hair=int(hairish.sum()),skin=int(skin.sum()),keepdark=int(keepdark.sum())),round(time.time()-T0,1))
# ---------- 3. brow paint ----------
BROW=np.median(tex[brow&browc],0)
browpaint=brow  # alpha applied after skin field

# ---------- 4. skin smoothing ----------
donor=skin&(h>=17)&(v>0.5)
def field(mask,sigma):
    P=pos[mask];C=lin(new[mask])
    A=blur(G.splat(P,np.c_[C,np.ones(len(P))]),sigma)
    return A
A=field(donor,6.0)
o=G.sample(A,pos[skin]);sm=o[:,:3]/np.maximum(o[:,3:],1e-6)
# outlier rejection: drop donors far from smoothed and redo
dev=np.zeros(cov.shape,np.float32);dev[skin]=np.abs(lin(new[skin])-sm).max(1)
donor2=donor&(dev<0.08)
A=field(donor2,6.0)
o=G.sample(A,pos[skin]);sm=srgb(o[:,:3]/np.maximum(o[:,3:],1e-6))
SKIN_MED=np.median(sm,0)
sm=srgb(lin(sm)*0.5+lin(SKIN_MED)*0.5)
wz=ss(Z[skin],0.74,0.775)[:,None]
new[skin]=srgb(lin(new[skin])*(1-wz)+lin(sm)*wz);edited|=skin
# brow: blend over smoothed skin at the edge
A=field(donor2,3.0);ob=G.sample(A,pos[brow]);under=srgb(ob[:,:3]/np.maximum(ob[:,3:],1e-6))
under=srgb(lin(under)*0.5+lin(SKIN_MED)*0.5)
t=browt[brow][:,None];new[brow]=srgb(lin(under)*(1-t)+lin(BROW)*t);edited|=brow
report.update(brow_color=BROW.round(3).tolist(),classes=dict(brow=int(brow.sum()),hair=int(hairish.sum()),skin=int(skin.sum())))
np.save("classes.npy",np.stack([eye_any,brow,hairish,skin,keepdark]))
# ---------- 5. dilate edits into gutters ----------
def dilate_into(img,src,free,iters):
    img=img.copy();have=src.copy()
    for _ in range(iters):
        acc=np.zeros_like(img);cnt=np.zeros(have.shape,np.float32)
        for dy,dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
            sh=np.roll(np.roll(have,dy,0),dx,1);acc+=np.roll(np.roll(img*have[...,None],dy,0),dx,1);cnt+=sh
        grow=free&~have&(cnt>0)
        img[grow]=acc[grow]/cnt[grow][:,None];have|=grow
    return img
new=dilate_into(new,cov,~cov,10)
np.save('new_lin_cov.npy',edited)
Image.fromarray((np.clip(new,0,1)*255+0.5).astype(np.uint8)).save(OUTPNG)
json.dump(report,open(OUTPNG+".json","w"),indent=1)
print("done",round(time.time()-T0,1))
