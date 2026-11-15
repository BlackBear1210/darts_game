import time,sys
from common import *
T0=time.time()
m=np.load("mesh.npz");co,ls,lt,lv=m["co"],m["ls"],m["lt"],m["lv"]
F=len(ls);fidx=np.load("fidx.npy")
cls=np.load("classes.npy");eye,brow=cls[0],cls[1]
h,s,v=hsv(tex)
# face centers / normals (Newell)
fc=np.zeros((F,3));fn=np.zeros((F,3))
for k in range(3,5):
    sel=np.flatnonzero(lt==k)
    idx=ls[sel][:,None]+np.arange(k)[None];V=co[lv[idx]]
    fc[sel]=V.mean(1)
    nx=np.zeros((len(sel),3))
    for i in range(k):
        a=V[:,i];b=V[:,(i+1)%k];nx+=np.cross(a,b)
    fn[sel]=nx
assert (lt<=4).all()
area=np.linalg.norm(fn,axis=1)/2;fn/=np.maximum(np.linalg.norm(fn,axis=1,keepdims=True),1e-12)
# edges -> adjacent faces
ev=[];ef=[]
for k in range(3,5):
    sel=np.flatnonzero(lt==k);idx=ls[sel][:,None]+np.arange(k)[None];VI=lv[idx]
    for i in range(k):
        a=VI[:,i];b=VI[:,(i+1)%k];ev.append(np.c_[np.minimum(a,b),np.maximum(a,b)]);ef.append(sel)
ev=np.concatenate(ev);ef=np.concatenate(ef)
key=ev[:,0].astype(np.int64)*10**6+ev[:,1];o=np.argsort(key);key=key[o];ef=ef[o];ev=ev[o]
same=key[1:]==key[:-1]
fa=ef[:-1][same];fb=ef[1:][same];eva=ev[:-1][same]
print("faces",F,"interior edges",len(fa),round(time.time()-T0,1))
# per-face texel stats
t=fidx[cov];tf=t>=0
ti=t[tf]
def fmean(x):return np.bincount(ti,weights=x[cov][tf].astype(np.float64),minlength=F)/np.maximum(np.bincount(ti,minlength=F),1)
cnt=np.bincount(ti,minlength=F)
hairc=(h<20.5)&~(h>270)
fhair=fmean(hairc);feye=fmean(eye);fbrow=fmean(brow);fpur=fmean(h>270)
np.savez("faces.npz",fc=fc,fn=fn,area=area,fa=fa,fb=fb,eva=eva,cnt=cnt,fhair=fhair,feye=feye,fbrow=fbrow,fpur=fpur)
print("saved",round(time.time()-T0,1))
